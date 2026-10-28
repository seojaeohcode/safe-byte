# Safe-Byte V2

기존 Flutter 앱을 복사한 UI 리뉴얼입니다. 원본 `mobile/`, `web/`, `hardware/`는 수정하지 않았습니다. 신규 서비스 기능, 서버, OCR 연동을 추가하지 않았으며 기존 API 모델·카메라/앨범 선택·NAVER CLOVA OCR 분석·기준 저장·가족·장보기·기록·BLE 흐름을 유지합니다.

## 디자인

식품 선택에 필요한 순서로 정보를 배치했습니다. 결과는 **상태 한 단어 → 이유 → 직접 함유/같은 제조시설 → 근거 상세** 순서입니다. 홈은 촬영, 기준 편집은 저장, 장보기는 스캔, 연결 코드는 카트 화면에 입력하는 실제 흐름(Wi-Fi 연결)에 맞춰 입력 안내와 입력 완료를 주 행동으로 둡니다. 읽기 전용 화면과 분석 중에는 불필요한 행동 버튼을 추가하지 않았습니다.

| 항목 | 규칙 |
|---|---|
| 브랜드 | 딥틸 `#0E7C66` |
| 기본 | 흰색 `#FFFFFF`, 보조 면 `#F4F6F5` |
| 글자 | 본문 `#202925`, 보조 `#626E68` |
| 상태 | 안전 `#2F7D5B`, 주의 `#906018`, 위험 `#B54848` |
| 주의 색 | 요청한 `#B7791F` 계열을 어둡게 조정해 작은 글씨도 AA 대비 확보 |
| 글꼴 | 번들 Noto Sans KR / Arabic, 추가 JP / SC 대체 글꼴 |
| 위계 | 제목 22–26dp, 핵심 16–20dp, 보조 12–14dp; 결과 상태 40dp |
| 간격·모서리 | 8pt 기반 간격, 화면 좌우 24dp, 입력/버튼 12dp, 큰 면 16dp |
| 입력 | 주 버튼 56dp, 텍스트/아이콘 버튼 최소 48dp, 선택은 체크/스위치 병행 |
| 시각 표현 | 그라데이션·광택·이모지 없이 라인 아이콘, 평면 배경 |

일반 텍스트와 상태색은 4.5:1 이상, 입력 경계는 3:1 이상을 자동 검사합니다. 한국어·영어·아랍어·중국어·일본어를 유지하며 아랍어는 RTL입니다. 입력 코드의 숫자는 RTL에서도 LTR로 유지합니다. 긴 목록과 큰 글씨는 스크롤로 접근합니다.

## 구조

- `mobile/lib/main.dart`, `workspace.dart`: 복사한 앱의 실제 화면·탐색·기존 로직
- `mobile/lib/v2_ui.dart`: 결과·근거·분석 중·연결 코드 및 공통 UI
- `mobile/lib/v2_strings.dart`: 추가 문구의 5개 언어 번역
- `mobile/lib/preview_api.dart`: 외부 요청을 하지 않는 목업 API와 예시 데이터
- `mobile/lib/main_preview.dart`: 화면 검토 전용 오프라인 진입점
- `kiosk/`: 파일로 여는 정적 HTML/CSS/JS 목업
- `screenshots/`: Flutter 엔진과 Edge가 실제 렌더한 PNG
- `scripts/`: 캡처·키오스크 동작·이미지 크기·글꼴 검증
- [DONE.md](DONE.md): 화면별 변경, 검증 결과, 제한 사항

## Flutter 실행과 캡처

검증 환경: Windows, Flutter **3.38.7**, Dart **3.10.7**. 저장소 루트에서 시작합니다.

```powershell
Set-Location V2/mobile
flutter pub get
flutter test
flutter analyze
```

기준 캡처를 재생성할 때만 다음 명령을 실행합니다. `flutter test` 자체는 저장된 PNG와 비교하므로 이후 회귀를 탐지합니다.

```powershell
flutter test --update-goldens test/design_screenshot_test.dart
```

