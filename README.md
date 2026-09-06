# SafeByte

한국어 식품 라벨을 촬영하면 OCR로 원재료를 읽고, 사용자가 고른 기준(알레르기·할랄·비건·베지테리언)에
맞춰 `SAFE` / `CAUTION` / `DANGER`를 근거와 함께 돌려주는 Flutter + FastAPI MVP입니다.

- 백엔드: FastAPI + SQLite + Redis, Nginx 리버스 프록시, Docker Compose
- OCR: NAVER CLOVA General OCR V2 (일일 호출 한도·캐시로 비용 통제)
- 판정: `data/risk_rules.json` 기반 규칙 엔진 (직접 원재료 / 교차 접촉 / 문맥 불명 구분)
- 보강: OpenAI(gpt-4o-mini)로 원재료명 정리와 결과 번역. 모델은 판정을 바꾸지 못합니다
- 다국어: 앱 화면 전체가 한국어·영어·아랍어·중국어·일본어로 전환되며 아랍어는 RTL 레이아웃
- 앱: Flutter (Android + Web 동일 코드), 카트 기기 연동(BLE, Raspberry Pi + Arduino Nano)
- 인프라: Terraform으로 NAVER Cloud Platform(VPC) 프로비저닝 + 애플리케이션 배포

---

## 1. 배포된 서버 정보

| 항목 | 값 |
|---|---|
| API Base URL | `http://101.79.20.37` |
| 클라우드 | NAVER Cloud Platform (VPC), 리전 `KR`, 존 `KR-2` |
| 서버 | `safebyte-app` · Ubuntu 22.04 · `mi1-g3` (1 vCPU / 1GB) · 정액제(FXSUM) |
| 서버 인스턴스 번호 | `145044708` (공인 IP 인스턴스 `145044822`) |
| 구성 | Nginx :80 → FastAPI :8000 → Redis / SQLite (모두 Docker Compose) |
| SSH | `ssh -i ~/.ssh/safebyte_ed25519 deploy@101.79.20.37` (키 인증만 허용) |
| 앱 디렉터리 | `/opt/safebyte` |

### 화면·엔드포인트

| URL | 설명 |
|---|---|
| `http://101.79.20.37/mobile/` | Flutter 웹 앱 (실제 서비스 화면) |
| `http://101.79.20.37/app` | 위 주소로 리다이렉트 |
| `http://101.79.20.37/lab` | OCR 개발 도구 (라벨 업로드/규칙 확인용) |
| `http://101.79.20.37/health` | 서버 상태 |
| `http://101.79.20.37/health/ocr` | OCR 제공자·한도·오늘 사용량 |
| `http://101.79.20.37/api/v1/costs` | OCR 비용/캐시/서버 요약 |
| `http://101.79.20.37/docs` | Swagger UI (연동 개발용) |
| `http://101.79.20.37/openapi.json` | OpenAPI 스펙 |

> Swagger는 `enable_docs = true`(`infra/terraform/terraform.tfvars`)로 열어둔 상태입니다.
> API 전체 구조가 공개되므로 외부 공개 서비스로 전환할 때는 `false`로 되돌리세요.
> `/docs`만 Swagger CDN을 허용하도록 CSP를 따로 두었고 나머지 경로는 그대로 엄격합니다.

### 현재 제약

- HTTPS가 아닌 **평문 HTTP**이며 접근 CIDR이 `0.0.0.0/0`입니다. 데모/내부 테스트 용도로만 쓰고
  실제 사용자 데이터를 넣지 마세요. 도메인을 연결하면 Caddy가 자동으로 인증서를 발급합니다
  (`public_domain` Terraform 변수 → 재배포 → 서버에서 `sudo ufw allow 443/tcp`).
- 회원가입이 열려 있으므로 아무나 계정을 만들 수 있습니다.

---

## 2. 팀원용 테스트 가이드

### OCR 한도

