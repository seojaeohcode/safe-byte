import os
import tempfile
from pathlib import Path

import pytest

_test_dir = tempfile.TemporaryDirectory(prefix="safebyte-tests-")
os.environ.update({
    "SAFEBYTE_ENV_FILE": str(Path(_test_dir.name) / "no-env"),
    "SAFEBYTE_SQLITE_PATH": str(Path(_test_dir.name) / "test.sqlite3"),
    "MFDS_CONFIG_PATH": str(Path(__file__).resolve().parents[1] / "config/mfds_public_apis.example.json"),
    "OCR_PROVIDER": "mock", "ALLOW_PAID_OCR": "false", "REDIS_ENABLED": "false",
    "LLM_ENABLED": "false", "TRANSLATION_ENABLED": "false", "PUBLIC_API_LIVE_HEALTH": "false",
})


@pytest.fixture(autouse=True)
def authenticate_existing_pipeline_tests(request):
    client = getattr(request.module, "client", None)
    if client is not None:
        import uuid
        response = client.post("/api/v1/auth/register", json={"email": f"{uuid.uuid4().hex}@test.local", "password": "test-password", "profiles": ["allergy"]})
        client.headers["Authorization"] = "Bearer " + response.json()["token"]


@pytest.fixture
def clients():
    from fastapi.testclient import TestClient
    from app.main import app
    import uuid
    result = []
    for _ in range(2):
        c = TestClient(app)
        auth = c.post("/api/v1/auth/register", json={"email":f"{uuid.uuid4().hex}@test.local", "password":"test-password", "profiles":["allergy:milk"]}).json()
        c.headers["Authorization"] = "Bearer " + auth["token"]
        result.append(c)
    return result
