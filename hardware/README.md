# Safe-Byte 카트 장치

앱에서 가족 기준으로 장바구니를 만들고 **카트 기기 연결**을 누릅니다. BLE로 5분 유효·1회 사용 코드를 보내거나 LCD에 직접 입력합니다. 기기는 해당 장바구니에만 접근할 수 있고, 앱에서 장보기를 종료하면 접근 토큰이 폐기됩니다. 사용자 비밀번호와 CLOVA 키는 장치에 저장하지 않습니다.

## Raspberry Pi

Raspberry Pi OS의 데스크톱 환경에서 실행합니다. Tk 창과 BLE 어댑터가 필요합니다. CSI 카메라는 Picamera2, 일반 USB 카메라는 OpenCV를 사용합니다.

```bash
sudo apt install python3-venv python3-tk python3-picamera2 python3-opencv python3-dbus libgirepository1.0-dev libcairo2-dev pkg-config python3-dev
python3 -m venv --system-site-packages .venv
. .venv/bin/activate
pip install -r hardware/pi/requirements.txt
python hardware/pi/kiosk.py --api https://YOUR_DOMAIN --picamera --serial /dev/ttyUSB0 --ble
```

USB 카메라는 `--picamera` 대신 `--camera 0`을 사용합니다. `--auto`는 움직임 후 1.2초 정지했을 때 촬영하며 최소 8초 간격을 둡니다. 화면의 가이드 안에 원재료 라벨을 맞춥니다. 카메라가 실제로 상품과 원재료 영역을 식별하는 객체 탐지기는 아닙니다.

도메인이 없는 개발 환경에서는 서버와 SSH 터널을 먼저 연결하고 `--api http://127.0.0.1:8080`을 사용합니다. 공개 HTTP 주소는 기기 클라이언트가 거부합니다.

```bash
ssh -N -L 8080:127.0.0.1:80 -i ~/.ssh/safebyte_ed25519 deploy@SERVER_IP
```

BLE 실행 권한은 배포할 Pi의 BlueZ/D-Bus 정책에 맞춰 설정해야 합니다. 페어링 코드는 서비스 `76c10001-249b-4e40-9c5d-a0f6b80c10a1`, 쓰기 특성 `76c10002-249b-4e40-9c5d-a0f6b80c10a1`에 UTF-8과 마지막 줄바꿈으로 전송합니다.

## Arduino Nano

`arduino/safebyte/safebyte.ino`를 ATmega328P Nano에 올립니다. Adafruit NeoPixel 라이브러리가 필요합니다.

| 연결 | 핀 / 규격 |
|---|---|
| Pi ↔ Nano | USB 직렬, 115200 baud |
| NeoPixel 데이터 | D6, 코드 기본 16개 |
| 촬영 버튼 | D7 ↔ GND, INPUT_PULLUP |
| 버저 제어 | D8, 활성형 버저 드라이버 입력 |
| 상태 명령 | SAFE / CAUTION / DANGER / BUSY / ERROR / IDLE + 줄바꿈 |
| 버튼 이벤트 | Nano → Pi: SCAN + 줄바꿈 |

전원은 실제 LED·LCD·Pi 소비전류에 맞춰 별도 5V 전원을 설계하고 공통 접지를 사용합니다. LED와 큰 버저를 GPIO에서 직접 구동하지 않습니다. 버저가 수동형이면 펌웨어의 출력 방식을 `tone()`에 맞춰 변경해야 합니다.

```bash
arduino-cli core install arduino:avr
arduino-cli lib install "Adafruit NeoPixel"
arduino-cli compile --fqbn arduino:avr:nano:cpu=atmega328 hardware/arduino/safebyte
```

## 실물 확인이 필요한 항목

실물 하드웨어가 연결되지 않아 CSI 화질, LCD 해상도/아랍어 글꼴, BLE 권한·연결 거리, 버튼·LED·버저, 전원 발열, 카트 장착 강도는 확인하지 못했습니다. 자동 촬영은 동일 상품 재촬영을 새 상품으로 추가할 수 있으므로 시연 시 수동 촬영부터 검증하세요. 장치가 기록을 잊는 것과 구매자의 앱 이력을 삭제하는 것은 별개입니다.