- **하루 50회**(서버 전체 합계, UTC 기준 자정 리셋). 사용자별이 아니라 서버 공용입니다.
- **캐시 적중은 한도를 소모하지 않습니다.** 같은 이미지를 다시 올리면 무료입니다.
- 실패한 유료 요청도 예약한 1회를 사용합니다. 한도 초과 시 `402`가 돌아옵니다.
- 남은 횟수는 `GET /health/ocr`의 `daily_limit`, `usage_today`로 확인합니다.

```powershell
curl http://101.79.20.37/health/ocr
```

### 가장 쉬운 방법: 웹 앱

브라우저에서 `http://101.79.20.37/mobile/` → 가입 → 기준 선택 → 라벨 촬영/업로드.

### API로 직접 테스트

```powershell
# 1) 가입하고 토큰 받기
$body = @{ email="tester1@example.com"; password="test-password"; display_name="테스터";
           profiles=@("allergy:milk","halal") } | ConvertTo-Json
$auth = Invoke-RestMethod -Method Post -Uri http://101.79.20.37/api/v1/auth/register `
        -ContentType 'application/json' -Body $body
$headers = @{ Authorization = "Bearer $($auth.token)" }

# 2) 텍스트 분석 - OCR 한도를 쓰지 않습니다
$text = @{ text="원재료명: 밀가루, 우유, 돼지고기"; profiles=@("allergy:milk","halal") } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri http://101.79.20.37/api/v1/analyze/text `
        -Headers $headers -ContentType 'application/json' -Body $text

# 3) 라벨 이미지 분석 - 여기서만 OCR 한도를 씁니다
curl.exe -H "Authorization: Bearer $($auth.token)" `
     -F "file=@label.jpg" -F "profiles=allergy:milk,halal" -F "ocr_mode=live" `
     http://101.79.20.37/api/v1/analyze/image
```

### 한도를 쓰지 않고 이미지 흐름만 확인하기

`ocr_mode=mock` + `mock_text`를 보내면 CLOVA를 호출하지 않고 나머지 파이프라인(규칙·번역·영양)을 그대로 탑니다.

```powershell
curl.exe -H "Authorization: Bearer $($auth.token)" `
     -F "file=@label.jpg" -F "ocr_mode=mock" `
     -F "mock_text=원재료명: 밀, 대두, 우유 함유" `
     http://101.79.20.37/api/v1/analyze/image
```

### 다른 앱에서 이 API를 쓸 때

**`/api/v1/*`는 헬스체크와 `auth/*`, `rules`, `samples`, `costs`, `devices/redeem`을 빼면 전부 토큰이 필요합니다.**
헤더가 없으면 `401 authorization header is required`가 돌아옵니다. 분석 결과는 사용자 소유라
익명 호출을 허용하지 않습니다. 순서는 `register`(최초 1회) → `login` → 이후 모든 요청에 헤더를 붙입니다.
토큰 수명은 30일이고, `POST /api/v1/auth/logout`을 부르면 즉시 무효화됩니다.

```bash
# 1) 로그인해서 토큰 받기
TOKEN=$(curl -s -X POST http://101.79.20.37/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"you@example.com","password":"..."}' | jq -r .token)

# 2) 이후 모든 호출에 붙이기 (본문은 UTF-8 파일로 보내세요)
cat > body.json <<'JSON'
{"text":"원재료명: 밀가루, 우유","profiles":["allergy:milk"]}
JSON
curl -X POST http://101.79.20.37/api/v1/analyze/text \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  --data-binary @body.json
```

> 한글을 `-d '...'`에 그대로 넣으면 Windows 터미널(Git Bash·cmd)이 인코딩을 깨뜨려
> `400 There was an error parsing the body`가 납니다. API 문제가 아니라 셸 문제이므로
> UTF-8 파일이나 Python·JS 클라이언트를 쓰세요.

