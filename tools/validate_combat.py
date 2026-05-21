from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def unique_ids(items: list[dict], label: str, errors: list[str]) -> set[str]:
    seen: set[str] = set()
    for item in items:
        item_id = item.get("id")
        if not item_id:
            errors.append(f"{label} has item without id")
        elif item_id in seen:
            errors.append(f"{label} has duplicate id '{item_id}'")
        else:
            seen.add(item_id)
    return seen


def validate_fighter(fighter: dict, label: str, weapon_ids: set[str], armor_ids: set[str], errors: list[str]) -> None:
    required = [
        "id",
        "name",
        "background",
        "level",
        "hp",
        "max_hp",
        "armor_body",
        "armor_head",
        "fatigue",
        "max_fatigue",
        "morale_state",
        "action_points",
        "melee_skill",
        "ranged_skill",
        "melee_defense",
        "ranged_defense",
        "resolve",
        "initiative",
        "weapon_id",
        "armor_id",
        "traits",
        "injuries",
    ]
    for field in required:
        if field not in fighter:
            errors.append(f"{label} missing required field '{field}'")
    for field, low, high in [
        ("level", 1, 20),
        ("hp", 1, 200),
        ("max_hp", 1, 200),
        ("armor_body", 0, 300),
        ("armor_head", 0, 300),
        ("fatigue", 0, 300),
        ("max_fatigue", 1, 300),
        ("action_points", 1, 12),
        ("melee_skill", 1, 120),
        ("ranged_skill", 1, 120),
        ("melee_defense", 0, 80),
        ("ranged_defense", 0, 80),
        ("resolve", 1, 120),
        ("initiative", 1, 160),
    ]:
        value = fighter.get(field)
        if not isinstance(value, int) or not low <= value <= high:
            errors.append(f"{label} field '{field}' must be an integer between {low} and {high}")
    if fighter.get("hp", 0) > fighter.get("max_hp", 0):
        errors.append(f"{label} hp cannot exceed max_hp")
    if fighter.get("weapon_id") not in weapon_ids:
        errors.append(f"{label} references unknown weapon '{fighter.get('weapon_id')}'")
    if fighter.get("armor_id") not in armor_ids:
        errors.append(f"{label} references unknown armor '{fighter.get('armor_id')}'")
    if fighter.get("morale_state") not in {"steady", "wavering", "breaking"}:
        errors.append(f"{label} has invalid morale_state '{fighter.get('morale_state')}'")
    if not isinstance(fighter.get("traits", []), list):
        errors.append(f"{label} traits must be a list")
    if not isinstance(fighter.get("injuries", []), list):
        errors.append(f"{label} injuries must be a list")


def validate() -> list[str]:
    errors: list[str] = []
    weapons = load_json(ROOT / "data/combat/weapons.json")
    armor = load_json(ROOT / "data/combat/armor.json")
    enemies = load_json(ROOT / "data/combat/enemies.json")
    encounters = load_json(ROOT / "data/combat/encounters.json")
    company = load_json(ROOT / "data/company/company_start.json")

    weapon_ids = unique_ids(weapons, "weapons", errors)
    armor_ids = unique_ids(armor, "armor", errors)
    enemy_ids = unique_ids(enemies, "enemies", errors)
    unique_ids(encounters, "encounters", errors)

    for weapon in weapons:
        label = f"weapon {weapon.get('id', '<missing>')}"
        for field in ["id", "name", "range", "ap_cost", "fatigue_cost", "damage_min", "damage_max", "armor_damage", "hit_bonus"]:
            if field not in weapon:
                errors.append(f"{label} missing required field '{field}'")
        if not isinstance(weapon.get("range"), int) or not 0 <= weapon["range"] <= 8:
            errors.append(f"{label} range must be 0-8")
        if weapon.get("damage_min", 0) > weapon.get("damage_max", 0):
            errors.append(f"{label} damage_min cannot exceed damage_max")

    for armor_item in armor:
        label = f"armor {armor_item.get('id', '<missing>')}"
        for field in ["id", "name", "body_armor", "head_armor", "fatigue_penalty"]:
            if field not in armor_item:
                errors.append(f"{label} missing required field '{field}'")

    roster = company.get("roster", [])
    if not isinstance(roster, list) or len(roster) != 6:
        errors.append("company_start roster must contain exactly 6 starting fighters")
    unique_ids(roster, "company roster", errors)
    for fighter in roster:
        validate_fighter(fighter, f"fighter {fighter.get('id', '<missing>')}", weapon_ids, armor_ids, errors)

    for enemy in enemies:
        validate_fighter(enemy, f"enemy {enemy.get('id', '<missing>')}", weapon_ids, armor_ids, errors)

    for encounter in encounters:
        label = f"encounter {encounter.get('id', '<missing>')}"
        enemies_in_encounter = encounter.get("enemies", [])
        if not isinstance(enemies_in_encounter, list) or not 5 <= len(enemies_in_encounter) <= 7:
            errors.append(f"{label} enemies must list 5-7 enemy ids")
        for enemy_id in enemies_in_encounter:
            if enemy_id not in enemy_ids:
                errors.append(f"{label} references unknown enemy '{enemy_id}'")

    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print("Combat validation failed:")
        for error in found:
            print(f"- {error}")
        raise SystemExit(1)
    print("Combat validation passed.")
