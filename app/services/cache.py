from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from app.core.config import Settings


@dataclass(frozen=True)
class CacheStatus:
    enabled: bool
    connected: bool
    backend: str
    detail: str


class CacheClient:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._client = None
        if settings.redis_enabled:
            try:
                import redis

                self._client = redis.Redis.from_url(
                    settings.redis_url,
                    socket_connect_timeout=settings.redis_timeout_seconds,
                    socket_timeout=settings.redis_timeout_seconds,
                    decode_responses=True,
                )
            except Exception:
                self._client = None

    @property
    def enabled(self) -> bool:
        return self.settings.redis_enabled and self._client is not None

    def status(self) -> CacheStatus:
        if not self.settings.redis_enabled:
            return CacheStatus(False, False, "sqlite", "Redis disabled; SQLite cache only")
        if not self._client:
            return CacheStatus(True, False, "sqlite", "Redis client unavailable; SQLite fallback")
        try:
            self._client.ping()
        except Exception as exc:
            return CacheStatus(True, False, "sqlite", f"Redis unavailable; SQLite fallback: {type(exc).__name__}")
        return CacheStatus(True, True, "redis+sqlite", "Redis hot cache with SQLite persistence")

    def get_json(self, key: str) -> dict[str, Any] | None:
        if not self.enabled:
            return None
        try:
            value = self._client.get(key)
            return json.loads(value) if value else None
        except Exception:
            return None

    def set_json(self, key: str, value: dict[str, Any], ttl_seconds: int) -> None:
        if not self.enabled:
            return
        try:
            payload = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
            self._client.setex(key, ttl_seconds, payload)
        except Exception:
            return
