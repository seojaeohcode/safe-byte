from io import BytesIO
import uuid

from fastapi.testclient import TestClient
from PIL import Image

from app.main import app


client = TestClient(app)


def make_test_image() -> bytes:
    image = Image.new("RGB", (640, 420), "white")
    output = BytesIO()
    image.save(output, format="JPEG")
    return output.getvalue()


def test_text_analysis_detects_core_risks():
    response = client.post(
        "/api/v1/analyze/text",
        json={
            "text": "원재료명: 밀가루, 대두, 우유, 계란, 돼지고기향분말, 젤라틴",
            "profiles": ["halal", "vegan", "allergy"],
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["risk"]["final_level"] == "DANGER"
    names = {item["canonical_name"] for item in payload["risk"]["detections"]}
    assert "돼지고기" in names
    assert "우유/유제품" in names
    assert "밀/글루텐" in names


def test_image_analysis_uses_mock_text_without_paid_ocr():
    response = client.post(
        "/api/v1/analyze/image",
        files={"file": ("label.jpg", make_test_image(), "image/jpeg")},
        data={
            "profiles": "halal,vegan,allergy",
            "ocr_mode": "mock",
            "mock_text": "원재료명: 밀가루, 대두, 우유, 계란\n알레르기 유발물질: 밀, 대두, 우유, 계란 함유",
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["ocr"]["provider"] == "mock"
    assert payload["ocr"]["called_paid_api"] is False
    assert payload["risk"]["final_level"] == "DANGER"


def test_image_analysis_rejects_invalid_ocr_mode_before_ocr_call():
    response = client.post(
        "/api/v1/analyze/image",
        files={"file": ("label.jpg", make_test_image(), "image/jpeg")},
        data={
            "profiles": "halal,vegan,allergy",
            "ocr_mode": "clova-ish",
            "mock_text": "원재료명: 돼지고기",
        },
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "ocr_mode must be live or mock"


def test_register_login_and_update_preferences():
    email = f"user-{uuid.uuid4().hex[:10]}@example.com"
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "secret123",
            "display_name": "민지",
            "profiles": ["halal", "allergy"],
            "allergy_notes": "우유 주의",
        },
    )
    assert response.status_code == 200
    payload = response.json()
    token = payload["token"]
    assert payload["user"]["profiles"] == ["halal", "allergy"]

    me = client.get("/api/v1/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["user"]["email"] == email

    updated = client.put(
        "/api/v1/me/preferences",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "display_name": "민지",
            "profiles": ["vegan", "allergy"],
            "allergy_notes": "우유, 계란",
        },
    )
    assert updated.status_code == 200
    assert updated.json()["user"]["profiles"] == ["vegan", "allergy"]

    login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "secret123"},
    )
    assert login.status_code == 200
    assert login.json()["user"]["allergy_notes"] == "우유, 계란"


def test_register_can_defer_preferences_until_after_login():
    email = f"user-{uuid.uuid4().hex[:10]}@example.com"
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "secret123",
            "display_name": "민지",
            "profiles": [],
            "allergy_notes": "",
        },
    )
    assert response.status_code == 200
    assert response.json()["user"]["profiles"] == []


def test_public_api_health_skips_live_calls_by_default():
    response = client.get("/health/public-apis")
    assert response.status_code == 200
    payload = response.json()
    assert payload["live"] is False
    assert len(payload["services"]) == 6


