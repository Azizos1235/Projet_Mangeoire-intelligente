"""
Feeder AI service (runs on the Raspberry Pi).

Node-RED  --HTTP POST /predict (ESP32 JSON)-->  this service
  1. stores the day in SQLite (last 30 days per cow, survives reboots)
  2. builds the features with train_rf.build_features (same code as training)
  3. runs the model + thresholds (train_rf.predict)
  4. publishes {"esp32": <original data>, "model": <result>} to AMQP
  5. returns the same JSON to Node-RED

Settings (environment variables, all optional except AMQP_URL if you want publishing):
  MODEL_PATH     default appetite_models.joblib
  DB_PATH        default history.db
  AMQP_URL       e.g. amqp://user:pass@host:5672/%2F   (empty = do not publish)
  AMQP_EXCHANGE  default "" (default exchange)
  AMQP_ROUTING   routing key / queue name, default feeder.results
  EXPECTED_COWS  default 1. If the ESP32 simulates several cows, set the herd size N: the
                 service then waits until all N cows have sent a given date and only then
                 gives every cow her verdict (the model compares each cow with the herd of
                 the same day, so a verdict made before the others reported would differ
                 from training). 1 = answer immediately.
  PORT           default 8000
"""

import json
import os
import sqlite3
import threading

import joblib
import pandas as pd
from flask import Flask, jsonify, request

try:
    import pika
except ImportError:          # publishing is simply disabled without pika
    pika = None

import train_rf              # build_features / predict: identical to training

BASE = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.environ.get("MODEL_PATH", os.path.join(BASE, "appetite_models.joblib"))
DB_PATH = os.environ.get("DB_PATH", os.path.join(BASE, "history.db"))
AMQP_URL = os.environ.get("AMQP_URL", "")
AMQP_EXCHANGE = os.environ.get("AMQP_EXCHANGE", "")
AMQP_ROUTING = os.environ.get("AMQP_ROUTING", "feeder.results")
PORT = int(os.environ.get("PORT", "8000"))
EXPECTED_COWS = int(os.environ.get("EXPECTED_COWS", "1"))
KEEP_DAYS = 30           # enough for the 21-day windows used by the features
# A cow gets a verdict from her 15th day: the 14-day trend feature (food_vs_trend) needs
# 14 earlier days with no gap, even though the 7-day medians need only 7.
DAYS_NEEDED = 15

BUNDLE = joblib.load(MODEL_PATH)
CLASSES = BUNDLE["classes"]
MIN_HIST = BUNDLE["min_history"]
COLS = ["cow_id", "date", "age_months", "food_consumed_g", "feed_offered_g", "visits",
        "eating_minutes", "avg_meal_duration_min", "no_food_visits",
        "first_visit_hour", "last_visit_hour"]

db = sqlite3.connect(DB_PATH, check_same_thread=False)
db.execute("""CREATE TABLE IF NOT EXISTS days(
              cow_id TEXT, date TEXT, data TEXT, PRIMARY KEY(cow_id, date))""")
db.commit()
lock = threading.Lock()      # one request at a time (SQLite + pika are not thread-safe)

# ------------------------------ AMQP ---------------------------------------
_conn = _ch = None


def publish(msg):
    """Publish msg as JSON. Returns True/False; never raises."""
    global _conn, _ch
    if not AMQP_URL or pika is None:
        return False
    for _ in range(2):                       # second try = reconnect
        try:
            if _conn is None or _conn.is_closed:
                _conn = pika.BlockingConnection(pika.URLParameters(AMQP_URL))
                _ch = _conn.channel()
                if AMQP_EXCHANGE == "":
                    _ch.queue_declare(queue=AMQP_ROUTING, durable=True)
            _ch.basic_publish(
                exchange=AMQP_EXCHANGE, routing_key=AMQP_ROUTING,
                body=json.dumps(msg),
                properties=pika.BasicProperties(content_type="application/json",
                                                delivery_mode=2))
            return True
        except Exception as e:               # noqa: BLE001
            print("AMQP error:", e, flush=True)
            _conn = _ch = None
    return False


# ------------------------------ model --------------------------------------
def build_all():
    """Features for ALL stored cows (the herd features need the others)."""
    rows = [json.loads(r[0]) for r in db.execute("SELECT data FROM days")]
    return train_rf.build_features(pd.DataFrame(rows)[COLS])


def verdict(d, cow_id, date):
    """Verdict for one cow on one date, from the feature table d."""
    mine = d[(d["cow_id"] == cow_id) & (d["date"] == date)]
    n_days = int((d["cow_id"] == cow_id).sum())
    if mine.empty or not bool(mine["ready"].iloc[0]):
        return {"status": "insufficient_history", "days_stored": n_days,
                "days_needed": DAYS_NEEDED}
    out = train_rf.predict(mine, BUNDLE).iloc[0]
    return {"status": "ok",
            "category": out["category"],
            "p_flagged": round(float(out["p_flagged"]), 4),
            "probabilities": {c: round(float(out["p_" + c]), 4) for c in CLASSES},
            "alert": out["category"] != "normal"}


def answer(d, cow_id, date):
    """Verdict + original ESP32 data, published to AMQP."""
    data = json.loads(db.execute("SELECT data FROM days WHERE cow_id=? AND date=?",
                                 (cow_id, date)).fetchone()[0])
    try:
        result = verdict(d, cow_id, date)
    except Exception as e:               # noqa: BLE001
        print("model error:", e, flush=True)
        result = {"status": "error", "detail": str(e)}
    msg = {"esp32": data, "model": result}
    msg["published"] = publish(msg)
    return msg


app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify(status="up", classes=CLASSES, thresholds=BUNDLE["thresholds"],
                   amqp="on" if AMQP_URL else "off")


@app.post("/predict")
def predict_route():
    row = request.get_json(silent=True)
    if not isinstance(row, dict):
        return jsonify(error="JSON object expected"), 400
    missing = [c for c in COLS if c not in row]
    if missing:
        return jsonify(error=f"missing fields: {missing}"), 400

    with lock:
        db.execute("INSERT OR REPLACE INTO days VALUES (?,?,?)",
                   (row["cow_id"], row["date"], json.dumps(row)))
        db.execute("""DELETE FROM days WHERE cow_id=? AND date NOT IN
                      (SELECT date FROM days WHERE cow_id=? ORDER BY date DESC LIMIT ?)""",
                   (row["cow_id"], row["cow_id"], KEEP_DAYS))
        db.commit()
        date = row["date"]
        if EXPECTED_COWS > 1:
            reported = [r[0] for r in db.execute(
                "SELECT cow_id FROM days WHERE date=? ORDER BY cow_id", (date,))]
            if len(reported) < EXPECTED_COWS:
                return jsonify(esp32=row, published=False,
                               model={"status": "waiting_for_herd",
                                      "cows_reported": len(reported),
                                      "cows_expected": EXPECTED_COWS})
            d = build_all()                      # herd complete: everybody gets a verdict
            return jsonify([answer(d, cow, date) for cow in reported])
        return jsonify(answer(build_all(), row["cow_id"], date))


if __name__ == "__main__":
    app.run("127.0.0.1", PORT, threaded=False)