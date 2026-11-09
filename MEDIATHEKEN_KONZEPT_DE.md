# Mediatheken-Modul – Konzept, noch nicht implementiert

Ziel: Optionaler, länderabhängiger Katalog offizieller öffentlich-rechtlicher Mediatheken für Android und Android TV. V1 verlinkt nur auf die offiziellen Apps oder Websites; keine direkte Wiedergabe, kein Stream-Scraping, keine Übernahme fremder Logos oder Metadaten ohne Rechteprüfung.

Länder/Prüfkandidaten: DE ARD/ZDF, TR TRT, EN BBC, RU Anbieter gesondert prüfen, PL TVP, ES RTVE, FR france.tv, AR länderabhängig. Die App-Sprache ist keine Aussage über die Geolokation oder Nutzungsberechtigung.

Implementierung später: konfigurierbarer Provider-Katalog mit ID, Land, unterstützten Sprachen, offiziellem HTTPS-Link, optionalem geprüften Android-Paketnamen und Lizenz-/Prüfstatus. Nur explizit freigegebene Einträge sichtbar. Auf Android TV installierte Apps über sichere Intents starten, sonst offiziellen Browser-Link anbieten. Keine QUERY_ALL_PACKAGES-Berechtigung.

Rechtsprüfung: https://www.ardmediathek.de/nutzungsbedingungen ; https://www.zdf.de/nutzungsbedingungen ; https://www.ard-digital.de/medienwissen/medienpolitik . Nichtkommerzielle Embedding-Regeln beachten, insbesondere bei späteren Premium-Tarifen. Anbieter- und Markenfreigaben vor Veröffentlichung prüfen.
