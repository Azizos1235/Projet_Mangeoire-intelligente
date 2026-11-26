import argparse
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

from bson import ObjectId
from bson.errors import InvalidId
from pymongo import MongoClient


DB_NAME = "farm"
PROJECT_ROOT = Path(__file__).resolve().parent.parent


def load_dotenv(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values

    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:].strip()
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
                value = value[1:-1]
            values[key] = value
    return values


def get_mongo_uri() -> str:
    dotenv = load_dotenv(PROJECT_ROOT / ".env")
    mongo_uri = os.environ.get("MONGO_URI") or dotenv.get("MONGO_URI")
    if not mongo_uri:
        raise SystemExit("MONGO_URI is missing from the environment and .env.")
    return mongo_uri


def parse_admin_id(value: str) -> ObjectId:
    try:
        return ObjectId(value)
    except (InvalidId, TypeError):
        raise SystemExit("--admin-id must be a valid MongoDB ObjectId.")


def get_cow_ids(db, admin_id: ObjectId) -> list[str]:
    cow_ids: list[str] = []
    seen: set[str] = set()

    profiles = db["cow_profiles"].find(
        {"admin_id": admin_id},
        {"_id": 1, "cow_id": 1},
    )
    for profile in profiles:
        cow_id = profile.get("cow_id")
        if not isinstance(cow_id, str) or not cow_id.strip():
            cow_id = str(profile["_id"])
        cow_id = cow_id.strip().upper()
        if cow_id and cow_id not in seen:
            seen.add(cow_id)
            cow_ids.append(cow_id)

    return cow_ids


def base_alert(
    *,
    source: str,
    alert_type: str,
    severity: str,
    message: str,
    cow_id: str | None,
    admin_id: ObjectId,
    status: str,
    created_at: datetime,
    task_id: ObjectId | None,
    handled: bool,
    seed_key: str,
    **extra,
) -> dict:
    return {
        "source": source,
        "type": alert_type,
        "severity": severity,
        "message": message,
        "cow_id": cow_id,
        "admin_id": admin_id,
        "action": None,
        "status": status,
        "created_at": created_at,
        "read_at": created_at if status == "read" else None,
        "task_id": task_id,
        "handled": handled,
        "seed": True,
        "seed_key": seed_key,
        **extra,
    }


