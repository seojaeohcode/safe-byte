from __future__ import annotations

import csv
from pathlib import Path
from typing import Annotated
from urllib.parse import quote

from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, UploadFile
from starlette.concurrency import run_in_threadpool

from app.core.config import Settings, get_settings
from app.core.database import Database
from app.core.dependencies import (
    get_analysis_service,
    get_cache_client,
    get_database,
    get_public_api_client,
    get_rule_engine,
)
from app.services.cache import CacheClient
from app.services.analysis import AnalysisError, AnalysisService
from app.services.auth import AuthError, AuthService
from app.services.costs import cost_summary
from app.services.ocr import CostGuardError, OcrProviderError
from app.services.profile_tokens import normalize_profiles
from app.services.public_api import PublicApiClient
from app.services.risk_rules import RiskRuleEngine

router = APIRouter()


def parse_profiles(value: str | None) -> list[str]:
    return normalize_profiles(value, default=["halal", "vegan", "allergy"])


def bearer_token(authorization: str | None = Header(None)) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail="authorization header is required")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(status_code=401, detail="bearer token is required")
    return token.strip()


def auth_service(db: Annotated[Database, Depends(get_database)]) -> AuthService:
    return AuthService(db)


def current_user(token: Annotated[str, Depends(bearer_token)], auth: Annotated[AuthService, Depends(auth_service)]) -> dict:
    try:
        return auth.me(token)
    except AuthError as exc:
        raise HTTPException(401, "로그인이 필요합니다.") from exc


def resolve_sample_root(configured_path: Path) -> Path:
    if configured_path.exists():
        return configured_path
    return Path("상품 이미지/selected_ocr_samples")


def selected_sample_rel_path(selected_path: str, root: Path) -> str:
    normalized = selected_path.replace("\\", "/")
    prefixes = {
        root.as_posix().rstrip("/") + "/",
        "data/selected_ocr_samples/",
        "상품 이미지/selected_ocr_samples/",
    }
    for prefix in prefixes:
        if normalized.startswith(prefix):
            return normalized[len(prefix):]

    parts = normalized.split("/")
    if "selected_ocr_samples" in parts:
        return "/".join(parts[parts.index("selected_ocr_samples") + 1 :])
    return normalized


@router.get("/health")
def health(
    settings: Annotated[Settings, Depends(get_settings)],
    db: Annotated[Database, Depends(get_database)],
) -> dict:
    return {
        "status": "ok",
        "app": settings.app_name,
        "version": settings.app_version,
        "environment": settings.environment,
        "database_path": str(settings.safebyte_sqlite_path),
        "clova_configured": settings.clova_configured,
        "paid_ocr_enabled": settings.paid_ocr_enabled,
        "clova_usage_today": db.get_usage_count("clova_ocr"),
    }


@router.get("/health/ocr")
def ocr_health(
    settings: Annotated[Settings, Depends(get_settings)],
    db: Annotated[Database, Depends(get_database)],
) -> dict:
    return {
        "status": "configured" if settings.ocr_provider == "mock" or settings.clova_configured else "missing_config",
        "provider": settings.ocr_provider,
        "clova_configured": settings.clova_configured,
        "allow_paid_ocr": settings.allow_paid_ocr,
        "paid_ocr_enabled": settings.paid_ocr_enabled,
        "cache_enabled": settings.ocr_cache_enabled,
        "daily_limit": settings.ocr_daily_limit,
        "usage_today": db.get_usage_count("clova_ocr"),
        "cost_guard": (
            "Live CLOVA calls are blocked unless ALLOW_PAID_OCR=true. "
            "Use ocr_mode=mock with mock_text for zero-cost tests."
        ),
    }


@router.post("/api/v1/auth/register")
def register(
    payload: dict,
    auth: Annotated[AuthService, Depends(auth_service)],
) -> dict:
    try:
        return auth.register(
            email=str(payload.get("email", "")),
            password=str(payload.get("password", "")),
            display_name=str(payload.get("display_name", "")),
            profiles=payload.get("profiles"),
            allergy_notes=str(payload.get("allergy_notes", "")),
        )
    except AuthError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/api/v1/auth/login")
def login(
    payload: dict,
    auth: Annotated[AuthService, Depends(auth_service)],
) -> dict:
    try:
        return auth.login(
            email=str(payload.get("email", "")),
            password=str(payload.get("password", "")),
        )
    except AuthError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


@router.get("/api/v1/me")
def me(
    token: Annotated[str, Depends(bearer_token)],
    auth: Annotated[AuthService, Depends(auth_service)],
) -> dict:
    try:
        return {"user": auth.me(token)}
    except AuthError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


