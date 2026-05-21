from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def require_fields(item: dict, fields: list[str], label: str, errors: list[str]) -> None:
    for field in fields:
        if field not in item:
            errors.append(f"{label} missing required field '{field}'")


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


def validate() -> list[str]:
    errors: list[str] = []
    locations = load_json(ROOT / "data/world/locations.json")
    routes = load_json(ROOT / "data/world/routes.json")

    if not isinstance(locations, list):
        return ["locations.json must contain a list"]
    if not isinstance(routes, list):
        return ["routes.json must contain a list"]

    location_ids = unique_ids(locations, "locations", errors)
    route_ids = unique_ids(routes, "routes", errors)

    for location in locations:
        require_fields(
            location,
            ["id", "name", "type", "description", "faction_influence", "market_tags", "available_contracts"],
            f"location {location.get('id', '<missing>')}",
            errors,
        )
        if not isinstance(location.get("faction_influence", {}), dict):
            errors.append(f"location {location.get('id')} faction_influence must be an object")
        if not isinstance(location.get("market_tags", []), list):
            errors.append(f"location {location.get('id')} market_tags must be a list")
        if not isinstance(location.get("available_contracts", []), list):
            errors.append(f"location {location.get('id')} available_contracts must be a list")

    for route in routes:
        label = f"route {route.get('id', '<missing>')}"
        require_fields(
            route,
            ["id", "from", "to", "days", "food_cost", "vigor_cost", "danger", "terrain_tags", "encounter_table", "battlefield_tags"],
            label,
            errors,
        )
        if route.get("from") not in location_ids:
            errors.append(f"{label} references unknown from location '{route.get('from')}'")
        if route.get("to") not in location_ids:
            errors.append(f"{label} references unknown to location '{route.get('to')}'")
        if route.get("from") == route.get("to"):
            errors.append(f"{label} cannot connect a location to itself")
        for field, low, high in [("days", 1, 10), ("food_cost", 0, 50), ("vigor_cost", 0, 80), ("danger", 1, 5)]:
            value = route.get(field)
            if not isinstance(value, int) or not low <= value <= high:
                errors.append(f"{label} field '{field}' must be an integer between {low} and {high}")
        if not isinstance(route.get("terrain_tags", []), list):
            errors.append(f"{label} terrain_tags must be a list")
        if not isinstance(route.get("battlefield_tags", []), list):
            errors.append(f"{label} battlefield_tags must be a list")

    if len(location_ids) < 3:
        errors.append("world must contain at least 3 locations")
    if len(route_ids) < 6:
        errors.append("world must contain at least 6 routes")
    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print("World validation failed:")
        for error in found:
            print(f"- {error}")
        raise SystemExit(1)
    print("World validation passed.")
