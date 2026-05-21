from __future__ import annotations

import json
from pathlib import Path

from validate_combat import validate_fighter

ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate() -> list[str]:
    errors: list[str] = []
    company = load_json(ROOT / "data/company/company_start.json")
    locations = load_json(ROOT / "data/world/locations.json")
    factions = load_json(ROOT / "data/factions/factions.json")
    weapons = load_json(ROOT / "data/combat/weapons.json")
    armor = load_json(ROOT / "data/combat/armor.json")

    required = [
        "company_name",
        "current_location",
        "crowns",
        "food",
        "tools",
        "medicine",
        "ammunition",
        "morale",
        "vigor",
        "renown",
        "roster",
        "graveyard",
        "faction_reputation",
    ]
    for field in required:
        if field not in company:
            errors.append(f"company_start missing required field '{field}'")

    location_ids = {item["id"] for item in locations}
    faction_ids = {item["id"] for item in factions}
    weapon_ids = {item["id"] for item in weapons}
    armor_ids = {item["id"] for item in armor}

    if company.get("current_location") not in location_ids:
        errors.append(f"company_start current_location references unknown location '{company.get('current_location')}'")

    for field, low, high in [
        ("crowns", 0, 100000),
        ("food", 0, 1000),
        ("tools", 0, 1000),
        ("medicine", 0, 1000),
        ("ammunition", 0, 1000),
        ("morale", 0, 100),
        ("vigor", 0, 100),
        ("renown", 0, 10000),
    ]:
        value = company.get(field)
        if not isinstance(value, int) or not low <= value <= high:
            errors.append(f"company_start field '{field}' must be an integer between {low} and {high}")

    reputation = company.get("faction_reputation", {})
    if not isinstance(reputation, dict):
        errors.append("company_start faction_reputation must be an object")
    else:
        for faction_id, value in reputation.items():
            if faction_id not in faction_ids:
                errors.append(f"company_start faction_reputation references unknown faction '{faction_id}'")
            if not isinstance(value, int) or not -100 <= value <= 100:
                errors.append(f"company_start faction_reputation.{faction_id} must be an integer between -100 and 100")

    roster = company.get("roster", [])
    if not isinstance(roster, list) or len(roster) != 6:
        errors.append("company_start roster must contain exactly 6 starting fighters")
    seen: set[str] = set()
    for fighter in roster:
        fighter_id = fighter.get("id")
        if fighter_id in seen:
            errors.append(f"company roster has duplicate id '{fighter_id}'")
        if fighter_id:
            seen.add(fighter_id)
        validate_fighter(fighter, f"fighter {fighter.get('id', '<missing>')}", weapon_ids, armor_ids, errors)

    if not isinstance(company.get("graveyard", []), list):
        errors.append("company_start graveyard must be a list")

    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print("Company validation failed:")
        for error in found:
            print(f"- {error}")
        raise SystemExit(1)
    print("Company validation passed.")
