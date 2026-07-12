from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any, Iterator


def utc_now() -> datetime:
    return datetime.now(UTC)


def json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def json_loads(value: str | None, default: Any = None) -> Any:
    if not value:
        return default
    return json.loads(value)


class Database:
    def __init__(self, path: Path):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.init_schema()

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("PRAGMA foreign_keys = ON")
            yield conn
            conn.commit()
        finally:
            conn.close()

    def init_schema(self) -> None:
        with self.connect() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS analysis_requests (
                    request_id TEXT PRIMARY KEY,
                    image_hash TEXT,
                    source_name TEXT,
                    status TEXT NOT NULL,
                    final_level TEXT,
                    profiles_json TEXT NOT NULL,
                    response_json TEXT,
                    error_message TEXT,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS ocr_results (
                    image_hash TEXT PRIMARY KEY,
                    provider TEXT NOT NULL,
                    text TEXT NOT NULL,
                    raw_response_json TEXT,
                    image_format TEXT,
                    image_width INTEGER,
                    image_height INTEGER,
                    called_paid_api INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS ingredient_segments (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    request_id TEXT NOT NULL,
                    segment_type TEXT NOT NULL,
                    text TEXT NOT NULL,
                    FOREIGN KEY(request_id) REFERENCES analysis_requests(request_id)
                );

                CREATE TABLE IF NOT EXISTS risk_detections (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    request_id TEXT NOT NULL,
                    rule_id TEXT NOT NULL,
                    category TEXT NOT NULL,
                    severity TEXT NOT NULL,
                    canonical_name TEXT NOT NULL,
                    matched_keyword TEXT NOT NULL,
                    evidence TEXT NOT NULL,
                    reason TEXT NOT NULL,
                    confidence REAL NOT NULL,
                    FOREIGN KEY(request_id) REFERENCES analysis_requests(request_id)
                );

                CREATE TABLE IF NOT EXISTS api_usage (
                    provider TEXT NOT NULL,
                    usage_date TEXT NOT NULL,
                    count INTEGER NOT NULL,
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY(provider, usage_date)
                );

                CREATE TABLE IF NOT EXISTS public_api_cache (
                    cache_key TEXT PRIMARY KEY,
                    api_name TEXT NOT NULL,
                    query_json TEXT NOT NULL,
                    response_json TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS users (
                    user_id TEXT PRIMARY KEY,
                    email TEXT NOT NULL UNIQUE,
                    display_name TEXT NOT NULL,
                    password_salt TEXT NOT NULL,
                    password_hash TEXT NOT NULL,
                    profiles_json TEXT NOT NULL,
                    allergy_notes TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS user_sessions (
                    token TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    expires_at TEXT NOT NULL,
                    FOREIGN KEY(user_id) REFERENCES users(user_id)
                );
                """
            )

    @staticmethod
    def _user_payload(row: sqlite3.Row) -> dict[str, Any]:
        return {
            "user_id": row["user_id"],
            "email": row["email"],
            "display_name": row["display_name"],
            "profiles": json_loads(row["profiles_json"], []),
            "allergy_notes": row["allergy_notes"] or "",
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    def create_user(
        self,
        user_id: str,
        email: str,
        display_name: str,
        password_salt: str,
        password_hash: str,
        profiles: list[str],
        allergy_notes: str,
    ) -> dict[str, Any]:
        now = utc_now().isoformat()
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO users
                    (user_id, email, display_name, password_salt, password_hash,
                     profiles_json, allergy_notes, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    user_id,
                    email,
                    display_name,
                    password_salt,
                    password_hash,
                    json_dumps(profiles),
                    allergy_notes,
                    now,
                    now,
                ),
            )
            row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
            return self._user_payload(row)

    def get_user_by_email(self, email: str) -> dict[str, Any] | None:
        with self.connect() as conn:
            row = conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
            return dict(row) if row else None

    def get_user_by_id(self, user_id: str) -> dict[str, Any] | None:
        with self.connect() as conn:
            row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
            return self._user_payload(row) if row else None

    def update_user_preferences(
        self,
        user_id: str,
        display_name: str,
        profiles: list[str],
        allergy_notes: str,
    ) -> dict[str, Any] | None:
        with self.connect() as conn:
            conn.execute(
                """
                UPDATE users
                SET display_name = ?, profiles_json = ?, allergy_notes = ?, updated_at = ?
                WHERE user_id = ?
                """,
                (display_name, json_dumps(profiles), allergy_notes, utc_now().isoformat(), user_id),
            )
            row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
            return self._user_payload(row) if row else None

    def create_session(self, token: str, user_id: str, ttl_days: int = 30) -> dict[str, Any]:
        now = utc_now()
        expires_at = now + timedelta(days=ttl_days)
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO user_sessions (token, user_id, created_at, expires_at)
                VALUES (?, ?, ?, ?)
                """,
                (token, user_id, now.isoformat(), expires_at.isoformat()),
            )
            return {
                "token": token,
                "user_id": user_id,
                "expires_at": expires_at.isoformat(),
            }

    def get_user_by_session(self, token: str) -> dict[str, Any] | None:
        with self.connect() as conn:
            row = conn.execute(
                """
                SELECT users.*
                FROM user_sessions
                JOIN users ON users.user_id = user_sessions.user_id
                WHERE user_sessions.token = ? AND user_sessions.expires_at > ?
                """,
                (token, utc_now().isoformat()),
            ).fetchone()
            return self._user_payload(row) if row else None

    def create_analysis_request(
        self,
        request_id: str,
        image_hash: str | None,
        source_name: str | None,
        profiles: list[str],
    ) -> None:
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO analysis_requests
                    (request_id, image_hash, source_name, status, profiles_json, created_at)
                VALUES (?, ?, ?, 'started', ?, ?)
                """,
                (request_id, image_hash, source_name, json_dumps(profiles), utc_now().isoformat()),
            )

    def complete_analysis(
        self,
        request_id: str,
        final_level: str,
        response: dict[str, Any],
    ) -> None:
        with self.connect() as conn:
            conn.execute(
                """
                UPDATE analysis_requests
                SET status = 'completed', final_level = ?, response_json = ?, error_message = NULL
                WHERE request_id = ?
                """,
                (final_level, json_dumps(response), request_id),
            )

    def fail_analysis(self, request_id: str, message: str) -> None:
        with self.connect() as conn:
            conn.execute(
                """
                UPDATE analysis_requests
                SET status = 'failed', error_message = ?
                WHERE request_id = ?
                """,
                (message, request_id),
            )

    def get_analysis_response(self, request_id: str) -> dict[str, Any] | None:
        with self.connect() as conn:
            row = conn.execute(
                "SELECT response_json, status, error_message FROM analysis_requests WHERE request_id = ?",
                (request_id,),
            ).fetchone()
            if not row:
                return None
            if row["response_json"]:
                return json_loads(row["response_json"], {})
            return {
                "request_id": request_id,
                "status": row["status"],
                "error_message": row["error_message"],
            }

    def find_ocr_result(self, image_hash: str, provider: str | None = None) -> dict[str, Any] | None:
        with self.connect() as conn:
            if provider:
                row = conn.execute(
                    "SELECT * FROM ocr_results WHERE image_hash = ? AND provider = ?",
                    (image_hash, provider),
                ).fetchone()
            else:
                row = conn.execute(
                    "SELECT * FROM ocr_results WHERE image_hash = ?",
                    (image_hash,),
                ).fetchone()
            if not row:
                return None
            result = dict(row)
            result["raw_response"] = json_loads(result.pop("raw_response_json"), {})
            result["cached"] = True
            return result

    def save_ocr_result(
        self,
        image_hash: str,
        provider: str,
        text: str,
        raw_response: dict[str, Any] | None,
        image_format: str,
        image_width: int,
        image_height: int,
        called_paid_api: bool,
    ) -> None:
        with self.connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO ocr_results
                    (image_hash, provider, text, raw_response_json, image_format,
                     image_width, image_height, called_paid_api, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    image_hash,
                    provider,
                    text,
                    json_dumps(raw_response or {}),
                    image_format,
                    image_width,
                    image_height,
                    int(called_paid_api),
                    utc_now().isoformat(),
                ),
            )

    def save_segments(self, request_id: str, segments: list[dict[str, str]]) -> None:
        with self.connect() as conn:
            conn.executemany(
                """
                INSERT INTO ingredient_segments (request_id, segment_type, text)
                VALUES (?, ?, ?)
                """,
                [(request_id, item["type"], item["text"]) for item in segments],
            )

    def save_detections(self, request_id: str, detections: list[dict[str, Any]]) -> None:
        with self.connect() as conn:
            conn.executemany(
                """
                INSERT INTO risk_detections
                    (request_id, rule_id, category, severity, canonical_name,
                     matched_keyword, evidence, reason, confidence)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        request_id,
                        item["rule_id"],
                        item["category"],
                        item["severity"],
                        item["canonical_name"],
                        item["matched_keyword"],
                        item["evidence"],
                        item["reason"],
                        float(item["confidence"]),
                    )
                    for item in detections
                ],
            )

    def get_usage_count(self, provider: str, usage_date: str | None = None) -> int:
        usage_date = usage_date or utc_now().date().isoformat()
        with self.connect() as conn:
            row = conn.execute(
                "SELECT count FROM api_usage WHERE provider = ? AND usage_date = ?",
                (provider, usage_date),
            ).fetchone()
            return int(row["count"]) if row else 0

    def get_usage_total(
        self,
        provider: str,
        start_date: str | None = None,
        end_date: str | None = None,
    ) -> int:
        query = "SELECT COALESCE(SUM(count), 0) AS total FROM api_usage WHERE provider = ?"
        params: list[Any] = [provider]
        if start_date:
            query += " AND usage_date >= ?"
            params.append(start_date)
        if end_date:
            query += " AND usage_date <= ?"
            params.append(end_date)
        with self.connect() as conn:
            row = conn.execute(query, params).fetchone()
            return int(row["total"]) if row else 0

    def count_ocr_results(self, provider: str | None = None) -> int:
        with self.connect() as conn:
            if provider:
                row = conn.execute(
                    "SELECT COUNT(*) AS count FROM ocr_results WHERE provider = ?",
                    (provider,),
                ).fetchone()
            else:
                row = conn.execute("SELECT COUNT(*) AS count FROM ocr_results").fetchone()
            return int(row["count"]) if row else 0

    def count_analysis_requests(self) -> int:
        with self.connect() as conn:
            row = conn.execute("SELECT COUNT(*) AS count FROM analysis_requests").fetchone()
            return int(row["count"]) if row else 0

    def increment_usage(self, provider: str, usage_date: str | None = None) -> int:
        usage_date = usage_date or utc_now().date().isoformat()
        now = utc_now().isoformat()
        with self.connect() as conn:
            conn.execute(
                """
                INSERT INTO api_usage (provider, usage_date, count, updated_at)
                VALUES (?, ?, 1, ?)
                ON CONFLICT(provider, usage_date)
                DO UPDATE SET count = count + 1, updated_at = excluded.updated_at
                """,
                (provider, usage_date, now),
            )
            row = conn.execute(
                "SELECT count FROM api_usage WHERE provider = ? AND usage_date = ?",
                (provider, usage_date),
            ).fetchone()
            return int(row["count"])

    def get_public_cache(self, cache_key: str) -> dict[str, Any] | None:
        with self.connect() as conn:
            row = conn.execute(
                "SELECT response_json, expires_at FROM public_api_cache WHERE cache_key = ?",
                (cache_key,),
            ).fetchone()
            if not row:
                return None
            expires_at = datetime.fromisoformat(row["expires_at"])
            if expires_at <= utc_now():
                return None
            return json_loads(row["response_json"], {})

    def set_public_cache(
        self,
        cache_key: str,
        api_name: str,
        query: dict[str, Any],
        response: dict[str, Any],
        ttl_seconds: int,
    ) -> None:
        now = utc_now()
        expires_at = now + timedelta(seconds=ttl_seconds)
        with self.connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO public_api_cache
                    (cache_key, api_name, query_json, response_json, expires_at, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    cache_key,
                    api_name,
                    json_dumps(query),
                    json_dumps(response),
                    expires_at.isoformat(),
                    now.isoformat(),
                ),
            )
