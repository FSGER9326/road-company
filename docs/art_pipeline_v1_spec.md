# Art Pipeline V1 — Specification

## Purpose
Define the AI-friendly 2D art asset pipeline for ROAD COMPANY. Every visual asset is defined by manifest ID so gameplay code never depends on art file paths or quality. Placeholder assets are simple and procedural now; final Imagen-generated PNGs slot in later by replacing manifest fallback paths.

## Scope
Single Codex pass. Creates the asset manifest, placeholder generator, validator, and schema. No final-quality art is produced. No Imagen prompts are generated (except the schema that will hold them later).

---

## 1. Asset Philosophy

| Principle | Rule |
|-----------|------|
| **2D only** | Godot 4.x `gl_compatibility` renderer. No 3D models, no isometric animation. |
| **No binary dumps** | Assets are text-first: SVG, procedural GDScript drawing, or small indexed PNGs. |
| **Placeholder-first** | All gameplay works with colored shapes and text labels. Final art is cosmetic. |
| **Manifest-driven** | Every visual reference uses an `asset_id`. Scenes never hardcode file paths. |
| **Replaceable** | Any placeholder can be swapped for final art by changing `fallback_path` in the manifest. |
| **Gameplay-independent** | Game logic must not depend on image resolution, art style, or file presence. Missing assets fall back to procedural rendering. |
| **Low-spec** | Tokens readable at 64×64 to 128×128. Tiles readable at 32×32 to 64×64. |

---

## 2. Required Asset Categories for V1

### Tactical Tokens (Combat)
| Asset ID Pattern | Count | Purpose |
|-----------------|-------|---------|
| `token_fighter_*` | 6 | Player company fighter tokens (colored discs with 2-char label fallback) |
| `token_enemy_bandit_*` | 4 | Bandit cutthroat, thug, archer, knave |
| `token_enemy_undead_*` | 2 | Future: skeleton, wraith (placeholder only) |
| `token_enemy_beast_*` | 2 | Future: dire wolf, beast hound |
| `token_enemy_cultist_*` | 2 | Future: cult fanatic, cult leader |
| `token_wagon` | 1 | Escort objective wagon |
| `token_objective_generic` | 1 | Generic objective marker |

### Hex Terrain Tiles
| Asset ID Pattern | Count | Purpose |
|-----------------|-------|---------|
| `tile_grass` | 1 | Default open hex |
| `tile_road` | 1 | Road surface |
| `tile_mud` | 1 | Slow movement hex |
| `tile_forest` | 1 | Blocked or slow hex |
| `tile_ruins` | 1 | Difficult terrain / cover |
| `tile_water` | 1 | Impassable blocker |
| `tile_stone` | 1 | Rocky terrain / hill |

### Settlement Icons
| Asset ID | Purpose |
|----------|---------|
| `icon_settlement_town` | Default town icon |
| `icon_settlement_village` | Village |
| `icon_settlement_city` | City |
| `icon_settlement_fort` | Fort / garrison |
| `icon_settlement_monastery` | Religious site |
| `icon_settlement_caravanserai` | Road inn |
| `icon_settlement_mining_camp` | Mining outpost |
| `icon_settlement_freehold` | Independent settlement |

### Route / Danger Icons
| Asset ID | Purpose |
|----------|---------|
| `icon_danger_1` through `icon_danger_5` | Danger level skulls/stars |
| `icon_route_blocked` | Closed route marker |
| `icon_route_stabilizing` | Partially secured |
| `icon_route_secure` | Fully secured / safe |

### Combat Condition Icons (16 total)
| Asset ID | Purpose |
|----------|---------|
| `icon_condition_bleeding` | Bleeding overlay |
| `icon_condition_stunned` | Stunned |
| `icon_condition_staggered` | Staggered |
| `icon_condition_frightened` | Frightened |
| `icon_condition_pinned` | Pinned |
| `icon_condition_poisoned` | Poisoned |
| `icon_condition_burning` | Burning |
| `icon_condition_exhausted` | Exhausted |
| `icon_condition_exposed` | Exposed |
| `icon_condition_inspired` | Inspired |
| `icon_condition_guarded` | Guarded |
| `icon_condition_cursed` | Cursed |
| `icon_condition_marked` | Marked |
| `icon_condition_disarmed` | Disarmed |
| `icon_condition_prone` | Prone |
| `icon_condition_rallied` | Rallied |

