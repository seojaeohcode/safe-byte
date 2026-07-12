from __future__ import annotations

import hashlib
import hmac
import secrets
import uuid
from typing import Any

from app.core.database import Database
from app.services.profile_tokens import normalize_profiles


class AuthError(RuntimeError):
    pass


def normalize_email(email: str) -> str:
    return email.strip().lower()


def hash_password(password: str, salt: str | None = None) -> tuple[str, str]:
    if len(password) < 6:
        raise AuthError("비밀번호는 6자 이상으로 입력해주세요.")
    salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        bytes.fromhex(salt),
        120_000,
    )
    return salt, digest.hex()


def verify_password(password: str, salt: str, expected_hash: str) -> bool:
    _, actual_hash = hash_password(password, salt=salt)
    return hmac.compare_digest(actual_hash, expected_hash)


class AuthService:
    def __init__(self, db: Database):
        self.db = db

    def register(
        self,
        email: str,
        password: str,
        display_name: str,
        profiles: Any,
        allergy_notes: str,
    ) -> dict[str, Any]:
        email = normalize_email(email)
        display_name = display_name.strip() or "Safe-Byte 사용자"
        if "@" not in email or "." not in email:
            raise AuthError("이메일 형식이 올바르지 않습니다.")
        if self.db.get_user_by_email(email):
            raise AuthError("이미 가입된 이메일입니다.")

        salt, password_hash = hash_password(password)
        user = self.db.create_user(
            user_id=str(uuid.uuid4()),
            email=email,
            display_name=display_name,
            password_salt=salt,
            password_hash=password_hash,
            profiles=normalize_profiles(profiles, default=[]),
            allergy_notes=allergy_notes.strip(),
        )
        return self._with_session(user)

    def login(self, email: str, password: str) -> dict[str, Any]:
        email = normalize_email(email)
        raw_user = self.db.get_user_by_email(email)
        if not raw_user or not verify_password(
            password,
            str(raw_user["password_salt"]),
            str(raw_user["password_hash"]),
        ):
            raise AuthError("이메일 또는 비밀번호를 확인해주세요.")
        user = self.db.get_user_by_id(str(raw_user["user_id"]))
        if not user:
            raise AuthError("사용자 정보를 찾을 수 없습니다.")
        return self._with_session(user)

    def me(self, token: str) -> dict[str, Any]:
        user = self.db.get_user_by_session(token)
        if not user:
            raise AuthError("로그인이 필요합니다.")
        return user

    def update_preferences(
        self,
        token: str,
        display_name: str,
        profiles: Any,
        allergy_notes: str,
    ) -> dict[str, Any]:
        current = self.me(token)
        user = self.db.update_user_preferences(
            user_id=current["user_id"],
            display_name=display_name.strip() or current["display_name"],
            profiles=normalize_profiles(profiles, default=[]),
            allergy_notes=allergy_notes.strip(),
        )
        if not user:
            raise AuthError("사용자 정보를 저장하지 못했습니다.")
        return user

    def _with_session(self, user: dict[str, Any]) -> dict[str, Any]:
        session = self.db.create_session(
            token=secrets.token_urlsafe(32),
            user_id=user["user_id"],
        )
        return {"token": session["token"], "expires_at": session["expires_at"], "user": user}
