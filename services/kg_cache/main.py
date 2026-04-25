import json
import logging
import os

from fastapi import FastAPI, Request, Response

from cache import TTLCache

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

WEB_INTEL_URL = os.getenv("WEB_INTEL_URL", "http://web_intelligence:8003")

app = FastAPI(title="Knowledge Graph Cache")
cache = TTLCache(web_intel_url=WEB_INTEL_URL)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/cache/{zone_id}/{event_type}")
async def get_cache(zone_id: str, event_type: str):
    key = f"{zone_id}:{event_type}"
    value = cache.get(key)
    if value is None:
        return Response(content="not found", status_code=404)
    return Response(content=value, media_type="application/json", status_code=200)


@app.put("/cache/{zone_id}/{event_type}", status_code=201)
async def put_cache(zone_id: str, event_type: str, request: Request):
    body = await request.body()
    try:
        json.loads(body)
    except Exception:
        return Response(content="request body must be valid JSON", status_code=400)
    key = f"{zone_id}:{event_type}"
    cache.set(key, body.decode())
    return Response(status_code=201)


@app.delete("/cache/{zone_id}/{event_type}", status_code=204)
async def delete_cache(zone_id: str, event_type: str):
    key = f"{zone_id}:{event_type}"
    cache.delete(key)
    return Response(status_code=204)


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "8080"))
    uvicorn.run("main:app", host="0.0.0.0", port=port)
