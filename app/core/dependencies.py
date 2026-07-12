from functools import lru_cache

from app.core.config import get_settings
from app.core.database import Database
from app.services.analysis import AnalysisService
from app.services.cache import CacheClient
from app.services.ocr import OcrService
from app.services.public_api import PublicApiClient
from app.services.risk_rules import RiskRuleEngine


@lru_cache
def get_database() -> Database:
    settings = get_settings()
    return Database(settings.safebyte_sqlite_path)


@lru_cache
def get_rule_engine() -> RiskRuleEngine:
    settings = get_settings()
    return RiskRuleEngine(settings.risk_rules_path)


@lru_cache
def get_public_api_client() -> PublicApiClient:
    settings = get_settings()
    return PublicApiClient(settings.mfds_config_path, get_database(), settings)


@lru_cache
def get_cache_client() -> CacheClient:
    return CacheClient(get_settings())


@lru_cache
def get_ocr_service() -> OcrService:
    return OcrService(get_settings(), get_database(), get_cache_client())


@lru_cache
def get_analysis_service() -> AnalysisService:
    return AnalysisService(get_settings(), get_database(), get_ocr_service(), get_rule_engine())