### UI Elements
| Asset ID | Purpose |
|----------|---------|
| `ui_parchment_bg` | Screen background |
| `ui_card_bg` | Panel/card background |
| `ui_button_normal` | Button background |
| `ui_button_hover` | Button hover state |
| `ui_contract_board_bg` | Contract list background |
| `ui_road_map_border` | Map frame |

### Faction Emblems
| Asset ID | Purpose |
|----------|---------|
| `emblem_ashen_crown` | Ashen Crown faction |
| `emblem_millers_compact` | Millers' Compact |
| `emblem_lantern_church` | Lantern Church |
| `emblem_gutter_league` | Gutter League |

**Total V1 asset count**: ~60 entries in the manifest.

---

## 3. Asset Manifest Schema

### File: `data/art/asset_manifest.json`

```json
{
  "version": "1.0",
  "generated_by": "codex_placeholder",
  "assets": [
    {
      "asset_id": "string (unique, lowercase_underscores)",
      "category": "token|tile|icon|ui|emblem",
      "subcategory": "string|null (fighter|enemy|terrain|condition|settlement|faction)",
      "path": "string|null (relative to res://, e.g. 'res://assets/tokens/fighter_01.png')",
      "fallback_path": "string|null (SVG or procedural fallback)",
      "intended_use": "string (where this asset appears)",
      "size_px": "int (largest dimension, e.g. 64)",
      "anchor": "center|top_left|bottom_center",
      "replaceable": "bool (true = can be swapped for final art)",
      "generated_by": "procedural|svg|imagen|null",
      "imagen_request_id": "string|null (maps to imagen_asset_requests.json later)",
      "notes": "string"
    }
  ]
}
```

### Example Entry

```json
{
  "asset_id": "token_enemy_bandit_cutthroat",
  "category": "token",
  "subcategory": "enemy",
  "path": null,
  "fallback_path": "res://game/scripts/combat/CombatBoard.gd",
  "intended_use": "Tactical combat hex token for bandit cutthroat enemy",
  "size_px": 28,
  "anchor": "center",
  "replaceable": true,
  "generated_by": "procedural",
  "imagen_request_id": "enemy_bandit_cutthroat_v1",
  "notes": "Current fallback: colored circle with text label. Replace with Imagen PNG later."
}
```

---

## 4. Token / Paper-Doll Future Plan

### Layer Stack (Future, not V1)

When Imagen generates final art, each combat token is composed of layers:

```
Layer 1: body (base silhouette + skin tone)
Layer 2: head (face + hair)
Layer 3: helmet (headgear from equipment)
Layer 4: armor (body armor from equipment)
Layer 5: cloak (optional, faction-colored)
Layer 6: weapon (held weapon from equipment)
Layer 7: shield (if equipped)
Layer 8: wound_overlay (if injured, red tint)
Layer 9: status_overlay (condition icon, e.g. bleeding drip)
```

Each layer is a separate transparent PNG. Godot composes them with `CanvasLayer` or a single `Node2D` with multiple `Sprite2D` children.

### Why This Matters for V1

- The manifest tracks each token as one entry now
- In a future pass, the manifest gains `layer_stack_manifest_id` that references a separate layer manifest
- The manifest design leaves room for this without breaking V1
- V1 tokens are single composite images (or procedural fallbacks)

---

## 5. Placeholder Generation Strategy

### What Codex Should Generate

Codex can produce two things reliably:
1. **SVG files** — text-based vector graphics, small, deterministic
2. **Procedural GDScript drawing** — what the current prototype already does

### Recommended Approach for V1

#### Primary: Procedural fallback (keep what works)
The current prototype already renders tokens as colored circles with text labels and terrain as hex polygons. This is fully functional. V1 keeps this as the primary render method.

#### Secondary: SVG placeholders (new)
For assets that benefit from a static visual, generate simple SVG files:

