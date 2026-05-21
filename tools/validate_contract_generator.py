from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from contract_generator_core import CONTRACT_TYPES, generate_contracts
from validate_contracts import validate_route_effects

SETTLEMENT_EFFECT_FIELDS = {
    "food_stock",
    "medicine_stock",
    "tools_stock",
    "arms_stock",
    "prosperity",
    "security",
    "unrest",
    "trade_access",
    "recruitment_pool_quality",
}


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def unique_values(values: list[str], label: str, errors: list[str]) -> None:
    seen: set[str] = set()
    for value in values:
        if not value:
            errors.append(f"{label} has blank value")
        elif value in seen:
            errors.append(f"{label} has duplicate '{value}'")
        seen.add(value)


def validate_defaults(defaults: Any, encounter_ids: set[str], errors: list[str]) -> None:
    if not isinstance(defaults, list):
        errors.append("contract_type_defaults.json must contain a list")
        return
    types = [str(item.get("type", "")) for item in defaults if isinstance(item, dict)]
    unique_values(types, "contract type defaults", errors)
    missing = CONTRACT_TYPES.difference(types)
    extra = set(types).difference(CONTRACT_TYPES)
    if missing:
        errors.append(f"contract type defaults missing: {', '.join(sorted(missing))}")
    if extra:
        errors.append(f"contract type defaults include unsupported types: {', '.join(sorted(extra))}")
    required = [
        "type",
        "base_crowns",
        "base_renown",
        "encounter_id",
        "required_objective",
        "trigger_condition",
        "route_effects_success",
        "route_effects_failure",
        "settlement_effects_success",
        "settlement_effects_failure",
        "title_template",
        "description_template",
        "success_template",
        "failure_template",
    ]
    for item in defaults:
        if not isinstance(item, dict):
            errors.append("contract type default entries must be objects")
            continue
        label = f"contract type default {item.get('type', '<missing>')}"
        for field in required:
            if field not in item:
                errors.append(f"{label} missing required field '{field}'")
        if item.get("encounter_id") not in encounter_ids:
            errors.append(f"{label} references unknown encounter '{item.get('encounter_id')}'")
        for field, low, high in [("base_crowns", 50, 5000), ("base_renown", 0, 100)]:
            value = item.get(field)
            if not isinstance(value, int) or not low <= value <= high:
                errors.append(f"{label} {field} must be an integer between {low} and {high}")
        pseudo_contract = {
            "route_effects_on_success": item.get("route_effects_success", {}),
            "route_effects_on_failure": item.get("route_effects_failure", {}),
        }
        validate_route_effects(pseudo_contract, "route_effects_on_success", label, errors)
        validate_route_effects(pseudo_contract, "route_effects_on_failure", label, errors)
        for field in ["settlement_effects_success", "settlement_effects_failure"]:
            validate_settlement_effect_dict(item.get(field, {}), f"{label} {field}", errors)


def validate_settlement_effect_dict(effects: Any, label: str, errors: list[str]) -> None:
    if not isinstance(effects, dict):
        errors.append(f"{label} must be an object")
        return
    for key, value in effects.items():
        if key in {"add_status_effect", "remove_status_effect"}:
            if not isinstance(value, str) or not value:
                errors.append(f"{label}.{key} must be a non-empty string")
            continue
        if key not in SETTLEMENT_EFFECT_FIELDS:
            errors.append(f"{label}.{key} is not an allowed settlement effect")
        if not isinstance(value, int) or not -500 <= value <= 500:
            errors.append(f"{label}.{key} must be an integer between -500 and 500")


