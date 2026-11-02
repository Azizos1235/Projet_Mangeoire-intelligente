import asyncio, contextlib, json, logging
from contextlib import asynccontextmanager

import aio_pika
from fastapi import FastAPI, Query, Request, WebSocket, WebSocketDisconnect
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
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


# --------------------------------------------------------------------------
# WebSocket hub: keeps the connected Flutter clients and pushes live updates
# --------------------------------------------------------------------------
class Hub:
    def __init__(self):
        self.clients: set[WebSocket] = set()

    async def broadcast(self, msg: dict):
        try:
            text = json.dumps(jsonable_encoder(msg))
        except Exception:
            log.exception("Could not encode broadcast message")
            return
        dead = []
        for ws in list(self.clients):
            try:
                await ws.send_text(text)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.clients.discard(ws)


hub = Hub()


async def reply(ws: WebSocket, msg: dict):
    await ws.send_text(json.dumps(jsonable_encoder(msg)))


# --------------------------------------------------------------------------
# Data helpers
# --------------------------------------------------------------------------
async def latest(col, cow_id: str):
    return await col.find_one({"cow_id": cow_id}, {"_id": 0}, sort=[("date", -1)])


async def predict(record: dict) -> dict:
    """Plug your AI model here. Return {...record, "model": {...}} (the shape
    AiResult.fromResponse expects in the Flutter app)."""
    raise NotImplementedError("No prediction model is wired into this server yet")


# --------------------------------------------------------------------------
# RabbitMQ -> MongoDB ingestion
# --------------------------------------------------------------------------
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
        return
    except Exception:
        log.exception("DB error, requeueing")
        await asyncio.sleep(2)
        await message.nack(requeue=True)
        return

    # push the new records to every connected app (never affects the ack above)
    for d in items:
        data = {k: v for k, v in d.items() if k != "_id"}
        await hub.broadcast({"type": "update", "cow_id": d["cow_id"], "data": data})


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


# --------------------------------------------------------------------------
# HTTP endpoints
# --------------------------------------------------------------------------
@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/events/{cow_id}")
async def events(cow_id: str, request: Request, limit: int = Query(30, ge=1, le=500)):
    cur = request.app.state.col.find(
        {"cow_id": cow_id.strip().upper()}, {"_id": 0}
    ).sort("date", -1).limit(limit)
    return await cur.to_list(length=limit)


# These three are what HttpCowService calls (they were missing -> HTTP 404)
@app.get("/cows")
async def cows(request: Request):
    return {"cows": sorted(await request.app.state.col.distinct("cow_id"))}


@app.get("/latest/{cow_id}")
async def latest_http(cow_id: str, request: Request):
    doc = await latest(request.app.state.col, cow_id.strip().upper())
    if doc is None:
        return JSONResponse({"error": f"No data for cow {cow_id}"}, status_code=404)
    return doc


@app.get("/predict/{cow_id}")
async def predict_http(cow_id: str, request: Request):
    doc = await latest(request.app.state.col, cow_id.strip().upper())
    if doc is None:
        return JSONResponse({"error": f"No data for cow {cow_id}"}, status_code=404)
    try:
        return await predict(doc)
    except NotImplementedError as e:
        return JSONResponse({"error": str(e)}, status_code=501)


# --------------------------------------------------------------------------
# WebSocket endpoint used by the Flutter CowService
# --------------------------------------------------------------------------
async def on_client_message(ws: WebSocket, col, msg: dict):
    kind = msg.get("type")
    echo_id = msg.get("cow_id")  # sent back untouched so the app can match it
    cow_id = str(echo_id).strip().upper() if echo_id is not None else None
    try:
        if kind == "list":
            ids = sorted(await col.distinct("cow_id"))
            await reply(ws, {"type": "cows", "ids": ids})

        elif kind == "get" and cow_id:
            doc = await latest(col, cow_id)
            if doc is None:
                await reply(ws, {"type": "error", "cow_id": echo_id, "where": "data",
                                 "message": f"No data for cow {cow_id}"})
            else:
                await reply(ws, {"type": "cow", "cow_id": echo_id, "data": doc})

        elif kind == "ask" and cow_id:
            doc = await latest(col, cow_id)
            if doc is None:
                raise LookupError(f"No data for cow {cow_id}")
            result = await predict(doc)
            await reply(ws, {"type": "ai", "cow_id": echo_id, "result": result})

    except Exception as e:
        if not isinstance(e, (NotImplementedError, LookupError)):
            log.exception("WebSocket request failed: %r", msg)
        await reply(ws, {"type": "error", "cow_id": echo_id,
                         "where": "ai" if kind == "ask" else "data",
                         "message": str(e)})


@app.websocket("/ws/cows")
async def ws_cows(ws: WebSocket):
    await ws.accept()
    hub.clients.add(ws)
    col = ws.app.state.col
    try:
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except ValueError:
                continue
            if isinstance(msg, dict):
                await on_client_message(ws, col, msg)
    except WebSocketDisconnect:
        pass
    except Exception:
        log.exception("WebSocket crashed")
    finally:
        hub.clients.discard(ws)