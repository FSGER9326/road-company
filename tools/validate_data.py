from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from validate_combat import validate as validate_combat
from validate_company import validate as validate_company
from validate_contracts import validate as validate_contracts
from validate_factions import validate as validate_factions
from validate_world import validate as validate_world
from validate_world_economy import validate as validate_world_economy


def validate_json_parses() -> list[str]:
    errors: list[str] = []
    for path in sorted((ROOT / "data").rglob("*.json")):
        try:
            with path.open("r", encoding="utf-8") as handle:
                json.load(handle)
        except json.JSONDecodeError as exc:
            errors.append(f"{path.relative_to(ROOT)} JSON parse error: {exc}")
    return errors


def validate_company_resources() -> list[str]:
    errors: list[str] = []
    with (ROOT / "data/company/company_start.json").open("r", encoding="utf-8") as handle:
        company = json.load(handle)
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
    return errors


def main() -> int:
    checks = [
        ("JSON parse", validate_json_parses),
        ("Factions", validate_factions),
        ("World", validate_world),
        ("World economy", validate_world_economy),
        ("Contracts", validate_contracts),
        ("Company", validate_company),
        ("Combat", validate_combat),
        ("Company resources", validate_company_resources),
    ]
    all_errors: list[str] = []
    for name, func in checks:
        errors = func()
        if errors:
            print(f"{name}: failed")
            all_errors.extend(errors)
        else:
            print(f"{name}: passed")
    if all_errors:
        print("\nValidation errors:")
        for error in all_errors:
            print(f"- {error}")
        return 1
    print("\nAll data validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
