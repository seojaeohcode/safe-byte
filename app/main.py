from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes import router
from app.api.workspace_routes import router as workspace_router
from app.services.workspace import WorkspaceError
from fastapi.responses import JSONResponse
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
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Accept", "Content-Type", "Authorization"],
    )
    app.include_router(router)
    app.include_router(workspace_router)

    @app.exception_handler(WorkspaceError)
    async def workspace_error(request, exc):
        return JSONResponse(status_code=400, content={"detail": str(exc)})

    web_dir = Path("web")
    if web_dir.exists():
        app.mount("/static", StaticFiles(directory=web_dir), name="static")
        if (web_dir / 'mobile').exists():
            app.mount('/mobile', StaticFiles(directory=web_dir / 'mobile', html=True), name='flutter')

        @app.get("/app")
        @app.get("/app/")
        def web_app():
            from fastapi.responses import FileResponse
            if (web_dir / 'mobile' / 'index.html').exists():
                from fastapi.responses import RedirectResponse
                return RedirectResponse('/mobile/')
            return FileResponse(web_dir / "index.html")

        @app.get('/lab')
        def ocr_lab():
            from fastapi.responses import FileResponse
            return FileResponse(web_dir / 'index.html')

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
