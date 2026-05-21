from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(rel: str):
    with (ROOT / rel).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def clamp(value: int, low: int, high: int) -> int:
    return min(high, max(low, value))


def market_tier(population: int, prosperity: int) -> int:
    base = 1
    if population >= 3000:
        base = 4
    elif population >= 1200:
        base = 3
    elif population >= 300:
        base = 2
    if prosperity >= 75 and base < 5:
        base += 1
    if prosperity < 25 and base > 1:
        base -= 1
    return clamp(base, 1, 5)


def tick_route(route: dict) -> dict:
    route = copy.deepcopy(route)
    if route["blocked"]:
        route["traffic"] = 0
        route["trade_flow"] = 0
        route["danger"] = clamp(route["danger"] + 2, 0, 100)
        return route
    pressure = route["bandit_pressure"] + route["monster_pressure"]
    safety = route["patrol_presence"] + route["road_quality"]
    traffic_delta = round((safety - pressure - route["danger"]) / 25)
    route["traffic"] = clamp(route["traffic"] + traffic_delta, 0, 100)
    danger_delta = round((pressure - safety) / 35)
    route["danger"] = clamp(route["danger"] + danger_delta, 0, 100)
    route["trade_flow"] = clamp(round((route["traffic"] + route["road_quality"] + route["patrol_presence"] - route["danger"]) / 3), 0, 100)
    return route


def route_trade_delta(routes: list[dict]) -> int:
    if not routes:
        return -2
    average = sum(route["trade_flow"] for route in routes) / len(routes)
    return clamp(round((average - 50) / 15), -4, 4)


def tick_settlement(settlement: dict, connected_routes: list[dict]) -> dict:
    settlement = copy.deepcopy(settlement)
    population = clamp(settlement["population"], 10, 50000)
    weekly_food_need = max(1, int(-(-population // 250)))
    food_before = max(0, settlement["food_stock"])
    shortage = food_before < weekly_food_need * 2
    settlement["food_stock"] = max(0, food_before - weekly_food_need)
    settlement["trade_access"] = clamp(settlement["trade_access"] + route_trade_delta(connected_routes), 0, 100)

    unrest_delta = -1
    if shortage:
        unrest_delta += 8
    if settlement["security"] < 30:
        unrest_delta += 3
    settlement["unrest"] = clamp(settlement["unrest"] + unrest_delta, 0, 100)

    prosperity_delta = 0
    if shortage:
        prosperity_delta -= 5
    if settlement["trade_access"] >= 60:
        prosperity_delta += 2
    elif settlement["trade_access"] < 35:
        prosperity_delta -= 2
    if settlement["security"] >= 55:
        prosperity_delta += 1
    elif settlement["security"] < 30:
        prosperity_delta -= 2
    if settlement["unrest"] > 60:
        prosperity_delta -= 3
    settlement["prosperity"] = clamp(settlement["prosperity"] + prosperity_delta, 0, 100)

    population_delta = 0
    if settlement["prosperity"] >= 70 and settlement["security"] >= 45 and settlement["unrest"] <= 35 and not shortage:
        population_delta = max(1, round(population * 0.002))
    elif shortage or settlement["prosperity"] < 20 or settlement["unrest"] > 80:
        population_delta = -max(1, round(population * 0.003))
    settlement["population"] = clamp(population + population_delta, 10, 50000)
    settlement["market_tier"] = market_tier(settlement["population"], settlement["prosperity"])
    settlement["recruitment_pool_quality"] = clamp(round((settlement["prosperity"] + settlement["security"] - settlement["unrest"] * 0.5) / 2), 0, 100)
    return settlement


class WorldEconomyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settlements = load("data/world/settlement_economy.json")
        self.routes = load("data/world/route_economy.json")

    def test_sufficient_food_does_not_raise_unrest_from_hunger(self) -> None:
        settlement = copy.deepcopy(self.settlements[0])
        settlement["food_stock"] = 500
        before = settlement["unrest"]
        after = tick_settlement(settlement, [])
        self.assertLessEqual(after["unrest"], before)

    def test_food_shortage_raises_unrest_and_lowers_prosperity(self) -> None:
        settlement = copy.deepcopy(self.settlements[0])
        settlement["food_stock"] = 1
        before_unrest = settlement["unrest"]
        before_prosperity = settlement["prosperity"]
        after = tick_settlement(settlement, [])
        self.assertGreater(after["unrest"], before_unrest)
        self.assertLess(after["prosperity"], before_prosperity)

    def test_safe_trade_route_supports_trade_access(self) -> None:
        settlement = copy.deepcopy(self.settlements[1])
        route = {
            "trade_flow": 75,
            "traffic": 80,
            "danger": 10,
            "road_quality": 80,
            "patrol_presence": 60,
            "bandit_pressure": 5,
            "monster_pressure": 0,
            "blocked": False,
        }
        before_trade = settlement["trade_access"]
        before_prosperity = settlement["prosperity"]
        after = tick_settlement(settlement, [tick_route(route)])
        self.assertGreaterEqual(after["trade_access"], before_trade)
        self.assertGreaterEqual(after["prosperity"], before_prosperity)

    def test_dangerous_route_reduces_traffic_or_trade_access(self) -> None:
        route = copy.deepcopy(self.routes[3])
        route["danger"] = 90
        route["traffic"] = 30
        route["bandit_pressure"] = 90
        before_traffic = route["traffic"]
        after_route = tick_route(route)
        self.assertLessEqual(after_route["traffic"], before_traffic)

        settlement = copy.deepcopy(self.settlements[0])
        settlement["trade_access"] = 50
        after_settlement = tick_settlement(settlement, [after_route])
        self.assertLessEqual(after_settlement["trade_access"], 50)

    def test_market_tier_can_increase(self) -> None:
        settlement = copy.deepcopy(self.settlements[0])
        settlement["population"] = 3200
        settlement["prosperity"] = 78
        settlement["security"] = 70
        settlement["unrest"] = 5
        settlement["food_stock"] = 999
        settlement["market_tier"] = 3
        after = tick_settlement(settlement, [{"trade_flow": 80}])
        self.assertGreaterEqual(after["market_tier"], 4)
        self.assertLessEqual(after["market_tier"], 5)

    def test_clamping(self) -> None:
        settlement = copy.deepcopy(self.settlements[0])
        settlement.update({"population": 999999, "prosperity": 999, "security": -5, "unrest": 999, "trade_access": -20, "food_stock": 0})
        after = tick_settlement(settlement, [])
        self.assertTrue(10 <= after["population"] <= 50000)
        self.assertTrue(0 <= after["prosperity"] <= 100)
        self.assertTrue(0 <= after["unrest"] <= 100)
        self.assertTrue(0 <= after["trade_access"] <= 100)
        self.assertTrue(1 <= after["market_tier"] <= 5)

    def test_determinism(self) -> None:
        settlement = copy.deepcopy(self.settlements[0])
        routes = [tick_route(copy.deepcopy(self.routes[0]))]
        first = tick_settlement(settlement, routes)
        second = tick_settlement(copy.deepcopy(self.settlements[0]), [tick_route(copy.deepcopy(self.routes[0]))])
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()