```javascript
const { token } = await fetch('http://101.79.20.37/api/v1/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password }),
}).then((r) => r.json());

const result = await fetch('http://101.79.20.37/api/v1/analyze/image', {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}` },   // FormData 쓸 때 Content-Type은 직접 넣지 마세요
  body: formData,                                   // file, profiles, language, ocr_mode
}).then((r) => r.json());
```

브라우저에서 호출한다면 출처가 서버의 허용 목록에 있어야 합니다. 현재 `localhost`/`127.0.0.1`의
`3000`, `4200`, `5173`, `8080` 포트와 `http://101.79.20.37`이 열려 있습니다. 다른 출처를 쓰면
로컬 `.env`의 `CORS_ALLOWED_ORIGINS`에 추가하고 재배포하세요. 서버끼리 호출하거나 curl·Postman을
쓸 때는 CORS가 적용되지 않습니다.

카트 기기(라즈베리파이)는 이 경로가 아니라 앱이 발급한 페어링 코드로 동작합니다
(`carts/{id}/pair` → `devices/redeem` → `devices/analyze`). 기기에는 이메일·비밀번호를 넣지 않습니다.

### 전체 기능 자동 점검 (OCR 0회 소모)

```powershell
python scripts/smoke_workspace.py --api http://101.79.20.37
```

가족 기준 CRUD, 분석·이력, 카트 항목/영양 합산, 저장 상품·대체 후보, 기기 페어링·폐기,
로그아웃 세션 무효화를 합성 텍스트만으로 검증합니다.

실제 CLOVA 호출까지 확인하려면(**OCR 1회 소모**):

```powershell
python scripts/smoke_live.py --api http://101.79.20.37 --live
```

---

## 3. 아키텍처

```text
Flutter App (Android / Web)  ─┐
Raspberry Pi 카트 클라이언트  ─┤
                              ├─→ Nginx :80 ─→ FastAPI :8000
웹 OCR 랩 (/lab)             ─┘                  │
                                                 ├─→ CLOVA OCR V2 (일일 한도 + 캐시)
                                                 ├─→ OCR 보정 → 규칙 엔진 → SAFE/CAUTION/DANGER
                                                 ├─→ OpenAI gpt-4o-mini (성분 정리 / 결과 번역, 판정에는 관여 안 함)
                                                 └─→ SQLite(영구) + Redis(핫 캐시)
```

### 저장소 구조

```text
app/                     FastAPI 백엔드
  api/routes.py          헬스체크, 인증, 분석, 룰, 샘플, 비용
  api/workspace_routes.py 가족/카트/기기/상품/대체품/공공DB 검색
  core/                  설정(config), SQLite 접근(database), DI(dependencies)
  services/              ocr, ocr_correction, risk_rules, analysis, workspace,
                         auth, cache, enrichment, localization, nutrition, vision
data/risk_rules.json     위험 판정 규칙 사전
mobile/                  Flutter 앱 (Android + Web)
  lib/l10n.dart          언어 선택·저장, t()/tf() 조회, 언어 선택 시트
  lib/l10n_data.dart     생성물: 한국어 원문을 키로 하는 5개 언어 UI 카탈로그
scripts/build_l10n.py    UI 카탈로그 생성기 (+ scripts/l10n_cache.json)
hardware/                Raspberry Pi 키오스크 / Arduino Nano 펌웨어 / 케이스
web/                     경량 OCR 개발 도구(/lab) + Flutter 웹 산출물 배포 위치
deploy/                  nginx.conf, Caddyfile(HTTPS)
infra/terraform/         Ncloud VPC/서버/방화벽/공인 IP + 애플리케이션 배포
scripts/                 배포·빌드·스모크 테스트 헬퍼
tests/                   백엔드 테스트
```

---

## 4. 로컬 개발

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
Copy-Item config/mfds_public_apis.example.json config/mfds_public_apis.json
python -m uvicorn app.main:app --reload --port 8000
```

| URL | 설명 |
|---|---|
| `http://127.0.0.1:8000/health` | 상태 확인 |
| `http://127.0.0.1:8000/docs` | Swagger UI (로컬만) |
| `http://127.0.0.1:8000/app` | 웹 화면 |

