from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from typing import Any

from app.core.config import Settings
from app.core.database import Database
from app.services.cache import CacheClient


def load_json_file(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception:
        return None


def current_month_start() -> str:
    today = date.today()
    return today.replace(day=1).isoformat()


def cost_summary(settings: Settings, db: Database, cache: CacheClient) -> dict[str, Any]:
    snapshot = load_json_file(settings.ncloud_cost_snapshot_path) or {}
    usage_today = db.get_usage_count("clova_ocr")
    usage_month = db.get_usage_total("clova_ocr", start_date=current_month_start())
    billable_ocr_calls = max(0, usage_month - settings.ocr_general_free_quota_monthly)
    estimated_ocr_cost = billable_ocr_calls * settings.ocr_general_unit_price_krw
    cache_status = cache.status()

    return {
        "currency": "KRW",
        "ncloud": {
            "source": snapshot.get("source", "missing_snapshot"),
            "generated_at": snapshot.get("generated_at"),
            "month": snapshot.get("month"),
            "return_code": snapshot.get("return_code"),
            "return_message": snapshot.get("return_message"),
            "current_month_amount_krw": int(snapshot.get("this_month_amount_krw") or 0),
            "current_month_vat_krw": int(snapshot.get("this_month_vat_krw") or 0),
            "current_month_amount_including_vat_krw": int(
                snapshot.get("this_month_amount_including_vat_krw") or 0
            ),
            "note": snapshot.get(
                "note",
                "Ncloud Billing API snapshot is updated during deployment and can lag behind real-time usage.",
            ),
        },
        "server": {
            "spec_code": settings.ncloud_server_spec_code,
            "fee_system_type_code": settings.ncloud_fee_system_type_code,
            "extra_managed_cache_cost_krw": 0,
            "cache_note": "Redis runs as an internal Docker container; no Cloud DB for Cache resource is created.",
        },
        "ocr": {
            "provider": settings.ocr_provider,
            "allow_paid_ocr": settings.allow_paid_ocr,
            "paid_ocr_enabled": settings.paid_ocr_enabled,
            "usage_today": usage_today,
            "usage_month": usage_month,
            "free_quota_monthly": settings.ocr_general_free_quota_monthly,
            "billable_calls_month": billable_ocr_calls,
            "unit_price_krw_after_free": settings.ocr_general_unit_price_krw,
            "estimated_month_cost_krw": estimated_ocr_cost,
        },
        "cache": {
            "enabled": cache_status.enabled,
            "connected": cache_status.connected,
            "backend": cache_status.backend,
            "detail": cache_status.detail,
            "sqlite_ocr_results": db.count_ocr_results(),
            "analysis_requests": db.count_analysis_requests(),
        },
    }
