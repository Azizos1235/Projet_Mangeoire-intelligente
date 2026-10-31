"""
Generate a SYNTHETIC feeding_data.csv (one row per cow per day) for MEAT cattle.
THREE appetite classes: normal, decreased, increased  (the "irregular" class was removed).

Usage:  python generate_feeding_data.py [n_cows] [n_days] [output.csv]

Columns
  cow_id, date
  age_months             age of the cow on that day
  food_consumed_g        grams eaten that day
  feed_offered_g         grams made available that day
  visits                 visits to the feeder
  eating_minutes         total minutes eating
  avg_meal_duration_min  eating_minutes / (visits where she actually ate)
  no_food_visits         visits where she ate nothing (counted inside `visits`)
  first_visit_hour       hour of the first visit (5.8 = 05:48)
  last_visit_hour        hour of the last visit
  appetite_label         0 = normal, 1 = decreased, 2 = increased
  appetite_class         the same label as text

The three classes
  0 normal     intake and feeding pattern within her usual range
  1 decreased  eats clearly less than expected (episodes of 1-6 days), fewer
               visits, shorter eating time, later first / earlier last visit
  2 increased  eats clearly more than usual (episodes of 1-4 days), a bit more
               visiting and eating time. Limited by what was offered

What makes the data realistic (and not solvable by one simple rule)
  - ~25% of animals are young and still growing: their normal intake rises
    steadily with age (the model sees this through age_months). The others are
    mature animals with stable intake
  - every animal has her own baseline and slow drift
  - normal days that LOOK unusual, all labelled 0:
      * farm-wide heat days (everybody eats less)
      * farm-wide cold days (everybody eats a bit more)
      * farm-wide underfed days (little feed delivered)
      * individual small dips and small rises
  - a day is labelled abnormal ONLY if the change is clearly visible (see
    MIN_EFFECT); weak build-up days of an episode stay "normal"
  - an animal can never eat more than what was offered
  - ~1.5% of labels are replaced by a wrong class, like human labelling errors

This is for building and testing the pipeline only. A model trained on it
tells you nothing reliable about real animals: replace it with real farm data.
"""

import sys
import numpy as np
import pandas as pd

N_COWS = int(sys.argv[1]) if len(sys.argv) > 1 else 60
N_DAYS = int(sys.argv[2]) if len(sys.argv) > 2 else 180
OUT = sys.argv[3] if len(sys.argv) > 3 else "feeding_data.csv"
SEED = 42
GROWING_SHARE = 0.25
LABEL_NOISE = 0.015

# A day only gets an abnormal label when the change is clearly visible.
# The build-up days of a gradual episode that are still too weak stay "normal",
# like a vet would call them.
#   decreased: at least 15% less food than usual
#   increased: at least 12% more food than usual
MIN_EFFECT = {1: 0.15, 2: 0.12}

CLASS_NAMES = {0: "normal", 1: "decreased", 2: "increased"}
N_CLASSES = len(CLASS_NAMES)

rng = np.random.default_rng(SEED)
dates = pd.date_range("2026-01-01", periods=N_DAYS, freq="D")


def growth_level(age_m):
    """Fraction of adult intake for a growing animal (reaches 1.0 at 24 months)."""
    return float(np.clip(0.40 + 0.60 * (age_m - 6) / 18, 0.40, 1.0))


# ---- who is growing (used only to simulate; not written to the file) ------
n_growing = max(int(round(N_COWS * GROWING_SHARE)), 1)
growing_ids = set(
    rng.choice(np.arange(1, N_COWS + 1), size=n_growing, replace=False).tolist()
)

