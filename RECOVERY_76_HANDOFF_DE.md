# Streamia Player – Recovery 76

Basis: Recovery 75. Android-TV-Navigation langer Sender- und Episodenlisten.

- Beim Fokuswechsel sorgt Scrollable.ensureVisible für die Sichtbarkeit des fokussierten Eintrags.
- Senderliste fokussiert den aktuellen Sender oder den ersten sichtbaren Eintrag, falls der aktuelle nicht in der gewählten Kategorie steht.
- Episodenliste erhält die Fokusführung für die aktuelle Episode.
- Ein zusätzlicher Quellcode-Regressionstest ist enthalten (nicht ausgeführt).

Statische Prüfungen und ZIP-Integrität ausgeführt. Flutter analyze/test/build und Hardwaretests sind weiterhin offen (Flutter SDK nicht installiert).
