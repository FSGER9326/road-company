from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate() -> list[str]:
    errors: list[str] = []
    factions = load_json(ROOT / "data/factions/factions.json")
    if not isinstance(factions, list):
        return ["factions.json must contain a list"]
    seen: set[str] = set()
    for faction in factions:
        label = f"faction {faction.get('id', '<missing>')}"
        for field in ["id", "name", "description"]:
            if field not in faction:
                errors.append(f"{label} missing required field '{field}'")
        faction_id = faction.get("id")
        if faction_id in seen:
            errors.append(f"duplicate faction id '{faction_id}'")
        if faction_id:
            seen.add(faction_id)
        for field in ["name", "description"]:
            if not isinstance(faction.get(field), str) or not faction.get(field, "").strip():
                errors.append(f"{label} field '{field}' must be a non-empty string")
    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print("Faction validation failed:")
        for error in found:
            print(f"- {error}")
        raise SystemExit(1)
    print("Faction validation passed.")
