"""
Appetite model: normal / decreased / increased, from the last 7 days of a cow.

Usage:  python train_rf.py feeding_data.csv
CSV columns: cow_id, date, age_months, food_consumed_g, feed_offered_g, visits,
eating_minutes, avg_meal_duration_min, no_food_visits, first_visit_hour,
last_visit_hour, appetite_class   (pen_id is optional)

Every feature uses ONLY today + the 7 days before it, so training on the whole CSV and
predicting from 8 rows in the service give exactly the same numbers.
The service (service.py) imports build_features() and predict() from this file and
loads the saved appetite_models.joblib.
"""

import os
import sys

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
from sklearn.model_selection import GroupKFold

SEED = 42
CLASSES = ["normal", "decreased", "increased"]
MIN_HISTORY = 7          # earlier days a cow needs before she gets a verdict
OUT_FILE = "appetite_models.joblib"
INC_PRECISION = 0.85     # precision target for "increased" (fewer false alarms)

BASE_COLS = ["food_consumed_g", "visits", "eating_minutes", "avg_meal_duration_min",
             "no_food_visits", "first_visit_hour", "last_visit_hour"]

FEATS_BASE = [
    # food: today compared with her own last 7 days
    "food_vs_med7", "food_z", "food_vs_lag1", "food_vs_trend", "food_vs_offered",
    # visits and meal pattern: today compared with her own last 7 days
    "visits_vs_med7", "visits_z", "minutes_vs_med7", "minutes_z",
    "meal_vs_med7", "meal_z", "nofood_minus_med7", "nofood_share",
    "first_shift", "last_shift",
    "age_months",
]
# food, eating time and visits rising together
FEATS_EXTRA = ["up_score"]
FEATS = FEATS_BASE + FEATS_EXTRA


# ------------------------------ features ------------------------------------
def _trend_next(w):
    """Straight line through the window; predicted value for the next day.
    Empty values (the first day has no 'yesterday') are ignored."""
    w = w[~np.isnan(w)]
    n = len(w)
    if n < 2:
        return np.nan
    x = np.arange(n)
    xm = x.mean()
    slope = ((x - xm) * (w - w.mean())).sum() / ((x - xm) ** 2).sum()
    return w.mean() + slope * (n - xm)


def _robust_scale(s, floor_share, med):
    """Spread of the last 7 days (IQR / 1.35), never below a share of the median."""
    r = s.shift(1).rolling(7, min_periods=MIN_HISTORY)
    return np.maximum((r.quantile(0.75) - r.quantile(0.25)) / 1.35, floor_share * med)


def build_features(df):
    """Compare each day with the cow's OWN previous 7 days (today is never part of her
    baseline). Returns all rows plus a boolean `ready`."""
    df = df.sort_values(["cow_id", "date"]).reset_index(drop=True)
    parts = []
    for _, g in df.groupby("cow_id", sort=False):
        g = g.copy()
        g["n_history"] = np.arange(len(g))
        for c in BASE_COLS:
            g[c + "_med7"] = g[c].shift(1).rolling(7, min_periods=MIN_HISTORY).median()
        f = g["food_consumed_g"].shift(1)
        g["food_lag1"] = f
        g["food_scale7"] = _robust_scale(g["food_consumed_g"], 0.03, g["food_consumed_g_med7"])
        g["visits_scale7"] = _robust_scale(g["visits"], 0.08, g["visits_med7"])
        g["minutes_scale7"] = _robust_scale(g["eating_minutes"], 0.05, g["eating_minutes_med7"])
        g["meal_scale7"] = _robust_scale(g["avg_meal_duration_min"], 0.08,
                                         g["avg_meal_duration_min_med7"])
        g["food_trend"] = f.rolling(7, min_periods=MIN_HISTORY).apply(_trend_next, raw=True)
        parts.append(g)
    d = pd.concat(parts, ignore_index=True)

    food = d["food_consumed_g"]
    d["has_baseline"] = d["n_history"] >= MIN_HISTORY
    d["food_vs_med7"] = food / d["food_consumed_g_med7"]
    d["food_vs_trend"] = food / d["food_trend"]
    d["food_vs_offered"] = food / d["feed_offered_g"]
    d["food_vs_lag1"] = food / d["food_lag1"]
    d["food_z"] = (food - d["food_consumed_g_med7"]) / d["food_scale7"]
    d["visits_vs_med7"] = d["visits"] / d["visits_med7"]
    d["visits_z"] = (d["visits"] - d["visits_med7"]) / d["visits_scale7"]
    d["minutes_vs_med7"] = d["eating_minutes"] / d["eating_minutes_med7"]
    d["minutes_z"] = (d["eating_minutes"] - d["eating_minutes_med7"]) / d["minutes_scale7"]
    d["meal_vs_med7"] = d["avg_meal_duration_min"] / d["avg_meal_duration_min_med7"]
    d["meal_z"] = (d["avg_meal_duration_min"] - d["avg_meal_duration_min_med7"]) / d["meal_scale7"]
    d["nofood_minus_med7"] = d["no_food_visits"] - d["no_food_visits_med7"]
    d["nofood_share"] = d["no_food_visits"] / d["visits"].clip(lower=1)
    d["first_shift"] = d["first_visit_hour"] - d["first_visit_hour_med7"]
    d["last_shift"] = d["last_visit_hour"] - d["last_visit_hour_med7"]

    # food, eating time and visits rising together
    d["up_score"] = ((d["food_vs_med7"] - 1) + 0.6 * (d["minutes_vs_med7"] - 1)
                     + 0.4 * (d["visits_vs_med7"] - 1))

    d = d.replace([np.inf, -np.inf], np.nan)
    d["up_score"] = d["up_score"].fillna(0.0)
    d["ready"] = d["has_baseline"] & d[FEATS_BASE].notna().all(axis=1)
    return d


