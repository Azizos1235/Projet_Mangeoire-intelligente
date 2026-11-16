import pandas as pd
import lightgbm as lgb
import joblib
from sklearn.model_selection import GroupShuffleSplit
from sklearn.metrics import mean_absolute_error, r2_score

# --- load -------------------------------------------------------------------
df = pd.read_csv("cow_feed_dataset.csv")
print("Dataset shape:", df.shape)          # expect (500000, 6)

TARGET = "feed_intake_kg_dm"
FEATURES = ["age_months", "weight_kg", "type", "breed"]

df["type"] = df["type"].astype("category")
df["breed"] = df["breed"].astype("category")
print("Types: ", list(df["type"].cat.categories))
print("Breeds:", list(df["breed"].cat.categories))

# --- split BY COW (same animal never in both train and test) ----------------
gss = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=42)
train_idx, test_idx = next(gss.split(df, groups=df["cow_id"]))
train, test = df.iloc[train_idx], df.iloc[test_idx]

# validation slice (also by cow) for early stopping
gss2 = GroupShuffleSplit(n_splits=1, test_size=0.1, random_state=1)
tr_idx, val_idx = next(gss2.split(train, groups=train["cow_id"]))
tr, val = train.iloc[tr_idx], train.iloc[val_idx]

print(f"Train cows: {train['cow_id'].nunique()}  Test cows: {test['cow_id'].nunique()}")

# --- train LightGBM ---------------------------------------------------------
model = lgb.LGBMRegressor(
    n_estimators=3000,
    learning_rate=0.05,
    num_leaves=63,
    min_child_samples=50,
    subsample=0.8,
    subsample_freq=1,
    colsample_bytree=0.9,
    random_state=42,
    n_jobs=-1,
    verbose=-1,
)
model.fit(
    tr[FEATURES], tr[TARGET],
    eval_set=[(val[FEATURES], val[TARGET])],
    eval_metric="l1",
    callbacks=[lgb.early_stopping(50), lgb.log_evaluation(100)],
)

# --- evaluate ---------------------------------------------------------------
pred = model.predict(test[FEATURES])
print(f"\nLightGBM  MAE = {mean_absolute_error(test[TARGET], pred):.3f} kg/day   "
      f"R2 = {r2_score(test[TARGET], pred):.4f}")
print("Best iteration:", model.best_iteration_)

# --- feature importance -----------------------------------------------------
imp = pd.Series(model.feature_importances_, index=FEATURES).sort_values(ascending=False)
print("\nFeature importance:\n", imp)

# --- save model -------------------------------------------------------------
joblib.dump(model, "cow_intake_lgbm.joblib")
print("\nModel saved to cow_intake_lgbm.joblib")

# --- example prediction -----------------------------------------------------
new_cow = pd.DataFrame({
    "age_months": [36],
    "weight_kg": [580],
    "type": pd.Categorical(["dairy"], categories=df["type"].cat.categories),
    "breed": pd.Categorical(["Holstein"], categories=df["breed"].cat.categories),
})
print("Predicted intake for a 36-month, 580 kg Holstein:",
      round(float(model.predict(new_cow[FEATURES])[0]), 2), "kg DM/day")