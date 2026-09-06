from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

import httpx

from app.core.config import Settings
from app.core.database import Database


class PublicApiClient:
    def __init__(self, config_path: Path, db: Database, settings: Settings):
        self.config_path = config_path
        self.db = db
        self.settings = settings
        self.config = self._load_config()

    def _load_config(self) -> dict[str, Any]:
        with self.config_path.open(encoding="utf-8") as f:
            return json.load(f)

    def reload(self) -> None:
        self.config = self._load_config()

    def search_reference(self, name: str, kind: str = 'nutrition') -> dict:
        api_name, field = ('food_nutrition_component_db', 'FOOD_NM_KR') if kind == 'nutrition' else ('food_raw_material_info', 'ORM_STD_NM')
        api = self.config.get('apis', {}).get(api_name, {})
        key = self.config.get('keys', {}).get(api.get('service_key_ref', ''))
        empty = {'source': 'MFDS', 'kind': kind, 'query': name, 'items': [],
                 'note': '공공 DB 참고 정보입니다. 동일 제품·제조사·기준량을 확인하세요. 인증 판정에는 사용하지 않습니다.'}
        if not key or str(key).startswith('YOUR_'):
            return {**empty, 'status': 'not_configured'}
        cache_key = 'reference:v1:' + hashlib.sha256(f'{kind}:{name}'.encode()).hexdigest()
        cached = self.db.get_public_cache(cache_key)
        if cached:
            return {**cached, 'cached': True}
        try:
            response = httpx.get(api['request_url'].replace('http://', 'https://'),
                params={'serviceKey': key, 'pageNo': 1, 'numOfRows': 20, 'type': 'json', field: name},
                timeout=self.settings.public_api_timeout_seconds)
            response.raise_for_status()
            data = response.json()
            if str(data.get('header', {}).get('resultCode')) != '00':
                return {**empty, 'status': 'provider_error'}
            rows = data.get('body', {}).get('items', []) or []
            if not isinstance(rows, list):
                raise ValueError('Unexpected public API shape')
            # Also filter locally: ignored remote filters must never produce false matches.
            rows = [r for r in rows if name.casefold() in str(r.get(field, '')).casefold()]
            items = [{'name': r.get(field), 'english_name': r.get('ORM_STD_NM_ENG'),
                      'manufacturer': r.get('MAKER_NM'), 'serving_size': r.get('SERVING_SIZE'),
                      'code': r.get('FOOD_CD') or r.get('ORM_STD_CD'), 'updated_at': r.get('UPDATE_DATE')} for r in rows]
            result = {**empty, 'status': 'found' if items else 'no_match', 'items': items,
                      'total_count': data.get('body', {}).get('totalCount'), 'limit': 20}
            self.db.set_public_cache(cache_key, api_name, {'name': name}, result, self.settings.public_api_cache_ttl_seconds)
            return result
        except (httpx.HTTPError, ValueError, KeyError, TypeError):
            return {**empty, 'status': 'unavailable'}

    def configured_services(self) -> list[dict[str, Any]]:
        return [
            {
                "api_name": api_name,
                "display_name": api.get("display_name", api_name),
                "provider": api.get("provider"),
                "purpose": api.get("purpose"),
            }
            for api_name, api in self.config.get("apis", {}).items()
        ]

    def health_check(self, live: bool = False) -> dict[str, Any]:
        services = self.configured_services()
        if not live:
            return {
                "live": False,
                "message": "Live public API calls skipped. Use ?live=true only when needed.",
                "services": [
                    {**service, "status": "configured"} for service in services
                ],
            }

        results = []
        for service in services:
            api_name = service["api_name"]
            cached = self.db.get_public_cache(f"health:{api_name}")
            if cached:
                results.append({**service, **cached, "cached": True})
                continue
            result = self._call_health(api_name)
            self.db.set_public_cache(
                cache_key=f"health:{api_name}",
                api_name=api_name,
                query={"health": True},
                response=result,
                ttl_seconds=self.settings.public_api_cache_ttl_seconds,
            )
            results.append({**service, **result, "cached": False})

        return {"live": True, "services": results}

    def _call_health(self, api_name: str) -> dict[str, Any]:
        api = self.config["apis"][api_name]
        provider = api.get("provider")
        keys = self.config.get("keys", {})
        key = keys.get(api.get("service_key_ref", ""))
        timeout = self.config.get("defaults", {}).get(
            "timeout_seconds", self.settings.public_api_timeout_seconds
        )
        try:
            if provider == "data.go.kr":
                response = httpx.get(
                    api["request_url"],
                    params={
                        "serviceKey": key,
                        "pageNo": "1",
                        "numOfRows": "1",
                        "type": "json",
                    },
                    timeout=timeout,
                )
            else:
                defaults = self.config.get("defaults", {})
                url = api["endpoint_template"].format(
                    key=key,
                    service_id=api["service_id"],
                    format=defaults.get("format", "json"),
                    start_index=1,
                    end_index=1,
                )
                response = httpx.get(url, timeout=timeout)
        except httpx.HTTPError:
            return {"status": "error", "error": "Public API connection failed"}

        if response.status_code >= 400:
            return {
                "status": "error",
                "http_status": response.status_code,
            }
        return {
            "status": "ok",
            "http_status": response.status_code,
            "body_sha256": hashlib.sha256(response.content).hexdigest(),
        }
