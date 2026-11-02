"""
Appetite model: normal / decreased / increased, from the last 7 days of a cow.
Reads feeding_data.csv (edit CSV_PATH below to use another file).
Every feature uses ONLY today + the 7 days before it (8 rows needed per prediction).
service.py imports build_features() and predict() from here and loads appetite_models.joblib.

HERD = True adds "cow vs herd on the same date" features. The service must then pass the
rows of ALL cows for the day (the history of every cow), not only the one cow.
"""

import os
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import GroupKFold

SEED = 42
CLASSES = ["normal", "decreased", "increased"]
MIN_HISTORY = 7          # earlier days a cow needs before she gets a verdict
CSV_PATH = "feeding_data.csv"
OUT_FILE = "appetite_models.joblib"
INC_PRECISION = 0.87     # precision target for "increased" (0.0 = best F1)
DROP_IRREGULAR = False   # False: irregular -> normal.  True: ignore irregular days in training
HERD = False             # True: add cow-vs-herd features (needs all cows' rows in the service)

BASE_COLS = ["food_consumed_g", "visits", "eating_minutes", "avg_meal_duration_min",
             "no_food_visits", "first_visit_hour", "last_visit_hour", "feed_offered_g"]
# name -> (column, minimum spread as a share of the median)
SCALES = {"food": ("food_consumed_g", 0.03), "visits": ("visits", 0.08),
          "minutes": ("eating_minutes", 0.05), "meal": ("avg_meal_duration_min", 0.08)}
PERSIST = {"food": "food_consumed_g", "minutes": "eating_minutes", "visits": "visits"}

FEATS_BASE = ["food_vs_med7", "food_z", "food_vs_lag1", "food_vs_trend", "food_vs_offered",
              "visits_vs_med7", "visits_z", "minutes_vs_med7", "minutes_z",
              "meal_vs_med7", "meal_z", "nofood_minus_med7", "nofood_share",
              "first_shift", "last_shift", "age_months"]
# offered feed vs its own 7-day median (a feed change is not an appetite change)
FEATS_OFFER = ["offered_vs_med7"]
FEATS_HERD = ["herd_food_vs_med7", "food_vs_herd", "herd_minutes_vs_med7", "minutes_vs_herd"]
FEATS = (FEATS_BASE + FEATS_OFFER + (FEATS_HERD if HERD else []) + ["up_score"] +
         ["food_shift3v4", "minutes_shift3v4", "visits_shift3v4",
          "food_lag1_vs_med7", "food_lag2_vs_med7", "days_above_med3"])


# ------------------------------ features ------------------------------------
def _trend_next(w):
    """Straight line through the window; predicted value for the next day."""
    w = w[~np.isnan(w)]
    n = len(w)
    if n < 2:
        return np.nan
    x = np.arange(n)
    xm = x.mean()
    slope = ((x - xm) * (w - w.mean())).sum() / ((x - xm) ** 2).sum()
    return w.mean() + slope * (n - xm)


def _robust_scale(s, floor_share, med, w=7):
    """Spread of the last w days (IQR / 1.35), never below a share of the median."""
    r = s.shift(1).rolling(w, min_periods=w)
    return np.maximum((r.quantile(0.75) - r.quantile(0.25)) / 1.35, floor_share * med)


