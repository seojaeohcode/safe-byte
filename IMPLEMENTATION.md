# Safe-Byte 개발 및 운영 안내

기획서의 앱·서버·카트 연동 흐름을 확장한 구현입니다. 아래의 구현 범위와 실물/외부 설정이 필요한 범위를 구분합니다. 전체 기획이 검증 완료된 상용 제품이라는 의미는 아닙니다.

## 구현한 기능

- 사용자 인증, 로그아웃 시 세션 무효화, 사용자별 분석 이력과 접근 권한.
- 가족별 식이 기준과 결과 언어 저장·수정, 장바구니별 고정 기준, 상품 추가·제거·수량 변경, 위험 집계, 장보기 종료.
- 영양성분 OCR 참고값 추출. 상품 1개 전체 기준을 사용자가 확인한 값만 수량으로 합산하고, 항목별 집계에 포함된 수량을 표시. 누락값을 0으로 처리하지 않음.
- CLOVA General OCR V2, 유효 결과 검증, CLAHE 대비 보정·제한적인 기울기 보정, 압축, Redis/SQLite 캐시, 원자적 일일 호출 제한.
- 제조시설 교차 접촉과 직접 원재료, 불명확한 문맥 구분. 읽기 품질 부족 시 SAFE 반환 방지.
- 한국어·영어·아랍어·중국어·일본어 결과 요약 및 규칙 성분 어휘 번역. DeepL 활성화 시 상세 이유 번역. 화면 전체의 다국어 번역은 아님.
- Ollama 및 GPT-4o-mini 성분 정리 어댑터. 원문 근거 검증, 스키마 검사, 캐시, OpenAI 호출량 제한. 모델 출력으로 규칙 판정을 덮어쓰지 않음.
- 촬영한 처리 이미지의 OCR 좌표에 위험 성분 표시. 실시간 카메라 추적형 AR은 아님.
- 본인이 저장한 동일 분류 상품 라벨 중 현재 기준의 위험 규칙에 걸리지 않는 후보 추천. 전국 상품 카탈로그·가격·재고 연동은 아님.
- 식약처 식품·원료 검색, API 응답 코드 확인, 쿼리 검증·캐시. 검색 결과는 인증 여부와 별개.
- Flutter BLE 코드 전송, Pi LCD/카메라 클라이언트, Nano 버튼·LED·버저 펌웨어. 5분 1회용 페어링, 4시간 기기 토큰, 장보기 종료 시 폐기.
- Ncloud Terraform 서버/VPC/방화벽/공인 IP와 애플리케이션 배포 연결. 비밀값을 로컬 임시 파일 없이 SSH로 전송.

## Ncloud / OCR 배포

로컬 `.env`의 `CLOVA_OCR_INVOKE_URL`, `CLOVA_OCR_SECRET_KEY`와 `infra/terraform/.env.ncloud`의 자격증명을 사용합니다. CLOVA 키는 Terraform 변수·상태에 넣지 않습니다. 단, Ncloud 로그인 키 리소스의 개인키는 Terraform 상태에 포함되므로 상태 파일을 보호해야 합니다.

현재 Ncloud Terraform 공급자는 CLOVA OCR 도메인을 생성하는 리소스를 제공하지 않습니다. **기존 CLOVA 도메인/API Gateway를 연결**하는 방식입니다. 공급자 외의 미지원 리소스를 생성했다고 가장하지 않습니다.

```powershell
python scripts/terraform_run.py init '-input=false'
python scripts/terraform_run.py plan '-var=deploy_application=true' '-var=allow_paid_ocr=true' '-out=deployment.tfplan'
python scripts/terraform_run.py apply '-input=false' deployment.tfplan
```

비밀값만 변경한 경우 Terraform 소스 변경 감지 대상이 아니므로 python scripts/terraform_run.py plan '-replace=terraform_data.application[0]' '-out=deployment.tfplan' 후 해당 계획을 적용해 서버 설정을 갱신합니다.

기본 OCR 한도는 서버 전체 합계 하루 50회입니다. 실패한 유료 요청도 예약한 횟수를 사용하며, 캐시 적중은 횟수를 소모하지 않습니다. 한도를 늘릴 때는 실제 요금과 계정 한도를 확인해야 합니다.