기본 `.env`는 `OCR_PROVIDER=clova`, `ALLOW_PAID_OCR=false`입니다. 키가 없으면 유료 OCR은 차단되고
`analyze/text` 또는 `ocr_mode=mock`으로 개발할 수 있습니다.

### OpenAI 연동

`OPENAI_API_KEY`를 넣고 `LLM_ENABLED=true`, `LLM_PROVIDER=openai`, `TRANSLATION_ENABLED=true`로 두면
두 가지가 켜집니다. 둘 다 `LLM_DAILY_LIMIT`(기본 100회, 서버 전체 합계)을 각각 따로 소비하며
결과는 SQLite에 캐시됩니다.

| 기능 | 동작 | 실패했을 때 |
|---|---|---|
| 원재료명 정리 | 라벨에 **그대로 있는** 이름만 남기고, 근거 문장은 모델이 아니라 라벨에서 잘라 붙입니다 | 쉼표 분리 사전 방식으로 폴백 |
| 결과 번역 | 요약과 위험 사유를 선택 언어로 번역 | 검수된 어휘 번역(`localization.py`)으로 폴백 |

모델이 만들어낸 성분은 버려지고(`rejected_count`로 표시), 번역 개수가 원문과 다르면 통째로 폴백합니다.
**모델 출력이 SAFE/CAUTION/DANGER 판정을 바꾸는 경로는 없습니다.**

### Docker로 실행

```powershell
Copy-Item .env.example .env
docker compose up -d --build
curl http://127.0.0.1:8080/health
```

`Nginx :8080 → FastAPI :8000 → Redis + SQLite` 구성이며 Nginx만 외부에 노출됩니다.

### 테스트

```powershell
python -m pytest -q                          # 백엔드 32개
python scripts/mobile_check.py test --no-pub # Flutter 위젯·골든 11개
python scripts/mobile_check.py analyze --no-pub
```

`mobile_check.py`는 OneDrive 밖(`%LOCALAPPDATA%\SafeByte\mobile-work`)으로 소스를 복사해 빌드합니다.

---

## 5. API 레퍼런스

공통 규칙

- 대부분의 `/api/v1/*`는 `Authorization: Bearer <token>` 헤더가 필요합니다.
- 응답은 JSON, 토큰이 없거나 만료되면 `401`, 유료 OCR 한도 초과는 `402`, OCR 제공자 오류는 `502`입니다.

### 헬스 체크 (인증 불필요)

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | 앱 상태, 버전, CLOVA 설정 여부, 오늘 OCR 사용량 |
| `GET` | `/health/ocr` | OCR 제공자·캐시·일일 한도·금액 가드 상태 |
| `GET` | `/health/public-apis` | 공공 API 연동 상태 (필요 시 `?live=true`) |

### 인증

| Method | Path | Auth | Request Body | Purpose |
|---|---|---|---|---|
| `POST` | `/api/v1/auth/register` | 없음 | `email`, `password`, `display_name`, `profiles`, `allergy_notes` | 회원가입 + 세션 토큰 |
| `POST` | `/api/v1/auth/login` | 없음 | `email`, `password` | 로그인 + 세션 토큰 |
| `GET` | `/api/v1/me` | 필요 | - | 내 정보 조회 |
| `PUT` | `/api/v1/me/preferences` | 필요 | `display_name`, `profiles`, `allergy_notes` | 기준 설정 저장 |
| `POST` | `/api/v1/auth/logout` | 필요 | - | 현재 세션 무효화 |

`profiles` 값은 `halal`, `vegan`, `vegetarian`, `allergy`, `all` 또는
`allergy:milk`처럼 세부 알레르겐(`egg, milk, buckwheat, peanut, soy, wheat, mackerel, crab, shrimp,
pork, peach, tomato, sulfite, walnut, chicken, beef, squid, shellfish, pine_nut, fish, tree_nut, sesame`)을 씁니다.
`우유`, `할랄` 같은 한국어 표기도 받습니다.

### 분석 / 리포트

