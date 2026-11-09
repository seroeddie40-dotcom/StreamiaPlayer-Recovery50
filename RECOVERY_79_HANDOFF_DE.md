# Recovery 79 – APK- und Android-TV-Build-Vorbereitung

## Umgesetzt
- Android-TV-Launcher-Banner (320 × 180 Pixel) und Manifest-Referenz ergänzt.
- Debug-Manifest in `AndroidManifest.xml` umbenannt, sodass Android-Gradle-Tools die Overlay-Datei regulär finden.
- Gefährlichen automatischen Fallback von Release-Signierung auf den Debug-Schlüssel entfernt. Ein Release ohne bereitgestellte Signatur bleibt unsigniert.
- Einfache lokale Prüfungen im Skript `scripts/check_android_package.py` hinzugefügt.

## Windows: erste installierbare Test-APK
1. Flutter SDK und Android Studio mit Android SDK einrichten; `flutter doctor -v` ausführen.
2. ZIP entpacken und im Projektverzeichnis ein Terminal öffnen.
3. `flutter pub get` und `flutter analyze` ausführen; eventuelle Fehler beheben.
4. `flutter test` ausführen; Fehler beheben.
5. `flutter build apk --debug` ausführen.
6. APK liegt üblicherweise unter `build/app/outputs/flutter-apk/app-debug.apk`.
7. Smartphone/Android-TV mit Entwickleroptionen und USB-Debugging verbinden; `flutter devices` und `flutter install --debug` verwenden oder APK via `adb install -r` installieren.

## Release-Signierung (später)
Für einen signierten Release die Datei `android/app/upload-keystore.jks` **lokal** bereitstellen und `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` als Umgebungsvariablen setzen. Keystore und Passwörter niemals in Git/ZIP aufnehmen. Erst danach `flutter build apk --release` ausführen. Ohne diese Werte ist der Release-Build absichtlich nicht signiert.

## Bekannte Grenzen
- Hier steht kein Flutter-/Dart-SDK bereit: keine erfolgreiche Kompilierung, keine Flutter-Tests, keine echte APK und kein Gerätetest bestätigt.
- Android-TV-Launcher-Banner ist ein vorläufiges, eigens erstelltes Branding-Asset; spätere Markenabnahme offen.
- `android:usesCleartextTraffic=true` bleibt für vom Nutzer eingetragene HTTP-IPTV-Quellen aktiv. Datenschutz und Transport-Sicherheit vor Veröffentlichung gesondert bewerten.
- Versionsnummer, Datenschutz, Supabase-Konfiguration, Store-Anforderungen und tatsächliche Gerätekompatibilität vor Release prüfen.
