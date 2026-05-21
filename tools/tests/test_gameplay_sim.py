from __future__ import annotations

import copy
import json
import random
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(rel: str):
    with (ROOT / rel).open("r", encoding="utf-8") as handle:
        return json.load(handle)


class SimCompany:
    def __init__(self) -> None:
        data = copy.deepcopy(load("data/company/company_start.json"))
        self.name = data["company_name"]
        self.current_location = data["current_location"]
        self.crowns = data["crowns"]
        self.food = data["food"]
        self.tools = data["tools"]
        self.medicine = data["medicine"]
        self.ammunition = data["ammunition"]
        self.morale = data["morale"]
        self.vigor = data["vigor"]
        self.renown = data["renown"]
        self.roster = data["roster"]
        self.graveyard = []
        self.faction_reputation = data["faction_reputation"]
        self.active_contract: dict = {}

    def apply_route_cost(self, route: dict) -> None:
        self.food = max(0, self.food - route["food_cost"])
        self.vigor = max(0, self.vigor - route["vigor_cost"])
        if route["danger"] >= 4:
            self.morale = max(0, self.morale - 2)

    def accept(self, contract: dict) -> None:
        self.active_contract = copy.deepcopy(contract)

    def complete_contract(self) -> None:
        contract = self.active_contract
        self.crowns += contract["reward_crowns"]
        self.renown += contract["reward_renown"]
        for faction_id, value in contract["faction_effects"].items():
            self.faction_reputation[faction_id] += value
        self.active_contract = {}

    def fail_contract(self) -> None:
        contract = self.active_contract
        for faction_id, value in contract.get("failure_faction_effects", {}).items():
            self.faction_reputation[faction_id] += value
        self.active_contract = {}

    def rest(self) -> None:
        self.food -= 2
        self.vigor = min(100, self.vigor + 22)
        self.morale = min(100, self.morale + 4)

    def repair(self) -> None:
        self.tools -= 2
        for fighter in self.roster:
            fighter["armor_body"] += 12
            fighter["armor_head"] += 6

    def treat(self) -> None:
        self.medicine -= 1
        for fighter in self.roster:
            fighter["hp"] = min(fighter["max_hp"], fighter["hp"] + 10)
            if fighter["injuries"]:
                fighter["injuries"].pop(0)


def by_id(items: list[dict], item_id: str) -> dict:
    return next(item for item in items if item["id"] == item_id)


def connected(location: str, route: dict) -> bool:
    return route["from"] == location or route["to"] == location


def destination(location: str, route: dict) -> str:
    if route["from"] == location:
        return route["to"]
    if route["to"] == location:
        return route["from"]
    return ""


def scout_score(company: SimCompany) -> int:
    score = 0
    for fighter in company.roster:
        if "sharp_eyes" in fighter["traits"]:
            score += 1
        if fighter["background"] in {"ditch poacher", "debt runner"}:
            score += 1
    return score


def travel_context(company: SimCompany, route: dict, seed: int = 12345) -> dict:
    rng = random.Random(seed)
    scouts = scout_score(company)
    threshold = max(0, min(95, route["danger"] * 12 - scouts * 10))
    roll = rng.randint(1, 100)
    contract = company.active_contract
    dest = destination(company.current_location, route)
    contract_on_route = bool(contract) and (contract.get("target_route") == route["id"] or contract.get("target_location") == dest)
    return {
        "destination": dest,
        "ambush_roll": roll,
        "ambush_threshold": threshold,
        "ambush": route["danger"] >= 4 or company.vigor < 40 or scouts <= 0 or roll <= threshold,
        "low_vigor": company.vigor < 40,
        "escort_objective": contract_on_route and contract.get("type") == "escort_caravan",
        "terrain_tags": route["terrain_tags"],
    }


def apply_damage(defender: dict, damage: int, armor_multiplier: float = 1.0) -> dict:
    armor_before = defender["armor_body"]
    armor_damage = min(armor_before, int(damage * armor_multiplier))
    defender["armor_body"] = max(0, armor_before - armor_damage)
    hp_damage = max(0, damage - armor_before) if armor_before > 0 else damage
    defender["hp"] = max(0, defender["hp"] - hp_damage)
    if defender["hp"] <= 0:
        defender["alive"] = False
    return {"armor_damage": armor_damage, "hp_damage": hp_damage, "dead": not defender.get("alive", True)}


def morale_step(unit: dict) -> None:
    if unit["morale_state"] == "steady":
        unit["morale_state"] = "wavering"
    elif unit["morale_state"] == "wavering":
        unit["morale_state"] = "breaking"


class GameplaySimulationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.locations = load("data/world/locations.json")
        self.routes = load("data/world/routes.json")
        self.contracts = load("data/contracts/contracts.json")
        self.weapons = load("data/combat/weapons.json")

    def test_road_travel_connected_and_costs(self) -> None:
        company = SimCompany()
        route = by_id(self.routes, "blackford_embermill_highroad")
        self.assertTrue(connected(company.current_location, route))
        before_food, before_vigor = company.food, company.vigor
        company.apply_route_cost(route)
        company.current_location = destination("blackford", route)
        self.assertEqual(company.current_location, "embermill")
        self.assertEqual(company.food, before_food - route["food_cost"])
        self.assertEqual(company.vigor, before_vigor - route["vigor_cost"])
        disconnected = by_id(self.routes, "embermill_saintsfall_pilgrim")
        self.assertFalse(connected("blackford", disconnected))

    def test_scouts_reduce_ambush_threshold(self) -> None:
        company = SimCompany()
        route = by_id(self.routes, "blackford_embermill_highroad")
        with_scouts = travel_context(company, route, 12345)
        for fighter in company.roster:
            fighter["traits"] = []
            fighter["background"] = "untrained hand"
        without_scouts = travel_context(company, route, 12345)
        self.assertLess(with_scouts["ambush_threshold"], without_scouts["ambush_threshold"])
        self.assertEqual(with_scouts["ambush_roll"], without_scouts["ambush_roll"])

    def test_contract_accept_complete_and_escort_failure(self) -> None:
        company = SimCompany()
        contract = by_id(self.contracts, "escort_embermill")
        company.accept(contract)
        self.assertEqual(company.active_contract["id"], "escort_embermill")
        before_crowns, before_renown = company.crowns, company.renown
        company.complete_contract()
        self.assertEqual(company.crowns, before_crowns + contract["reward_crowns"])
        self.assertEqual(company.renown, before_renown + contract["reward_renown"])
        self.assertEqual(company.faction_reputation["millers_compact"], 8)

        company = SimCompany()
        company.accept(contract)
        before_crowns = company.crowns
        company.fail_contract()
        self.assertEqual(company.crowns, before_crowns)
        self.assertEqual(company.faction_reputation["millers_compact"], -10)

    def test_contract_references_are_valid(self) -> None:
        location_ids = {item["id"] for item in self.locations}
        route_ids = {item["id"] for item in self.routes}
        faction_ids = {item["id"] for item in load("data/factions/factions.json")}
        encounter_ids = {item["id"] for item in load("data/combat/encounters.json")}
        for contract in self.contracts:
            self.assertIn(contract["origin_location"], location_ids)
            self.assertIn(contract["patron_faction"], faction_ids)
            self.assertIn(contract["target_route"], route_ids)
            self.assertIn(contract["target_location"], location_ids)
            self.assertIn(contract["encounter_id"], encounter_ids)

    def test_combat_ap_fatigue_armor_death_and_morale(self) -> None:
        attacker = copy.deepcopy(SimCompany().roster[0])
        defender = copy.deepcopy(SimCompany().roster[1])
        attacker["ap"] = 9
        attacker["q"], attacker["r"] = 1, 1
        defender["alive"] = True
        weapon = by_id(self.weapons, attacker["weapon_id"])
        attacker["q"] += 1
        attacker["ap"] -= 3
        attacker["fatigue"] += 3
        self.assertEqual(attacker["ap"], 6)
        self.assertEqual(attacker["fatigue"], 3)
        attacker["ap"] -= weapon["ap_cost"]
        attacker["fatigue"] += weapon["fatigue_cost"]
        result = apply_damage(defender, 20, weapon["armor_damage"])
        self.assertGreater(result["armor_damage"], 0)
        self.assertEqual(result["hp_damage"], 0)
        self.assertEqual(attacker["ap"], 2)
        self.assertGreater(attacker["fatigue"], 3)

        defender["armor_body"] = 0
        kill = apply_damage(defender, 999, 1.0)
        self.assertTrue(kill["dead"])
        morale_step(attacker)
        self.assertEqual(attacker["morale_state"], "wavering")

    def test_travel_to_combat_consequences(self) -> None:
        company = SimCompany()
        company.vigor = 35
        contract = by_id(self.contracts, "escort_embermill")
        company.accept(contract)
        route = by_id(self.routes, contract["target_route"])
        context = travel_context(company, route, 12345)
        self.assertTrue(context["low_vigor"])
        self.assertTrue(context["escort_objective"])
        self.assertIn("road", context["terrain_tags"])

        forest_route = by_id(self.routes, "blackford_saintsfall_oldwood")
        forest_context = travel_context(company, forest_route, 12345)
        self.assertTrue(forest_context["ambush"])
        self.assertIn("forest", forest_context["terrain_tags"])

    def test_camp_actions(self) -> None:
        company = SimCompany()
        company.vigor = 30
        company.morale = 40
        company.roster[0]["hp"] -= 20
        company.roster[0]["injuries"] = ["cut arm"]
        food, tools, medicine = company.food, company.tools, company.medicine
        company.rest()
        self.assertEqual(company.food, food - 2)
        self.assertGreater(company.vigor, 30)
        self.assertGreater(company.morale, 40)
        company.repair()
        self.assertEqual(company.tools, tools - 2)
        company.treat()
        self.assertEqual(company.medicine, medicine - 1)
        self.assertEqual(company.roster[0]["injuries"], [])

    def test_seed_reproducibility(self) -> None:
        company = SimCompany()
        route = by_id(self.routes, "blackford_embermill_highroad")
        first = travel_context(company, route, 12345)
        second = travel_context(company, route, 12345)
        third = travel_context(company, route, 777)
        self.assertEqual(first, second)
        self.assertNotEqual(first["ambush_roll"], third["ambush_roll"])


if __name__ == "__main__":
    unittest.main()
