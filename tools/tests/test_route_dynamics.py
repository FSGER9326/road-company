from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from test_world_economy import tick_route, tick_settlement

ROOT = Path(__file__).resolve().parents[2]
EFFECT_FIELDS = {"bandit_pressure", "danger", "monster_pressure", "patrol_presence", "traffic", "trade_flow"}
HISTORY_MAX = 20


def load(rel: str):
    with (ROOT / rel).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def clamp(value: int, low: int = 0, high: int = 100) -> int:
    return min(high, max(low, value))


def recalculate_status(route: dict) -> str:
    successes = sum(1 for item in route.get("route_history", []) if item.get("outcome") == "success")
    if successes >= 6 and route.get("danger", 0) <= 30:
        route["status"] = "secure"
    elif successes >= 3:
        route["status"] = "stabilizing"
    else:
        route["status"] = "normal"
    return route["status"]


def append_history(route: dict, tick: int, contract_id: str, outcome: str, effects: dict) -> None:
    history = route.setdefault("route_history", [])
    history.append({"tick": tick, "contract": contract_id, "outcome": outcome, "effects": copy.deepcopy(effects)})
    while len(history) > HISTORY_MAX:
        history.pop(0)


def apply_contract_effects(contract: dict, route: dict, outcome: str, tick: int = 0) -> dict:
    route = copy.deepcopy(route)
    field = "route_effects_on_success" if outcome == "success" else "route_effects_on_failure"
    effects = contract.get(field, {})
    applied: dict[str, int] = {}
    for key, value in effects.items():
        if key in EFFECT_FIELDS:
            route[key] = clamp(route.get(key, 0) + int(value))
            applied[key] = int(value)
    if outcome == "failure" and "block_duration_ticks" in effects:
        duration = max(1, int(effects["block_duration_ticks"]))
        route["blocked"] = True
        route["blocked_until_tick"] = tick + duration
        applied["block_duration_ticks"] = duration
    append_history(route, tick, contract["id"], outcome, applied)
    recalculate_status(route)
    if route["status"] == "secure":
        route["patrol_presence"] = max(30, route.get("patrol_presence", 0))
    return route


class RouteDynamicsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.contracts = {item["id"]: item for item in load("data/contracts/contracts.json")}
        self.routes = {item["route_id"]: item for item in load("data/world/route_economy.json")}
        self.settlements = {item["settlement_id"]: item for item in load("data/world/settlement_economy.json")}

    def test_escort_success_improves_route(self) -> None:
        contract = self.contracts["escort_embermill"]
        route = self.routes[contract["target_route"]]
        after = apply_contract_effects(contract, route, "success", tick=1)
        self.assertLess(after["bandit_pressure"], route["bandit_pressure"])
        self.assertLess(after["danger"], route["danger"])
        self.assertGreater(after["traffic"], route["traffic"])
        self.assertGreater(after["trade_flow"], route["trade_flow"])
        self.assertEqual(after["route_history"][-1]["outcome"], "success")

    def test_escort_failure_damages_route(self) -> None:
        contract = self.contracts["escort_embermill"]
        route = self.routes[contract["target_route"]]
        after = apply_contract_effects(contract, route, "failure", tick=2)
        self.assertGreater(after["bandit_pressure"], route["bandit_pressure"])
        self.assertGreater(after["danger"], route["danger"])
        self.assertLess(after["traffic"], route["traffic"])
        self.assertLess(after["trade_flow"], route["trade_flow"])
        self.assertTrue(after["blocked"])
        self.assertEqual(after["blocked_until_tick"], 5)

    def test_patrol_success_improves_patrol_presence(self) -> None:
        contract = {
            "id": "patrol_test",
            "target_route": "blackford_embermill_fenway",
            "route_effects_on_success": {"patrol_presence": 20, "danger": -10},
        }
        route = self.routes["blackford_embermill_fenway"]
        after = apply_contract_effects(contract, route, "success", tick=3)
        self.assertGreater(after["patrol_presence"], route["patrol_presence"])
        self.assertLess(after["danger"], route["danger"])

    def test_bandit_hunt_lowers_bandit_pressure(self) -> None:
        contract = self.contracts["hunt_red_sashes"]
        route = self.routes[contract["target_route"]]
        after = apply_contract_effects(contract, route, "success", tick=4)
        self.assertLess(after["bandit_pressure"], route["bandit_pressure"])
        self.assertLess(after["danger"], route["danger"])

    def test_repeated_success_is_clamped_and_deterministic(self) -> None:
        contract = self.contracts["hunt_red_sashes"]
        route = copy.deepcopy(self.routes[contract["target_route"]])
        route["danger"] = 25
        first = copy.deepcopy(route)
        second = copy.deepcopy(route)
        for tick in range(6):
            first = apply_contract_effects(contract, first, "success", tick=tick)
            second = apply_contract_effects(contract, second, "success", tick=tick)
        self.assertEqual(first, second)
        self.assertEqual(first["status"], "secure")
        self.assertTrue(0 <= first["bandit_pressure"] <= 100)
        self.assertTrue(0 <= first["danger"] <= 100)

    def test_route_history_max_entries(self) -> None:
        contract = self.contracts["capture_gravetithe"]
        route = copy.deepcopy(self.routes[contract["target_route"]])
        for tick in range(25):
            route = apply_contract_effects(contract, route, "success", tick=tick)
        self.assertEqual(len(route["route_history"]), HISTORY_MAX)
        self.assertEqual(route["route_history"][0]["tick"], 5)

    def test_modified_route_affects_settlement_tick(self) -> None:
        contract = self.contracts["escort_embermill"]
        route = copy.deepcopy(self.routes[contract["target_route"]])
        route["traffic"] = 40
        route["trade_flow"] = 40
        route["danger"] = 40
        settlement = copy.deepcopy(self.settlements["embermill"])
        settlement["trade_access"] = 58
        before = tick_settlement(copy.deepcopy(settlement), [tick_route(copy.deepcopy(route))])
        improved_route = apply_contract_effects(contract, route, "success", tick=1)
        after = tick_settlement(copy.deepcopy(settlement), [tick_route(improved_route)])
        self.assertGreaterEqual(after["trade_access"], before["trade_access"])
        self.assertGreaterEqual(after["prosperity"], before["prosperity"])

    def test_contract_reference_route_effects_are_valid(self) -> None:
        for contract in self.contracts.values():
            self.assertIn("route_effects_on_success", contract)
            self.assertIn("route_effects_on_failure", contract)
            self.assertIn(contract["target_route"], self.routes)


if __name__ == "__main__":
    unittest.main()
