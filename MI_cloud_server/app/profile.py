"""Create the 7 cow profiles in farm.cow_profiles.

Matches what simulate_history.py expects:
  - _id is the RFID tag (same ids as COW_IDS there)
  - birth_date is set (simulate_history only fills it when it is missing)
  - admin_id is the owner account (ObjectId): the API only shows a cow to the
    admin whose id matches this field
Existing profiles keep all their data. For profiles that already exist,
admin_id is only added when it is missing (never overwritten), unless you
pass --force-owner.

Usage:
    python create_cow_profiles.py --dry-run       # print only, no database access
    python create_cow_profiles.py                 # write (needs MONGO_URI)
    python create_cow_profiles.py --force-owner   # also overwrite a different admin_id
"""
import argparse
import os
from datetime import datetime, timedelta, timezone

import numpy as np

DB_NAME = os.environ.get("MONGO_DB", "farm")
COLLECTION = "cow_profiles"

# Owner account: can be overridden with the ADMIN_ID environment variable
ADMIN_ID = os.environ.get("ADMIN_ID", "6af8c379510d8b0a4fbfe603")

TAGS = [
    "3C43FA39",  # Nouveau tag #1
    "CC8B7922",  # Nouveau tag #2
    "92EBEA51",  # Nouveau tag #3
    "822D4251",  # Nouveau tag #4
    "EC954B17",  # Nouveau tag #5
    "92B47151",  # Nouveau tag #6
    "EDFF4D24",  # Nouveau tag #7
]
N_COWS = len(TAGS)
SEED = 42

# name: (type, mature_weight_kg, weight_sd, probability)
BREEDS = {
    "Holstein":  ("dairy", 650, 50, 0.30),
    "Jersey":    ("dairy", 430, 35, 0.10),
    "Angus":     ("beef",  600, 50, 0.25),
    "Limousin":  ("beef",  700, 60, 0.15),
    "Charolais": ("beef",  800, 70, 0.10),
    "Simmental": ("dual",  700, 60, 0.10),
}


def build_profiles(admin_id) -> list[dict]:
    rng = np.random.default_rng(SEED)

    names = list(BREEDS)
    probs = np.array([BREEDS[b][3] for b in names])
    probs /= probs.sum()

    # --- per-cow attributes -------------------------------------------------
    breed = rng.choice(names, size=N_COWS, p=probs)
    cow_type = np.array([BREEDS[b][0] for b in breed])
    mature_w = np.array([rng.normal(BREEDS[b][1], BREEDS[b][2]) for b in breed])
    growth_rate = rng.normal(0.09, 0.01, N_COWS).clip(0.06, 0.12)   # per month
    age = rng.uniform(6, 60, N_COWS)                                 # months

    # --- current weight (von Bertalanffy-style growth curve) ----------------
    weight = mature_w * (1 - 0.6 * np.exp(-growth_rate * age)) ** 3
    weight *= rng.normal(1.0, 0.03, N_COWS)

    # --- documents ----------------------------------------------------------
    created_at = datetime.now(timezone.utc)
    today = created_at.replace(hour=0, minute=0, second=0, microsecond=0)

    profiles = []
    for i in range(N_COWS):
        profiles.append({
            "_id": TAGS[i],                                   # RFID tag
            "cow_id": f"COW{i + 1:03d}",                      # COW001 ... COW007
            "admin_id": admin_id,                             # owner account (ObjectId)
            "age_months": round(float(age[i]), 1),
            "weight_kg": round(float(weight[i]), 1),
            "type": str(cow_type[i]),
            "breed": str(breed[i]),
            "birth_date": today - timedelta(days=round(float(age[i]) * 30.44)),
            "created_at": created_at,                         # when the profile was added
        })
    return profiles


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="print documents, do not write")
    ap.add_argument("--force-owner", action="store_true",
                    help="overwrite admin_id even on profiles that already have another owner")
    args = ap.parse_args()

    if len(ADMIN_ID) != 24 or any(c not in "0123456789abcdefABCDEF" for c in ADMIN_ID):
        raise SystemExit(f"ADMIN_ID '{ADMIN_ID}' is not a valid ObjectId (24 hex characters)")

    if args.dry_run:
        for p in build_profiles(ADMIN_ID):               # shown as text, no bson needed
            print(p)
        print(f"{N_COWS} documents would be written to {DB_NAME}.{COLLECTION} "
              f"with admin_id {ADMIN_ID}")
        return

    from bson import ObjectId                           # imported here so --dry-run needs no pymongo
    from pymongo import MongoClient, UpdateOne
    admin_oid = ObjectId(ADMIN_ID)
    profiles = build_profiles(admin_oid)

    col = MongoClient(os.environ.get("MONGO_URI", "mongodb://localhost:27017"))[DB_NAME][COLLECTION]

    ops = [UpdateOne({"_id": p["_id"]}, {"$setOnInsert": p}, upsert=True) for p in profiles]
    res = col.bulk_write(ops, ordered=False)
    print(f"{COLLECTION}: {res.upserted_count} inserted, "
          f"{len(ops) - res.upserted_count} already existed (left untouched)")

    # Existing profiles: attach the owner (only where it is missing, unless --force-owner)
    if args.force_owner:
        flt = {"_id": {"$in": TAGS}}
    else:
        flt = {"_id": {"$in": TAGS},
               "$or": [{"admin_id": {"$exists": False}}, {"admin_id": None}]}
    upd = col.update_many(flt, {"$set": {"admin_id": admin_oid}})
    print(f"admin_id {ADMIN_ID} set on {upd.modified_count} existing profile(s)")

    # Warn about profiles whose owner is a string instead of an ObjectId (never matches)
    bad = col.count_documents({"_id": {"$in": TAGS}, "admin_id": {"$type": "string"}})
    if bad:
        print(f"WARNING: {bad} profile(s) have admin_id stored as a string; "
              "use --force-owner to replace it with an ObjectId")


if __name__ == "__main__":
    main()