# ------------------------------ decision rule -------------------------------
def decide(proba, thresholds):
    """One threshold per abnormal class (decreased, increased). A class is raised
    when its probability passes its threshold; if both pass, the larger margin wins."""
    score = proba[:, 1:] / np.asarray(thresholds)[None, :]
    raised = score >= 1.0
    best = 1 + np.where(raised, score, -np.inf).argmax(axis=1)
    return np.where(raised.any(axis=1), best, 0)


def predict(rows, bundle):
    """Add class probabilities and the final category to each row (used by the service)."""
    rows = rows.copy()
    proba = bundle["model"].predict_proba(rows[bundle["feats"]])
    for i, c in enumerate(bundle["classes"]):
        rows["p_" + c] = proba[:, i]
    idx = decide(proba, bundle["thresholds"])
    rows["category"] = [bundle["classes"][i] for i in idx]
    rows["p_flagged"] = [proba[r, i] if i else 1 - proba[r, 0] for r, i in enumerate(idx)]
    return rows


def pick_threshold(p, is_k, min_precision=0.0, min_flagged=30):
    """Best-F1 threshold; with min_precision: the highest-recall threshold that reaches
    that precision (at least min_flagged alerts), else the most precise one."""
    n_pos = max(int(is_k.sum()), 1)
    stats = []
    for t in np.arange(0.05, 0.96, 0.01):
        flag = p >= t
        n = int(flag.sum())
        tp = int((flag & is_k).sum())
        prec = tp / n if n else 0.0
        rec = tp / n_pos
        f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        stats.append((t, n, prec, rec, f1))
    if min_precision > 0:
        ok = [s for s in stats if s[1] >= min_flagged and s[2] >= min_precision]
        if ok:
            return max(ok, key=lambda s: s[3])[0]
        ok = [s for s in stats if s[1] >= min_flagged]
        if ok:
            return max(ok, key=lambda s: s[2])[0]
    return max(stats, key=lambda s: s[4])[0]


# ------------------------------ training ------------------------------------
def make_model():
    """Random Forest. A bigger forest = bigger file; if appetite_models.joblib is too
    large for the Pi, lower n_estimators / max_depth or raise min_samples_leaf."""
    return RandomForestClassifier(n_estimators=100, min_samples_leaf=30, max_depth=14,
                                  max_samples=0.5, random_state=SEED, n_jobs=-1)


def split_cows(rows, test_share=0.25):
    """Hold out whole cows (young and mature animals in both sets)."""
    rng = np.random.default_rng(SEED)
    first = rows.sort_values("date").groupby("cow_id").first()
    young = (first["age_months"] < 24).to_numpy()
    test = []
    for flag in (False, True):
        ids = first.index[young == flag].to_numpy()
        if len(ids):
            test += rng.choice(ids, size=max(int(round(len(ids) * test_share)), 1),
                               replace=False).tolist()
    return test


def main(path):
    print("reading the CSV and building features...", flush=True)
    df = pd.read_csv(path)
    df["appetite_class"] = df["appetite_class"].replace("irregular", "normal")
    d = build_features(df)
    rows = d[d["ready"]].copy()
    y = rows["appetite_class"].map({c: i for i, c in enumerate(CLASSES)}).to_numpy()
    cows = rows["cow_id"].to_numpy()
    test = rows["cow_id"].isin(split_cows(rows)).to_numpy()
    train = ~test
    print(f"{len(rows)} rows: {len(set(cows[train]))} cows for training, "
          f"{len(set(cows[test]))} held-out cows", flush=True)

    # 1. thresholds from cross-validation by cow on the training cows
    X, yt, g = rows.loc[train, FEATS], y[train], cows[train]
    oof = np.zeros((len(X), len(CLASSES)))
    for i, (a, b) in enumerate(GroupKFold(5).split(X, yt, g), 1):
        print(f"cross-validation fold {i}/5...", flush=True)
        oof[b] = make_model().fit(X.iloc[a], yt[a]).predict_proba(X.iloc[b])
    thresholds = [float(round(pick_threshold(oof[:, k], yt == k,
                                             INC_PRECISION if k == 2 else 0.0), 2))
                  for k in (1, 2)]
    print("thresholds (decreased, increased):", thresholds, flush=True)

    # 2. check on cows the model never saw
    print("training the test model...", flush=True)
    m = make_model().fit(X, yt)
    pred = decide(m.predict_proba(rows.loc[test, FEATS]), thresholds)
    print(classification_report(y[test], pred, labels=range(len(CLASSES)),
                                target_names=CLASSES, zero_division=0))

    # 3. final model on ALL cows, saved for the Raspberry Pi
    print("training the final model...", flush=True)
    final = make_model().fit(rows[FEATS], y)
    final.n_jobs = 1          # the Pi predicts one row at a time: no thread overhead
    joblib.dump({"model": final, "classes": CLASSES, "feats": FEATS,
                 "thresholds": thresholds, "min_history": MIN_HISTORY},
                OUT_FILE, compress=3)
    print(f"saved {OUT_FILE} ({os.path.getsize(OUT_FILE) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "feeding_data.csv")