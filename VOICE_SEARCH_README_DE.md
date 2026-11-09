# Streamia Player – Voice Search Patch

## Included
- Native Speech-to-Text integration through Flutter `speech_to_text` (`^7.3.0`).
- Voice and keyboard search in the Master Search screen for Live TV, VOD and Series.
- Search is wired to the existing dashboard Master Search tile.
- Eight app languages are supported in the voice-search UI: German, Turkish, English, Russian, Arabic, Polish, Spanish and French.
- A language/dialect picker lists the recognition locales actually offered by the Android device's speech recognition service.
- Text normalization handles common Latin diacritics and several Arabic letter variants to improve matching.
- Android microphone permission was already present; Android 11+ speech-recognition service visibility query is included.

## Important dialect and device limitations
The app does not ship eight independent speech-recognition engines or language packs. It asks Android's installed speech-recognition service which locales are available and lets the user select among them. Therefore, dialects/accents are available only when the device/provider exposes them. The exact list varies by phone/TV, Android version, Google app or other recognition provider, installed offline packs, and region. Android TV devices without a compatible recognition service or microphone may not support voice input; the app displays a fallback message and keyboard search remains available.

For consistently strong dialect coverage across all supported languages and Android TV devices, a later cloud STT provider integration would be needed. That adds network, privacy, API-key/security, and usage-cost considerations.

## Build / test
Run `flutter pub get`, then `flutter analyze` and test on a real Android phone and Android TV device with the target languages installed. This patch was not compiled in this environment; the included ZIP is a source-code integration, not a verified APK.
