# SafeByte

SafeByte is a Flutter + FastAPI MVP that helps users check Korean food labels against
personal dietary criteria such as allergy, halal, and vegan restrictions.

The core goal is simple: take a food-label image, extract Korean text with OCR, correct
common OCR noise, classify ingredient context, and return `SAFE`, `CAUTION`, or `DANGER`
with evidence.

## Highlights

- Korean food-label OCR using Naver CLOVA OCR
- Rule-based risk detection for allergy, halal, vegan, and cross-contact phrases
- OCR correction rules for spacing, broken Korean terms, and common label words
- Direct ingredient vs. shared-facility warning separation
- Redis + SQLite OCR cache to reduce paid OCR calls
- Daily OCR call guard for cost control
- Flutter mobile app for login, preference setup, image input, and result review
- Docker Compose deployment with Nginx, FastAPI, Redis, and SQLite
- Terraform scaffold for Ncloud Compute deployment

## Architecture

```text
Flutter App
  -> Nginx
  -> FastAPI
  -> CLOVA OCR
  -> OCR correction
  -> Risk rule engine
  -> SQLite / Redis
  -> SAFE / CAUTION / DANGER
```

## Repository Layout

```text
app/                 FastAPI backend
app/services/        OCR, correction, risk rules, auth, cache, cost services
app/api/             REST API routes
data/risk_rules.json Risk dictionary and rule definitions
mobile/              Flutter Android app
web/                 Lightweight local web tester
deploy/              Nginx configuration
infra/terraform/     Ncloud infrastructure scaffold
scripts/             Deployment and local helper scripts
tests/               Backend tests
```

## Secret Policy

This repository intentionally excludes runtime secrets and local state.

Not committed:

- `.env`
- CLOVA OCR invoke URL and secret key
- Ncloud access key and secret key
- Terraform state and `terraform.tfvars`
- SQLite runtime database
- OCR logs, local cost snapshots, build outputs, APK files, and sample image datasets

Use the example files instead:

```powershell
Copy-Item .env.example .env
Copy-Item config/mfds_public_apis.example.json config/mfds_public_apis.json
Copy-Item infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
```

Then fill only your local copies.

## Backend Quick Start

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
python -m uvicorn app.main:app --reload --port 8000
```

Open:

- `http://127.0.0.1:8000/health`
- `http://127.0.0.1:8000/docs`
- `http://127.0.0.1:8000/app`

## Zero-Cost Analysis

For development, avoid live CLOVA calls by using text analysis or mock OCR text.

```http
POST /api/v1/analyze/text
```

```http
POST /api/v1/analyze/image
form-data:
  file=<label image>
  profiles=halal,vegan,allergy:milk
  ocr_mode=mock
  mock_text=원재료명: 밀, 대두, 우유 함유
```

Live CLOVA OCR is blocked unless all conditions are met:

- `OCR_PROVIDER=clova`
- `ALLOW_PAID_OCR=true`
- CLOVA OCR invoke URL and secret key are configured
- the daily limit has not been reached
- the OCR result is not already cached

## Core API

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/api/v1/auth/register` | Register and issue session |
| `POST` | `/api/v1/auth/login` | Login and issue session |
| `GET` | `/api/v1/me` | Get current user |
| `PUT` | `/api/v1/me/preferences` | Save dietary criteria |
| `POST` | `/api/v1/analyze/image` | OCR image and analyze risks |
| `POST` | `/api/v1/analyze/text` | Analyze text without OCR cost |
| `GET` | `/api/v1/analysis/{request_id}` | Fetch stored analysis |
| `GET` | `/api/v1/rules` | Inspect risk rules |
| `GET` | `/api/v1/costs` | Check Ncloud/OCR/cache status |
| `GET` | `/health/ocr` | Check OCR configuration and usage |
| `GET` | `/health/public-apis` | Check public-data API status |

## Flutter App

```powershell
cd mobile
flutter pub get
flutter run --dart-define=SAFE_BYTE_API_BASE=http://127.0.0.1:8000
```

For a deployed backend:

```powershell
flutter run --dart-define=SAFE_BYTE_API_BASE=http://YOUR_SERVER_IP
```

The app flow is intentionally short:

1. Sign up or log in
2. Select allergy, halal, and vegan criteria
3. Capture or choose a food-label image
4. Review a large verdict first
5. Open details only when evidence is needed

## Docker

```powershell
Copy-Item .env.example .env
docker compose up -d --build
docker compose ps
curl http://127.0.0.1:8080/health
```

Default stack:

```text
Nginx :8080 -> FastAPI :8000 -> Redis + SQLite
```

Only Nginx is exposed. FastAPI and Redis stay inside the Docker network.

## Ncloud Deployment

Terraform files live in `infra/terraform`.

```powershell
cd infra/terraform
terraform init
terraform plan
terraform apply
```

Local Ncloud credentials should stay outside git:

```text
infra/terraform/.env.ncloud
infra/terraform/terraform.tfvars
```

The deployment scripts are designed to upload application code while keeping cloud
credentials and CLOVA secrets on the server environment.

## Public Food Data

`config/mfds_public_apis.example.json` documents the public-data integrations used for
reference and future rule enhancement:

- Food raw material information
- Imported food ingredient information
- Food QR information service
- Food nutrition component DB
- Health functional food nutrition DB
- Food raw material code

The real-time risk verdict is currently driven by `data/risk_rules.json`.

## Tests

```powershell
python -m pytest -q
```

## License

This MVP was built for the Hanium Dream Up project. Add a license file before public
production use if needed.
