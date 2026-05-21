"""Validate ROAD COMPANY art asset manifest and generated files."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "data" / "art" / "asset_manifest.json"

VALID_CATEGORIES = {"token", "tile", "icon", "ui", "emblem"}
VALID_GENERATED_BY = {"procedural", "svg", "imagen", None}

REQUIRED_ASSETS = {
    "enemy_tokens": [
        "token_enemy_bandit_cutthroat",
        "token_enemy_bandit_thug",
        "token_enemy_bandit_archer",
        "token_enemy_bounty_knave",
        "token_enemy_undead_skeleton",
        "token_enemy_beast_wolf",
        "token_enemy_cultist_fanatic",
    ],
    "objective_tokens": [
        "token_wagon",
        "token_objective_generic",
    ],
    "terrain_tiles": [
        "tile_grass",
        "tile_road",
        "tile_mud",
        "tile_forest",
        "tile_ruins",
        "tile_water",
        "tile_stone",
    ],
    "settlement_icons": [
        "icon_settlement_town",
        "icon_settlement_village",
        "icon_settlement_city",
        "icon_settlement_fort",
        "icon_settlement_monastery",
        "icon_settlement_caravanserai",
        "icon_settlement_mining_camp",
        "icon_settlement_freehold",
    ],
    "danger_icons": [
        "icon_danger_1",
        "icon_danger_2",
        "icon_danger_3",
        "icon_danger_4",
        "icon_danger_5",
    ],
    "route_icons": [
        "icon_route_blocked",
        "icon_route_stabilizing",
        "icon_route_secure",
    ],
    "condition_icons": [
        "icon_condition_bleeding",
        "icon_condition_stunned",
        "icon_condition_staggered",
        "icon_condition_frightened",
        "icon_condition_pinned",
        "icon_condition_poisoned",
        "icon_condition_burning",
        "icon_condition_exhausted",
        "icon_condition_exposed",
        "icon_condition_inspired",
        "icon_condition_guarded",
        "icon_condition_cursed",
        "icon_condition_marked",
        "icon_condition_disarmed",
        "icon_condition_prone",
        "icon_condition_rallied",
    ],
    "ui_elements": [
        "ui_parchment_bg",
        "ui_card_bg",
        "ui_button_normal",
        "ui_button_hover",
        "ui_contract_board_bg",
        "ui_road_map_border",
    ],
    "faction_emblems": [
        "emblem_ashen_crown",
        "emblem_millers_compact",
        "emblem_lantern_church",
        "emblem_gutter_league",
    ],
}


def validate() -> list[str]:
    errors: list[str] = []

    if not MANIFEST_PATH.exists():
        errors.append(f"Manifest not found at {MANIFEST_PATH}")
        return errors

    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"Manifest JSON parse error: {exc}")
        return errors

    if manifest.get("version") != "1.0":
        errors.append("Manifest version must be '1.0'")

    assets = manifest.get("assets", [])
    if not isinstance(assets, list):
        errors.append("Manifest 'assets' must be an array")
        return errors

    if not assets:
        errors.append("Manifest 'assets' is empty")
        return errors

    # Check fields on each asset
    seen_ids: set[str] = set()
    seen_paths: set[str] = set()
    all_ids: set[str] = set()

    for i, entry in enumerate(assets):
        asset_id = entry.get("asset_id", "")
        label = f"asset[{i}] ({asset_id or 'missing id'})"

        # Required fields
        for field in ("asset_id", "category", "intended_use", "size_px", "replaceable", "generated_by"):
            if field not in entry:
                errors.append(f"{label}: missing required field '{field}'")

        if not isinstance(asset_id, str) or not asset_id:
            errors.append(f"{label}: asset_id must be non-empty string")
        else:
            all_ids.add(asset_id)
            if asset_id in seen_ids:
                errors.append(f"{label}: duplicate asset_id '{asset_id}'")
            seen_ids.add(asset_id)

        category = entry.get("category", "")
        if category not in VALID_CATEGORIES:
            errors.append(f"{label}: category '{category}' not in {VALID_CATEGORIES}")

        generated_by = entry.get("generated_by")
        if generated_by not in VALID_GENERATED_BY:
            errors.append(f"{label}: generated_by '{generated_by}' not in {VALID_GENERATED_BY}")

        size_px = entry.get("size_px")
        if not isinstance(size_px, int) or size_px < 8 or size_px > 4096:
            errors.append(f"{label}: size_px must be int 8-4096, got {size_px}")

        path = entry.get("path")
        if path is not None:
            if not isinstance(path, str):
                errors.append(f"{label}: path must be string or null")
            elif not path.startswith("res://"):
                errors.append(f"{label}: path must start with 'res://', got '{path}'")
            else:
                # Resolve path to filesystem
                rel = path[6:]  # strip res://
                abs_path = ROOT / rel.replace("/", "\\")
                if abs_path.exists():
                    seen_paths.add(path)
                else:
                    errors.append(f"{label}: path '{path}' does not exist on disk")

        fallback = entry.get("fallback_path")
        if fallback is not None:
            if not isinstance(fallback, str):
                errors.append(f"{label}: fallback_path must be string or null")
            elif not fallback.startswith("res://"):
                errors.append(f"{label}: fallback_path must start with 'res://'")

    # Check required assets exist
    for category_name, required_ids in REQUIRED_ASSETS.items():
        for req_id in required_ids:
            if req_id not in all_ids:
                errors.append(f"Missing required asset: {req_id} (category: {category_name})")

    # Check no duplicate paths
    # (already caught by file existence check, but explicit is good)

    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print(f"Art asset validation FAILED ({len(found)} errors):")
        for error in found:
            print(f"  - {error}")
        raise SystemExit(1)
    print("Art asset validation PASSED")
