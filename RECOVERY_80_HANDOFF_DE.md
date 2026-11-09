# Recovery 80 – CI-Build und Test-APK-Pipeline

Basis: Recovery 79. Ziel: die bislang nur statisch geprüften Flutter-Dateien in einer echten Flutter-Umgebung automatisch analysieren, testen und eine installierbare Debug-APK erzeugen.

## Änderungen
- GitHub Actions `.github/workflows/build.yml` aktualisiert: Java 17, aktueller Flutter-stable-Kanal, `flutter doctor -v`, Android-Strukturprüfung, `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test`, `flutter build apk --debug`.
- Die Pipeline erstellt **keine unsignierte Release-APK** mehr und versucht nicht, ohne Release-Keystore eine Release-Version bereitzustellen.
- Bei erfolgreichem Workflow steht unter GitHub Actions ein 14 Tage gespeichertes Artefakt `streamia-player-debug-apk` mit `app-debug.apk` bereit.
- `.gitignore` schützt lokale Keystores, Zugangsdaten, Build-Ausgaben und temporäre Dateien. Achtung: bereits eingecheckte Geheimnisse werden durch `.gitignore` nicht nachträglich entfernt.

## Verwendung ohne lokale Flutter-Installation
1. Projekt in ein privates GitHub-Repository hochladen, ohne Zugangsdaten/Keystores.
2. Repository → Actions → `Streamia Player - Android Debug APK and checks` → `Run workflow`.
3. **Erst wenn alle Schritte grün sind**, das Artefakt `streamia-player-debug-apk` herunterladen und die enthaltene APK auf dem Testgerät installieren.
4. Bei Fehlern die konkrete Fehlermeldung aus dem Actions-Protokoll zur Korrektur verwenden. Ein grüner CI-Lauf ersetzt keinen Android-TV-Hardwaretest.

## Verifikation dieser Recovery
- ZIP-Integrität, Android-Manifest-/Projektstruktur, YAML/JSON und relative Dart-Imports statisch geprüft.
- Flutter-/Dart-SDK hier nicht installiert: `flutter analyze`, `flutter test` und `flutter build apk` **noch nicht ausgeführt**. Ob die CI-Pipeline durchläuft, ist daher nicht bestätigt.
- Die Mediatheken-Idee bleibt wie vereinbart außerhalb der aktiven Entwicklungsplanung.