OneDrive 동기화 때문에 상태 쓰기가 실패하여 상태와 플러그인 작업 폴더를 `%LOCALAPPDATA%/SafeByte/<작업경로 해시>/`로 분리했습니다. 이 프로젝트의 Terraform은 **항상 `scripts/terraform_run.py` 또는 `infra/terraform/scripts/tf.ps1`로 실행**하세요. 예전 프로젝트 폴더의 상태는 현재 상태가 아닙니다. 다른 컴퓨터로 이동할 때 현재 상태를 안전하게 이전해야 합니다.

현재 배포용 서버 IP는 `101.79.20.37`입니다. 서버의 초기 OS 구성은 VM 생성 완료 이후에도 몇 분 더 걸릴 수 있습니다.

도메인이 없으면 Nginx는 서버 localhost에만 바인딩합니다. 다음 터널을 유지하고 브라우저에서 `http://127.0.0.1:8080/app`을 엽니다. 이 경로는 실제 Flutter 앱 `/mobile/`로 이동합니다. 기존 OCR 개발 도구는 `/lab`입니다.

```powershell
powershell -File scripts/open_dev_tunnel.ps1
```

본인 도메인의 A 레코드를 서버로 연결한 뒤 `public_domain` Terraform 변수에 호스트명을 넣고 다시 배포하면 Caddy가 HTTPS 인증서를 발급·갱신합니다. DNS와 외부 80/443 도달 가능 여부를 실제 확인해야 합니다. 기존 서버는 초기 설정이 재실행되지 않으므로 SSH에서 `sudo ufw allow 443/tcp`도 적용해야 합니다. 앱은 `--dart-define=SAFE_BYTE_API_BASE=https://본인도메인`으로 빌드합니다.

## 프론트엔드와 기능 연결

참고 UI의 흰 배경·민트색·넓은 여백·하단 탐색 구조를 식품 라벨 검사에 맞춰 적용했습니다. Android와 웹은 같은 Flutter 코드와 테마를 사용합니다. Noto Sans KR, Noto Sans Arabic, Roboto 글꼴과 OFL 라이선스를 번들에 포함했습니다.

상용 앱에 가까운 절제된 화면으로 후속 정리했습니다. 장식 일러스트·반짝이·중복 배지를 없애고 촬영, 검사 기준, 가족/장보기 목록 순서로 배치합니다. 아이콘은 기능을 식별하는 22–24px 윤곽선 형태를 기본으로 쓰고 선택된 하단 메뉴만 채웁니다. 기본 배경 `#FFFFFF`, 보조 배경 `#F5F6F7`, 본문 `#25282B`, 보조 글자 `#71777C`, 구분선 `#E8EBED`, 주요 동작 `#00856B`를 사용합니다. 좌우 여백 24px, 버튼·입력란 모서리 12px, 정보 영역 모서리 16px를 기준으로 하며 그림자는 쓰지 않습니다. 홈·로그인·내 정보는 목록과 여백으로 구분하고 위험 색은 검사 결과에 사용합니다.

| 화면 | 연결한 기능 |
| --- | --- |
| 가입·로그인·내 기준 | 세션 복원, 사용자 기준 저장, 로그아웃 무효화 |
| 홈·촬영·결과 | 이미지 업로드, 기준별 분석, 번역, OCR 좌표 표시, 상세 근거 |
| 장바구니 | 생성·목록·항목 추가/제거, 이름·수량 변경, 위험 집계, 확인한 영양 합산, 장보기 종료 |
| 가족 | 기준·언어 생성/수정/삭제, 선택한 기준으로 스캔·장보기 |
| 기록·저장 상품 | 목록과 상세 결과, 저장 취소, 같은 분류의 대체 후보, 식약처 검색 |
| 기기 연결 | 1회용 코드, Android BLE 전송, 종료 시 기기 권한 폐기 |

웹에서는 BLE 전송 대신 코드를 카트 화면에 입력합니다. API 건강 상태가 정상이라는 것은 CLOVA 도메인 연결이나 실제 OCR 성공을 뜻하지 않습니다.

Terraform 배포는 Flutter 소스 변경을 감지하고 필요한 경우 로컬에서 웹을 빌드해 서버에 함께 배포합니다. `scripts/mobile_check.py`가 빌드 소스 해시를 기록하므로 오래된 웹 산출물을 조용히 배포하지 않습니다.