| Method | Path | Auth | Request Body / Form | Purpose |
|---|---|---|---|---|
| `POST` | `/api/v1/analyze/text` | 필요 | `text`, `profiles`, `language`(`ko\|en\|ar\|zh\|ja`) | 텍스트 분석 (OCR 0회) |
| `POST` | `/api/v1/analyze/image` | 필요 | `file`, `profiles`, `language`, `ocr_mode`(`live\|mock`), `mock_text`, `force_ocr` | 라벨 이미지 OCR + 분석 |
| `GET` | `/api/v1/analysis/{request_id}` | 필요 | - | 분석 결과 상세 |
| `GET` | `/api/v1/history` | 필요 | - | 내 분석 이력 (최근 100건) |
| `GET` | `/api/v1/rules` | 없음 | - | 현재 룰셋 조회 |
| `POST` | `/api/v1/rules/reload` | 없음 | - | 항상 `403` (룰은 배포로만 갱신) |
| `GET` | `/api/v1/samples` | 없음 | - | 샘플 라벨 목록 (미설치 시 빈 배열) |
| `GET` | `/api/v1/costs` | 없음 | - | OCR 비용·캐시·서버 요약 |

### 가족 · 카트 · 기기 · 상품

| Method | Path | Auth | Request Body | Purpose |
|---|---|---|---|---|
| `GET` | `/api/v1/family` | 필요 | - | 가족 기준 목록 |
| `POST` | `/api/v1/family` | 필요 | `name`, `profiles`, `language` | 가족 기준 생성 (최대 20개) |
| `PUT` | `/api/v1/family/{profile_id}` | 필요 | `name`, `profiles`, `language` | 수정 |
| `DELETE` | `/api/v1/family/{profile_id}` | 필요 | - | 삭제 |
| `GET` | `/api/v1/carts` | 필요 | - | 장바구니 목록 |
| `POST` | `/api/v1/carts` | 필요 | `name`, `profiles`, `language` | 장바구니 생성 (기준 고정) |
| `GET` | `/api/v1/carts/{cart_id}` | 필요 | - | 장바구니 상세 · 위험 집계 |
| `POST` | `/api/v1/carts/{cart_id}/items` | 필요 | `request_id`, `name`, `quantity` | 항목 추가 / 이름·수량 변경 |
| `DELETE` | `/api/v1/carts/{cart_id}/items/{item_id}` | 필요 | - | 항목 삭제 |
| `PUT` | `/api/v1/carts/{cart_id}/items/{item_id}/nutrition` | 필요 | `energy_kcal`, `sodium_mg` 등 | 확인한 영양값 입력 |
| `POST` | `/api/v1/carts/{cart_id}/close` | 필요 | - | 장보기 종료 (기기 토큰 폐기) |
| `POST` | `/api/v1/carts/{cart_id}/pair` | 필요 | - | 5분·1회용 기기 연동 코드 |
| `POST` | `/api/v1/devices/redeem` | 없음 | `code` | 기기 토큰 발급 (4시간) |
| `GET` | `/api/v1/devices/session` | 기기 토큰 | - | 기기가 연결된 장바구니 조회 |
| `POST` | `/api/v1/devices/analyze` | 기기 토큰 | `file`, `name` | 카트에서 촬영·분석·자동 담기 |
| `POST` | `/api/v1/products` | 필요 | `request_id`, `name`, `category` | 라벨 기반 상품 저장 |
| `GET` | `/api/v1/products` | 필요 | - | 저장 상품 목록 |
| `DELETE` | `/api/v1/products/{product_id}` | 필요 | - | 저장 상품 삭제 |
| `POST` | `/api/v1/alternatives` | 필요 | `name`(카테고리), `profiles`, `language` | 같은 분류의 안전 후보 |
| `POST` | `/api/v1/references/search` | 필요 | `name`, `kind`(`nutrition\|ingredient`) | 식약처 공공 DB 검색 |

### 주요 응답 키

