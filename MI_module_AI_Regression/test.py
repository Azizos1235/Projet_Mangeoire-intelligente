import joblib
import pandas as pd

model = joblib.load("cow_intake_lgbm.joblib")

# --- read the categories the model was trained with -------------------------
# Order matches FEATURES in training: type first, then breed.
cats = model.booster_.pandas_categorical
if not cats or len(cats) != 2:
    raise SystemExit(
        "This saved model was not trained with both 'type' and 'breed'.\n"
        "Run train_model.py again, then rerun this test."
    )
TYPES, BREEDS = list(cats[0]), list(cats[1])
FEATURES = ["age_months", "weight_kg", "type", "breed"]

# Each breed belongs to exactly one type, so type is filled in automatically
BREED_TYPE = {
    "Holstein": "dairy", "Jersey": "dairy",
    "Angus": "beef", "Limousin": "beef", "Charolais": "beef",
    "Simmental": "dual",
}


def predict_intake(age_months, weight_kg, breed):
    if breed not in BREEDS:
        raise ValueError(f"breed must be one of {BREEDS}")
    cow = pd.DataFrame({
        "age_months": [float(age_months)],
        "weight_kg": [float(weight_kg)],
        "type": pd.Categorical([BREED_TYPE[breed]], categories=TYPES),
        "breed": pd.Categorical([breed], categories=BREEDS),
    })
    return float(model.predict(cow[FEATURES])[0])


# --- 1. example cows ---------------------------------------------------------
examples = [
    (12, 300, "Angus"),
    (24, 450, "Jersey"),
    (36, 580, "Holstein"),
    (48, 700, "Charolais"),
    (60, 700, "Simmental"),
]

print(f"{'age':>5} {'weight':>7} {'breed':>10} {'type':>6} {'kg DM/day':>10} {'% body wt':>10}")
for age, w, b in examples:
    p = predict_intake(age, w, b)
    print(f"{age:>5} {w:>7} {b:>10} {BREED_TYPE[b]:>6} {p:>10.2f} {100 * p / w:>9.2f}%")

# --- 2. same cow, different breeds -------------------------------------------
print("\nSame cow (36 months, 600 kg), different breeds:")
for b in BREEDS:
    print(f"  {b:<10} {predict_intake(36, 600, b):6.2f} kg DM/day")

# --- 3. sanity check: heavier cow should eat more ----------------------------
light = predict_intake(36, 450, "Angus")
heavy = predict_intake(36, 700, "Angus")
print("\nSanity check (heavier eats more):", "OK" if heavy > light else "PROBLEM")

# --- 4. actual vs predicted on real rows -------------------------------------
df = pd.read_csv("cow_feed_dataset.csv").sample(5, random_state=1)
print("\nActual vs predicted on 5 random rows:")
for _, r in df.iterrows():
    p = predict_intake(r["age_months"], r["weight_kg"], r["breed"])
    print(f"  {r['breed']:<10} age {r['age_months']:>5.1f}  weight {r['weight_kg']:>6.1f}"
          f"  actual {r['feed_intake_kg_dm']:>6.2f}  predicted {p:>6.2f}")

# --- 5. interactive mode -----------------------------------------------------
print(f"\nTry your own cow (Ctrl+C to quit). Breeds: {', '.join(BREEDS)}")
while True:
    try:
        a = float(input("Age in months: "))
        w = float(input("Weight in kg: "))
        b = input("Breed: ").strip().title()
        print(f"-> Predicted intake: {predict_intake(a, w, b):.2f} kg DM/day\n")
    except ValueError as e:
        print("Invalid input:", e, "\n")
    except (KeyboardInterrupt, EOFError):
        print("\nBye")
        break