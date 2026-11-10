# Streamia Player – Erststart und Sprache

## Erstinstallation
1. Splash Screen (ca. 1,7 Sekunden).
2. Sprachauswahl. Die Gerätesprache wird vorausgewählt, sofern Streamia sie unterstützt; andernfalls Englisch. Die Auswahl ist nicht automatisch bestätigt.
3. Rechtlicher Hinweis in der ausdrücklich gewählten App-Sprache. Fortfahren ist erst nach aktivem Anhaken der Bestätigung möglich.
4. Anmeldung oder Registrierung.
5. Serverseitige Geräte- und Zugriffsprüfung.
6. Bei gültigem Zugriff Setup bzw. Player; andernfalls Paywall.

## Folgestarts
- Splash Screen.
- Gespeicherte Sprache wird verwendet; die Sprachauswahl wird übersprungen.
- Ist die aktuell hinterlegte Disclaimer-Version noch nicht bestätigt, wird der Hinweis erneut in der gespeicherten Sprache angezeigt.
- Danach Anmeldung/Zugriffsprüfung und App.

## Speicherung der rechtlichen Bestätigung
Die App speichert lokal Disclaimer-Version, UTC-Zeitpunkt und Sprache der Bestätigung. Eine neue Version (`PrefsService.legalDisclaimerVersion`) erzwingt eine erneute Bestätigung. Eine bloße Änderung der App-Sprache erzwingt keine erneute Zustimmung zur unveränderten Textversion.

## Grenzen
Die Bestätigung wird derzeit lokal auf dem Gerät gespeichert und noch nicht serverseitig mit einem Benutzerkonto synchronisiert. Vor Veröffentlichung sollte eine serverseitige, revisionsfähige Zustimmungshistorie erwogen werden. Die Texte sind keine anwaltlich geprüfte Rechtsberatung.
