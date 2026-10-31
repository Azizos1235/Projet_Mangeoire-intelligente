import asyncio, contextlib, json, logging
from contextlib import asynccontextmanager

import aio_pika
from fastapi import FastAPI, Query, Request
from pydantic_settings import BaseSettings, SettingsConfigDict
from pymongo import AsyncMongoClient, ReplaceOne

log = logging.getLogger("ingest")
logging.basicConfig(level=logging.INFO)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    amqp_url: str
    mongo_uri: str
    mongo_db: str = "farm"
    mongo_collection: str = "feeding_events"
    queue_name: str = "test_queue"


settings = Settings()


def parse_items(body: bytes) -> list[dict]:
    """Accept one cow object, a list of cow objects, or double-encoded JSON."""
    payload = json.loads(body)
    if isinstance(payload, str):  # JSON that was stringified twice
        payload = json.loads(payload)
    items = payload if isinstance(payload, list) else [payload]
    out = []
    for d in items:
        if not isinstance(d, dict) or "cow_id" not in d or "date" not in d:
            raise TypeError("every item must be an object with cow_id and date")
        d = dict(d)
        d["cow_id"] = str(d["cow_id"]).strip().upper()
        d["date"] = str(d["date"]).strip()
        d["_id"] = f'{d["cow_id"]}-{d["date"]}'  # one document per cow per day
        out.append(d)
    return out


async def handle(message: aio_pika.abc.AbstractIncomingMessage, col):
    try:
        items = parse_items(message.body)
        if items:
            ops = [ReplaceOne({"_id": d["_id"]}, d, upsert=True) for d in items]
            await col.bulk_write(ops, ordered=False)
            log.info("Stored %d document(s): %s", len(items), items[0]["_id"])
        await message.ack()
    except (ValueError, TypeError):  # JSONDecodeError and UnicodeDecodeError are ValueErrors
        log.warning("Bad message dropped: %r", message.body[:200])
        await message.reject(requeue=False)
    except Exception:
        log.exception("DB error, requeueing")
        await asyncio.sleep(2)
        await message.nack(requeue=True)


async def ensure_index(col):
    try:
        await col.create_index([("cow_id", 1), ("date", -1)])
    except Exception:
        log.exception("Could not create index (will continue)")


async def consume(col):
    # Keep retrying: the Tailscale tunnel may need a few seconds, and the Pi may be offline
    while True:
        try:
            connection = await aio_pika.connect_robust(settings.amqp_url)
            async with connection:
                channel = await connection.channel()
                await channel.set_qos(prefetch_count=20)
                # passive: only checks the existing queue, never changes it
                queue = await channel.declare_queue(settings.queue_name, passive=True)
                log.info("Consuming from %s", settings.queue_name)
                async with queue.iterator() as it:
                    async for message in it:
                        await handle(message, col)
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("AMQP connection failed, retrying in 5 s")
            await asyncio.sleep(5)


@asynccontextmanager
async def lifespan(app: FastAPI):
    client = AsyncMongoClient(settings.mongo_uri)
    col = client[settings.mongo_db][settings.mongo_collection]
    app.state.col = col
    tasks = [asyncio.create_task(consume(col)), asyncio.create_task(ensure_index(col))]
    yield
    for t in tasks:
        t.cancel()
    for t in tasks:
        with contextlib.suppress(asyncio.CancelledError):
            await t
    await client.close()


app = FastAPI(lifespan=lifespan)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/events/{cow_id}")
async def events(cow_id: str, request: Request, limit: int = Query(30, ge=1, le=500)):
    cur = request.app.state.col.find(
        {"cow_id": cow_id.strip().upper()}, {"_id": 0}
    ).sort("date", -1).limit(limit)
    return await cur.to_list(length=limit)