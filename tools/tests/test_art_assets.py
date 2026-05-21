from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "data/art/asset_manifest.json"


def load_assets() -> list[dict]:
    with MANIFEST.open("r", encoding="utf-8") as handle:
        return json.load(handle)["assets"]


def asset_ids() -> set[str]:
    return {asset["asset_id"] for asset in load_assets()}


class ArtAssetTests(unittest.TestCase):
    def test_manifest_loads(self) -> None:
        assets = load_assets()
        self.assertGreaterEqual(len(assets), 60)

    def test_manifest_ids_are_unique(self) -> None:
        ids = [asset["asset_id"] for asset in load_assets()]
        self.assertEqual(len(ids), len(set(ids)))

    def test_all_required_condition_icons_exist(self) -> None:
        required = {
            "icon_condition_bleeding", "icon_condition_stunned", "icon_condition_staggered", "icon_condition_frightened",
            "icon_condition_pinned", "icon_condition_poisoned", "icon_condition_burning", "icon_condition_exhausted",
            "icon_condition_exposed", "icon_condition_inspired", "icon_condition_guarded", "icon_condition_cursed",
            "icon_condition_marked", "icon_condition_disarmed", "icon_condition_prone", "icon_condition_rallied",
        }
        self.assertTrue(required.issubset(asset_ids()))

    def test_all_required_enemy_tokens_exist(self) -> None:
        required = {
            "token_enemy_bandit_cutthroat", "token_enemy_bandit_thug", "token_enemy_bandit_archer", "token_enemy_bounty_knave",
            "token_enemy_undead_skeleton", "token_enemy_undead_wraith", "token_enemy_beast_wolf", "token_enemy_beast_hound",
            "token_enemy_cultist_fanatic", "token_enemy_cultist_leader", "token_wagon",
        }
        self.assertTrue(required.issubset(asset_ids()))

    def test_all_required_terrain_tiles_exist(self) -> None:
        required = {"tile_grass", "tile_road", "tile_mud", "tile_forest", "tile_ruins", "tile_water", "tile_stone"}
        self.assertTrue(required.issubset(asset_ids()))

    def test_all_required_settlement_icons_exist(self) -> None:
        required = {
            "icon_settlement_town", "icon_settlement_village", "icon_settlement_city", "icon_settlement_fort",
            "icon_settlement_monastery", "icon_settlement_caravanserai", "icon_settlement_mining_camp", "icon_settlement_freehold",
        }
        self.assertTrue(required.issubset(asset_ids()))

    def test_all_required_faction_emblems_exist(self) -> None:
        required = {"emblem_ashen_crown", "emblem_millers_compact", "emblem_lantern_church", "emblem_gutter_league"}
        self.assertTrue(required.issubset(asset_ids()))

    def test_referenced_asset_files_exist(self) -> None:
        for asset in load_assets():
            path = asset.get("path")
            if path:
                self.assertTrue((ROOT / path.removeprefix("res://")).exists(), path)


if __name__ == "__main__":
    unittest.main()