- 분석 응답(`/analyze/*`, `/analysis/{id}`)
  - `request_id`, `status`, `profiles`, `image`
  - `ocr`: `provider`, `cached`, `cache_backend`, `called_paid_api`, `text`, `corrected_text`, `corrections`, `regions`
  - `risk`: `final_level`(SAFE/CAUTION/DANGER), `summary`, `detections[]`
    (`rule_id`, `category`, `severity`, `canonical_name`, `matched_keyword`, `evidence`, `occurrence_type`)
  - `quality`: `issues`, `needs_review` — 읽기 품질이 나쁘면 SAFE 대신 CAUTION으로 낮춥니다
  - `ingredients`, `nutrition`, `translation`, `cost_guard`, `preview_data_url`
- 장바구니 리포트(`/carts/{id}`): `cart`, `items`, `counts`, `total_quantity`, `final_level`, `nutrition`
- 비용(`/costs`): `currency`, `ncloud`, `server`, `ocr`, `cache`
- 인증(`/auth/*`): `token`, `expires_at`, `user`

---

## 6. Terraform 배포

> OneDrive 동기화가 상태 파일을 깨뜨리기 때문에 상태와 플러그인 폴더를
> `%LOCALAPPDATA%\SafeByte\<작업경로 해시>\`로 분리했습니다.
> **항상 저장소 루트에서 `scripts/terraform_run.py`를 통해 실행하세요.** `terraform`을 직접 부르면 안 됩니다.

```powershell
python scripts/terraform_run.py init -input=false
python scripts/terraform_run.py plan -input=false -out=deployment.tfplan
python scripts/terraform_run.py apply -input=false deployment.tfplan
python scripts/terraform_run.py output
```

### 자주 바꾸는 값 (`infra/terraform/terraform.tfvars`, git 미포함)

| 변수 | 현재 값 | 설명 |
|---|---|---|
| `deploy_application` | `true` | 인프라 준비 후 애플리케이션까지 배포 |
| `allow_paid_ocr` | `true` | 한도 안에서 실제 CLOVA 호출 허용 |
| `ocr_daily_limit` | `50` | 서버 전체 일일 OCR 호출 한도 (0~1000) |
| `public_domain` | `""` | 도메인을 넣으면 Caddy HTTPS로 전환 |
| `ssh_allowed_cidr` / `web_allowed_cidr` | 배포자 IP / `0.0.0.0/0` | 방화벽(ACG + ufw) 허용 대역 |

Terraform은 `app/`, `mobile/`, `web/`, 배포 스크립트의 해시를 추적해서 변경이 있을 때만 다시 배포합니다.
Flutter 웹 산출물이 오래됐으면 `scripts/mobile_check.py`가 자동으로 다시 빌드합니다.
비밀값만 바꿨을 때처럼 소스 해시가 그대로면 강제로 갱신합니다.

```powershell
python scripts/terraform_run.py plan -replace=terraform_data.application[0] -out=deployment.tfplan
python scripts/terraform_run.py apply -input=false deployment.tfplan
```

### CLOVA OCR

Ncloud Terraform 공급자에는 CLOVA OCR 도메인을 만드는 리소스가 없습니다.
콘솔에서 만든 **기존 도메인 / API Gateway를 연결**하는 방식이며, 키는 Terraform 상태에 들어가지 않고
로컬 `.env`의 `CLOVA_OCR_INVOKE_URL`, `CLOVA_OCR_SECRET_KEY`를 배포 시 SSH로 서버에 직접 전달합니다.

### 상태 파일 주의

`ncloud_login_key`의 개인키가 상태에 포함되므로 상태 파일을 반드시 보호하세요.
상태를 잃어버리면 `terraform apply`가 서버를 새로 만들려고 합니다. 그럴 때는
기존 리소스를 `terraform import`로 되살린 뒤 진행하세요(서버·공인 IP 인스턴스 번호는 1절 참고).
Ncloud가 import 시 돌려주지 않는 `fee_system_type_code`는 상태에 직접 채워야 서버 재생성 계획이 사라집니다.

---

## 7. Flutter 앱

```powershell
python scripts/mobile_check.py build apk --debug --dart-define=SAFE_BYTE_API_BASE=http://101.79.20.37
python scripts/mobile_check.py build web --release --base-href=/mobile/ --no-pub
```

로컬 백엔드를 볼 때는 `--dart-define=SAFE_BYTE_API_BASE=http://127.0.0.1:8000`,
USB 연결 실기기에서는 `adb reverse tcp:8080 tcp:8080`을 함께 씁니다.

