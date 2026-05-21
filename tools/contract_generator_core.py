from __future__ import annotations

import copy
import math
from typing import Any

CONTRACT_TYPES = {
    "escort_caravan",
    "patrol_route",
    "hunt_bandits",
    "recover_wagon",
    "deliver_medicine",
    "defend_settlement",
    "bounty_target",
}


def clamp(value: int, low: int, high: int) -> int:
    return min(high, max(low, value))


def generate_contracts(
    current_location: str,
    settlement_economies: list[dict[str, Any]],
    route_economies: list[dict[str, Any]],
    route_links: list[dict[str, Any]],
    faction_reputation: dict[str, int] | None,
    existing_contracts: list[dict[str, Any]],
    locations: list[dict[str, Any]],
    factions: list[dict[str, Any]],
    defaults: list[dict[str, Any]],
    seed: int = 12345,
    tick: int = 0,
) -> list[dict[str, Any]]:
    generator = ContractGenerator(defaults, seed)
    return generator.generate_contracts(
        current_location,
        settlement_economies,
        route_economies,
        route_links,
        faction_reputation or {},
        existing_contracts,
        locations,
        factions,
        tick,
    )


class ContractGenerator:
    def __init__(self, defaults: list[dict[str, Any]], seed: int = 12345) -> None:
        self.defaults = copy.deepcopy(defaults)
        self.defaults_by_type = {item.get("type", ""): item for item in self.defaults}
        self.seed = seed

    def generate_contracts(
        self,
        current_location: str,
        settlement_economies: list[dict[str, Any]],
        route_economies: list[dict[str, Any]],
        route_links: list[dict[str, Any]],
        faction_reputation: dict[str, int],
        existing_contracts: list[dict[str, Any]],
        locations: list[dict[str, Any]],
        factions: list[dict[str, Any]],
        tick: int = 0,
    ) -> list[dict[str, Any]]:
        current_settlement = self._settlement_by_id(settlement_economies, current_location)
        if not current_settlement:
            return []

        connected_routes = self._connected_routes(current_location, route_economies, route_links)
        settlement_candidates = [current_settlement]
        for route in connected_routes:
            other_id = self._other_end(self._route_link(route_links, route.get("route_id", "")), current_location)
            other_settlement = self._settlement_by_id(settlement_economies, other_id)
            if other_settlement and other_settlement not in settlement_candidates:
                settlement_candidates.append(other_settlement)

        candidates: list[dict[str, Any]] = []
        for settlement in settlement_candidates:
            candidates.extend(self._settlement_candidates(current_location, settlement, connected_routes, route_links))
        for route in connected_routes:
            candidates.extend(self._route_candidates(current_location, route, route_links))

        filtered = [
            candidate
            for candidate in candidates
            if float(candidate.get("score", 0.0)) > 0.0 and not self._duplicates_existing(candidate, existing_contracts)
        ]
        filtered.sort(key=lambda item: (-float(item.get("score", 0.0)), str(item.get("type", ""))))

        pressure = self._pressure_level(current_settlement, connected_routes)
        limit = 3 if pressure >= 4 else 2 if pressure >= 2 else 1
        generated: list[dict[str, Any]] = []
        used_keys: set[tuple[str, str, str]] = set()
        for candidate in filtered:
            if len(generated) >= limit:
                break
            key = (
                str(candidate.get("type", "")),
                str(candidate.get("target_location", "")),
                str(candidate.get("target_route", "")),
            )
            if key in used_keys:
                continue
            used_keys.add(key)
            generated.append(self._build_contract(candidate, len(generated) + 1, tick, locations, route_links))
        return generated

    def _settlement_candidates(
        self,
        current_location: str,
        settlement: dict[str, Any],
        connected_routes: list[dict[str, Any]],
        route_links: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        candidates: list[dict[str, Any]] = []
        population = int(settlement.get("population", 10))
        weekly_food_need = max(1, math.ceil(population / 250.0))
        food_weeks = int(settlement.get("food_stock", 0)) / weekly_food_need
        medicine_need = max(1.0, population / 400.0)
        medicine_ratio = float(settlement.get("medicine_stock", 0)) / medicine_need
        target_id = str(settlement.get("settlement_id", ""))
        best_route = self._best_route_for_settlement(current_location, target_id, connected_routes, route_links)

        if food_weeks < 2.0:
            candidates.append(
                self._candidate(
                    "escort_caravan",
                    current_location,
                    target_id,
                    best_route,
                    30.0 + (2.0 - food_weeks) * 15.0,
                    f"{target_id} food stores are below two weeks",
                    {"food_weeks": round(food_weeks, 2), "food_stock": settlement.get("food_stock", 0)},
                )
            )
        if medicine_ratio < 1.0:
            candidates.append(
                self._candidate(
                    "deliver_medicine",
                    current_location,
                    target_id,
                    best_route,
                    30.0 + (1.0 - medicine_ratio) * 25.0,
                    f"{target_id} medicine stock is below need",
                    {"medicine_ratio": round(medicine_ratio, 2), "medicine_stock": settlement.get("medicine_stock", 0)},
                )
            )
        if int(settlement.get("trade_access", 0)) < 30:
            score = 18.0 + float(30 - int(settlement.get("trade_access", 0)))
            candidates.append(
                self._candidate(
                    "escort_caravan",
                    current_location,
                    target_id,
                    best_route,
                    score,
                    f"{target_id} trade access is low",
                    {"trade_access": settlement.get("trade_access", 0)},
                )
            )
            candidates.append(
                self._candidate(
                    "recover_wagon",
                    current_location,
                    target_id,
                    best_route,
                    score - 3.0,
                    f"{target_id} trade access points to missing cargo",
                    {"trade_access": settlement.get("trade_access", 0)},
                )
            )
        if int(settlement.get("security", 0)) < 35:
            candidates.append(
                self._candidate(
                    "defend_settlement",
                    current_location,
                    target_id,
                    best_route,
                    25.0 + float(35 - int(settlement.get("security", 0))),
                    f"{target_id} security is low",
                    {"security": settlement.get("security", 0)},
                )
            )
        if int(settlement.get("unrest", 0)) > 50:
            candidates.append(
                self._candidate(
                    "bounty_target",
                    current_location,
                    target_id,
                    best_route,
                    20.0 + float(int(settlement.get("unrest", 0)) - 50),
                    f"{target_id} unrest is high",
                    {"unrest": settlement.get("unrest", 0)},
                )
            )
        return candidates

    def _route_candidates(
        self,
        current_location: str,
        route: dict[str, Any],
        route_links: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        candidates: list[dict[str, Any]] = []
        route_id = str(route.get("route_id", ""))
        link = self._route_link(route_links, route_id)
        target_id = self._other_end(link, current_location)
        danger = int(route.get("danger", 0))
        bandits = int(route.get("bandit_pressure", 0))

        if danger > 40:
            candidates.append(self._candidate("patrol_route", current_location, target_id, route, 25.0 + danger - 40, f"{route_id} danger is high", {"route.danger": danger}))
            candidates.append(self._candidate("escort_caravan", current_location, target_id, route, 15.0 + (danger - 40) * 0.5, f"{route_id} needs guarded caravans", {"route.danger": danger}))
        if bool(route.get("blocked", False)):
            candidates.append(self._candidate("patrol_route", current_location, target_id, route, 45.0, f"{route_id} is blocked", {"route.blocked": True}))
        if bandits > 40:
            candidates.append(self._candidate("patrol_route", current_location, target_id, route, 25.0 + bandits - 40, f"{route_id} bandit pressure is high", {"route.bandit_pressure": bandits}))
        if bandits > 55:
            candidates.append(self._candidate("hunt_bandits", current_location, target_id, route, 35.0 + bandits - 55, f"{route_id} bandits are organized", {"route.bandit_pressure": bandits}))
        else:
            candidates.append(self._candidate("hunt_bandits", current_location, target_id, route, max(0.0, float(bandits - 40)), f"{route_id} bandits are active", {"route.bandit_pressure": bandits}))
        if int(route.get("traffic", 0)) > 30 and danger > 50:
            candidates.append(self._candidate("recover_wagon", current_location, target_id, route, 20.0 + danger - 50, f"{route_id} has traffic and frequent losses", {"route.traffic": route.get("traffic", 0), "route.danger": danger}))
        if int(route.get("monster_pressure", 0)) > 30:
            candidates.append(self._candidate("defend_settlement", current_location, target_id, route, 20.0 + int(route.get("monster_pressure", 0)) - 30, f"{route_id} has monster pressure near settlements", {"route.monster_pressure": route.get("monster_pressure", 0)}))
        return candidates

    def _candidate(
        self,
        contract_type: str,
        origin: str,
        target: str,
        route: dict[str, Any],
        score: float,
        reason: str,
        trigger_fields: dict[str, Any],
    ) -> dict[str, Any]:
        return {
            "type": contract_type,
            "origin_location": origin,
            "target_location": target or origin,
            "target_route": route.get("route_id", ""),
            "route": route,
            "score": score + self._deterministic_jitter(contract_type, origin, target, str(route.get("route_id", ""))) / 100.0,
            "reason": reason,
            "trigger_fields": trigger_fields,
        }

    def _build_contract(
        self,
        candidate: dict[str, Any],
        index: int,
        tick: int,
        locations: list[dict[str, Any]],
        route_links: list[dict[str, Any]],
    ) -> dict[str, Any]:
        contract_type = str(candidate.get("type", ""))
        defaults = self.defaults_by_type.get(contract_type, {})
        origin_id = str(candidate.get("origin_location", ""))
        target_id = str(candidate.get("target_location", origin_id))
        route = candidate.get("route", {})
        target_location = self._location_by_id(locations, target_id)
        origin_location = self._location_by_id(locations, origin_id)
        route_days = max(1, int(self._route_link(route_links, route.get("route_id", "")).get("days", 2)))
        urgency = clamp(math.ceil(float(candidate.get("score", 0.0)) / 20.0), 1, 5)
        danger = self._calculate_danger(candidate, route)
        reward_crowns = self._calculate_reward(int(defaults.get("base_crowns", 250)), danger, urgency, route_days)
        reward_renown = clamp(round(float(defaults.get("base_renown", 8)) * (0.8 + urgency * 0.05) * (0.8 + route_days * 0.05)), 2, 50)
        patron_faction = self._pick_patron_faction(target_location, origin_location)
        route_success = copy.deepcopy(defaults.get("route_effects_success", {}))
        route_failure = copy.deepcopy(defaults.get("route_effects_failure", {}))
        settlement_success = {target_id: copy.deepcopy(defaults.get("settlement_effects_success", {}))}
        settlement_failure = {target_id: copy.deepcopy(defaults.get("settlement_effects_failure", {}))}
        target_name = target_location.get("name", target_id)
        route_name = str(route.get("route_id", "local roads")).replace("_", " ")
        format_vars = {"target_name": target_name, "route_name": route_name}

        return {
            "id": f"{contract_type}_{origin_id}_{target_id}_{index:03d}",
            "title": str(defaults.get("title_template", contract_type)).format(**format_vars),
            "type": contract_type,
            "patron_faction": patron_faction,
            "origin_location": origin_id,
            "target_location": target_id,
            "target_route": route.get("route_id", ""),
            "urgency": urgency,
            "danger": danger,
            "reward_crowns": reward_crowns,
            "reward_renown": reward_renown,
            "description": str(defaults.get("description_template", "")).format(**format_vars),
            "success_text": str(defaults.get("success_template", "")).format(**format_vars),
            "failure_text": str(defaults.get("failure_template", "")).format(**format_vars),
            "encounter_id": defaults.get("encounter_id", "road_raiders"),
            "encounter_tags": [contract_type],
            "required_cargo_or_objective": defaults.get("required_objective", ""),
            "faction_effects": {patron_faction: max(2, int(defaults.get("base_renown", 8) / 2))},
            "failure_faction_effects": {patron_faction: -max(2, int(defaults.get("base_renown", 8) / 2))},
            "route_effects_on_success": route_success,
            "route_effects_on_failure": route_failure,
            "settlement_effects_on_success": settlement_success,
            "settlement_effects_on_failure": settlement_failure,
            "success_effects": {"route": route_success, "settlement": settlement_success},
            "failure_effects": {"route": route_failure, "settlement": settlement_failure},
            "route_effects": {"success": route_success, "failure": route_failure},
            "settlement_effects": {"success": settlement_success, "failure": settlement_failure},
            "generated_from": {
                "world_state_reason": candidate.get("reason", ""),
                "trigger_fields": candidate.get("trigger_fields", {}),
                "seed_offset": self._deterministic_jitter(contract_type, origin_id, target_id, str(route.get("route_id", ""))),
                "tick": tick,
            },
            "expires_after_days": clamp(max(3, round(urgency * 2.0 - danger * 0.5)), 1, 52),
            "expires_after_ticks": clamp(max(3, round(urgency * 2.0 - danger * 0.5)), 1, 52),
            "seed": self.seed,
        }

    def _pressure_level(self, settlement: dict[str, Any], connected_routes: list[dict[str, Any]]) -> int:
        pressure = 0
        population = int(settlement.get("population", 10))
        weekly_food_need = max(1, math.ceil(population / 250.0))
        if int(settlement.get("food_stock", 0)) < weekly_food_need * 2:
            pressure += 1
        if float(settlement.get("medicine_stock", 0)) < max(1.0, population / 400.0):
            pressure += 1
        if int(settlement.get("security", 0)) < 35 or int(settlement.get("unrest", 0)) > 50:
            pressure += 1
        for route in connected_routes:
            if int(route.get("danger", 0)) > 40 or int(route.get("bandit_pressure", 0)) > 40 or bool(route.get("blocked", False)):
                pressure += 1
        return pressure

    def _calculate_danger(self, candidate: dict[str, Any], route: dict[str, Any]) -> int:
        if route:
            return clamp(round(float(route.get("danger", 0)) * 0.08 + float(route.get("bandit_pressure", 0)) * 0.04), 1, 10)
        trigger_fields = candidate.get("trigger_fields", {})
        security = int(trigger_fields.get("security", 50))
        unrest = int(trigger_fields.get("unrest", 0))
        return clamp(round((100.0 - security + unrest) / 20.0), 1, 10)

    def _calculate_reward(self, base: int, danger: int, urgency: int, route_days: int) -> int:
        value = float(base)
        value *= 0.8 + danger * 0.05
        value *= 0.8 + urgency * 0.05
        value *= 0.8 + route_days * 0.05
        return clamp(round(value), 50, 5000)

    def _pick_patron_faction(self, target_location: dict[str, Any], origin_location: dict[str, Any]) -> str:
        influence = target_location.get("faction_influence", {}) or origin_location.get("faction_influence", {})
        if not influence:
            return "ashen_crown"
        return max(influence.items(), key=lambda item: int(item[1]))[0]

    def _duplicates_existing(self, candidate: dict[str, Any], existing_contracts: list[dict[str, Any]]) -> bool:
        for contract in existing_contracts:
            if (
                contract.get("type") == candidate.get("type")
                and contract.get("target_route", "") == candidate.get("target_route", "")
                and contract.get("target_location", "") == candidate.get("target_location", "")
            ):
                return True
        return False

    def _connected_routes(self, location_id: str, route_economies: list[dict[str, Any]], route_links: list[dict[str, Any]]) -> list[dict[str, Any]]:
        route_ids = {route.get("id", "") for route in route_links if route.get("from") == location_id or route.get("to") == location_id}
        return [route for route in route_economies if route.get("route_id", "") in route_ids]

    def _best_route_for_settlement(self, current_location: str, settlement_id: str, connected_routes: list[dict[str, Any]], route_links: list[dict[str, Any]]) -> dict[str, Any]:
        best: dict[str, Any] = {}
        best_score = -999
        for route in connected_routes:
            link = self._route_link(route_links, route.get("route_id", ""))
            if settlement_id != current_location and self._other_end(link, current_location) != settlement_id:
                continue
            score = int(route.get("danger", 0)) + int(route.get("bandit_pressure", 0)) - int(route.get("traffic", 0))
            if score > best_score:
                best = route
                best_score = score
        return best

    def _settlement_by_id(self, settlements: list[dict[str, Any]], settlement_id: str) -> dict[str, Any]:
        return next((item for item in settlements if item.get("settlement_id") == settlement_id), {})

    def _location_by_id(self, locations: list[dict[str, Any]], location_id: str) -> dict[str, Any]:
        return next((item for item in locations if item.get("id") == location_id), {"id": location_id, "name": location_id, "faction_influence": {"ashen_crown": 1}})

    def _route_link(self, route_links: list[dict[str, Any]], route_id: str) -> dict[str, Any]:
        return next((item for item in route_links if item.get("id") == route_id), {})

    def _other_end(self, route: dict[str, Any], location_id: str) -> str:
        if route.get("from") == location_id:
            return str(route.get("to", ""))
        if route.get("to") == location_id:
            return str(route.get("from", ""))
        return location_id

    def _deterministic_jitter(self, contract_type: str, origin: str, target: str, route_id: str) -> int:
        text = f"{self.seed}|{contract_type}|{origin}|{target}|{route_id}"
        value = 0
        for index, char in enumerate(text):
            value = (value + ord(char) * (index + 17)) % 97
        return value