```powershell
python scripts/mobile_check.py build web --release --base-href=/mobile/ --no-pub
python scripts/smoke_workspace.py
```

`smoke_workspace.py`는 배포 서버에 합성 텍스트로 가족·분석 이력·카트·영양·저장 상품·추천·페어링·로그아웃을 검증합니다. OCR 과금 없이 전체 검증이 통과했습니다. 실제 OCR 검증은 `smoke_live.py --live`로 별도 수행합니다.

## 앱과 장치 검증

2026-09-06 검증: Python 테스트 27개, Flutter 테스트 10개 통과. Flutter 정적 분석 오류 없음. Terraform 계획은 변경 없음이며 배포 서버의 `/health` 응답을 확인했습니다. 한국어 일반 OCR 도메인 safebyte-label(57711)의 Secret Key 생성 및 API Gateway 자동 연결을 완료하고 Terraform으로 서버 설정을 배포했습니다. 합성 라벨 실호출에서 DANGER 판정·글자 영역 17개를 확인했으며 첫 호출 7.75초, 캐시 재호출 0.50초(추가 유료 호출 없음)를 기록했습니다. 카트 종료 후 장치 토큰 차단과 로그아웃 후 세션 차단도 통과했습니다.

```powershell
python -m pytest -q
python scripts/mobile_check.py test --no-pub
python scripts/mobile_check.py analyze --no-pub
python scripts/mobile_check.py build apk --debug --dart-define=SAFE_BYTE_API_BASE=http://127.0.0.1:8080
```

`mobile_check.py`는 현재 소스를 `%LOCALAPPDATA%/SafeByte/mobile-work`로 복사해 OneDrive 밖에서 빌드합니다. 디버그 APK 경로는 그 폴더의 `build/app/outputs/flutter-apk/app-debug.apk`입니다. USB 연결 휴대폰에서 개발용 터널을 쓰려면 `adb reverse tcp:8080 tcp:8080`도 실행합니다. 이 파일이 실제 생성되었는지 확인한 뒤 설치하세요.

장치 실행과 배선은 `hardware/README.md`를 참조하세요. 실물 장치는 현재 연결되지 않았습니다.

## 아직 필요한 작업과 외부 조건

- 디스크 공간 확보 후 Android 디버그 APK 빌드 성공. AndroidX 종속성을 사용하므로 Jetifier를 비활성화하고 Gradle 작업자 수를 2로 제한함.
- Nano 펌웨어는 Arduino AVR 1.8.8 / Adafruit NeoPixel 1.15.5로 컴파일 성공: 프로그램 4,266바이트, 정적 RAM 295바이트. 실물 업로드 및 동작은 미검증.
- 실제 Pi/Nano/LCD/BLE 장치 검증, 전원·발열·카트 장착 및 케이스 제작 검증.
- 공개 서비스용 도메인/DNS, 앱 배포 서명과 스토어 등록 정보.
- GPT/DeepL 실호출에는 별도 API 키가 필요. 현재 설정은 기본 비활성화이며 OpenAI/Ollama는 테스트 응답으로 근거 검증을 확인함.
- 원통형 라벨의 곡률 복원, 반사광으로 사라진 글자 복원, 실시간 AR 추적, 완전한 다국어 UI는 완료되지 않음.
- 실라벨 정답 데이터셋 평가가 필요. OCR 정확도 90% 이상이나 반사광 인식률 85%를 달성했다고 주장하지 않음.
- 상품 전체 카탈로그 기반 추천, 공식 할랄/비건 인증 DB 및 인증 유효기간 검증은 별도 확장 필요.

## 구현 시 확인한 공식 자료

- [CLOVA General OCR API](https://api.ncloud-docs.com/docs/en/ai-application-service-ocr-ocr)
- [Ncloud Terraform 공급자](https://github.com/NaverCloudPlatform/terraform-provider-ncloud)
- [OpenAI 구조화 출력](https://developers.openai.com/api/docs/guides/structured-outputs)
- [식약처 식품영양성분 DB](https://www.data.go.kr/data/15127578/openapi.do)
- [Caddy 자동 HTTPS](https://caddyserver.com/docs/automatic-https)