- **Tiles**: Flat-colored squares/hexes with a simple symbol (grass = green with 3 small lines, road = brown with dashed center line, mud = brown with wavy lines)
- **Icons**: Simple geometric shapes with 1-2 letter abbrevations (skull for danger, cross for medicine, sword for weapons)
- **Emblems**: Simple geometric designs (circle with a symbol inside, faction-colored)
- **UI backgrounds**: Solid color rectangles with subtle texture pattern (lines or dots)

#### SVG Requirements
- Single `<svg>` element, viewBox 0 0 SIZE SIZE
- No external fonts — use simple shapes only
- No embedded images
- No JavaScript
- Colors from a fixed palette: `#2c3a24` (dark green), `#5c4a2c` (brown), `#4a3a2a` (dark brown), `#8a6a3a` (tan), `#c4a84a` (gold), `#6a2a2a` (dark red), `#3a4a6a` (dark blue), `#2a2a2a` (near-black), `#4a4a4a` (gray)
- File size under 2KB

### Token Procedural Fallback Specification

Each token type has procedural drawing rules in code:

```gdscript
# CombatBoard._draw() already does this pattern:
# 1. Background circle (dark)
# 2. Colored circle (blue for player, red for enemy, gold for objective)
# 3. 2-char label centered
# 4. HP bar below

# For V1 extension, add:
# 5. Condition icon overlay (16×16 icon above the token)
# 6. Wound/death state tint (red tint when HP < 30%)
```

### Placeholder File Naming

```
assets/
  placeholder/
    tokens/
      fighter_01.svg
      enemy_bandit_cutthroat.svg
      enemy_bandit_thug.svg
      enemy_bandit_archer.svg
      wagon.svg
    tiles/
      grass.svg
      road.svg
      mud.svg
      forest.svg
      ruins.svg
      water.svg
      stone.svg
    icons/
      settlement_town.svg
      settlement_village.svg
      ...
      danger_1.svg through danger_5.svg
      condition_bleeding.svg
      ...
    ui/
      parchment_bg.svg
      card_bg.svg
    emblems/
      ashen_crown.svg
      millers_compact.svg
      lantern_church.svg
      gutter_league.svg
```

---

## 6. Godot Integration

### Asset Location
```
res://assets/                    # final art (future)
res://assets/placeholder/         # SVG/V1 placeholders
  tokens/
  tiles/
  icons/
  ui/
  emblems/
res://game/scripts/combat/CombatBoard.gd  # procedural token fallback
res://game/scripts/road/RoadMapCanvas.gd  # procedural map drawing
```

### Manifest Loading
DataStore loads `res://data/art/asset_manifest.json` at startup. The manifest is cached in a dictionary keyed by `asset_id`.

### How Scenes Reference Assets

```gdscript
# Get asset info by ID
var asset = data_store.get_asset("token_enemy_bandit_cutthroat")

# If path exists, load texture
if asset.path and FileAccess.file_exists(asset.path):
    var texture = load(asset.path)
    draw_texture(texture, position)
# Else use fallback path (procedural)
elif asset.fallback_path:
    _draw_procedural_token(asset, position)
# Else: draw error placeholder (red X)
else:
    _draw_error_token(position)
```

### Combat Board Integration
The current `CombatBoard._draw()` draws tokens procedurally. V1 adds a look-up step:

1. For each unit, look up `token_{side}_{archetype}` in manifest
2. If the manifest has a `path` to a real image, try loading it
3. If loading fails or path is null, use existing procedural fallback (circles + text)
4. Condition icons are drawn as 16×16 overlays on tokens

### Road Map Integration
The current `RoadMapCanvas._draw()` draws settlements as circles. V1 adds:

1. For each settlement, look up `icon_settlement_{type}` in manifest
2. If icon path exists, draw a small icon instead of a circle
3. Route danger text can be replaced with `icon_danger_{level}`

### UI Integration
ContractBoard, RoadScreen, CampScreen, etc. can reference `ui_card_bg`, `ui_parchment_bg`, etc. as background textures. If not found, use dark colored rectangles (current behavior).

---

## 7. Validation

### File: `tools/validate_art_assets.py`

