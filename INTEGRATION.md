# SafeByte API 연동 안내 (외부 개발자용)

이 문서 하나만 있으면 SafeByte 서버에 붙을 수 있습니다. 이 저장소를 클론하지 않아도 됩니다.

## 1. 서버

| 항목 | 값 |
|---|---|
| Base URL | `http://101.79.20.37` |
| 프로토콜 | **평문 HTTP** (HTTPS 아님, 도메인 없음) |
| Swagger UI | `http://101.79.20.37/docs` |
| OpenAPI 스펙 | `http://101.79.20.37/openapi.json` |
| 상태 확인 | `http://101.79.20.37/health` |

데모/내부 테스트용 서버입니다. 실제 개인정보를 넣지 마세요.

## 2. 인증 — 여기서 대부분 막힙니다

**`/api/v1/*`는 아래 목록을 제외하면 전부 Bearer 토큰이 필요합니다.**
헤더가 없으면 `401 {"detail":"authorization header is required"}`가 돌아옵니다.
분석 결과가 사용자 소유(이력·장바구니·저장상품이 계정에 묶임)라서 익명 호출을 막아둔 설계이고,
서버가 중간에 바뀐 것이 아닙니다.

인증이 **필요 없는** 엔드포인트:
`/health`, `/health/ocr`, `/health/public-apis`,
`/api/v1/auth/register`, `/api/v1/auth/login`,
`/api/v1/rules`, `/api/v1/samples`, `/api/v1/costs`, `/api/v1/devices/redeem`

### 순서

```
POST /api/v1/auth/register   (최초 1회)  → { token, expires_at, user }
POST /api/v1/auth/login                  → { token, expires_at, user }
이후 모든 요청에  Authorization: Bearer <token>
```

토큰 수명은 30일이고 `POST /api/v1/auth/logout`을 부르면 즉시 무효화됩니다.

### 테스트 계정

```
email    team-test@safebyte.test
password safebyte-9d1aca28
```

```python
import httpx

API = "http://101.79.20.37"
c = httpx.Client(base_url=API, timeout=60)

token = c.post("/api/v1/auth/login", json={
    "email": "team-test@safebyte.test",
    "password": "safebyte-9d1aca28",
}).json()["token"]
auth = {"Authorization": "Bearer " + token}

r = c.post("/api/v1/analyze/text", headers=auth, json={
    "text": "원재료명: 밀가루, 우유",
    "profiles": ["allergy:milk"],
})
print(r.json()["risk"]["final_level"])   # DANGER
```

새 계정을 만들려면:

```python
c.post("/api/v1/auth/register", json={
    "email": "me@example.com", "password": "6자 이상",
    "display_name": "이름", "profiles": ["allergy:milk", "halal"],
})
```

## 3. 자주 쓰는 엔드포인트

| Method | Path | Auth | 설명 |
|---|---|---|---|
| `POST` | `/api/v1/analyze/text` | 필요 | 텍스트 분석. **OCR 한도를 쓰지 않음** |
| `POST` | `/api/v1/analyze/image` | 필요 | 라벨 이미지 OCR + 분석 (multipart) |
| `GET` | `/api/v1/analysis/{request_id}` | 필요 | 분석 결과 다시 조회 |
| `GET` | `/api/v1/history` | 필요 | 내 분석 이력 (최근 100건) |
| `GET` | `/api/v1/rules` | 없음 | 현재 위험 판정 룰셋 |
| `GET` | `/health/ocr` | 없음 | OCR 남은 한도 확인 |

`analyze/image`의 multipart 필드:

| 필드 | 값 |
|---|---|
| `file` | 이미지 파일 (JPEG/PNG, 업로드 10MB 이하) |
| `profiles` | 쉼표 구분 문자열 예: `allergy:milk,halal` |
| `language` | `ko` \| `en` \| `ar` \| `zh` \| `ja` (기본 `ko`) |
| `ocr_mode` | `live`(실제 OCR) \| `mock`(무료) |
| `mock_text` | `ocr_mode=mock`일 때 필수. 이 텍스트를 OCR 결과로 씀 |

### profiles 값

기본: `halal`, `vegan`, `vegetarian`, `allergy`, `all`

알레르겐은 `allergy:` 접두사:
`egg, milk, buckwheat, peanut, soy, wheat, mackerel, crab, shrimp, pork, peach,
tomato, sulfite, walnut, chicken, beef, squid, shellfish, pine_nut, fish, tree_nut, sesame`

`우유`, `할랄` 같은 한국어 표기도 받습니다.

## 4. 응답 형태

```jsonc
{
  "request_id": "uuid",
  "status": "completed",
  "profiles": ["allergy:milk"],
  "risk": {
    "final_level": "SAFE | CAUTION | DANGER",
    "summary": "직접 함유 주의 성분: 우유",
    "detections": [{
      "rule_id": "allergy_milk",
      "category": "allergy",
      "severity": "danger | caution",
      "canonical_name": "우유",
      "matched_keyword": "우유",
      "evidence": "라벨에서 잘라낸 근거 문장",
      "occurrence_type": "direct | cross_contact | unknown"
    }]
  },
  "quality": { "issues": [], "needs_review": false },
  "ocr": { "provider": "clova", "cached": false, "called_paid_api": true,
           "corrected_text": "...", "regions": [ /* 글자 좌표 0~1 정규화 */ ] },
  "ingredients": { "provider": "openai", "status": "grounded", "ingredients": [...] },
  "nutrition": { "status": "unverified", "values": {} },
  "translation": { "language": "en", "status": "translated", "summary": "..." },
  "preview_data_url": "data:image/jpeg;base64,..."
}
```