@router.put("/api/v1/me/preferences")
def update_preferences(
    payload: dict,
    token: Annotated[str, Depends(bearer_token)],
    auth: Annotated[AuthService, Depends(auth_service)],
) -> dict:
    try:
        user = auth.update_preferences(
            token=token,
            display_name=str(payload.get("display_name", "")),
            profiles=payload.get("profiles"),
            allergy_notes=str(payload.get("allergy_notes", "")),
        )
        return {"user": user}
    except AuthError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/health/public-apis")
def public_api_health(
    client: Annotated[PublicApiClient, Depends(get_public_api_client)],
    settings: Annotated[Settings, Depends(get_settings)],
    live: Annotated[bool | None, Query(description="Set true to perform cached live public API checks.")] = None,
) -> dict:
    should_call_live = settings.public_api_live_health if live is None else live
    return client.health_check(live=should_call_live)


@router.get("/api/v1/costs")
def get_costs(
    settings: Annotated[Settings, Depends(get_settings)],
    db: Annotated[Database, Depends(get_database)],
    cache: Annotated[CacheClient, Depends(get_cache_client)],
) -> dict:
    return cost_summary(settings, db, cache)


@router.post("/api/v1/analyze/text")
def analyze_text(
    payload: dict,
    service: Annotated[AnalysisService, Depends(get_analysis_service)],
    user: Annotated[dict, Depends(current_user)],
) -> dict:
    text = str(payload.get("text", "")).strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is required")
    profiles = payload.get("profiles")
    if isinstance(profiles, str):
        profiles = parse_profiles(profiles)
    elif not isinstance(profiles, list):
        profiles = None
    if len(text) > 20000:
        raise HTTPException(400, "Text exceeds 20000 characters")
    return service.analyze_text(text=text, profiles=profiles or user["profiles"], user_id=user["user_id"], language=str(payload.get("language", "ko")))


@router.post("/api/v1/analyze/image")
async def analyze_image(
    service: Annotated[AnalysisService, Depends(get_analysis_service)],
    user: Annotated[dict, Depends(current_user)],
    file: UploadFile = File(...),
    profiles: str = Form(""),
    language: str = Form("ko"),
    ocr_mode: str = Form("live"),
    mock_text: str | None = Form(
        None,
        description="Zero-cost OCR substitute. When supplied, CLOVA is not called.",
    ),
    force_ocr: bool = Form(False),
) -> dict:
    normalized_ocr_mode = ocr_mode.strip().lower()
    if normalized_ocr_mode not in {"live", "mock"}:
        raise HTTPException(status_code=400, detail="ocr_mode must be live or mock")
    effective_mock_text = mock_text.strip() if mock_text and normalized_ocr_mode == "mock" else None
    if normalized_ocr_mode == "mock" and not effective_mock_text:
        raise HTTPException(status_code=400, detail="mock_text is required when ocr_mode is mock")

    image_bytes = await file.read(service.settings.ocr_max_upload_mb * 1024 * 1024 + 1)
    try:
        return await run_in_threadpool(service.analyze_image,
            image_bytes=image_bytes,
            filename=file.filename,
            profiles=parse_profiles(profiles) if profiles else user["profiles"],
            mock_text=effective_mock_text,
            force_ocr=force_ocr,
            user_id=user["user_id"],
            language=language,
        )
    except AnalysisError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except CostGuardError as exc:
        raise HTTPException(
            status_code=402,
            detail={
                "message": str(exc),
                "safe_test_tip": "Send ocr_mode=mock with mock_text, or set OCR_PROVIDER=mock for zero-cost tests.",
            },
        ) from exc
    except OcrProviderError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/api/v1/analysis/{request_id}")
def get_analysis(
    request_id: str,
    db: Annotated[Database, Depends(get_database)],
    user: Annotated[dict, Depends(current_user)],
) -> dict:
    if not db.owns_analysis(request_id, user["user_id"]):
        raise HTTPException(404, "analysis not found")
    result = db.get_analysis_response(request_id)
    if not result:
        raise HTTPException(status_code=404, detail="analysis not found")
    return result


@router.get("/api/v1/rules")
def list_rules(engine: Annotated[RiskRuleEngine, Depends(get_rule_engine)]) -> dict:
    return {"rules": engine.list_rules()}


@router.post("/api/v1/rules/reload")
def reload_rules(engine: Annotated[RiskRuleEngine, Depends(get_rule_engine)]) -> dict:
    raise HTTPException(403, "Rules are updated through deployment")


@router.get("/api/v1/samples")
def list_samples(settings: Annotated[Settings, Depends(get_settings)]) -> dict:
    root = resolve_sample_root(settings.sample_images_path)
    manifest = root / "manifest.csv"
    if not manifest.exists():
        return {"samples": []}

    samples = []
    with manifest.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rel = selected_sample_rel_path(row["selected_path"], root)
            url = "/samples/" + quote(rel, safe="/")
            samples.append(
                {
                    "category": row.get("category"),
                    "product": row.get("product"),
                    "filename": row.get("filename"),
                    "url": url,
                }
            )
    return {"samples": samples}
