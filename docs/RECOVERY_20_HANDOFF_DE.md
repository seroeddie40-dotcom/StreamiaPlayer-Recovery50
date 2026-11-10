# Streamia Player – Recovery 20

## Arbeitsbasis
Recovery 20 baut auf Recovery 19 auf. Das vollständige Projektarchiv enthält alle Projektdateien einschließlich Android-, Supabase-, Sprach- und Dokumentationsdateien.

## Änderungen
- Fokusgruppen für Live-TV-, Film- und Serienraster.
- Initialer Fokus auf dem ersten Rasterelement.
- Sichtbare Fokusfarbe auf fokussierten Kacheln.
- Dashboard und Einstellungen in Fokusgruppen; initialer Fokus auf erster Aktion.
- Serienepisodenliste startet mit Fokus auf der ersten Episode.

## Grenzen
Flutter/Dart SDK ist in der Erstellungsumgebung nicht installiert. Daher wurde kein `flutter analyze`, Testlauf oder APK-Build ausgeführt. Die Fokusnavigation ist statisch ergänzt, aber nicht auf realer Android-TV-Hardware validiert. Supabase-Migrationen wurden nicht live ausgeführt.

## Nächster Schritt
Auf Android TV mit echter Fernbedienung testen: Dashboard-Raster, Film-/Serienraster, Episodenlisten, Einstellungen, Rückkehr aus Detailseiten und Fokus-Sichtbarkeit. Anschließend AppBar-Aktionen und Sondertasten ergänzen.