Checks:
1. Manifest parses as valid JSON
2. Every `asset_id` is unique
3. Every `category` is in {token, tile, icon, ui, emblem}
4. If `path` is set, file exists at that location
5. If `path` is set, `path` starts with `res://`
6. `size_px` is a positive integer
7. `generated_by` is in {procedural, svg, imagen, null}
8. Every `generated_by` = "svg" entry has a corresponding file in `assets/placeholder/`
9. No assets reference paths outside `res://assets/` or `res://game/scripts/`
10. No duplicate paths (two assets can't share the same file)
11. All `asset_id` values that combat code needs (16 conditions, 12 enemies, 7 terrains, 8 settlements, 4 factions, 5 danger levels) exist in the manifest

### Integration with run_all_tests.py
`tools/run_all_tests.py` should include `tools/validate_art_assets.py` in its validator list.

---

## 8. Automated Tests

### File: `tools/tests/test_art_assets.py`

```python
class ArtAssetTests(unittest.TestCase):
    def test_manifest_loads(self):
        # manifest.json parses without error

    def test_all_required_condition_icons_exist(self):
        # Every condition ID in combat_design has a manifest entry

    def test_all_required_enemy_tokens_exist(self):
        # Every enemy archetype has a manifest entry

    def test_all_required_terrain_tiles_exist(self):
        # Every terrain type has a manifest entry

    def test_all_required_settlement_icons_exist(self):
        # Every settlement type has a manifest entry

    def test_all_required_faction_emblems_exist(self):
        # Every faction ID has a manifest entry

    def test_manifest_ids_are_unique(self):
        # No duplicate asset_id values

    def test_procedural_fallback_does_not_crash(self):
        # For assets with generated_by="procedural" and no path,
        # calling CombatBoard._draw_procedural_token() succeeds

    def test_nonregression_combat_board_draws_tokens(self):
        # CombatBoard._draw() still produces valid output
        # (relies on existing Godot headless smoke test)
```

---

## 9. Imagen Prompt Pack Structure (Future)

### File: `data/art/imagen_asset_requests.json` (NOT created in V1)

```json
{
  "version": "1.0",
  "requests": [
    {
      "asset_id": "string (matches manifest)",
      "priority": 1,
      "category": "token",
      "prompt": "Dark fantasy token art. A grim cutthroat bandit with a rusted knife, wearing tattered leather, facing right. Low-fantasy mercenary style. No glowing magic. No heroic poses.",
      "negative_prompt": "heroic fantasy, glowing weapons, clean armor, anime style, bright lighting, cute",
      "style_reference": "battle_brothers_token_art",
      "transparent_background": true,
      "aspect_ratio": "1:1",
      "target_size_px": 128,
      "replacement_manifest_id": "token_enemy_bandit_cutthroat",
      "notes": "Generate as transparent PNG. Token faces right. Neutral stance."
    }
  ]
}
```

Do NOT create this file in V1. It is designed for a later Imagen pass.

---

## 10. What NOT to Build Yet

- Do not generate actual PNG/SVG art beyond the placeholder generator
- Do not create `imagen_asset_requests.json`
- Do not implement paper-doll layer compositing (single images only for V1)
- Do not add animation (no walk cycles, no attack animations)
- Do not add particle effects
- Do not add shaders beyond Godot built-in canvas_item
- Do not replace procedural token rendering with image loading (additive, not replacement)
- Do not create asset thumbnails or previews
- Do not import any external art libraries or tools

---

## 11. Acceptance Criteria

- [ ] `data/art/asset_manifest.json` exists with ~60 entries
- [ ] All 16 condition icons have manifest entries
- [ ] All 4 enemy archetypes have manifest entries
- [ ] All 7 terrain tiles have manifest entries
- [ ] All 8 settlement types have manifest entries
- [ ] All 4 faction emblems have manifest entries
- [ ] All 5 danger levels have manifest entries
- [ ] `tools/validate_art_assets.py` passes
- [ ] `tools/tests/test_art_assets.py` passes
- [ ] `python tools/run_all_tests.py` exits zero (art validation included)
- [ ] CombatBoard still draws tokens with procedural fallback
- [ ] RoadMapCanvas still draws settlements and routes
- [ ] Existing Godot headless smoke test still passes
