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


def validate_route_effects(contract: dict, field: str, label: str, errors: list[str]) -> None:
    allowed = {"bandit_pressure", "danger", "monster_pressure", "patrol_presence", "traffic", "trade_flow"}
    effects = contract.get(field)
    if not isinstance(effects, dict):
        errors.append(f"{label} {field} must be an object")
        return
    for key, value in effects.items():
        if key == "block_duration_ticks":
            if field != "route_effects_on_failure":
                errors.append(f"{label} block_duration_ticks is only allowed on route_effects_on_failure")
            if not isinstance(value, int) or not 1 <= value <= 52:
                errors.append(f"{label} {field}.block_duration_ticks must be an integer between 1 and 52")
            continue
        if key not in allowed:
            errors.append(f"{label} {field}.{key} is not an allowed route effect")
        if not isinstance(value, int) or not -100 <= value <= 100:
            errors.append(f"{label} {field}.{key} must be an integer between -100 and 100")


def validate() -> list[str]:
    errors: list[str] = []
    contracts = load_json(ROOT / "data/contracts/contracts.json")
    locations = load_json(ROOT / "data/world/locations.json")
    routes = load_json(ROOT / "data/world/routes.json")
    factions = load_json(ROOT / "data/factions/factions.json")
    encounters = load_json(ROOT / "data/combat/encounters.json")

    if not isinstance(contracts, list):
        return ["contracts.json must contain a list"]

    location_ids = {item["id"] for item in locations}
    route_ids = {item["id"] for item in routes}
    faction_ids = {item["id"] for item in factions}
    encounter_ids = {item["id"] for item in encounters}
    unique_ids(contracts, "contracts", errors)

    required = [
        "id",
        "title",
        "type",
        "patron_faction",
        "origin_location",
        "reward_crowns",
        "reward_renown",
        "danger",
        "description",
        "success_text",
        "failure_text",
        "encounter_id",
        "faction_effects",
        "required_cargo_or_objective",
        "route_effects_on_success",
        "route_effects_on_failure",
    ]
    allowed_types = {"escort_caravan", "hunt_bandits", "recover_missing_wagon", "capture_bounty_target"}

    for contract in contracts:
        label = f"contract {contract.get('id', '<missing>')}"
        for field in required:
            if field not in contract:
                errors.append(f"{label} missing required field '{field}'")
        if contract.get("type") not in allowed_types:
            errors.append(f"{label} has unsupported type '{contract.get('type')}'")
        if contract.get("patron_faction") not in faction_ids:
            errors.append(f"{label} references unknown patron faction '{contract.get('patron_faction')}'")
        if contract.get("origin_location") not in location_ids:
            errors.append(f"{label} references unknown origin '{contract.get('origin_location')}'")
        if contract.get("target_location") and contract.get("target_location") not in location_ids:
            errors.append(f"{label} references unknown target location '{contract.get('target_location')}'")
        if contract.get("target_route") and contract.get("target_route") not in route_ids:
            errors.append(f"{label} references unknown target route '{contract.get('target_route')}'")
        if contract.get("encounter_id") not in encounter_ids:
            errors.append(f"{label} references unknown encounter '{contract.get('encounter_id')}'")
        for field, low, high in [("reward_crowns", 0, 5000), ("reward_renown", 0, 100), ("danger", 1, 5)]:
            value = contract.get(field)
            if not isinstance(value, int) or not low <= value <= high:
                errors.append(f"{label} field '{field}' must be an integer between {low} and {high}")
        for effects_field in ["faction_effects", "failure_faction_effects"]:
            effects = contract.get(effects_field, {})
            if not isinstance(effects, dict):
                errors.append(f"{label} {effects_field} must be an object")
                continue
            for faction_id, value in effects.items():
                if faction_id not in faction_ids:
                    errors.append(f"{label} {effects_field} references unknown faction '{faction_id}'")
                if not isinstance(value, int) or not -50 <= value <= 50:
                    errors.append(f"{label} {effects_field}.{faction_id} must be an integer between -50 and 50")
        validate_route_effects(contract, "route_effects_on_success", label, errors)
        validate_route_effects(contract, "route_effects_on_failure", label, errors)

    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print("Contract validation failed:")
        for error in found:
            print(f"- {error}")
        raise SystemExit(1)
    print("Contract validation passed.")
