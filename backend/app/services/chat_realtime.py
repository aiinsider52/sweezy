from __future__ import annotations

import asyncio
import json
from collections import defaultdict
from typing import Any

from fastapi import WebSocket

from ..core.chat_metrics import CHAT_WEBSOCKET_CONNECTIONS
from ..core.config import get_settings
from ..core.logging import get_logger


log = get_logger(module="chat_realtime")


class ChatRealtime:
    def __init__(self) -> None:
        self._connections: dict[str, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()
        self._redis = None
        self._pubsub = None
        self._listener: asyncio.Task | None = None
        self._channel = get_settings().CHAT_REDIS_CHANNEL

    async def start(self) -> None:
        redis_url = get_settings().REDIS_URL
        if not redis_url:
            log.warning("chat_redis_disabled", reason="REDIS_URL is empty")
            return
        try:
            from redis.asyncio import Redis

            self._redis = Redis.from_url(redis_url, encoding="utf-8", decode_responses=True)
            await self._redis.ping()
            self._pubsub = self._redis.pubsub()
            await self._pubsub.subscribe(self._channel)
            self._listener = asyncio.create_task(self._listen())
            log.info("chat_redis_connected")
        except Exception as exc:
            self._redis = None
            self._pubsub = None
            log.error("chat_redis_connection_failed", error=str(exc))
            if get_settings().APP_ENV.lower() == "production":
                raise RuntimeError("Redis is unavailable; production chat cannot start") from exc

    async def stop(self) -> None:
        if self._listener:
            self._listener.cancel()
            try:
                await self._listener
            except asyncio.CancelledError:
                pass
        if self._pubsub:
            await self._pubsub.close()
        if self._redis:
            await self._redis.close()

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections[user_id].add(websocket)
        CHAT_WEBSOCKET_CONNECTIONS.inc()

    async def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            sockets = self._connections.get(user_id)
            if not sockets:
                return
            sockets.discard(websocket)
            CHAT_WEBSOCKET_CONNECTIONS.dec()
            if not sockets:
                self._connections.pop(user_id, None)

    async def publish(self, user_id: str, event: dict[str, Any]) -> None:
        envelope = {"user_id": user_id, "event": event}
        if self._redis:
            try:
                await self._redis.publish(self._channel, json.dumps(envelope, default=str))
                return
            except Exception as exc:
                log.warning("chat_redis_publish_failed", error=str(exc))
        await self._deliver_local(user_id, event)

    async def _listen(self) -> None:
        backoff_seconds = 1.0
        while True:
            try:
                if self._pubsub is None:
                    await self._resubscribe()
                    backoff_seconds = 1.0
                assert self._pubsub is not None
                message = await self._pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
                if not message:
                    await asyncio.sleep(0.05)
                    continue
                envelope = json.loads(message["data"])
                await self._deliver_local(str(envelope["user_id"]), dict(envelope["event"]))
                backoff_seconds = 1.0
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                log.warning("chat_redis_listener_error", error=str(exc), backoff=backoff_seconds)
                await self._reset_pubsub()
                await asyncio.sleep(backoff_seconds)
                backoff_seconds = min(backoff_seconds * 2, 30.0)

    async def _resubscribe(self) -> None:
        redis_url = get_settings().REDIS_URL
        if not redis_url:
            raise RuntimeError("REDIS_URL is empty")
        from redis.asyncio import Redis

        if self._redis is None:
            self._redis = Redis.from_url(redis_url, encoding="utf-8", decode_responses=True)
        await self._redis.ping()
        self._pubsub = self._redis.pubsub()
        await self._pubsub.subscribe(self._channel)
        log.info("chat_redis_resubscribed")

    async def _reset_pubsub(self) -> None:
        if self._pubsub is not None:
            try:
                await self._pubsub.close()
            except Exception:
                pass
            self._pubsub = None
        if self._redis is not None:
            try:
                await self._redis.close()
            except Exception:
                pass
            self._redis = None

    async def _deliver_local(self, user_id: str, event: dict[str, Any]) -> None:
        async with self._lock:
            sockets = list(self._connections.get(user_id, set()))
        dead: list[WebSocket] = []
        for socket in sockets:
            try:
                await socket.send_json(event)
            except Exception:
                dead.append(socket)
        for socket in dead:
            await self.disconnect(user_id, socket)


chat_realtime = ChatRealtime()
