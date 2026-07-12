from __future__ import annotations

import json
import sys
from pathlib import Path

from fastapi.testclient import TestClient

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.main import app


SAMPLE_TEXT = (
    "원재료명: 밀가루, 팜유, 정제염, 대두, 우유, 계란, 돼지고기향분말, 젤라틴\n"
    "알레르기 유발물질: 밀, 대두, 우유, 계란, 돼지고기 함유"
)


def main() -> None:
    root = Path("상품 이미지/selected_ocr_samples")
    images = sorted(
        path for path in root.rglob("*")
        if path.suffix.lower() in {".jpg", ".jpeg", ".png"} and not path.name.startswith("_")
    )
    client = TestClient(app)
    results = []
    for path in images[:5]:
        with path.open("rb") as f:
            response = client.post(
                "/api/v1/analyze/image",
                files={"file": (path.name, f, "image/jpeg")},
                data={"profiles": "halal,vegan,allergy", "mock_text": SAMPLE_TEXT},
            )
        response.raise_for_status()
        payload = response.json()
        results.append(
            {
                "file": str(path),
                "request_id": payload["request_id"],
                "final_level": payload["risk"]["final_level"],
                "paid_ocr": payload["ocr"]["called_paid_api"],
                "detections": [item["canonical_name"] for item in payload["risk"]["detections"][:5]],
            }
        )
    print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
