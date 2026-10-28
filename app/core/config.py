from functools import lru_cache
import os
from pathlib import Path
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Safe-Byte Backend"
    app_version: str = "0.1.0"
    environment: str = "local"
    enable_docs: bool = True
    cors_allowed_origins: str = "http://127.0.0.1:5173,http://localhost:5173"
    redis_enabled: bool = False
    redis_url: str = "redis://redis:6379/0"
    redis_timeout_seconds: float = 0.25
    redis_ocr_cache_ttl_seconds: int = 2592000

    clova_ocr_invoke_url: str | None = None
    clova_ocr_secret_key: str | None = None
    ocr_provider: Literal["mock", "clova"] = "mock"
    allow_paid_ocr: bool = False
    ocr_daily_limit: int = 10
    ocr_cache_enabled: bool = True
    ocr_max_image_mb: int = 3
    ocr_max_upload_mb: int = 10
    ocr_max_long_edge: int = 1600
    ocr_jpeg_quality: int = 85
    ocr_timeout_seconds: int = 20
    image_preprocessing: bool = True
    ocr_min_confidence: float = 0.75
    llm_base_url: str = "http://127.0.0.1:11434"
    llm_model: str = "qwen2.5:3b"
    llm_enabled: bool = False
    llm_provider: Literal['ollama', 'openai'] = 'ollama'
    openai_api_key: str | None = None
    openai_model: str = 'gpt-4o-mini'
    llm_daily_limit: int = Field(default=100, ge=0)
    llm_timeout_seconds: int = 15
    translation_enabled: bool = False
    catalog_path: Path = Path("data/products.json")

    public_api_live_health: bool = False
    public_api_timeout_seconds: int = 10
    public_api_cache_ttl_seconds: int = 86400

    safebyte_sqlite_path: Path = Field(default=Path("data/safe_byte.sqlite3"))
    risk_rules_path: Path = Field(default=Path("data/risk_rules.json"))
    mfds_config_path: Path = Field(default=Path("config/mfds_public_apis.json"))
    sample_images_path: Path = Field(default=Path("data/selected_ocr_samples"))
    ncloud_cost_snapshot_path: Path = Field(default=Path("config/ncloud_cost_snapshot.json"))

    ncloud_server_spec_code: str = "mi1-g3"
    ncloud_fee_system_type_code: str = "FXSUM"
    ocr_general_free_quota_monthly: int = 100
    ocr_general_unit_price_krw: int = 3

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8-sig",
        case_sensitive=False,
        extra="ignore",
    )

    @field_validator("ocr_daily_limit")
    @classmethod
    def positive_daily_limit(cls, value: int) -> int:
        if value < 0:
            raise ValueError("OCR_DAILY_LIMIT must be 0 or greater")
        return value

    @field_validator("ocr_jpeg_quality")
    @classmethod
    def valid_jpeg_quality(cls, value: int) -> int:
        if value < 40 or value > 95:
            raise ValueError("OCR_JPEG_QUALITY must be between 40 and 95")
        return value

    @property
    def clova_configured(self) -> bool:
        return bool(self.clova_ocr_invoke_url and self.clova_ocr_secret_key)

    @property
    def paid_ocr_enabled(self) -> bool:
        return self.ocr_provider == "clova" and self.allow_paid_ocr and self.clova_configured

    @property
    def cors_origins(self) -> list[str]:
        return [
            origin.strip().rstrip("/")
            for origin in self.cors_allowed_origins.split(",")
            if origin.strip()
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings(_env_file=os.environ.get("SAFEBYTE_ENV_FILE", ".env"))
