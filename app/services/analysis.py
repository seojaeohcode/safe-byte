from __future__ import annotations

import hashlib
import uuid
from typing import Any

from app.core.config import Settings
from app.core.database import Database
from app.services.image_utils import ImageValidationError, PreparedImage, prepare_image
from app.services.ocr_correction import correct_ocr_text
from app.services.ocr import CostGuardError, OcrProviderError, OcrService
from app.services.profile_tokens import normalize_profiles
from app.services.risk_rules import RiskRuleEngine
from app.services.text_parser import extract_segments, normalize_text


class AnalysisError(RuntimeError):
    pass


class AnalysisService:
    def __init__(
        self,
        settings: Settings,
        db: Database,
        ocr: OcrService,
        rules: RiskRuleEngine,
    ):
        self.settings = settings
        self.db = db
        self.ocr = ocr
        self.rules = rules

    def analyze_text(
        self,
        text: str,
        profiles: list[str] | None = None,
        source_name: str | None = "direct_text",
    ) -> dict[str, Any]:
        profiles = self._normalize_profiles(profiles)
        normalized = normalize_text(text)
        request_id = str(uuid.uuid4())
        text_hash = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
        self.db.create_analysis_request(request_id, text_hash, source_name, profiles)
        return self._finish_analysis(
            request_id=request_id,
            image_hash=text_hash,
            source_name=source_name,
            profiles=profiles,
            ocr_payload={
                "provider": "none",
                "cached": False,
                "called_paid_api": False,
                "text": normalized,
            },
            text=normalized,
            image_meta=None,
        )

    def analyze_image(
        self,
        image_bytes: bytes,
        filename: str | None,
        profiles: list[str] | None = None,
        mock_text: str | None = None,
        force_ocr: bool = False,
    ) -> dict[str, Any]:
        profiles = self._normalize_profiles(profiles)
        try:
            prepared = prepare_image(
                image_bytes=image_bytes,
                max_upload_mb=self.settings.ocr_max_upload_mb,
                max_image_mb=self.settings.ocr_max_image_mb,
                max_long_edge=self.settings.ocr_max_long_edge,
                jpeg_quality=self.settings.ocr_jpeg_quality,
            )
        except ImageValidationError as exc:
            raise AnalysisError(str(exc)) from exc

        request_id = str(uuid.uuid4())
        self.db.create_analysis_request(request_id, prepared.original_hash, filename, profiles)
        try:
            ocr_result = self.ocr.extract_text(prepared, mock_text=mock_text, force_ocr=force_ocr)
        except (CostGuardError, OcrProviderError) as exc:
            self.db.fail_analysis(request_id, str(exc))
            raise

        return self._finish_analysis(
            request_id=request_id,
            image_hash=prepared.original_hash,
            source_name=filename,
            profiles=profiles,
            ocr_payload={
                "provider": ocr_result.provider,
                "cached": ocr_result.cached,
                "cache_backend": ocr_result.cache_backend,
                "called_paid_api": ocr_result.called_paid_api,
                "text": ocr_result.text,
            },
            text=ocr_result.text,
            image_meta=self._image_meta(prepared),
        )

    def _finish_analysis(
        self,
        request_id: str,
        image_hash: str,
        source_name: str | None,
        profiles: list[str],
        ocr_payload: dict[str, Any],
        text: str,
        image_meta: dict[str, Any] | None,
    ) -> dict[str, Any]:
        normalized = normalize_text(text)
        corrected_text, corrections = correct_ocr_text(normalized)
        segments = extract_segments(corrected_text)
        risk = self.rules.detect(corrected_text, profiles=profiles)
        self.db.save_segments(request_id, segments)
        self.db.save_detections(request_id, risk["detections"])
        ocr_payload = {
            **ocr_payload,
            "corrected_text": corrected_text,
            "corrections": corrections,
            "correction_count": sum(item["count"] for item in corrections),
        }

        response = {
            "request_id": request_id,
            "status": "completed",
            "source_name": source_name,
            "image_hash": image_hash,
            "profiles": profiles,
            "image": image_meta,
            "ocr": ocr_payload,
            "segments": segments,
            "risk": risk,
            "cost_guard": {
                "ocr_provider": self.settings.ocr_provider,
                "paid_ocr_enabled": self.settings.paid_ocr_enabled,
                "allow_paid_ocr": self.settings.allow_paid_ocr,
                "daily_limit": self.settings.ocr_daily_limit,
                "cache_enabled": self.settings.ocr_cache_enabled,
            },
        }
        self.db.complete_analysis(request_id, risk["final_level"], response)
        return response

    @staticmethod
    def _normalize_profiles(profiles: list[str] | None) -> list[str]:
        return normalize_profiles(profiles, default=["halal", "vegan", "allergy"])

    @staticmethod
    def _image_meta(image: PreparedImage) -> dict[str, Any]:
        return {
            "format": image.image_format,
            "width": image.width,
            "height": image.height,
            "original_size_bytes": image.original_size_bytes,
            "processed_size_bytes": image.processed_size_bytes,
            "compressed": image.compressed,
        }
