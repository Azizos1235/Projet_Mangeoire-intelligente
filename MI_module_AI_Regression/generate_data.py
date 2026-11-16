import numpy as np
import pandas as pd

rng = np.random.default_rng(42)

N_COWS = 25_000
RECORDS_PER_COW = 20          # 25,000 x 20 = 500,000 rows

# name: (type, mature_weight_kg, weight_sd, intake_coefficient_k, probability)
# intake (kg dry matter/day) ~ k * weight^0.75 (metabolic body weight)
BREEDS = {
    "Holstein":  ("dairy", 650, 50, 0.165, 0.30),
    "Jersey":    ("dairy", 430, 35, 0.170, 0.10),
    "Angus":     ("beef",  600, 50, 0.100, 0.25),
    "Limousin":  ("beef",  700, 60, 0.098, 0.15),
    "Charolais": ("beef",  800, 70, 0.095, 0.10),
    "Simmental": ("dual",  700, 60, 0.125, 0.10),
}

names = list(BREEDS)
probs = np.array([BREEDS[b][4] for b in names])   # FIXED: index 4
probs /= probs.sum()

# --- per-cow attributes -----------------------------------------------------
breed = rng.choice(names, size=N_COWS, p=probs)
cow_type = np.array([BREEDS[b][0] for b in breed])
mature_w = np.array([rng.normal(BREEDS[b][1], BREEDS[b][2]) for b in breed])
k_intake = np.array([BREEDS[b][3] for b in breed])
growth_rate = rng.normal(0.09, 0.01, N_COWS).clip(0.06, 0.12)   # per month
start_age = rng.uniform(6, 60, N_COWS)                           # months
cow_eff = rng.normal(1.0, 0.04, N_COWS)                          # individual appetite

# --- expand to records ------------------------------------------------------
cow_id = np.repeat(np.arange(N_COWS), RECORDS_PER_COW)
step = np.tile(np.arange(RECORDS_PER_COW), N_COWS)

def rep(x):
    return np.repeat(x, RECORDS_PER_COW)

age = rep(start_age) + step * 2                                  # months

# Growth curve (von Bertalanffy-style)
weight = rep(mature_w) * (1 - 0.6 * np.exp(-rep(growth_rate) * age)) ** 3
weight *= rng.normal(1.0, 0.03, len(weight))                     # measurement/day noise

# --- intake model -----------------------------------------------------------
metabolic_w = weight ** 0.75
growth_boost = 1 + 0.25 * np.exp(-age / 18)                      # young animals eat more per kg^0.75
senior_drop = 1 - 0.10 * np.clip((age - 84) / 36, 0, 1)          # old cows eat a bit less
is_dairy = rep(cow_type) == "dairy"
lactation = np.where(is_dairy & (age >= 26), 1.30, 1.0)          # adult dairy cows are milking

intake = (
    rep(k_intake) * metabolic_w
    * growth_boost * senior_drop * lactation * rep(cow_eff)
)
intake *= rng.lognormal(mean=0, sigma=0.07, size=len(intake))   # day-to-day noise

df = pd.DataFrame({
    "cow_id": cow_id,
    "age_months": age.round(1),
    "weight_kg": weight.round(1),
    "type": rep(cow_type),
    "breed": rep(breed),
    "feed_intake_kg_dm": intake.round(2),
})

df.to_csv("cow_feed_dataset.csv", index=False)
print(df.shape)                      # should print (500000, 6)
print(df.head())
print(df.describe(include="all").T)