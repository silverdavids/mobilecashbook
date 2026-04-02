# mobilecashbook

## Stack
- Flutter app
- Dart
- Android native Kotlin
- Gradle Kotlin DSL

## Commands
- Install deps: flutter pub get
- Analyze: flutter analyze
- Tests: flutter test
- Android debug build: cd android && ./gradlew assembleDebug || gradlew.bat assembleDebug

## Project rules
- Foreground Flutter SMS listener is for UI updates only.
- Background SMS forwarding is handled by Android BroadcastReceiver + WorkManager.
- Do not reintroduce duplicate SMS forwarding from Flutter background handlers.
- Keep Dart imports consistent and avoid duplicate library paths.
- Make minimal, high-confidence changes.
