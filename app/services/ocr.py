from __future__ import annotations

import base64
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import httpx

from app.core.config import Settings
from app.core.database import Database
from app.services.cache import CacheClient
from app.services.image_utils import PreparedImage


class CostGuardError(RuntimeError):
    pass


class OcrProviderError(RuntimeError):
    pass


@dataclass(frozen=True)
class OcrResult:
    provider: str
    text: str
    raw_response: dict[str, Any]
    cached: bool
    called_paid_api: bool
    cache_backend: str | None = None


class OcrService:
    def __init__(self, settings: Settings, db: Database, cache: CacheClient | None = None):
        self.settings = settings
        self.db = db
        self.cache = cache

    def extract_text(
        self,
        image: PreparedImage,
        mock_text: str | None = None,
        force_ocr: bool = False,
    ) -> OcrResult:
        if mock_text:
            text = mock_text.strip()
            return OcrResult(
                provider="mock",
                text=text,
                raw_response={"source": "request.mock_text"},
                cached=False,
                called_paid_api=False,
                cache_backend=None,
            )

        if self.settings.ocr_provider == "mock":
            return OcrResult(
                provider="mock",
                text=self._default_mock_text(),
                raw_response={"source": "default.mock_text"},
                cached=False,
                called_paid_api=False,
                cache_backend=None,
            )

        if self.settings.ocr_provider == "clova":
            return self._extract_with_clova(image, force_ocr=force_ocr)

        raise OcrProviderError(f"unsupported OCR provider: {self.settings.ocr_provider}")

    def _extract_with_clova(self, image: PreparedImage, force_ocr: bool = False) -> OcrResult:
        if not self.settings.clova_configured:
            raise OcrProviderError("CLOVA OCR invoke URL or secret key is not configured")

        if self.settings.ocr_cache_enabled and not force_ocr:
            redis_payload = self._find_redis_ocr_result(image.original_hash, provider="clova")
            if redis_payload:
                return OcrResult(
                    provider=str(redis_payload.get("provider", "clova")),
                    text=str(redis_payload.get("text", "")),
                    raw_response=redis_payload.get("raw_response") or {},
                    cached=True,
                    called_paid_api=False,
                    cache_backend="redis",
                )

            cached = self.db.find_ocr_result(image.original_hash, provider="clova")
            if cached:
                self._save_redis_ocr_result(image.original_hash, cached)
                return OcrResult(
                    provider=cached["provider"],
                    text=cached["text"],
                    raw_response=cached["raw_response"],
                    cached=True,
                    called_paid_api=False,
                    cache_backend="sqlite",
                )

        if not self.settings.allow_paid_ocr:
            raise CostGuardError(
                "Paid CLOVA OCR call blocked. Set ALLOW_PAID_OCR=true only when you intentionally run live OCR."
            )

        today_count = self.db.get_usage_count("clova_ocr")
        if today_count >= self.settings.ocr_daily_limit:
            raise CostGuardError(
                f"Daily CLOVA OCR limit reached: {today_count}/{self.settings.ocr_daily_limit}"
            )

        payload = {
            "version": "V2",
            "requestId": str(uuid.uuid4()),
            "timestamp": int(datetime.now().timestamp() * 1000),
            "images": [
                {
                    "format": image.image_format,
                    "name": image.original_hash[:16],
                    "data": base64.b64encode(image.bytes).decode("ascii"),
                }
            ],
        }
        headers = {
            "Content-Type": "application/json",
            "X-OCR-SECRET": self.settings.clova_ocr_secret_key or "",
        }

        self.db.increment_usage("clova_ocr")
        try:
            response = httpx.post(
                self.settings.clova_ocr_invoke_url or "",
                headers=headers,
                json=payload,
                timeout=self.settings.ocr_timeout_seconds,
            )
        except httpx.HTTPError as exc:
            raise OcrProviderError(f"CLOVA OCR request failed: {exc}") from exc

        if response.status_code >= 400:
            raise OcrProviderError(
                f"CLOVA OCR returned HTTP {response.status_code}: {response.text[:300]}"
            )

        raw = response.json()
        text = self._parse_clova_text(raw)
        result = OcrResult(
            provider="clova",
            text=text,
            raw_response=raw,
            cached=False,
            called_paid_api=True,
            cache_backend=None,
        )
        self._save(image, result)
        return result

    def _save(self, image: PreparedImage, result: OcrResult) -> None:
        self.db.save_ocr_result(
            image_hash=image.original_hash,
            provider=result.provider,
            text=result.text,
            raw_response=result.raw_response,
            image_format=image.image_format,
            image_width=image.width,
            image_height=image.height,
            called_paid_api=result.called_paid_api,
        )
        self._save_redis_ocr_result(
            image.original_hash,
            {
                "provider": result.provider,
                "text": result.text,
                "raw_response": result.raw_response,
            },
        )

    def _find_redis_ocr_result(self, image_hash: str, provider: str) -> dict[str, Any] | None:
        if not self.cache:
            return None
        return self.cache.get_json(self._ocr_cache_key(provider, image_hash))

    def _save_redis_ocr_result(self, image_hash: str, payload: dict[str, Any]) -> None:
        if not self.cache:
            return
        provider = str(payload.get("provider", "clova"))
        self.cache.set_json(
            self._ocr_cache_key(provider, image_hash),
            {
                "provider": provider,
                "text": payload.get("text", ""),
                "raw_response": payload.get("raw_response") or {},
                "cached_at": datetime.now(UTC).isoformat(),
            },
            ttl_seconds=self.settings.redis_ocr_cache_ttl_seconds,
        )

    @staticmethod
    def _ocr_cache_key(provider: str, image_hash: str) -> str:
        return f"ocr:{provider}:{image_hash}"

    @staticmethod
    def _parse_clova_text(raw: dict[str, Any]) -> str:
        lines: list[str] = []
        for image in raw.get("images", []):
            for field in image.get("fields", []):
                text = field.get("inferText")
                if text:
                    lines.append(str(text))
        return "\n".join(lines).strip()

    @staticmethod
    def _default_mock_text() -> str:
        return (
            "원재료명: 밀가루, 팜유, 정제염, 대두, 우유, 계란, 돼지고기향분말, 젤라틴\n"
            "알레르기 유발물질: 밀, 대두, 우유, 계란, 돼지고기 함유\n"
            "영양정보: 나트륨, 탄수화물, 당류, 지방, 단백질"
        )