def test_cross_contact_is_caution_not_direct_danger():
    response = client.post(
        "/api/v1/analyze/text",
        json={
            "text": (
                "이 제품은 메밀, 땅콩, 돼지고기, 새우를 사용한 제품과 "
                "같은 제조시설에서 제조하고 있습니다."
            ),
            "profiles": ["halal", "allergy"],
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["risk"]["final_level"] == "CAUTION"
    assert {item["occurrence_type"] for item in payload["risk"]["detections"]} == {"cross_contact"}
    assert {item["severity"] for item in payload["risk"]["detections"]} == {"caution"}


def test_direct_ingredient_wins_over_later_cross_contact_notice():
    response = client.post(
        "/api/v1/analyze/text",
        json={
            "text": (
                "원재료명: 설탕, 혼합분유[전지분유(우유), 유청분말], 레시틴(대두). "
                "우유, 대두 함유. 이 제품은 메밀, 땅콩, 돼지고기를 사용한 제품과 "
                "같은 제조시설에서 제조하고 있습니다."
            ),
            "profiles": ["halal", "vegan", "allergy"],
        },
    )
    assert response.status_code == 200
    payload = response.json()
    milk = [
        item for item in payload["risk"]["detections"]
        if item["canonical_name"] == "우유" and item["category"] == "allergy"
    ][0]
    pork = [
        item for item in payload["risk"]["detections"]
        if item["canonical_name"] == "돼지고기"
    ][0]
    assert milk["occurrence_type"] == "direct"
    assert milk["severity"] == "danger"
    assert pork["occurrence_type"] == "cross_contact"
    assert pork["severity"] == "caution"
    assert "제조시설 공유 표기" in payload["risk"]["summary"]
    assert "직접 함유 아님" in payload["risk"]["summary"]


def test_ocr_correction_normalizes_spaced_risk_terms_before_detection():
    response = client.post(
        "/api/v1/analyze/text",
        json={
            "text": (
                "원 재료 명: 혼 합 분 유(우 유), 대 두, 돼지 고기향분말. "
                "알 러지 유 발 물질: 메 밀, 땅 콩, 갑 각류 함 유"
            ),
            "profiles": ["halal", "vegan", "allergy"],
        },
    )
    assert response.status_code == 200
    payload = response.json()
    names = {item["canonical_name"] for item in payload["risk"]["detections"]}
    assert payload["risk"]["final_level"] == "DANGER"
    assert payload["ocr"]["correction_count"] >= 8
    assert "원재료명" in payload["ocr"]["corrected_text"]
    assert "돼지고기" in names
    assert "우유/유제품" in names
    assert "메밀" in names
    assert "땅콩" in names
    assert "갑각류" in names


def test_corrected_cross_contact_terms_remain_caution():
    response = client.post(
        "/api/v1/analyze/text",
        json={
            "text": (
                "이 제품은 메 밀, 땅 콩, 돼지 고기, 갑 각류를 사용한 제품과 "
                "같은 제조 시설에서 제조하고 있습니다."
            ),
            "profiles": ["halal", "allergy"],
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["risk"]["final_level"] == "CAUTION"
    assert payload["ocr"]["correction_count"] >= 5
    assert {item["occurrence_type"] for item in payload["risk"]["detections"]} == {"cross_contact"}
    assert {item["severity"] for item in payload["risk"]["detections"]} == {"caution"}


def test_granular_allergy_profile_only_flags_selected_allergen():
    response = client.post(
        "/api/v1/analyze/text",
        json={
            "text": "원재료명: 밀가루, 우유, 대두, 계란. 알레르기 유발물질: 밀, 우유, 대두, 계란 함유",
            "profiles": ["allergy:milk"],
        },
    )
    assert response.status_code == 200
    payload = response.json()
    allergy_names = {
        item["canonical_name"]
        for item in payload["risk"]["detections"]
        if item["category"] == "allergy"
    }
    assert allergy_names == {"우유"}


def test_source_unknown_additives_are_caution_not_safe_claim():
    response = client.post(
        "/api/v1/analyze/text",
        json={
            "text": "원재료명: 설탕, 코코아분말, 글리세린지방산에스테르, 효소, 젤라틴",
            "profiles": ["halal", "vegan"],
        },
    )
    assert response.status_code == 200
    payload = response.json()
    bases = {item["decision_basis"] for item in payload["risk"]["detections"]}
    names = {item["canonical_name"] for item in payload["risk"]["detections"]}
    assert payload["risk"]["final_level"] == "DANGER"
    assert "source_unknown_additive" in bases
    assert "출처 확인 필요 첨가물" in names
    assert "젤라틴" in names


def test_plant_based_context_skips_ambiguous_shortening():
    response = client.post(
        "/api/v1/analyze/text",
        json={
            "text": "원재료명: 설탕, 식물성쇼트닝(유채씨유, 해바라기유), 코코아분말",
            "profiles": ["halal", "vegan"],
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["risk"]["final_level"] == "SAFE"