`test/design_screenshot_test.dart`는 `PreviewApi`만 주입하고, 실제 Flutter 위젯을 논리 크기 **360×780dp / DPR 3**으로 렌더해 `V2/screenshots/`에 **1080×2340** PNG를 생성합니다. OS 상태 표시줄을 합성하지 않습니다. 테스트의 글꼴 로더는 `FLUTTER_ROOT`를 우선 사용하며 이 작업 환경의 SDK 경로를 대체 경로로 둡니다.

Android 기기에서 목업 화면만 열고 싶다면 다음처럼 실행합니다. 웹 개발 서버는 필요하지 않습니다.

```powershell
flutter run -d <Android-device-id> -t lib/main_preview.dart --dart-define=PREVIEW_SCREEN=home_scan
```

`PREVIEW_SCREEN`: `splash`, `login`, `criteria`, `home_scan`, `analyzing`, `result_safe`, `result_caution`, `result_danger`, `detail`, `cart`, `pairing_code`, `family`. 기록과 내 정보는 홈 하단 탭으로 이동합니다. 이 진입점은 고정 예시를 검토하는 용도이며 원본 앱의 인증·저장 서버를 대신 구현하지 않습니다. 실제 앱 진입점 `lib/main.dart`의 기존 API 클라이언트는 보존했으며 이 작업 중 실행하지 않았습니다.

## 키오스크 실행과 캡처

`V2/kiosk/index.html`을 Edge에서 직접 엽니다. `?screen=connect|ready|preview|safe|caution|danger`로 상태를 고릅니다. `&lang=ko|en|ar|zh|ja`로 언어를 고를 수 있습니다.

연결 화면에 6자리 숫자를 입력하면 목업 연결이 진행됩니다. 대기 → 미리보기 → 위험 예시 → 다음 라벨 흐름을 눌러볼 수 있습니다. 실제 카트 인증, 카메라, OCR, Bluetooth, 서버 호출은 없습니다. 미리보기의 라벨도 HTML로 만든 예시입니다.

저장소 루트에서 다음 명령을 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File V2/scripts/capture_kiosk.ps1
```

스크립트는 지정된 Edge 실행 파일을 `--headless=new --window-size=1024,600 --force-device-scale-factor=1 --screenshot=... file:///...`로 실행합니다. 글꼴 렌더를 기다리고, 작업 전용 프로필을 `V2/kiosk/.edge-profile/`에 둡니다. 이 프로필과 빌드 산출물은 Git에서 제외합니다.

추가 검사에는 Python의 Pillow, fonttools, playwright가 필요합니다. Playwright는 설치된 Edge를 사용하므로 별도 브라우저 다운로드가 필요하지 않습니다.

```powershell
python V2/scripts/verify_kiosk.py
python V2/scripts/verify_assets.py
```

## 캡처 목록

필수 모바일 13장: `splash`, `login`, `criteria`, `home_scan`, `analyzing`, `result_safe`, `result_caution`, `result_danger`, `detail`, `cart`, `history`, `account`, `pairing_code`.

필수 키오스크 6장: `kiosk_connect`, `kiosk_ready`, `kiosk_preview`, `kiosk_safe`, `kiosk_caution`, `kiosk_danger`.

추가 검토: `family`, `login_en`, `login_ar`, `login_zh`, `login_ja`, `rtl_result`, `kiosk_rtl`. 모두 `.png`입니다. 목업 이름·상품·영양 합계는 실제 사용자 데이터가 아닙니다. OCR 원문과 상품명 등 원천 데이터는 예시 라벨의 한국어를 보존할 수 있습니다.

## 글꼴 라이선스

기존 글꼴과 새 JP/SC 글꼴은 앱에 포함해 오프라인으로 사용합니다. 새 글꼴은 [Google Fonts Noto Sans JP](https://github.com/google/fonts/tree/main/ofl/notosansjp), [Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)의 변수 TTF입니다. 각각의 SIL Open Font License를 `mobile/assets/fonts/OFL-JP.txt`, `OFL-SC.txt`에 동봉했습니다. 런타임 외부 글꼴 서비스는 사용하지 않습니다.