def seed_alerts(db, admin_id: ObjectId) -> int:
    if db["admins"].find_one({"_id": admin_id}, {"_id": 1}) is None:
        raise SystemExit("No admin found with that --admin-id.")

    cow_ids = get_cow_ids(db, admin_id)
    if not cow_ids:
        raise SystemExit("No cows found for that admin in cow_profiles.")

    now = datetime.now(timezone.utc)
    templates = [
        {
            "suffix": "appetite-low-1",
            "type": "appetite_low",
            "appetite_class": "low",
            "appetite_pct": {"low": 82.5, "normal": 12.5, "high": 5.0},
            "age": timedelta(hours=6),
            "status": "unread",
        },
        {
            "suffix": "appetite-low-2",
            "type": "appetite_low",
            "appetite_class": "low",
            "appetite_pct": {"low": 68.0, "normal": 24.0, "high": 8.0},
            "age": timedelta(days=1, hours=4),
            "status": "read",
        },
        {
            "suffix": "appetite-high-1",
            "type": "appetite_high",
            "appetite_class": "high",
            "appetite_pct": {"low": 4.0, "normal": 11.0, "high": 85.0},
            "age": timedelta(hours=18),
            "status": "read",
        },
        {
            "suffix": "appetite-high-2",
            "type": "appetite_high",
            "appetite_class": "high",
            "appetite_pct": {"low": 3.0, "normal": 17.0, "high": 80.0},
            "age": timedelta(days=2, hours=5),
            "status": "unread",
        },
    ]

    alerts = db["alerts"]
    inserted = 0

    for index, template in enumerate(templates):
        cow_id = cow_ids[index % len(cow_ids)]
        appetite_class = template["appetite_class"]
        created_at = now - template["age"]
        seed_key = f"seed:{admin_id}:{template['suffix']}:{cow_id}"
        message = (
            f"La vache {cow_id} a un appétit {appetite_class} depuis 3 jours "
            "(alerte de test)."
        )
        document = base_alert(
            source="system",
            alert_type=template["type"],
            severity="warning",
            message=message,
            cow_id=cow_id,
            admin_id=admin_id,
            status=template["status"],
            created_at=created_at,
            task_id=None,
            handled=False,
            seed_key=seed_key,
            appetite_class=appetite_class,
            appetite_pct=template["appetite_pct"],
            dedupe_key=f"{seed_key}:dedupe",
        )
        result = alerts.update_one(
            {"seed_key": seed_key},
            {"$setOnInsert": document},
            upsert=True,
        )
        if result.upserted_id is not None:
            inserted += 1

    eleveur = db["eleveurs"].find_one(
        {"admin_id": admin_id},
        {"name": 1},
    )
    eleveur_name = (
        eleveur.get("name")
        if eleveur and isinstance(eleveur.get("name"), str)
        else "L’éleveur"
    )

    task = db["tasks"].find_one(
        {"admin_id": admin_id},
        {
            "_id": 1,
            "title": 1,
            "cow_id": 1,
            "completion_note": 1,
            "completed_weight_kg": 1,
            "previous_weight_kg": 1,
        },
    )
    task_id = task["_id"] if task and isinstance(task.get("_id"), ObjectId) else None
    task_cow_id = task.get("cow_id") if task and isinstance(task.get("cow_id"), str) else cow_ids[0]
    task_cow_id = task_cow_id or cow_ids[0]
    task_title = task.get("title") if task and isinstance(task.get("title"), str) else "Vérifier le poids"

    previous_weight = task.get("previous_weight_kg") if task else None
    completed_weight = task.get("completed_weight_kg") if task else None
    if not isinstance(previous_weight, (int, float)):
        previous_weight = 605.0
    if not isinstance(completed_weight, (int, float)):
        completed_weight = 612.0

    task_completion_created_at = now - timedelta(days=2, hours=12)
    task_completion_key = f"seed:{admin_id}:task-completed:{task_cow_id}"
    task_completion_message = (
        f"{eleveur_name} a terminé la tâche : {task_title}. "
        f"Ancien poids : {previous_weight:g} kg → {completed_weight:g} kg."
    )
    task_completion = base_alert(
        source="system",
        alert_type="task_completed",
        severity="info",
        message=task_completion_message,
        cow_id=task_cow_id,
        admin_id=admin_id,
        status="unread",
        created_at=task_completion_created_at,
        task_id=task_id,
        handled=False,
        seed_key=task_completion_key,
        completion_note=task.get("completion_note") if task else None,
        completed_weight_kg=float(completed_weight),
        previous_weight_kg=float(previous_weight),
        dedupe_key=f"{task_completion_key}:dedupe",
    )
    result = alerts.update_one(
        {"seed_key": task_completion_key},
        {"$setOnInsert": task_completion},
        upsert=True,
    )
    if result.upserted_id is not None:
        inserted += 1

    return inserted


def delete_seed_alerts(db, admin_id: ObjectId) -> int:
    result = db["alerts"].delete_many({
        "seed": True,
        "admin_id": admin_id,
    })
    return result.deleted_count


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Seed test alerts for an existing admin."
    )
    parser.add_argument("--admin-id", required=True, help="MongoDB ObjectId of the admin")
    parser.add_argument("--delete", action="store_true", help="Delete this admin's seeded alerts")
    args = parser.parse_args()

    admin_id = parse_admin_id(args.admin_id)
    mongo_uri = get_mongo_uri()

    client = MongoClient(mongo_uri)
    try:
        db = client[DB_NAME]
        if args.delete:
            deleted = delete_seed_alerts(db, admin_id)
            print(f"Deleted {deleted} seeded alert(s).")
        else:
            inserted = seed_alerts(db, admin_id)
            print(f"Inserted {inserted} new seeded alert(s).")
    finally:
        client.close()


if __name__ == "__main__":
    main()
