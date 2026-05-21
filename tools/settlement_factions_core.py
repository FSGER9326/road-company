from __future__ import annotations

import copy
import math
from typing import Any

FACTION_TYPES = {
    "ruling_authority",
    "merchant_guild",
    "militia_command",
    "temple_chapter",
    "criminal_network",
    "peasant_commons",
}
TYPE_PRIORITY = {
    "ruling_authority": 0,
    "merchant_guild": 1,
    "militia_command": 2,
    "temple_chapter": 3,
    "criminal_network": 4,
    "peasant_commons": 5,
}
CONTRACT_TYPES = {
    "escort_caravan",
    "patrol_route",
    "hunt_bandits",
    "recover_wagon",
    "deliver_medicine",
    "defend_settlement",
    "bounty_target",
    "recover_missing_wagon",
    "capture_bounty_target",
}
CONTRACT_TYPE_SHIFTS = {
    "escort_caravan": {"merchant_guild": 5, "criminal_network": -2},
    "patrol_route": {"militia_command": 4, "ruling_authority": 2, "criminal_network": -3},
    "hunt_bandits": {"militia_command": 5, "ruling_authority": 3, "criminal_network": -4},
    "recover_wagon": {"merchant_guild": 5},
    "recover_missing_wagon": {"merchant_guild": 5},
    "deliver_medicine": {"temple_chapter": 4, "peasant_commons": 2},
    "defend_settlement": {"militia_command": 5, "ruling_authority": 3, "criminal_network": -5},
    "bounty_target": {"ruling_authority": 3, "criminal_network": -3},
    "capture_bounty_target": {"ruling_authority": 3, "criminal_network": -3},
}


def clamp(value: int, low: int, high: int) -> int:
    return min(high, max(low, value))


def factions_for_settlement(factions: list[dict[str, Any]], settlement_id: str) -> list[dict[str, Any]]:
    return [item for item in factions if item.get("settlement_id") == settlement_id]


def dominant_faction(factions: list[dict[str, Any]]) -> dict[str, Any]:
    if not factions:
        return {}
    return sorted(factions, key=lambda item: (-int(item.get("influence", 0)), TYPE_PRIORITY.get(item.get("type", ""), 99), item.get("id", "")))[0]


def faction_tension(factions: list[dict[str, Any]]) -> int:
    by_id = {item["id"]: item for item in factions}
    seen: set[tuple[str, str]] = set()
    tension = 0.0
    for faction in factions:
        for rival_id in faction.get("rival_faction_ids", []):
            if rival_id not in by_id:
                continue
            pair = tuple(sorted([faction["id"], rival_id]))
            if pair in seen:
                continue
            seen.add(pair)
            rival = by_id[rival_id]
            if faction.get("influence", 0) > 30 and rival.get("influence", 0) > 30:
                tension += min(faction["influence"], rival["influence"]) * 0.3
    if dominant_faction(factions).get("influence", 0) > 70:
        tension -= 5
    return clamp(round(tension), 0, 100)


