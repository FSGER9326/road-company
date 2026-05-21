from __future__ import annotations

import copy
import json
from pathlib import Path

from settlement_factions_core import CONTRACT_TYPES, FACTION_TYPES

ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_factions(factions: list[dict], settlement_ids: set[str]) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    by_id: dict[str, dict] = {}
    required = [
        "id",
        "settlement_id",
        "name",
        "type",
        "influence",
        "attitude_to_company",
        "agenda_tags",
        "resource_tags",
        "rival_faction_ids",
        "supported_contract_types",
        "opposed_contract_types",
        "economy_modifiers",
        "unrest_modifiers",
        "market_modifiers",
        "event_tags",
    ]
    for faction in factions:
        label = f"settlement faction {faction.get('id', '<missing>')}"
        for field in required:
            if field not in faction:
                errors.append(f"{label} missing required field '{field}'")
        faction_id = faction.get("id")
        if not faction_id:
            errors.append(f"{label} missing id")
        elif faction_id in seen:
            errors.append(f"duplicate settlement faction id '{faction_id}'")
        else:
            seen.add(faction_id)
            by_id[faction_id] = faction
        if faction.get("settlement_id") not in settlement_ids:
            errors.append(f"{label} references unknown settlement '{faction.get('settlement_id')}'")
        if faction.get("type") not in FACTION_TYPES:
            errors.append(f"{label} has unknown type '{faction.get('type')}'")
        if not isinstance(faction.get("influence"), int) or not 0 <= faction.get("influence", -1) <= 100:
            errors.append(f"{label} influence must be an integer between 0 and 100")
        if not isinstance(faction.get("attitude_to_company"), int) or not -100 <= faction.get("attitude_to_company", -999) <= 100:
            errors.append(f"{label} attitude_to_company must be an integer between -100 and 100")
        for field in ["agenda_tags", "resource_tags", "rival_faction_ids", "supported_contract_types", "opposed_contract_types", "event_tags"]:
            if not isinstance(faction.get(field), list):
                errors.append(f"{label} {field} must be a list")
        for field in ["economy_modifiers", "unrest_modifiers", "market_modifiers"]:
            if not isinstance(faction.get(field), dict):
                errors.append(f"{label} {field} must be an object")
        for contract_type in faction.get("supported_contract_types", []) + faction.get("opposed_contract_types", []):
            if contract_type not in CONTRACT_TYPES:
                errors.append(f"{label} references unsupported contract type '{contract_type}'")

    for faction in factions:
        label = f"settlement faction {faction.get('id', '<missing>')}"
        for rival_id in faction.get("rival_faction_ids", []):
            rival = by_id.get(rival_id)
            if not rival:
                errors.append(f"{label} references unknown rival '{rival_id}'")
            elif rival.get("settlement_id") != faction.get("settlement_id"):
                errors.append(f"{label} rival '{rival_id}' is not in the same settlement")

    for settlement_id in settlement_ids:
        local_types = {faction.get("type") for faction in factions if faction.get("settlement_id") == settlement_id}
        missing_types = sorted(FACTION_TYPES - local_types)
        if missing_types:
            errors.append(f"settlement {settlement_id} missing internal faction types: {', '.join(missing_types)}")
    return errors


def validate_settlement_state(settlements: list[dict], faction_ids: set[str], errors: list[str]) -> None:
    for settlement in settlements:
        label = f"settlement economy {settlement.get('settlement_id', '<missing>')}"
        for field in ["dominant_internal_faction", "faction_tension", "local_policy_tags", "active_internal_conflicts", "last_faction_events"]:
            if field not in settlement:
                errors.append(f"{label} missing required faction state field '{field}'")
        dominant = settlement.get("dominant_internal_faction", "")
        if dominant and dominant not in faction_ids:
            errors.append(f"{label} dominant_internal_faction references unknown faction '{dominant}'")
        if not isinstance(settlement.get("faction_tension"), int) or not 0 <= settlement.get("faction_tension", -1) <= 100:
            errors.append(f"{label} faction_tension must be an integer between 0 and 100")
        for field in ["local_policy_tags", "active_internal_conflicts", "last_faction_events"]:
            if not isinstance(settlement.get(field), list):
                errors.append(f"{label} {field} must be a list")


def validate() -> list[str]:
    errors: list[str] = []
    settlements = load_json(ROOT / "data/world/settlement_economy.json")
    factions = load_json(ROOT / "data/world/settlement_factions.json")
    settlement_ids = {item["settlement_id"] for item in settlements}
    errors.extend(validate_factions(factions, settlement_ids))
    validate_settlement_state(settlements, {item["id"] for item in factions}, errors)
    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print("Settlement faction validation failed:")
        for error in found:
            print(f"- {error}")
        raise SystemExit(1)
    print("Settlement faction validation passed.")
