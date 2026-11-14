
from pathlib import Path
import json
import sys

LANGUAGES = ("de", "tr", "en", "ru", "pl", "es", "fr", "ar")
LANG_DIR = Path(__file__).resolve().parents[1] / "assets" / "lang"


def reject_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Doppelter Schlüssel: {key}")
        result[key] = value
    return result


def main():
    translations = {}
    errors = []

    for language in LANGUAGES:
        path = LANG_DIR / f"{language}.json"

        if not path.is_file():
            errors.append(f"{language}: Datei fehlt")
            continue

        try:
            data = json.loads(
                path.read_text(encoding="utf-8-sig"),
                object_pairs_hook=reject_duplicates,
            )

            if not isinstance(data, dict):
                raise ValueError("JSON-Wurzel muss ein Objekt sein")

            for key, value in data.items():
                if not isinstance(value, str):
                    errors.append(
                        f"{language}: {key} ist kein Text"
                    )
                elif not value.strip():
                    errors.append(
                        f"{language}: {key} ist leer"
                    )

            translations[language] = data
            print(f"{language}: {len(data)} Schlüssel")

        except (OSError, ValueError) as exc:
            errors.append(f"{language}: {exc}")

    all_keys = set()
    for data in translations.values():
        all_keys.update(data.keys())

    print(f"\nUnterschiedliche Schlüssel: {len(all_keys)}")

    for language, data in translations.items():
        missing = sorted(all_keys - set(data.keys()))

        if missing:
            errors.append(
                f"{language}: {len(missing)} fehlende Schlüssel"
            )
            print(f"\n{language} – fehlende Schlüssel:")
            for key in missing:
                print(f"  - {key}")

    if errors:
        print("\nPRÜFUNG NICHT BESTANDEN")
        for error in errors:
            print(f"FEHLER: {error}")
        return 1

    print("\nERFOLG: Alle acht Sprachdateien sind konsistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