def apply_weekly_tick(settlement: dict[str, Any], factions: list[dict[str, Any]], contract_results: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    settlement = copy.deepcopy(settlement)
    factions = copy.deepcopy(factions)
    local = factions_for_settlement(factions, settlement["settlement_id"])
    changes: list[dict[str, Any]] = []
    changes.extend(apply_economy_shifts(settlement, local))
    for result in contract_results or []:
        changes.extend(apply_contract_result(settlement["settlement_id"], result["contract"], local, result.get("outcome", "success")))
    for faction in local:
        decay_attitude(faction)
    dominant = dominant_faction(local)
    tension = faction_tension(local)
    settlement["dominant_internal_faction"] = dominant.get("id", "")
    settlement["faction_tension"] = tension
    settlement["local_policy_tags"] = policy_tags_for_dominant(dominant)
    settlement["active_internal_conflicts"] = active_conflicts(local, tension)
    settlement.setdefault("last_faction_events", [])
    apply_dominant_modifiers(settlement, dominant)
    return {"settlement": settlement, "factions": factions, "faction_changes": changes}


def apply_economy_shifts(settlement: dict[str, Any], local: list[dict[str, Any]]) -> list[dict[str, Any]]:
    changes: list[dict[str, Any]] = []
    if settlement.get("security", 0) < 35:
        changes.extend(shift_type(local, "militia_command", 3, 0, "low_security"))
        changes.extend(shift_type(local, "criminal_network", 1, 0, "low_security"))
    if has_food_shortage(settlement):
        changes.extend(shift_type(local, "peasant_commons", 3, 0, "food_shortage"))
    if settlement.get("prosperity", 0) > 65:
        changes.extend(shift_type(local, "merchant_guild", 2, 0, "high_prosperity"))
    if settlement.get("trade_access", 0) < 30:
        changes.extend(shift_type(local, "merchant_guild", -2, 0, "low_trade_access"))
    if settlement.get("unrest", 0) > 50:
        changes.extend(shift_type(local, "criminal_network", 2, 0, "high_unrest"))
        changes.extend(shift_type(local, "ruling_authority", -2, 0, "high_unrest"))
    if settlement.get("corruption", 0) > 50:
        changes.extend(shift_type(local, "criminal_network", 3, 0, "high_corruption"))
        changes.extend(shift_type(local, "temple_chapter", -2, 0, "high_corruption"))
    return changes


def apply_contract_result(settlement_id: str, contract: dict[str, Any], local: list[dict[str, Any]], outcome: str = "success") -> list[dict[str, Any]]:
    changes: list[dict[str, Any]] = []
    patron = faction_by_id(local, contract.get("internal_patron_faction", "")) or best_faction_for_contract(local, contract.get("type", ""))
    if not patron:
        return changes
    if outcome == "success":
        changes.append(shift(patron, 5, 5, "contract_success_patron"))
        for rival_id in patron.get("rival_faction_ids", []):
            rival = faction_by_id(local, rival_id)
            if rival:
                changes.append(shift(rival, 0, -2, "contract_success_rival"))
        for faction_type, delta in CONTRACT_TYPE_SHIFTS.get(contract.get("type", ""), {}).items():
            changes.extend(shift_type(local, faction_type, delta, 0, "contract_type_shift"))
    else:
        changes.append(shift(patron, -5, -5, "contract_failure_patron"))
    return changes


def preference_for_contract(settlement_id: str, contract_type: str, factions: list[dict[str, Any]]) -> dict[str, Any]:
    dominant = dominant_faction(factions_for_settlement(factions, settlement_id))
    if not dominant:
        return {"score_multiplier": 1.0, "reward_multiplier": 1.0, "internal_patron_faction": ""}
    score_multiplier = 1.0
    if contract_type in dominant.get("supported_contract_types", []):
        score_multiplier = 1.3
    elif contract_type in dominant.get("opposed_contract_types", []):
        score_multiplier = 0.7
    reward_multiplier = max(0.5, min(1.5, 1.0 + dominant.get("attitude_to_company", 0) / 200.0))
    return {"score_multiplier": score_multiplier, "reward_multiplier": reward_multiplier, "internal_patron_faction": dominant["id"]}


def shift_type(local: list[dict[str, Any]], faction_type: str, influence_delta: int, attitude_delta: int, reason: str) -> list[dict[str, Any]]:
    return [shift(faction, influence_delta, attitude_delta, reason) for faction in local if faction.get("type") == faction_type]


def shift(faction: dict[str, Any], influence_delta: int, attitude_delta: int, reason: str) -> dict[str, Any]:
    before_influence = int(faction.get("influence", 0))
    before_attitude = int(faction.get("attitude_to_company", 0))
    faction["influence"] = clamp(before_influence + influence_delta, 0, 100)
    faction["attitude_to_company"] = clamp(before_attitude + attitude_delta, -100, 100)
    return {
        "faction_id": faction["id"],
        "reason": reason,
        "influence_delta": faction["influence"] - before_influence,
        "attitude_delta": faction["attitude_to_company"] - before_attitude,
    }


def decay_attitude(faction: dict[str, Any]) -> None:
    attitude = int(faction.get("attitude_to_company", 0))
    if attitude > 0:
        attitude = max(0, attitude - 2)
    elif attitude < 0:
        attitude = min(0, attitude + 2)
    faction["attitude_to_company"] = attitude


def has_food_shortage(settlement: dict[str, Any]) -> bool:
    weekly_need = max(1, math.ceil(int(settlement.get("population", 10)) / 250.0))
    return int(settlement.get("food_stock", 0)) < weekly_need * 2


def apply_dominant_modifiers(settlement: dict[str, Any], dominant: dict[str, Any]) -> None:
    for key, delta in dominant.get("economy_modifiers", {}).items():
        if key in {"prosperity", "security", "unrest", "trade_access", "corruption"}:
            settlement[key] = clamp(int(settlement.get(key, 0)) + int(delta), 0, 100)


def policy_tags_for_dominant(dominant: dict[str, Any]) -> list[str]:
    return {
        "ruling_authority": ["curfew_ready"],
        "merchant_guild": ["market_open"],
        "militia_command": ["raised_patrols"],
        "temple_chapter": ["sanctuary_watch"],
        "criminal_network": ["shadow_tolls"],
        "peasant_commons": ["bread_claims"],
    }.get(dominant.get("type", ""), [])


def active_conflicts(local: list[dict[str, Any]], tension: int) -> list[str]:
    if tension < 30:
        return []
    dominant = dominant_faction(local)
    conflicts = []
    for rival_id in dominant.get("rival_faction_ids", []):
        rival = faction_by_id(local, rival_id)
        if rival and rival.get("influence", 0) > 30:
            conflicts.append(f"{dominant['id']}_vs_{rival_id}")
    return conflicts


def best_faction_for_contract(local: list[dict[str, Any]], contract_type: str) -> dict[str, Any]:
    if not local:
        return {}
    return sorted(
        local,
        key=lambda faction: -(
            int(faction.get("influence", 0))
            + (20 if contract_type in faction.get("supported_contract_types", []) else 0)
            - (20 if contract_type in faction.get("opposed_contract_types", []) else 0)
        ),
    )[0]


def faction_by_id(local: list[dict[str, Any]], faction_id: str) -> dict[str, Any]:
    return next((faction for faction in local if faction.get("id") == faction_id), {})