**판정에서 꼭 봐야 할 것 두 가지:**

- `occurrence_type`이 `cross_contact`면 직접 원재료가 아니라 "같은 제조시설" 문구에서
  잡힌 것입니다. 직접 함유와 같게 표시하지 마세요.
- `quality.needs_review`가 `true`면 라벨을 충분히 읽지 못한 것입니다. 이때 서버는
  `SAFE` 대신 `CAUTION`을 돌려줍니다. "안전함"으로 표시하면 안 됩니다.

## 5. 지켜야 할 제약

| 항목 | 내용 |
|---|---|
| OCR 한도 | **하루 50회, 서버 전체 공용** (사용자별 아님). UTC 자정 리셋 |
| 캐시 | 같은 이미지 재요청은 한도를 소모하지 않음 |
| 한도 초과 | `402` 반환 |
| 실패한 유료 요청 | 그래도 1회를 소모함 |
| 업로드 크기 | 10MB 이하, 서버가 1600px로 축소해 CLOVA에 전달 |
| 남은 횟수 | `GET /health/ocr`의 `daily_limit`, `usage_today` |

**개발 중에는 `ocr_mode=mock` 또는 `/analyze/text`를 쓰세요.** 한도를 전혀 쓰지 않고
규칙 판정·번역·영양 파이프라인은 그대로 탑니다. 실제 OCR은 최종 확인할 때만 쓰면 됩니다.

## 6. 브라우저에서 호출할 때 (CORS)

허용된 출처만 됩니다. 현재 `localhost` / `127.0.0.1`의 `3000`, `4200`, `5173`, `8080`,
그리고 `http://101.79.20.37`입니다. 다른 포트를 쓰면 서버 관리자에게 추가를 요청하세요.

Python·curl·Postman·서버 간 호출에는 CORS가 적용되지 않습니다.

## 7. 라즈베리파이 / 카트 기기로 붙을 때

기기는 이메일·비밀번호를 쓰지 않습니다. 기기에 사용자 비밀번호를 저장하지 않으려는 설계입니다.
앱이 장바구니를 만들고 발급한 **5분·1회용 페어링 코드**로 4시간짜리 기기 토큰을 받습니다.

```
[앱/내 코드]  POST /api/v1/carts                 (사용자 토큰) → cart_id
[앱/내 코드]  POST /api/v1/carts/{id}/pair       (사용자 토큰) → { code }
[기기]        POST /api/v1/devices/redeem        (인증 없음)   → { token }   ← 기기 토큰
[기기]        GET  /api/v1/devices/session       (기기 토큰)   → 연결된 장바구니
[기기]        POST /api/v1/devices/analyze       (기기 토큰)   → 촬영 분석 + 장바구니 자동 담기
```

`devices/analyze`는 `file`(이미지)과 `name`(상품명, 선택)을 multipart로 받습니다.
장바구니를 닫으면(`POST /api/v1/carts/{id}/close`) 기기 토큰은 즉시 폐기됩니다.

> **주의:** 이 저장소의 참조 구현 `hardware/pi/client.py`는 보안상 **HTTPS 또는 localhost만**
> 허용합니다. 지금 서버는 평문 HTTP라 `http://101.79.20.37`을 그대로 넣으면
> `ValueError: Cart requires HTTPS`로 시작조차 안 됩니다. 방법은 둘 중 하나입니다.
>
> 1. 파이에서 SSH 터널을 열고 `--api http://127.0.0.1:8080`을 씁니다.
>    `ssh -N -L 8080:127.0.0.1:80 -i ~/.ssh/safebyte_ed25519 deploy@101.79.20.37`
> 2. 직접 클라이언트를 작성한다면 위 4단계를 그대로 호출하면 됩니다. 이 제약은
>    참조 구현에만 있는 것이고 서버가 막는 것이 아닙니다.

## 8. 알아두면 시간 아끼는 것들

- **한글이 든 JSON을 `curl -d '...'`로 보내지 마세요.** Windows 터미널(Git Bash·cmd)이
  인코딩을 깨뜨려 `400 There was an error parsing the body`가 납니다. API 문제가 아닙니다.
  UTF-8 파일로 `--data-binary @body.json`을 쓰거나 Python·JS 클라이언트를 쓰세요.
- `multipart/form-data`를 보낼 때 `Content-Type` 헤더를 직접 넣지 마세요. 라이브러리가
  boundary와 함께 붙입니다.
- 장바구니에 항목을 담으려면 **그 장바구니와 같은 `profiles`로 분석한 결과**여야 합니다.
  다르면 `400`입니다.
- `/docs`에서 바로 눌러볼 수 있습니다. 우측 상단 Authorize에 `Bearer <token>`을 넣으세요.
