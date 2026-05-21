# Codex Next Prompt: Art Placeholder Pipeline V1

## Task
Create the asset manifest, placeholder generator, art validator, and tests for ROAD COMPANY. Gameplay code must not depend on final art quality. All visuals are replaceable through manifest IDs.

## Prerequisites
Read before starting:
- `docs/art_pipeline_v1_spec.md` — full specification
- `docs/art_pipeline.md` — existing art philosophy
- `game/scripts/combat/CombatBoard.gd` — current procedural token drawing
- `game/scripts/road/RoadMapCanvas.gd` — current procedural map drawing
- `docs/combat_design_battlebrothers_plus_dnd.md` — condition IDs needed
- `docs/data_schema_plan.md` — enemy IDs, settlement types

## Branch
Stay on `feature/world-tick-v1` or whichever branch currently has the latest runtime code. Do not switch branches.

## Implementation Steps

### Step 1: Create asset directory structure

```
res://assets/
  placeholder/
    tokens/
    tiles/
    icons/
    ui/
    emblems/
```

Create `.gitkeep` files in each subdirectory so they commit.

### Step 2: Create the asset manifest

New file: `data/art/asset_manifest.json`

Create entries for all required V1 assets (~60 entries). Use the schema from `docs/art_pipeline_v1_spec.md` section 3.

Key entries to include:
- 6 enemy tokens (bandit cutthroat, thug, archer, knave + future undead/beast slots)
- 1 wagon token
- 7 terrain tiles
- 8 settlement icons
- 5 danger level icons
- 3 route status icons
- 16 condition icons
- 5 UI backgrounds
- 4 faction emblems

For all entries, set `path` to `null` (SVG files not generated yet) and `generated_by` to `"procedural"`. The `fallback_path` for tokens should point to `"res://game/scripts/combat/CombatBoard.gd"`. For settlement/tile icons, `fallback_path` can be `null` with a `notes` saying "Procedural circle fallback in RoadMapCanvas/CombatBoard".

### Step 3: Extend DataStore to load manifest

In `game/scripts/core/DataStore.gd`:
- Add `var asset_manifest = []` member
- Add `load_asset_manifest()` call in `load_all()`
- Add `func get_asset(asset_id: String) -> Dictionary` that looks up by `asset_id`

### Step 4: Extend CombatBoard with condition icon overlays

In `game/scripts/combat/CombatBoard.gd`:
- After drawing the token circle and label, check if the unit has conditions
- For each condition in `unit.conditions`, look up `icon_condition_{condition_id}` in asset manifest
- If the manifest has a path, try to draw the icon as a small 12×12 overlay above the token
- If no path (current V1 state), draw a small colored square with the condition's first letter as text

This is optional for V1 but recommended — it wires the manifest into the combat rendering path.

### Step 5: Create placeholder SVG generator

New file: `tools/generate_placeholders.py`

A Python script that generates minimal SVG placeholder files.

Function signature:
```python
def generate_token_svg(asset_id: str, category: str, size: int, color: str, label: str) -> str:
    # Returns SVG string for a disc token with color and 2-char label
    # Used for: enemy tokens, wagon, fighter tokens

def generate_tile_svg(asset_id: str, color: str, pattern_type: str) -> str:
    # Returns SVG string for a terrain tile
    # pattern_type: "flat", "grid", "wavy", "dots", "crosshatch"

def generate_icon_svg(asset_id: str, color: str, shape: str, label: str) -> str:
    # Returns SVG string for a small icon
    # shape: "circle", "diamond", "triangle", "cross"

def generate_emblem_svg(asset_id: str, faction_name: str, color_primary: str, color_secondary: str) -> str:
    # Returns SVG string for a faction emblem
```

The script should:
1. Read `data/art/asset_manifest.json`
2. For each entry where `generated_by == "svg"`, create an SVG file
3. For entries where `generated_by == "procedural"`, skip (handled by Godot)
4. Place generated files in `assets/placeholder/{subcategory}/{filename}.svg`
5. Print a summary: "Generated X SVG files, skipped Y procedural entries"

Run it as: `python tools/generate_placeholders.py`

Currently, since all V1 entries use `generated_by: "procedural"`, the script will generate zero SVGs and report "Generated 0 files." This is correct — it's infrastructure for when we add SVG assets later.

### Step 6: Create art validator

New file: `tools/validate_art_assets.py`

Validate:
- Manifest parses as valid JSON
- Every `asset_id` is unique
- Every `category` is in allowed set
- If `path` is set, the file exists
- No paths outside `res://assets/` or `res://game/scripts/`
- Required asset IDs exist (see checklist below)
- No duplicate paths

