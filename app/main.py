from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes import router
from app.core.config import get_settings


def resolve_sample_dir(configured_path: Path) -> Path:
    if configured_path.exists():
        return configured_path
    legacy_path = Path("상품 이미지/selected_ocr_samples")
    return legacy_path


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description="Safe-Byte MVP backend: OCR-based Korean food label risk analysis.",
        docs_url="/docs" if settings.enable_docs else None,
        redoc_url="/redoc" if settings.enable_docs else None,
        openapi_url="/openapi.json" if settings.enable_docs else None,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "OPTIONS"],
        allow_headers=["Accept", "Content-Type", "Authorization"],
    )
    app.include_router(router)

    web_dir = Path("web")
    if web_dir.exists():
        app.mount("/static", StaticFiles(directory=web_dir), name="static")

        @app.get("/app")
        def web_app():
            from fastapi.responses import FileResponse

            return FileResponse(web_dir / "index.html")

    sample_dir = resolve_sample_dir(settings.sample_images_path)
    if sample_dir.exists():
        app.mount("/samples", StaticFiles(directory=sample_dir), name="samples")

    @app.get("/")
    def root() -> dict:
        return {
            "name": settings.app_name,
            "version": settings.app_version,
            "docs": "/docs" if settings.enable_docs else None,
            "health": "/health",
        }

    return app


app = create_app()