def build_features(df):
    """Compare each day with the cow's OWN previous days. Returns all rows plus `ready`."""
    df = df.sort_values(["cow_id", "date"]).reset_index(drop=True)
    parts = []
    for _, g in df.groupby("cow_id", sort=False):
        g = g.copy()
        g["n_history"] = np.arange(len(g))
        for c in BASE_COLS:
            g[c + "_med7"] = g[c].shift(1).rolling(7, min_periods=MIN_HISTORY).median()
        f = g["food_consumed_g"].shift(1)
        g["food_lag1"], g["food_lag2"], g["food_lag3"] = f, g["food_consumed_g"].shift(2), g["food_consumed_g"].shift(3)
        for k, (c, floor) in SCALES.items():
            g[k + "_scale7"] = _robust_scale(g[c], floor, g[c + "_med7"])
        g["food_trend"] = f.rolling(7, min_periods=MIN_HISTORY).apply(_trend_next, raw=True)
        for k, c in PERSIST.items():  # last 3 earlier days vs the 4 before them
            prev = g[c].shift(1)
            g[k + "_rec3"], g[k + "_old4"] = prev.rolling(3).mean(), prev.shift(3).rolling(4).mean()
        parts.append(g)
    d = pd.concat(parts, ignore_index=True)

    food, med = d["food_consumed_g"], d["food_consumed_g_med7"]
    d["has_baseline"] = d["n_history"] >= MIN_HISTORY
    d["food_vs_trend"] = food / d["food_trend"]
    # an animal cannot really eat more than was offered: sensor noise above 1.0 is clipped
    d["food_vs_offered"] = (food / d["feed_offered_g"]).clip(upper=1.0)
    d["food_vs_lag1"] = food / d["food_lag1"]
    d["offered_vs_med7"] = d["feed_offered_g"] / d["feed_offered_g_med7"]
    for k, (c, _) in SCALES.items():
        d[k + "_vs_med7"] = d[c] / d[c + "_med7"]
        d[k + "_z"] = (d[c] - d[c + "_med7"]) / d[k + "_scale7"]
    d["nofood_minus_med7"] = d["no_food_visits"] - d["no_food_visits_med7"]
    d["nofood_share"] = d["no_food_visits"] / d["visits"].clip(lower=1)
    d["first_shift"] = d["first_visit_hour"] - d["first_visit_hour_med7"]
    d["last_shift"] = d["last_visit_hour"] - d["last_visit_hour_med7"]
    # food, eating time and visits rising together
    d["up_score"] = ((d["food_vs_med7"] - 1) + 0.6 * (d["minutes_vs_med7"] - 1)
                     + 0.4 * (d["visits_vs_med7"] - 1))
    # persistence features
    for k in PERSIST:
        d[k + "_shift3v4"] = d[k + "_rec3"] / d[k + "_old4"]
    d["food_lag1_vs_med7"] = d["food_lag1"] / med
    d["food_lag2_vs_med7"] = d["food_lag2"] / med
    d["days_above_med3"] = sum((d[f"food_lag{i}"] > med).astype(int) for i in (1, 2, 3))
    # herd context: what the whole herd did on the same date (farm-wide heat / cold / feed days)
    if HERD:
        for k in ("food", "minutes"):
            d[f"herd_{k}_vs_med7"] = d.groupby("date")[k + "_vs_med7"].transform("median")
            d[k + "_vs_herd"] = d[k + "_vs_med7"] / d[f"herd_{k}_vs_med7"]

    d = d.replace([np.inf, -np.inf], np.nan)
    d["up_score"] = d["up_score"].fillna(0.0)
    neutral = ["food_shift3v4", "minutes_shift3v4", "visits_shift3v4",
               "food_lag1_vs_med7", "food_lag2_vs_med7"]
    d[neutral] = d[neutral].fillna(1.0)
    d["ready"] = d["has_baseline"] & d[FEATS].notna().all(axis=1)
    return d


# ------------------------------ decision rule -------------------------------
def decide(proba, thresholds):
    """A class is raised when its probability passes its threshold; larger margin wins."""
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
    """Best-F1 threshold; with min_precision: highest recall reaching that precision."""
    n_pos = max(int(is_k.sum()), 1)
    stats = []
    for t in np.arange(0.05, 0.96, 0.01):
        flag = p >= t
        n, tp = int(flag.sum()), int((flag & is_k).sum())
        prec, rec = (tp / n if n else 0.0), tp / n_pos
        stats.append((t, n, prec, rec, 2 * prec * rec / (prec + rec) if prec + rec else 0.0))
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
    """Lower n_estimators / max_depth or raise min_samples_leaf if the file is too big for the Pi."""
    return RandomForestClassifier(n_estimators=100, min_samples_leaf=15, max_depth=16,
                                  max_samples=0.5, class_weight="balanced_subsample",
                                  random_state=SEED, n_jobs=-1)


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


def main(path=CSV_PATH):
    print("reading the CSV and building features...", flush=True)
    d = build_features(pd.read_csv(path))
    rows = d[d["ready"]].copy()
    if DROP_IRREGULAR:
        rows = rows[rows["appetite_class"] != "irregular"].copy()
    else:
        rows["appetite_class"] = rows["appetite_class"].replace("irregular", "normal")
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
    pred = decide(make_model().fit(X, yt).predict_proba(rows.loc[test, FEATS]), thresholds)
    print(classification_report(y[test], pred, labels=range(len(CLASSES)),
                                target_names=CLASSES, zero_division=0))
    print("confusion matrix (rows = true, columns = predicted: normal, decreased, increased)")
    print(confusion_matrix(y[test], pred, labels=range(len(CLASSES))))

    # 3. final model on ALL cows, saved for the Raspberry Pi
    print("training the final model...", flush=True)
    final = make_model().fit(rows[FEATS], y)
    final.n_jobs = 1
    joblib.dump({"model": final, "classes": CLASSES, "feats": FEATS,
                 "thresholds": thresholds, "min_history": MIN_HISTORY, "herd": HERD},
                OUT_FILE, compress=3)
    print(f"saved {OUT_FILE} ({os.path.getsize(OUT_FILE) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()