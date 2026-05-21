from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "data/art/asset_manifest.json"

ALLOWED_CATEGORIES = {"token", "tile", "icon", "ui", "emblem"}
ALLOWED_ANCHORS = {"center", "top_left", "top_center", "bottom_center"}
ALLOWED_GENERATORS = {"procedural", "svg", "imagen", None}
ALLOWED_EXTENSIONS = {".svg", ".png"}
ALLOWED_PATH_PREFIXES = ("res://assets/generated/", "res://game/scripts/")

REQUIRED_IDS = {
    "token_fighter_01", "token_fighter_02", "token_fighter_03", "token_fighter_04", "token_fighter_05", "token_fighter_06",
    "token_enemy_bandit_cutthroat", "token_enemy_bandit_thug", "token_enemy_bandit_archer", "token_enemy_bounty_knave",
    "token_enemy_undead_skeleton", "token_enemy_undead_wraith", "token_enemy_beast_wolf", "token_enemy_beast_hound",
    "token_enemy_cultist_fanatic", "token_enemy_cultist_leader", "token_wagon", "token_objective_generic",
    "tile_grass", "tile_road", "tile_mud", "tile_forest", "tile_ruins", "tile_water", "tile_stone",
    "icon_settlement_town", "icon_settlement_village", "icon_settlement_city", "icon_settlement_fort",
    "icon_settlement_monastery", "icon_settlement_caravanserai", "icon_settlement_mining_camp", "icon_settlement_freehold",
    "icon_danger_1", "icon_danger_2", "icon_danger_3", "icon_danger_4", "icon_danger_5",
    "icon_route_blocked", "icon_route_stabilizing", "icon_route_secure",
    "icon_condition_bleeding", "icon_condition_stunned", "icon_condition_staggered", "icon_condition_frightened",
    "icon_condition_pinned", "icon_condition_poisoned", "icon_condition_burning", "icon_condition_exhausted",
    "icon_condition_exposed", "icon_condition_inspired", "icon_condition_guarded", "icon_condition_cursed",
    "icon_condition_marked", "icon_condition_disarmed", "icon_condition_prone", "icon_condition_rallied",
    "ui_parchment_bg", "ui_card_bg", "ui_button_normal", "ui_button_hover", "ui_contract_board_bg", "ui_road_map_border",
    "emblem_ashen_crown", "emblem_millers_compact", "emblem_lantern_church", "emblem_gutter_league",
}


def load_manifest() -> dict:
    with MANIFEST_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def res_to_path(res_path: str) -> Path:
    return ROOT / res_path.removeprefix("res://")


def validate_path(value: str | None, label: str, errors: list[str], seen_paths: set[str], require_exists: bool, track_duplicate: bool) -> None:
    if value is None:
        return
    if not isinstance(value, str) or not value.startswith("res://"):
        errors.append(f"{label} must be null or a res:// path")
        return
    if not value.startswith(ALLOWED_PATH_PREFIXES):
        errors.append(f"{label} must stay inside assets/generated or game/scripts")
        return
    suffix = Path(value).suffix.lower()
    if suffix and suffix not in ALLOWED_EXTENSIONS and not value.startswith("res://game/scripts/"):
        errors.append(f"{label} uses unsupported extension '{suffix}'")
    if track_duplicate:
        if value in seen_paths:
            errors.append(f"{label} duplicates path '{value}'")
        seen_paths.add(value)
    if require_exists and not res_to_path(value).exists():
        errors.append(f"{label} references missing file '{value}'")


def validate() -> list[str]:
    errors: list[str] = []
    try:
        manifest = load_manifest()
    except Exception as exc:  # noqa: BLE001
        return [f"asset manifest failed to parse: {exc}"]

    if manifest.get("version") != "1.0":
        errors.append("asset manifest version must be '1.0'")
    if manifest.get("generated_by") != "codex_placeholder":
        errors.append("asset manifest generated_by must be 'codex_placeholder'")
    assets = manifest.get("assets")
    if not isinstance(assets, list):
        return errors + ["asset manifest assets must be a list"]

    ids: set[str] = set()
    seen_paths: set[str] = set()
    for index, asset in enumerate(assets):
        label = f"asset[{index}]"
        if not isinstance(asset, dict):
            errors.append(f"{label} must be an object")
            continue
        asset_id = asset.get("asset_id")
        if not isinstance(asset_id, str) or not asset_id:
            errors.append(f"{label} asset_id must be a nonempty string")
            asset_id = f"<missing-{index}>"
        if asset_id in ids:
            errors.append(f"duplicate asset_id '{asset_id}'")
        ids.add(asset_id)
        category = asset.get("category")
        if category not in ALLOWED_CATEGORIES:
            errors.append(f"{asset_id} category must be one of {sorted(ALLOWED_CATEGORIES)}")
        if asset.get("anchor") not in ALLOWED_ANCHORS:
            errors.append(f"{asset_id} anchor must be one of {sorted(ALLOWED_ANCHORS)}")
        if asset.get("generated_by") not in ALLOWED_GENERATORS:
            errors.append(f"{asset_id} generated_by is invalid")
        if not isinstance(asset.get("size_px"), int) or not 8 <= asset.get("size_px", 0) <= 4096:
            errors.append(f"{asset_id} size_px must be an integer between 8 and 4096")
        if not isinstance(asset.get("replaceable"), bool):
            errors.append(f"{asset_id} replaceable must be a boolean")
        if not isinstance(asset.get("intended_use"), str) or not asset.get("intended_use"):
            errors.append(f"{asset_id} intended_use must be a nonempty string")
        validate_path(asset.get("path"), f"{asset_id}.path", errors, seen_paths, require_exists=True, track_duplicate=True)
        validate_path(asset.get("fallback_path"), f"{asset_id}.fallback_path", errors, seen_paths, require_exists=True, track_duplicate=False)

    missing = sorted(REQUIRED_IDS - ids)
    if missing:
        errors.append(f"asset manifest missing required IDs: {', '.join(missing)}")
    return errors


if __name__ == "__main__":
    found = validate()
    if found:
        print("Art asset validation failed:")
        for error in found:
            print(f"- {error}")
        raise SystemExit(1)
    print("Art asset validation passed.")
