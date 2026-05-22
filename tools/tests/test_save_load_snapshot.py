from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from save_load_core import SCHEMA_VERSION, build_snapshot, load_snapshot_text, normalize_snapshot, round_trip, validate_snapshot


def load(rel: str):
    with (ROOT / rel).open("r", encoding="utf-8") as handle:
        return json.load(handle)


class SaveLoadSnapshotTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settlements = load("data/world/settlement_economy.json")
        self.routes = load("data/world/route_economy.json")
        self.factions = load("data/world/settlement_factions.json")
        self.company = {
            "company_name": "Ash Road Company",
            "current_location": "blackford",
            "resources": {
                "crowns": 140,
                "food": 18,
                "tools": 7,
                "medicine": 4,
                "ammunition": 12,
                "morale": 55,
                "vigor": 64,
                "renown": 1,
            },
            "roster": [{"id": "captain", "hp": 42, "fatigue": 3}],
            "graveyard": [],
            "faction_reputation": {"ashen_crown": 2},
            "active_contract": {},
        }

    def snapshot(self) -> dict:
        return build_snapshot(
            game_day=9,
            current_location="blackford",
            company=self.company,
            settlement_economy=self.settlements,
            route_economy=self.routes,
            settlement_factions=self.factions,
            active_contract={},
            contract_board=[{"id": "generated_test", "type": "escort_caravan"}],
            rumors=[{"text": "Roads are tense.", "urgency": 3, "expires": 12}],
            memory=[{"tick": 8, "category": "event", "title": "A hard bargain", "summary": "The town remembers."}],
            active_events=[{"tick": 8, "event_id": "food_shortage"}],
            rng_seed=12345,
            saved_at_unix_time=1_700_000_000,
        )

    def test_minimal_valid_snapshot_validates(self) -> None:
        snapshot = build_snapshot(game_day=0, current_location="blackford", company=self.company)
        self.assertEqual(validate_snapshot(snapshot), [])
        self.assertEqual(snapshot["schema_version"], SCHEMA_VERSION)

    def test_round_trip_preserves_day_location_and_resources(self) -> None:
        restored = round_trip(self.snapshot())
        self.assertEqual(restored["game_day"], 9)
        self.assertEqual(restored["current_location"], "blackford")
        self.assertEqual(restored["company"]["resources"], self.company["resources"])

    def test_world_economy_state_round_trip_preserves_settlement_values(self) -> None:
        snapshot = self.snapshot()
        snapshot["world"]["settlement_economy"][0]["prosperity"] = 77
        restored = round_trip(snapshot)
        self.assertEqual(restored["world"]["settlement_economy"][0]["prosperity"], 77)

    def test_route_state_round_trip_preserves_route_values(self) -> None:
        snapshot = self.snapshot()
        snapshot["world"]["route_economy"][0]["danger"] = 66
        snapshot["world"]["route_economy"][0]["route_history"] = [{"tick": 4, "contract": "c", "outcome": "success", "effects": {"danger": -5}}]
        restored = round_trip(snapshot)
        self.assertEqual(restored["world"]["route_economy"][0]["danger"], 66)
        self.assertEqual(restored["world"]["route_economy"][0]["route_history"][0]["outcome"], "success")

    def test_factions_rumors_and_memory_survive_round_trip(self) -> None:
        restored = round_trip(self.snapshot())
        self.assertEqual(restored["factions"]["settlement_factions"][0]["id"], self.factions[0]["id"])
        self.assertEqual(restored["rumors"]["active"][0]["text"], "Roads are tense.")
        self.assertEqual(restored["memory"]["entries"][0]["title"], "A hard bargain")

    def test_malformed_json_fails_gracefully(self) -> None:
        snapshot, errors = load_snapshot_text("{not json")
        self.assertIsNone(snapshot)
        self.assertTrue(errors)
        self.assertIn("Malformed save JSON", errors[0])

    def test_missing_optional_sections_do_not_crash(self) -> None:
        snapshot = self.snapshot()
        del snapshot["world"]["route_economy"]
        del snapshot["contracts"]["contract_board"]
        del snapshot["rumors"]["active"]
        normalized = normalize_snapshot(snapshot)
        self.assertEqual(normalized["world"]["route_economy"], [])
        self.assertEqual(normalized["contracts"]["contract_board"], [])
        self.assertEqual(normalized["rumors"]["active"], [])

    def test_schema_version_is_required(self) -> None:
        snapshot = self.snapshot()
        del snapshot["schema_version"]
        errors = validate_snapshot(snapshot)
        self.assertIn("schema_version is required.", errors)

    def test_timestamp_or_text_is_required(self) -> None:
        snapshot = self.snapshot()
        del snapshot["saved_at_unix_time"]
        errors = validate_snapshot(snapshot)
        self.assertIn("saved_at_unix_time or saved_at_text is required.", errors)

    def test_notes_or_debug_metadata_is_required(self) -> None:
        snapshot = self.snapshot()
        del snapshot["notes"]
        del snapshot["debug_metadata"]
        errors = validate_snapshot(snapshot)
        self.assertIn("notes or debug_metadata is required.", errors)

    def test_old_schema_version_fails_gracefully(self) -> None:
        snapshot = self.snapshot()
        snapshot["schema_version"] = 0
        errors = validate_snapshot(snapshot)
        self.assertIn("Unsupported schema_version 0; expected 1.", errors)

    def test_round_trip_does_not_alias_source_state(self) -> None:
        snapshot = self.snapshot()
        restored = round_trip(snapshot)
        snapshot["company"]["resources"]["crowns"] = 999
        self.assertNotEqual(restored["company"]["resources"]["crowns"], 999)


if __name__ == "__main__":
    unittest.main()
