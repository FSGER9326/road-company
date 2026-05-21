from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from contract_generator_core import generate_contracts
from settlement_factions_core import (
    apply_contract_result,
    apply_weekly_tick,
    dominant_faction,
    faction_tension,
    factions_for_settlement,
    preference_for_contract,
)
from validate_settlement_factions import validate, validate_factions


def load(rel: str):
    with (ROOT / rel).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def by_id(items: list[dict], item_id: str, key: str = "id") -> dict:
    return next(item for item in items if item[key] == item_id)


class SettlementFactionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settlements = load("data/world/settlement_economy.json")
        self.factions = load("data/world/settlement_factions.json")
        self.locations = load("data/world/locations.json")
        self.routes = load("data/world/routes.json")
        self.route_economy = load("data/world/route_economy.json")
        self.static_contracts = load("data/contracts/contracts.json")
        self.defaults = load("data/contracts/contract_type_defaults.json")
        self.external_factions = load("data/factions/factions.json")

    def local(self, settlement_id: str) -> list[dict]:
        return factions_for_settlement(self.factions, settlement_id)

    def test_high_insecurity_increases_militia_and_criminal_influence(self) -> None:
        settlement = copy.deepcopy(by_id(self.settlements, "blackford", "settlement_id"))
        factions = copy.deepcopy(self.factions)
        settlement["security"] = 20
        before_militia = by_id(factions_for_settlement(factions, "blackford"), "blackford_bridge_watch")["influence"]
        before_criminal = by_id(factions_for_settlement(factions, "blackford"), "blackford_gutter_knives")["influence"]
        after = apply_weekly_tick(settlement, factions)
        local = factions_for_settlement(after["factions"], "blackford")
        self.assertEqual(by_id(local, "blackford_bridge_watch")["influence"], before_militia + 3)
        self.assertEqual(by_id(local, "blackford_gutter_knives")["influence"], before_criminal + 1)

    def test_food_shortage_increases_peasant_refugee_influence(self) -> None:
        settlement = copy.deepcopy(by_id(self.settlements, "embermill", "settlement_id"))
        factions = copy.deepcopy(self.factions)
        settlement["food_stock"] = 1
        before = by_id(factions_for_settlement(factions, "embermill"), "embermill_commons")["influence"]
        after = apply_weekly_tick(settlement, factions)
        self.assertEqual(by_id(factions_for_settlement(after["factions"], "embermill"), "embermill_commons")["influence"], before + 3)

    def test_prosperity_increases_merchant_influence(self) -> None:
        settlement = copy.deepcopy(by_id(self.settlements, "saintsfall", "settlement_id"))
        factions = copy.deepcopy(self.factions)
        settlement["prosperity"] = 80
        before = by_id(factions_for_settlement(factions, "saintsfall"), "saintsfall_relic_brokers")["influence"]
        after = apply_weekly_tick(settlement, factions)
        self.assertEqual(by_id(factions_for_settlement(after["factions"], "saintsfall"), "saintsfall_relic_brokers")["influence"], before + 2)

    def test_contract_success_increases_patron_influence_and_attitude(self) -> None:
        local = copy.deepcopy(self.local("embermill"))
        contract = {"type": "escort_caravan", "internal_patron_faction": "embermill_millers_compact"}
        patron_before = copy.deepcopy(by_id(local, "embermill_millers_compact"))
        apply_contract_result("embermill", contract, local, "success")
        patron_after = by_id(local, "embermill_millers_compact")
        self.assertGreater(patron_after["influence"], patron_before["influence"])
        self.assertGreater(patron_after["attitude_to_company"], patron_before["attitude_to_company"])

    def test_rival_attitude_decreases_when_one_faction_is_helped(self) -> None:
        local = copy.deepcopy(self.local("blackford"))
        rival_before = by_id(local, "blackford_gutter_knives")["attitude_to_company"]
        contract = {"type": "patrol_route", "internal_patron_faction": "blackford_gate_wardens"}
        apply_contract_result("blackford", contract, local, "success")
        self.assertLess(by_id(local, "blackford_gutter_knives")["attitude_to_company"], rival_before)

    def test_dominant_faction_calculation_is_deterministic(self) -> None:
        local = copy.deepcopy(self.local("blackford"))
        first = dominant_faction(local)
        second = dominant_faction(copy.deepcopy(local))
        self.assertEqual(first, second)
        self.assertEqual(first["id"], "blackford_gate_wardens")

    def test_faction_tension_uses_rivalry_and_influence_conflict(self) -> None:
        local = copy.deepcopy(self.local("blackford"))
        by_id(local, "blackford_gate_wardens")["influence"] = 50
        by_id(local, "blackford_gutter_knives")["influence"] = 45
        self.assertGreaterEqual(faction_tension(local), 12)

    def test_contract_generator_uses_dominant_faction_preferences(self) -> None:
        factions = copy.deepcopy(self.factions)
        by_id(factions, "blackford_toll_factors")["influence"] = 90
        by_id(factions, "blackford_toll_factors")["attitude_to_company"] = 20
        settlements = copy.deepcopy(self.settlements)
        for settlement in settlements:
            if settlement["settlement_id"] == "blackford":
                settlement["trade_access"] = 5
                settlement["food_stock"] = 900
                settlement["medicine_stock"] = 200
        routes = copy.deepcopy(self.route_economy)
        for route in routes:
            route.update({"danger": 5, "bandit_pressure": 0, "monster_pressure": 0, "blocked": False})
        contracts = generate_contracts(
            "blackford",
            settlements,
            routes,
            self.routes,
            {},
            self.static_contracts,
            self.locations,
            self.external_factions,
            self.defaults,
            seed=12345,
            internal_factions=factions,
        )
        self.assertTrue(contracts)
        self.assertEqual(contracts[0]["internal_patron_faction"], "blackford_toll_factors")
        self.assertIn(contracts[0]["type"], {"escort_caravan", "recover_wagon"})

    def test_validator_passes_current_data(self) -> None:
        self.assertEqual(validate(), [])

    def test_validator_catches_bad_settlement_id(self) -> None:
        bad = copy.deepcopy(self.factions)
        bad[0]["settlement_id"] = "missing_settlement"
        errors = validate_factions(bad, {item["settlement_id"] for item in self.settlements})
        self.assertTrue(any("unknown settlement" in error for error in errors))

    def test_validator_catches_bad_rival_id(self) -> None:
        bad = copy.deepcopy(self.factions)
        bad[0]["rival_faction_ids"] = ["embermill_millers_compact"]
        errors = validate_factions(bad, {item["settlement_id"] for item in self.settlements})
        self.assertTrue(any("not in the same settlement" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
