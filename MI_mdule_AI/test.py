"""
Test the trained model on your own machine (no Raspberry Pi, no Atlas, no service).

Put this file next to train_rf.py and appetite_models.joblib, then:
    python test_local.py                    # made-up normal / decreased / increased days
    python test_local.py feeding_data.csv   # the same, plus real labeled days from your CSV

For every scenario it builds 200 random trials: a week of ordinary days (about +-6% noise
around the "usual" values) followed by one test day. Each trial goes through the same
code the service uses (train_rf.build_features + train_rf.predict).
"""

import sys
from datetime import datetime, timedelta

import joblib
import numpy as np
import pandas as pd

import train_rf

MODEL = "appetite_models.joblib"
TRIALS = 200
TODAY = datetime(2026, 11, 29)

# the cow's usual values (medians of cow EDFF4D24, 2026-11-22 .. 2026-11-28). Edit freely.
USUAL = {"age_months": 61.9, "food_consumed_g": 6808, "feed_offered_g": 8973,
         "visits": 10, "eating_minutes": 105, "avg_meal_duration_min": 12.3,
         "no_food_visits": 2, "first_visit_hour": 6.7, "last_visit_hour": 19.8}

# name, expected category, how today differs from usual
SCENARIOS = [
    ("normal day", "normal", {}),
    ("decreased, strong (food x0.5)", "decreased",
     dict(food=0.5, visits=0.4, minutes=0.45, meal=0.7, no_food=3, first=1.8, last=-2.8)),
    ("decreased, medium (food x0.7)", "decreased",
     dict(food=0.7, visits=0.7, minutes=0.75, meal=0.9, no_food=3)),
    ("decreased, mild (food x0.85)", "borderline", dict(food=0.85, visits=0.9, minutes=0.9)),
    ("increased, strong (food x1.6)", "increased",
     dict(food=1.6, visits=1.6, minutes=1.65, meal=1.15, first=-1.2, last=0.7)),
    ("increased, medium (food x1.35)", "increased",
     dict(food=1.35, visits=1.3, minutes=1.3, meal=1.05)),
    ("increased, mild (food x1.15)", "borderline", dict(food=1.15, visits=1.1, minutes=1.1)),
]


def day_row(cow, date, rng, f=None, noise=0.06):
    f = f or {}
    u = USUAL

    def jit(x):
        return x * (1 + rng.uniform(-noise, noise))

    return {
        "cow_id": cow, "date": date.strftime("%Y-%m-%d"), "age_months": u["age_months"],
        "food_consumed_g": round(jit(u["food_consumed_g"] * f.get("food", 1.0))),
        "feed_offered_g": round(jit(u["feed_offered_g"])),
        "visits": max(1, round(jit(u["visits"] * f.get("visits", 1.0)))),
        "eating_minutes": round(jit(u["eating_minutes"] * f.get("minutes", 1.0))),
        "avg_meal_duration_min": round(jit(u["avg_meal_duration_min"] * f.get("meal", 1.0)), 1),
        "no_food_visits": max(0, round(jit(f.get("no_food", u["no_food_visits"])))),
        "first_visit_hour": round(jit(u["first_visit_hour"]) + f.get("first", 0.0), 1),
        "last_visit_hour": round(jit(u["last_visit_hour"]) + f.get("last", 0.0), 1),
    }


def test_scenarios(bundle):
    rng = np.random.default_rng(1)
    rows = []
    for si, (_, _, f) in enumerate(SCENARIOS):
        for k in range(TRIALS):
            cow = f"S{si}_{k}"
            for i in range(7):                                   # 7 ordinary days
                rows.append(day_row(cow, TODAY - timedelta(days=7 - i), rng))
            rows.append(day_row(cow, TODAY, rng, f, noise=0.04))   # the test day
    d = train_rf.build_features(pd.DataFrame(rows))
    d = d[d["ready"] & (d["date"] == TODAY.strftime("%Y-%m-%d"))]
    out = train_rf.predict(d, bundle)
    out["scenario"] = out["cow_id"].str.extract(r"^S(\d+)_")[0].astype(int)

    print(f"{'scenario':<34}{'expected':<11}{'normal':>8}{'decreased':>11}{'increased':>11}"
          f"{'avg P(dec)':>12}{'avg P(inc)':>12}")
    for si, (name, expected, _) in enumerate(SCENARIOS):
        g = out[out["scenario"] == si]
        share = g["category"].value_counts(normalize=True)
        print(f"{name:<34}{expected:<11}{share.get('normal', 0):>8.0%}"
              f"{share.get('decreased', 0):>11.0%}{share.get('increased', 0):>11.0%}"
              f"{g['p_decreased'].mean():>12.3f}{g['p_increased'].mean():>12.3f}")
    print("\nA good model: 'normal day' mostly normal (few false alarms); the strong and medium"
          "\ncases mostly decreased / increased. The mild cases may go either way.")


def test_csv(bundle, path):
    from sklearn.metrics import classification_report
    df = pd.read_csv(path)
    df["appetite_class"] = df["appetite_class"].replace("irregular", "normal")
    d = train_rf.build_features(df)
    d = d[d["ready"]]
    parts = [g.sample(min(len(g), 3000), random_state=1)
             for _, g in d.groupby("appetite_class")]
    d = pd.concat(parts)
    out = train_rf.predict(d, bundle)
    print(f"\nReal labeled days from {path} ({len(d)} sampled).")
    print("Note: the saved model was trained on ALL cows, so these scores are optimistic;"
          "\nthe honest held-out scores are the ones printed at the end of training.\n")
    print(classification_report(out["appetite_class"], out["category"],
                                labels=train_rf.CLASSES, zero_division=0))


def main():
    bundle = joblib.load(MODEL)
    if list(bundle["feats"]) != list(train_rf.FEATS):
        sys.exit("appetite_models.joblib and train_rf.py do not match: retrain, "
                 "or use the train_rf.py that created this model.")
    test_scenarios(bundle)
    if len(sys.argv) > 1:
        test_csv(bundle, sys.argv[1])


if __name__ == "__main__":
    main()