def validate_generated_contract(
    contract: dict[str, Any],
    location_ids: set[str],
    route_ids: set[str],
    faction_ids: set[str],
    encounter_ids: set[str],
    settlement_ids: set[str],
    errors: list[str],
) -> None:
    label = f"generated contract {contract.get('id', '<missing>')}"
    required = [
        "id",
        "title",
        "type",
        "origin_location",
        "patron_faction",
        "urgency",
        "danger",
        "reward_crowns",
        "reward_renown",
        "description",
        "generated_from",
        "success_effects",
        "failure_effects",
        "route_effects",
        "settlement_effects",
        "expires_after_days",
        "seed",
    ]
    for field in required:
        if field not in contract:
            errors.append(f"{label} missing required field '{field}'")
    if contract.get("type") not in CONTRACT_TYPES:
        errors.append(f"{label} has unsupported type '{contract.get('type')}'")
    if contract.get("origin_location") not in location_ids:
        errors.append(f"{label} references unknown origin '{contract.get('origin_location')}'")
    if contract.get("target_location") and contract.get("target_location") not in location_ids:
        errors.append(f"{label} references unknown target location '{contract.get('target_location')}'")
    if contract.get("target_route") and contract.get("target_route") not in route_ids:
        errors.append(f"{label} references unknown target route '{contract.get('target_route')}'")
    if contract.get("patron_faction") not in faction_ids:
        errors.append(f"{label} references unknown patron faction '{contract.get('patron_faction')}'")
    encounter_id = contract.get("encounter_id")
    encounter_tags = contract.get("encounter_tags")
    if encounter_id and encounter_id not in encounter_ids:
        errors.append(f"{label} references unknown encounter '{encounter_id}'")
    if not encounter_id and not isinstance(encounter_tags, list):
        errors.append(f"{label} must include encounter_id or encounter_tags")
    for field, low, high in [("urgency", 1, 5), ("danger", 1, 10), ("reward_crowns", 50, 5000), ("reward_renown", 0, 100), ("expires_after_days", 1, 52)]:
        value = contract.get(field)
        if not isinstance(value, int) or not low <= value <= high:
            errors.append(f"{label} {field} must be an integer between {low} and {high}")
    validate_route_effects(contract, "route_effects_on_success", label, errors)
    validate_route_effects(contract, "route_effects_on_failure", label, errors)
    for field in ["settlement_effects_on_success", "settlement_effects_on_failure"]:
        settlement_effects = contract.get(field, {})
        if not isinstance(settlement_effects, dict):
            errors.append(f"{label} {field} must be an object")
            continue
        for settlement_id, effects in settlement_effects.items():
            if settlement_id not in settlement_ids:
                errors.append(f"{label} {field} references unknown settlement '{settlement_id}'")
            validate_settlement_effect_dict(effects, f"{label} {field}.{settlement_id}", errors)


def validate() -> list[str]:
    errors: list[str] = []
    defaults = load_json(ROOT / "data/contracts/contract_type_defaults.json")
    locations = load_json(ROOT / "data/world/locations.json")
    route_links = load_json(ROOT / "data/world/routes.json")
    settlement_economies = load_json(ROOT / "data/world/settlement_economy.json")
    route_economies = load_json(ROOT / "data/world/route_economy.json")
    factions = load_json(ROOT / "data/factions/factions.json")
    encounters = load_json(ROOT / "data/combat/encounters.json")
    static_contracts = load_json(ROOT / "data/contracts/contracts.json")

    location_ids = {item["id"] for item in locations}
    route_ids = {item["id"] for item in route_links}
    settlement_ids = {item["settlement_id"] for item in settlement_economies}
    faction_ids = {item["id"] for item in factions}
    encounter_ids = {item["id"] for item in encounters}

    validate_defaults(defaults, encounter_ids, errors)
    generated: list[dict[str, Any]] = []
    for location_id in sorted(settlement_ids):
        generated.extend(
            generate_contracts(
                location_id,
                settlement_economies,
                route_economies,
                route_links,
                {},
                static_contracts,
                locations,
                factions,
                defaults,
                seed=12345,
            )
        )
    unique_values([str(item.get("id", "")) for item in generated], "generated contracts", errors)
    for contract in generated:
        validate_generated_contract(contract, location_ids, route_ids, faction_ids, encounter_ids, settlement_ids, errors)
    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print("Contract generator validation failed:")
        for error in found:
            print(f"- {error}")
        raise SystemExit(1)
    print("Contract generator validation passed.")