# ---- farm-wide normal events (shared by EVERY animal on the farm) ----------
farm_heat = np.zeros(N_DAYS)
for j in rng.choice(N_DAYS, size=max(N_DAYS // 30, 1), replace=False):
    farm_heat[j] = rng.uniform(0.08, 0.18)           # everybody eats 8-18% less
farm_cold = np.zeros(N_DAYS)
for j in rng.choice(N_DAYS, size=max(N_DAYS // 40, 1), replace=False):
    if farm_heat[j] == 0:
        farm_cold[j] = rng.uniform(0.05, 0.10)       # everybody eats 5-10% more
farm_offer = np.ones(N_DAYS)
for j in rng.choice(N_DAYS, size=max(N_DAYS // 45, 1), replace=False):
    farm_offer[j] = rng.uniform(0.72, 0.88)          # little feed delivered

rows = []
for c in range(1, N_COWS + 1):
    cow_id = f"C{c:03d}"
    growing_animal = c in growing_ids

    if growing_animal:
        age0 = rng.uniform(6, 18)
        base_food = rng.normal(7500, 1000)       # adult-equivalent intake
    else:
        age0 = rng.uniform(30, 96)
        base_food = rng.normal(8000, 1200)

    base_visits = rng.normal(11, 1.5)
    base_minutes = rng.normal(90, 10)
    base_nofood = rng.uniform(0.8, 1.8)
    offered_ratio = rng.uniform(1.15, 1.30)      # farm offers ~15-30% extra
    base_first = rng.normal(5.5, 0.8)
    base_last = rng.normal(21.5, 0.9)

    drift = np.cumsum(rng.normal(0, 0.003, N_DAYS))
    drift -= drift.mean()

    # ---- abnormal episodes: one class per episode -------------------------
    sev_dec = np.zeros(N_DAYS)                   # decreased severity 0..1
    sev_inc = np.zeros(N_DAYS)                   # increased: fraction eaten extra
    label = np.zeros(N_DAYS, dtype=int)

    day = int(rng.integers(5, 20))
    while day < N_DAYS - 1:
        if rng.random() < 0.65:
            cls = int(rng.choice([1, 2], p=[0.60, 0.40]))
            if cls == 1:
                length, peak = int(rng.integers(1, 7)), rng.uniform(0.30, 1.0)
            else:
                length, peak = int(rng.integers(1, 5)), rng.uniform(0.15, 0.35)
            gradual = rng.random() < 0.5
            for i in range(length):
                if day + i >= N_DAYS:
                    break
                ramp = (i + 1) / length if gradual else 1.0
                sev = peak * ramp
                effect = 0.65 * sev if cls == 1 else sev        # food change
                if cls == 1:
                    sev_dec[day + i] = sev
                else:
                    sev_inc[day + i] = sev
                if effect >= MIN_EFFECT[cls]:                   # only clearly visible days are labelled
                    label[day + i] = cls
            day += length + int(rng.integers(8, 30))
        else:
            day += int(rng.integers(6, 20))

    # An animal cannot eat more than was offered, so on farm-wide underfed days
    # an "increased" episode is not possible: drop it.
    for t in range(N_DAYS):
        if sev_inc[t] > 0 and farm_offer[t] < 1:
            sev_inc[t] = 0.0
            if label[t] == 2:
                label[t] = 0

    # ---- individual NORMAL dips and rises (label stays 0) -----------------
    dip = np.zeros(N_DAYS)
    rise = np.zeros(N_DAYS)
    for _ in range(max(int(N_DAYS * 0.015), 1)):
        j = int(rng.integers(0, N_DAYS))
        if label[j] == 0:
            dip[j] = rng.uniform(0.08, 0.18)
    for _ in range(max(int(N_DAYS * 0.015), 1)):
        j = int(rng.integers(0, N_DAYS))
        if label[j] == 0 and dip[j] == 0:
            rise[j] = rng.uniform(0.05, 0.10)

    for t in range(N_DAYS):
        age_t = age0 + t / 30.4
        t_off = (t // 14) * 14                    # farm adjusts feed every 2 weeks
        if growing_animal:
            level = growth_level(age_t)
            level_off = growth_level(age0 + t_off / 30.4)
        else:
            level = level_off = 1.0               # mature: stable intake

        d_sev, i_sev = sev_dec[t], sev_inc[t]
        down = farm_heat[t] + dip[t]              # normal reasons to eat less
        up = farm_cold[t] + rise[t]               # normal reasons to eat more

        offered = base_food * level_off * offered_ratio * rng.normal(1, 0.04)
        offered *= farm_offer[t]

        food = (base_food * level * (1 + drift[t]) * (1 - 0.65 * d_sev)
                * (1 - down) * (1 + i_sev) * (1 + up))
        food *= rng.normal(1, 0.07)
        food = min(food, offered * rng.uniform(0.95, 0.99))     # cannot eat more than offered

        v_mult = ((0.7 + 0.3 * level) * (1 + drift[t]) * (1 - 0.55 * d_sev)
                  * (1 - 0.5 * down) * (1 + 0.5 * i_sev) * (1 + 0.3 * up))
        m_mult = ((0.75 + 0.25 * level) * (1 + drift[t]) * (1 - 0.60 * d_sev)
                  * (1 - 0.5 * down) * (1 + 0.8 * i_sev) * (1 + 0.5 * up))

        visits = int(max(round(base_visits * v_mult * rng.normal(1, 0.10)), 1))
        minutes = int(max(round(base_minutes * m_mult * rng.normal(1, 0.08)), 5))
        nofood = int(rng.poisson(base_nofood + 3.0 * d_sev + 0.5 * down))
        nofood = min(nofood, visits - 1)
        meals = max(visits - nofood, 1)

        first = base_first + 3.0 * d_sev * rng.uniform(0.5, 1.0) + rng.normal(0, 0.5)
        last = base_last - 3.0 * d_sev * rng.uniform(0.5, 1.0) + rng.normal(0, 0.6)
        first = float(np.clip(first, 0, 14))
        last = float(np.clip(last, first + 4, 24))

        rows.append({
            "cow_id": cow_id,
            "date": dates[t].date().isoformat(),
            "age_months": round(age_t, 1),
            "food_consumed_g": int(max(food, 300)),
            "feed_offered_g": int(max(offered, 1000)),
            "visits": visits,
            "eating_minutes": minutes,
            "avg_meal_duration_min": round(minutes / meals, 1),
            "no_food_visits": nofood,
            "first_visit_hour": round(first, 1),
            "last_visit_hour": round(last, 1),
            "appetite_label": int(label[t]),
        })

df = pd.DataFrame(rows)

# Label noise: replace ~1.5% of labels with a different, wrong class
flip = rng.random(len(df)) < LABEL_NOISE
shift = rng.integers(1, N_CLASSES, size=int(flip.sum()))
df.loc[flip, "appetite_label"] = (df.loc[flip, "appetite_label"] + shift) % N_CLASSES

df["appetite_class"] = df["appetite_label"].map(CLASS_NAMES)
df.to_csv(OUT, index=False)

print(f"Wrote {OUT}: {len(df)} rows, {df.cow_id.nunique()} animals "
      f"({n_growing} growing), {N_DAYS} days each")
print("Class counts:")
counts = df["appetite_class"].value_counts()
for k, name in CLASS_NAMES.items():
    print(f"  {k} {name:<10} {counts.get(name, 0):>7}  ({counts.get(name, 0) / len(df):.1%})")