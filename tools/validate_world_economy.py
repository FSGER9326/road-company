from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def unique(values: list[dict], key: str, label: str, errors: list[str]) -> set[str]:
    seen: set[str] = set()
    for item in values:
        item_id = item.get(key)
        if not item_id:
            errors.append(f"{label} item missing '{key}'")
        elif item_id in seen:
            errors.append(f"{label} duplicate id '{item_id}'")
        else:
            seen.add(item_id)
    return seen


def require(item: dict, fields: list[str], label: str, errors: list[str]) -> None:
    for field in fields:
        if field not in item:
            errors.append(f"{label} missing required field '{field}'")


def int_range(item: dict, field: str, low: int, high: int, label: str, errors: list[str]) -> None:
    value = item.get(field)
    if not isinstance(value, int) or not low <= value <= high:
        errors.append(f"{label} field '{field}' must be an integer between {low} and {high}")


def validate() -> list[str]:
    errors: list[str] = []
    locations = load_json(ROOT / "data/world/locations.json")
    routes = load_json(ROOT / "data/world/routes.json")
    goods = load_json(ROOT / "data/world/trade_goods.json")
    settlements = load_json(ROOT / "data/world/settlement_economy.json")
    route_economy = load_json(ROOT / "data/world/route_economy.json")
    effects = load_json(ROOT / "data/world/settlement_status_effects.json")

    location_ids = {item["id"] for item in locations}
    route_ids = {item["id"] for item in routes}
    effect_ids = unique(effects, "id", "settlement_status_effects", errors)
    unique(goods, "id", "trade_goods", errors)
    settlement_ids = unique(settlements, "settlement_id", "settlement_economy", errors)
    route_economy_ids = unique(route_economy, "route_id", "route_economy", errors)

    for good in goods:
        label = f"trade good {good.get('id', '<missing>')}"
        require(good, ["id", "name", "category", "base_value", "scarcity_weight", "produced_by_tags", "demanded_by_tags"], label, errors)
        if good.get("category") not in {"food", "construction", "material", "luxury", "dangerous", "service"}:
            errors.append(f"{label} category is invalid")
        int_range(good, "base_value", 1, 500, label, errors)
        if not isinstance(good.get("scarcity_weight"), (int, float)) or not 0.1 <= float(good.get("scarcity_weight", 0)) <= 5.0:
            errors.append(f"{label} scarcity_weight must be numeric between 0.1 and 5.0")
        if not isinstance(good.get("produced_by_tags"), list):
            errors.append(f"{label} produced_by_tags must be a list")
        if not isinstance(good.get("demanded_by_tags"), list):
            errors.append(f"{label} demanded_by_tags must be a list")

    for effect in effects:
        label = f"status effect {effect.get('id', '<missing>')}"
        require(effect, ["id", "name", "modifiers", "description"], label, errors)
        if "duration_days" not in effect and "duration_ticks" not in effect:
            errors.append(f"{label} must define duration_days or duration_ticks")
        if "duration_days" in effect:
            int_range(effect, "duration_days", 1, 365, label, errors)
        if "duration_ticks" in effect:
            int_range(effect, "duration_ticks", 1, 52, label, errors)
        if not isinstance(effect.get("modifiers"), dict):
            errors.append(f"{label} modifiers must be an object")

    for settlement in settlements:
        label = f"settlement economy {settlement.get('settlement_id', '<missing>')}"
        require(
            settlement,
            [
                "settlement_id",
                "population",
                "prosperity",
                "security",
                "food_stock",
                "medicine_stock",
                "tools_stock",
                "arms_stock",
                "unrest",
                "trade_access",
                "market_tier",
                "recruitment_pool_quality",
                "status_effects",
            ],
            label,
            errors,
        )
        if settlement.get("settlement_id") not in location_ids:
            errors.append(f"{label} references missing settlement location")
        int_range(settlement, "population", 10, 50000, label, errors)
        for field in ["prosperity", "security", "unrest", "trade_access", "recruitment_pool_quality"]:
            int_range(settlement, field, 0, 100, label, errors)
        for field in ["food_stock", "medicine_stock", "tools_stock", "arms_stock"]:
            int_range(settlement, field, 0, 100000, label, errors)
        int_range(settlement, "market_tier", 1, 5, label, errors)
        if not isinstance(settlement.get("status_effects"), list):
            errors.append(f"{label} status_effects must be a list")
        else:
            for effect_id in settlement["status_effects"]:
                if effect_id not in effect_ids:
                    errors.append(f"{label} references missing status effect '{effect_id}'")

    for route in route_economy:
        label = f"route economy {route.get('route_id', '<missing>')}"
        require(route, ["route_id", "traffic", "danger", "road_quality", "trade_flow", "patrol_presence", "bandit_pressure", "monster_pressure", "blocked"], label, errors)
        if route.get("route_id") not in route_ids:
            errors.append(f"{label} references missing route")
        for field in ["traffic", "danger", "road_quality", "trade_flow", "patrol_presence", "bandit_pressure", "monster_pressure"]:
            int_range(route, field, 0, 100, label, errors)
        if not isinstance(route.get("blocked"), bool):
            errors.append(f"{label} blocked must be a boolean")

    if settlement_ids != location_ids:
        missing = sorted(location_ids - settlement_ids)
        extra = sorted(settlement_ids - location_ids)
        if missing:
            errors.append(f"settlement_economy missing entries for locations: {', '.join(missing)}")
        if extra:
            errors.append(f"settlement_economy has entries for unknown locations: {', '.join(extra)}")
    missing_routes = sorted(route_ids - route_economy_ids)
    if missing_routes:
        errors.append(f"route_economy missing entries for routes: {', '.join(missing_routes)}")

    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print("World economy validation failed:")
        for error in found:
            print(f"- {error}")
        raise SystemExit(1)
    print("World economy validation passed.")
