from __future__ import annotations

import copy
import json
import time
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
REQUIRED_TOP_LEVEL = {
    "schema_version",
    "game_day",
    "current_location",
    "company",
    "world",
    "contracts",
    "factions",
    "rumors",
    "memory",
    "rng_seed",
}


class SaveLoadError(ValueError):
    pass


def build_snapshot(
    *,
    game_day: int,
    current_location: str,
    company: dict[str, Any],
    settlement_economy: list[dict[str, Any]] | None = None,
    route_economy: list[dict[str, Any]] | None = None,
    settlement_factions: list[dict[str, Any]] | None = None,
    active_contract: dict[str, Any] | None = None,
    contract_board: list[dict[str, Any]] | None = None,
    rumors: list[dict[str, Any]] | None = None,
    memory: list[dict[str, Any]] | None = None,
    active_events: list[dict[str, Any]] | None = None,
    event_cooldowns: dict[str, Any] | None = None,
    rng_seed: int = 12345,
    saved_at_unix_time: int | None = None,
) -> dict[str, Any]:
    company_copy = copy.deepcopy(company)
    company_copy.setdefault("current_location", current_location)
    company_copy.setdefault("resources", {})
    company_copy.setdefault("roster", [])
    company_copy.setdefault("graveyard", [])
    company_copy.setdefault("faction_reputation", {})
    company_copy.setdefault("active_contract", copy.deepcopy(active_contract or {}))

    return {
        "schema_version": SCHEMA_VERSION,
        "saved_at_unix_time": saved_at_unix_time if saved_at_unix_time is not None else int(time.time()),
        "game_day": int(game_day),
        "current_location": current_location,
        "company": company_copy,
        "world": {
            "settlement_economy": copy.deepcopy(settlement_economy or []),
            "route_economy": copy.deepcopy(route_economy or []),
            "active_events": copy.deepcopy(active_events or []),
            "event_cooldowns": copy.deepcopy(event_cooldowns or {}),
        },
        "contracts": {
            "active_contract": copy.deepcopy(active_contract or company_copy.get("active_contract", {})),
            "contract_board": copy.deepcopy(contract_board or []),
        },
        "factions": {"settlement_factions": copy.deepcopy(settlement_factions or [])},
        "rumors": {"active": copy.deepcopy(rumors or [])},
        "memory": {"entries": copy.deepcopy(memory or [])},
        "rng_seed": int(rng_seed),
        "notes": "Save/load snapshot v1 for prototype state.",
        "debug_metadata": {"format": "road_company_save_snapshot"},
    }


def validate_snapshot(snapshot: Any) -> list[str]:
    if not isinstance(snapshot, dict):
        return ["Snapshot must be a JSON object."]

    errors: list[str] = []
    missing = sorted(REQUIRED_TOP_LEVEL - set(snapshot))
    errors.extend(f"{key} is required." for key in missing)

    if "schema_version" in snapshot and snapshot.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"Unsupported schema_version {snapshot.get('schema_version')}; expected {SCHEMA_VERSION}.")
    if "saved_at_unix_time" not in snapshot and "saved_at_text" not in snapshot:
        errors.append("saved_at_unix_time or saved_at_text is required.")
    if "notes" not in snapshot and "debug_metadata" not in snapshot:
        errors.append("notes or debug_metadata is required.")

    for key in ("game_day", "rng_seed"):
        if key in snapshot and not isinstance(snapshot[key], int):
            errors.append(f"{key} must be an integer.")
    if "current_location" in snapshot and not isinstance(snapshot["current_location"], str):
        errors.append("current_location must be a string.")
    for key in ("company", "world", "contracts", "factions", "rumors", "memory"):
        if key in snapshot and not isinstance(snapshot[key], dict):
            errors.append(f"{key} must be an object.")

    if isinstance(snapshot.get("company"), dict):
        resources = snapshot["company"].get("resources", {})
        if resources is not None and not isinstance(resources, dict):
            errors.append("company.resources must be an object when present.")

    if isinstance(snapshot.get("world"), dict):
        for key in ("settlement_economy", "route_economy", "active_events"):
            if key in snapshot["world"] and not isinstance(snapshot["world"][key], list):
                errors.append(f"world.{key} must be a list when present.")

    return errors


def normalize_snapshot(snapshot: dict[str, Any]) -> dict[str, Any]:
    errors = validate_snapshot(snapshot)
    if errors:
        raise SaveLoadError("; ".join(errors))

    normalized = copy.deepcopy(snapshot)
    company = normalized.setdefault("company", {})
    company.setdefault("current_location", normalized.get("current_location", ""))
    company.setdefault("resources", {})
    company.setdefault("roster", [])
    company.setdefault("graveyard", [])
    company.setdefault("faction_reputation", {})
    company.setdefault("active_contract", normalized.get("contracts", {}).get("active_contract", {}))

    world = normalized.setdefault("world", {})
    world.setdefault("settlement_economy", [])
    world.setdefault("route_economy", [])
    world.setdefault("active_events", [])
    world.setdefault("event_cooldowns", {})

    contracts = normalized.setdefault("contracts", {})
    contracts.setdefault("active_contract", company.get("active_contract", {}))
    contracts.setdefault("contract_board", [])

    normalized.setdefault("factions", {}).setdefault("settlement_factions", [])
    normalized.setdefault("rumors", {}).setdefault("active", [])
    normalized.setdefault("memory", {}).setdefault("entries", [])
    return normalized


def round_trip(snapshot: dict[str, Any]) -> dict[str, Any]:
    return normalize_snapshot(json.loads(json.dumps(snapshot, indent=2, sort_keys=True)))


def load_snapshot_text(text: str) -> tuple[dict[str, Any] | None, list[str]]:
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        return None, [f"Malformed save JSON: {exc.msg} at line {exc.lineno} column {exc.colno}."]
    errors = validate_snapshot(parsed)
    if errors:
        return None, errors
    return normalize_snapshot(parsed), []


def load_snapshot_file(path: Path) -> tuple[dict[str, Any] | None, list[str]]:
    try:
        return load_snapshot_text(path.read_text(encoding="utf-8"))
    except OSError as exc:
        return None, [f"Could not read save snapshot: {exc}"]


def save_snapshot_file(snapshot: dict[str, Any], path: Path) -> list[str]:
    errors = validate_snapshot(snapshot)
    if errors:
        return errors
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    except OSError as exc:
        return [f"Could not write save snapshot: {exc}"]
    return []
