"""Tests for ROAD COMPANY art asset manifest and generator."""
from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "data" / "art" / "asset_manifest.json"


def load_manifest() -> dict:
    with MANIFEST_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


class ArtManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = load_manifest()
        cls.asset_ids = {a["asset_id"] for a in cls.manifest.get("assets", [])}

    def test_manifest_loads(self) -> None:
        self.assertIn("version", self.manifest)
        self.assertEqual(self.manifest["version"], "1.0")
        self.assertIn("assets", self.manifest)
        self.assertGreater(len(self.manifest["assets"]), 50)

    def test_manifest_ids_unique(self) -> None:
        ids = [a.get("asset_id") for a in self.manifest["assets"]]
        self.assertEqual(len(ids), len(set(ids)))

    def test_all_enemy_tokens_exist(self) -> None:
        required = {
            "token_enemy_bandit_cutthroat",
            "token_enemy_bandit_thug",
            "token_enemy_bandit_archer",
            "token_enemy_bounty_knave",
            "token_enemy_undead_skeleton",
            "token_enemy_beast_wolf",
            "token_enemy_cultist_fanatic",
        }
        for rid in required:
            self.assertIn(rid, self.asset_ids, f"Missing enemy token: {rid}")

    def test_objective_tokens_exist(self) -> None:
        for rid in ("token_wagon", "token_objective_generic"):
            self.assertIn(rid, self.asset_ids, f"Missing objective token: {rid}")

    def test_all_terrain_tiles_exist(self) -> None:
        required = {
            "tile_grass", "tile_road", "tile_mud", "tile_forest",
            "tile_ruins", "tile_water", "tile_stone",
        }
        for rid in required:
            self.assertIn(rid, self.asset_ids, f"Missing terrain tile: {rid}")

    def test_all_settlement_icons_exist(self) -> None:
        required = {
            "icon_settlement_town", "icon_settlement_village", "icon_settlement_city",
            "icon_settlement_fort", "icon_settlement_monastery", "icon_settlement_caravanserai",
            "icon_settlement_mining_camp", "icon_settlement_freehold",
        }
        for rid in required:
            self.assertIn(rid, self.asset_ids, f"Missing settlement icon: {rid}")

    def test_all_danger_icons_exist(self) -> None:
        for i in range(1, 6):
            rid = f"icon_danger_{i}"
            self.assertIn(rid, self.asset_ids, f"Missing danger icon: {rid}")

    def test_all_route_status_icons_exist(self) -> None:
        for rid in ("icon_route_blocked", "icon_route_stabilizing", "icon_route_secure"):
            self.assertIn(rid, self.asset_ids, f"Missing route icon: {rid}")

    def test_all_condition_icons_exist(self) -> None:
        required = {
            "icon_condition_bleeding", "icon_condition_stunned", "icon_condition_staggered",
            "icon_condition_frightened", "icon_condition_pinned", "icon_condition_poisoned",
            "icon_condition_burning", "icon_condition_exhausted", "icon_condition_exposed",
            "icon_condition_inspired", "icon_condition_guarded", "icon_condition_cursed",
            "icon_condition_marked", "icon_condition_disarmed", "icon_condition_prone",
            "icon_condition_rallied",
        }
        self.assertEqual(len(required), 16, "Should be exactly 16 condition types")
        for rid in required:
            self.assertIn(rid, self.asset_ids, f"Missing condition icon: {rid}")

    def test_all_ui_elements_exist(self) -> None:
        required = {
            "ui_parchment_bg", "ui_card_bg", "ui_button_normal",
            "ui_button_hover", "ui_contract_board_bg", "ui_road_map_border",
        }
        for rid in required:
            self.assertIn(rid, self.asset_ids, f"Missing UI element: {rid}")

    def test_all_faction_emblems_exist(self) -> None:
        required = {
            "emblem_ashen_crown", "emblem_millers_compact",
            "emblem_lantern_church", "emblem_gutter_league",
        }
        for rid in required:
            self.assertIn(rid, self.asset_ids, f"Missing faction emblem: {rid}")

    def test_category_values_valid(self) -> None:
        valid = {"token", "tile", "icon", "ui", "emblem"}
        for entry in self.manifest["assets"]:
            self.assertIn(entry.get("category"), valid,
                          f"{entry.get('asset_id')}: invalid category '{entry.get('category')}'")

    def test_generated_by_values_valid(self) -> None:
        valid = {"procedural", "svg", "imagen", None}
        for entry in self.manifest["assets"]:
            self.assertIn(entry.get("generated_by"), valid,
                          f"{entry.get('asset_id')}: invalid generated_by")

    def test_size_px_in_range(self) -> None:
        for entry in self.manifest["assets"]:
            size = entry.get("size_px", 0)
            self.assertGreaterEqual(size, 8,
                                    f"{entry.get('asset_id')}: size_px {size} < 8")
            self.assertLessEqual(size, 4096,
                                 f"{entry.get('asset_id')}: size_px {size} > 4096")

    def test_svg_assets_have_existing_paths(self) -> None:
        for entry in self.manifest["assets"]:
            if entry.get("generated_by") == "svg" and entry.get("path"):
                rel = entry["path"][6:]  # strip res://
                abs_path = ROOT / rel.replace("/", "\\")
                self.assertTrue(abs_path.exists(),
                                f"{entry.get('asset_id')}: SVG path does not exist: {rel}")


if __name__ == "__main__":
    unittest.main()