Required asset ID checklist to hardcode in validator:
```
TOKENS: token_enemy_bandit_cutthroat, token_enemy_bandit_thug, token_enemy_bandit_archer, token_enemy_bounty_knave, token_enemy_undead_skeleton, token_enemy_beast_wolf, token_enemy_cultist_fanatic, token_wagon
TILES: tile_grass, tile_road, tile_mud, tile_forest, tile_ruins, tile_water, tile_stone
SETTLEMENT_ICONS: icon_settlement_town, icon_settlement_village, icon_settlement_city, icon_settlement_fort, icon_settlement_monastery, icon_settlement_caravanserai, icon_settlement_mining_camp, icon_settlement_freehold
DANGER_ICONS: icon_danger_1 through icon_danger_5
ROUTE_ICONS: icon_route_blocked, icon_route_stabilizing, icon_route_secure
CONDITION_ICONS: icon_condition_bleeding, icon_condition_stunned, icon_condition_staggered, icon_condition_frightened, icon_condition_pinned, icon_condition_poisoned, icon_condition_burning, icon_condition_exhausted, icon_condition_exposed, icon_condition_inspired, icon_condition_guarded, icon_condition_cursed, icon_condition_marked, icon_condition_disarmed, icon_condition_prone, icon_condition_rallied
UI: ui_parchment_bg, ui_card_bg, ui_button_normal, ui_contract_board_bg, ui_road_map_border
EMBLEMS: emblem_ashen_crown, emblem_millers_compact, emblem_lantern_church, emblem_gutter_league
```

### Step 7: Create art asset tests

New file: `tools/tests/test_art_assets.py`

Required tests (6 minimum):
1. `test_manifest_loads` — JSON parses without error
2. `test_all_required_condition_icons_exist` — all 16 condition IDs in manifest
3. `test_all_required_enemy_tokens_exist` — all 8 enemy token IDs in manifest
4. `test_all_required_terrain_tiles_exist` — all 7 tiles in manifest
5. `test_all_required_settlement_icons_exist` — all 8 settlement icons in manifest
6. `test_all_required_faction_emblems_exist` — all 4 faction emblems in manifest
7. `test_manifest_ids_unique` — no duplicate asset_id (bonus)

### Step 8: Wire validator into run_all_tests.py

In `tools/run_all_tests.py`, add:
```python
"tools/validate_art_assets.py",
```
to the validators list so it runs automatically.

### Step 9: Update docs/art_pipeline.md

Append to the existing file (do not rewrite it). Add a section at the bottom:

```
## V1 Placeholder Pipeline

See `data/art/asset_manifest.json` for the authoritative asset list.
See `docs/art_pipeline_v1_spec.md` for the full specification.
Run `python tools/generate_placeholders.py` to generate SVG placeholders.
Run `python tools/validate_art_assets.py` to validate the manifest.
Run `python tools/tests/test_art_assets.py` for automated tests.
```

### Step 10: Do NOT do

- Do not create `imagen_asset_requests.json` — that's a future pass
- Do not generate any PNG files
- Do not generate any SVG files (the generator script exists but produces nothing for V1 since all assets are procedural)
- Do not modify CombatBoard or RoadMapCanvas rendering logic beyond the optional condition icon overlay
- Do not add any art dependencies (no Pillow, no ImageMagick, no external SVG library)
- Do not create paper-doll layer compositing

## Acceptance Criteria

- [ ] `data/art/asset_manifest.json` exists with ~60 entries covering all required categories
- [ ] All required asset IDs are present in the manifest (validated)
- [ ] `tools/validate_art_assets.py` passes all checks
- [ ] `tools/tests/test_art_assets.py` passes all 6+ tests
- [ ] `tools/generate_placeholders.py` runs without error (produces 0 SVGs for V1, which is correct)
- [ ] `tools/run_all_tests.py` exits zero (includes art validation)
- [ ] Existing combat autoplay smoke still passes
- [ ] CombatBoard still draws tokens (procedural fallback intact)
- [ ] RoadMapCanvas still draws settlements and routes

## File Preservation
- Do NOT modify `game/scenes/` files
- Do NOT modify `project.godot`
- New files only in `data/art/`, `tools/`, `assets/placeholder/`
- Append-only change to `docs/art_pipeline.md`
- Optional light extension of `game/scripts/combat/CombatBoard.gd` (condition icons, additive only)

## After Implementation
Run and report:
```
python tools/generate_placeholders.py
python tools/validate_art_assets.py
python tools/run_all_tests.py
```
