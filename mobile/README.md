# SafeByte Mobile

Flutter MVP app for SafeByte.

The app keeps the tester journey short:

1. Sign up or log in
2. Select allergy, halal, and vegan criteria
3. Capture or choose a Korean food-label image
4. Review `SAFE`, `CAUTION`, or `DANGER`
5. Open details only when evidence is needed

## Run

```powershell
cd mobile
flutter pub get
flutter run --dart-define=SAFE_BYTE_API_BASE=http://127.0.0.1:8000
```

For a deployed backend, pass the server URL at build/run time:

```powershell
flutter run --dart-define=SAFE_BYTE_API_BASE=http://YOUR_SERVER_IP
```

## API Usage

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `PUT /api/v1/me/preferences`
- `POST /api/v1/analyze/image`
- `GET /health/ocr`
- `GET /api/v1/costs`

## UX Notes

- Login is kept separate from preference setup.
- Allergy selection is search-first and avoids free-text input.
- A loading overlay blocks duplicate OCR taps.
- The first result screen emphasizes the verdict.
- Detail screens separate direct ingredients from cross-contact warnings.
