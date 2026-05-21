from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from contract_generator_core import CONTRACT_TYPES, generate_contracts
from test_route_dynamics import EFFECT_FIELDS
from validate_contract_generator import SETTLEMENT_EFFECT_FIELDS, validate as validate_contract_generator


def load(rel: str):
    with (ROOT / rel).open("r", encoding="utf-8") as handle:
        return json.load(handle)


class ContractGeneratorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.locations = load("data/world/locations.json")
        self.route_links = load("data/world/routes.json")
        self.settlements = load("data/world/settlement_economy.json")
        self.routes = load("data/world/route_economy.json")
        self.factions = load("data/factions/factions.json")
        self.static_contracts = load("data/contracts/contracts.json")
        self.defaults = load("data/contracts/contract_type_defaults.json")

    def generate(self, location: str = "blackford", seed: int = 12345, settlements=None, routes=None) -> list[dict]:
        return generate_contracts(
            location,
            settlements if settlements is not None else self.settlements,
            routes if routes is not None else self.routes,
            self.route_links,
            {},
            self.static_contracts,
            self.locations,
            self.factions,
            self.defaults,
            seed=seed,
        )

    def test_same_seed_same_state_produces_same_contracts(self) -> None:
        first = self.generate("blackford", seed=12345)
        second = self.generate("blackford", seed=12345)
        self.assertEqual(first, second)

    def test_starving_settlement_produces_food_delivery_contract(self) -> None:
        settlements = copy.deepcopy(self.settlements)
        for settlement in settlements:
            if settlement["settlement_id"] == "embermill":
                settlement["food_stock"] = 1
                settlement["medicine_stock"] = 100
        contracts = self.generate("blackford", settlements=settlements)
        self.assertTrue(any(contract["target_location"] == "embermill" and contract["type"] == "escort_caravan" for contract in contracts))

    def test_low_medicine_settlement_produces_deliver_medicine(self) -> None:
        settlements = copy.deepcopy(self.settlements)
        for settlement in settlements:
            if settlement["settlement_id"] == "embermill":
                settlement["medicine_stock"] = 0
                settlement["food_stock"] = 500
        contracts = self.generate("blackford", settlements=settlements)
        self.assertTrue(any(contract["target_location"] == "embermill" and contract["type"] == "deliver_medicine" for contract in contracts))

    def test_dangerous_route_produces_patrol_or_escort_or_recover(self) -> None:
        routes = copy.deepcopy(self.routes)
        for route in routes:
            if route["route_id"] == "blackford_embermill_highroad":
                route["danger"] = 92
                route["bandit_pressure"] = 20
                route["traffic"] = 70
        contracts = self.generate("blackford", routes=routes)
        self.assertTrue(any(contract["target_route"] == "blackford_embermill_highroad" and contract["type"] in {"patrol_route", "escort_caravan", "recover_wagon"} for contract in contracts))

    def test_high_bandit_pressure_produces_hunt_or_bounty(self) -> None:
        routes = copy.deepcopy(self.routes)
        for route in routes:
            if route["route_id"] == "blackford_embermill_highroad":
                route["bandit_pressure"] = 90
                route["danger"] = 75
        contracts = self.generate("blackford", routes=routes)
        self.assertTrue(any(contract["target_route"] == "blackford_embermill_highroad" and contract["type"] in {"hunt_bandits", "bounty_target"} for contract in contracts))

    def test_high_unrest_or_low_security_can_produce_defend_settlement(self) -> None:
        settlements = copy.deepcopy(self.settlements)
        for settlement in settlements:
            if settlement["settlement_id"] == "embermill":
                settlement["security"] = 12
                settlement["unrest"] = 70
                settlement["food_stock"] = 500
                settlement["medicine_stock"] = 100
        routes = copy.deepcopy(self.routes)
        for route in routes:
            route["danger"] = 5
            route["bandit_pressure"] = 0
        contracts = self.generate("blackford", settlements=settlements, routes=routes)
        self.assertTrue(any(contract["target_location"] == "embermill" and contract["type"] == "defend_settlement" for contract in contracts))

    def test_generated_contracts_validate(self) -> None:
        self.assertEqual(validate_contract_generator(), [])

    def test_generated_route_effects_are_route_dynamics_compatible(self) -> None:
        contracts = self.generate("blackford")
        self.assertTrue(contracts)
        for contract in contracts:
            for effects in [contract["route_effects_on_success"], contract["route_effects_on_failure"]]:
                for key in effects:
                    self.assertTrue(key in EFFECT_FIELDS or key == "block_duration_ticks")

    def test_generated_settlement_effects_are_world_economy_compatible(self) -> None:
        contracts = self.generate("blackford")
        self.assertTrue(contracts)
        for contract in contracts:
            for settlement_effects in [contract["settlement_effects_on_success"], contract["settlement_effects_on_failure"]]:
                for effects in settlement_effects.values():
                    for key in effects:
                        self.assertTrue(key in SETTLEMENT_EFFECT_FIELDS or key in {"add_status_effect", "remove_status_effect"})

    def test_different_world_conditions_change_priority(self) -> None:
        base = self.generate("blackford")
        settlements = copy.deepcopy(self.settlements)
        for settlement in settlements:
            if settlement["settlement_id"] == "embermill":
                settlement["food_stock"] = 1
                settlement["medicine_stock"] = 100
        hungry = self.generate("blackford", settlements=settlements)
        self.assertNotEqual([contract["id"] for contract in base], [contract["id"] for contract in hungry])

    def test_stable_settlement_generates_fewer_contracts(self) -> None:
        settlements = copy.deepcopy(self.settlements)
        routes = copy.deepcopy(self.routes)
        for settlement in settlements:
            settlement.update({"food_stock": 900, "medicine_stock": 200, "security": 80, "unrest": 2, "trade_access": 80})
        for route in routes:
            route.update({"danger": 5, "bandit_pressure": 0, "monster_pressure": 0, "traffic": 80, "trade_flow": 80, "blocked": False})
        contracts = self.generate("blackford", settlements=settlements, routes=routes)
        self.assertLessEqual(len(contracts), 1)

    def test_generated_contract_bounds_and_types(self) -> None:
        contracts = self.generate("blackford")
        self.assertTrue(contracts)
        for contract in contracts:
            self.assertIn(contract["type"], CONTRACT_TYPES)
            self.assertTrue(1 <= contract["urgency"] <= 5)
            self.assertTrue(1 <= contract["danger"] <= 10)
            self.assertTrue(50 <= contract["reward_crowns"] <= 5000)
            self.assertTrue(1 <= contract["expires_after_days"] <= 52)


if __name__ == "__main__":
    unittest.main()
