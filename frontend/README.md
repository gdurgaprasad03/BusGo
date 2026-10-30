# BusGo - Flutter app

Mobile/web client for the BusGo demo bus-booking system. Setup, API address options, tests and known
limitations are in the [root README](../README.md).

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome   # backend expected at http://localhost:8080
```

Override the API address with `--dart-define=API_BASE_URL=http://<host>:8080`.
