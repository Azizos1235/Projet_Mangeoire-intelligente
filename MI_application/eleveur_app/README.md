# Mangeoire Intelligente — Éleveur

Flutter application for viewing livestock sensor records and scanning RFID/NFC
tags.

## Run

```shell
flutter pub get
flutter run
```

Set `API_BASE_URL` when connecting to a non-default backend:

```shell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Current backend support

- `GET /cows` and `GET /latest/{cow_id}` provide animal identifiers and sensor
  telemetry. `GET /home/appetite` provides each owned cow's latest daily
  appetite class and its raw stored label.
- Profile writes and alert operations are attempted through their API routes,
  but are not currently implemented by the cloud server; the app displays the
  resulting errors instead of fabricating local records.
- Prediction currently returns `501` from the server. Feeding recommendations
  are therefore unavailable.
- NFC scanning uses the Android platform channel. QR camera scanning and
  biometric authentication are not configured in this project.

## Checks

```shell
flutter analyze
flutter test
flutter build apk --debug
```