화면 흐름: 가입/로그인 → 기준 선택 → 촬영 → 큰 판정 먼저 → 필요할 때만 근거 상세.
웹에서는 BLE 대신 카트 화면에 페어링 코드를 직접 입력합니다.

### 화면 언어 바꾸기

버튼·메뉴·안내 문구까지 화면 전체가 **한국어·English·العربية·中文·日本語**로 바뀝니다.
한국어를 못 읽는 사용자도 바꿀 수 있도록 **로그인 화면 우측 상단**에 언어 버튼이 있고,
로그인 후에는 `내 정보 → 언어`에서 바꿉니다. 선택은 기기에 저장되고, 아랍어는 화면 전체가 RTL로 바뀝니다.

번역 문구는 한국어 원문을 키로 쓰는 카탈로그 `mobile/lib/l10n_data.dart`에 들어 있습니다.
번역이 없는 문구는 빈칸이 아니라 한국어로 표시됩니다. 한국어 문구를 추가·수정한 뒤에는:

```powershell
python scripts/build_l10n.py          # 새로 생긴 문구만 번역해 카탈로그 재생성
python scripts/build_l10n.py --all    # 전부 다시 번역
```

`scripts/l10n_cache.json`이 커밋되어 있어서 평소 빌드는 OpenAI를 호출하지 않습니다.
위젯 코드에서는 `t('한국어 문구')`, 값이 끼어드는 문구는 `tf('{0}개 담았어요', [n])`을 씁니다.

---

## 8. 하드웨어 (카트 연동)

Raspberry Pi 키오스크(`hardware/pi`)가 카메라·LCD를, Arduino Nano 펌웨어(`hardware/arduino`)가
버튼·NeoPixel·버저를 담당합니다. 앱에서 발급한 5분·1회용 코드로 페어링하며 기기 토큰은 4시간 후
또는 장보기 종료 시 폐기됩니다. 배선과 실행 방법은 `hardware/README.md`를 보세요.
실물 장치 검증은 아직 완료되지 않았습니다.

---

## 9. 공공 데이터

`config/mfds_public_apis.example.json`에 식약처 공개 API 연동 정보를 정리했습니다
(식품 원재료 정보, 수입식품 원재료, 식품 QR, 식품영양성분 DB, 건강기능식품 영양 DB, 원재료 코드).
검색 결과는 참고용이며 실시간 위험 판정은 `data/risk_rules.json`이 담당합니다.

---

## 10. 비밀값 정책

커밋하지 않는 항목:

```text
.env                                CLOVA 키, 런타임 설정
infra/terraform/.env.ncloud         Ncloud 액세스/시크릿 키
infra/terraform/terraform.tfvars    SSH 공개키, 허용 CIDR, 배포 옵션
*.tfstate, *.tfplan                 Terraform 상태(로그인 키 개인키 포함)
config/mfds_public_apis.json        공공 API 서비스 키
data/*.sqlite3, logs/, web/config.js
```

예제 파일을 복사해서 로컬 값만 채우세요.

```powershell
Copy-Item .env.example .env
Copy-Item config/mfds_public_apis.example.json config/mfds_public_apis.json
Copy-Item infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
```

---

## 11. 라이선스

한이음 드림업 프로젝트 MVP입니다. 외부 공개 전에 라이선스 파일을 추가하세요.
번들된 글꼴(Noto Sans KR, Noto Sans Arabic, Roboto)은 OFL/Apache 라이선스를 따릅니다.
