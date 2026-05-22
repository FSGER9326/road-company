# Agent Handoff

ROAD COMPANY is designed so coding agents can verify the core loop without manual clicking. Keep changes small, deterministic, and data-first.

## Save/Load Snapshot V1

- **Branch**: `feature/save-load-snapshot-v1`
- **Purpose**: Add deterministic JSON snapshots for the current road/company/world prototype state.
- **Schema**: `schema_version: 1`
- **Save paths**: `user://saves/autosave.json`; optional manual slot constant `user://saves/manual_1.json`.
- **Runtime**: `game/scripts/core/SaveLoadSystem.gd`; callable from code through `build_snapshot`, `save_snapshot`, `load_snapshot`, and `apply_snapshot`.
- **Main hooks**: `Main.gd` exposes `save_game()` and `load_game()`. Debug shortcuts are `F5` for save and `F9` for load; no visible UI was added to avoid visual baseline churn.
- **Persisted**: game day, current location, company resources, roster/graveyard/faction reputation/active contract, current generated board snapshot, settlement economy, route economy, settlement factions, rumors, memory log, recent events/event cooldowns, and deterministic run seed.
- **Validation**: `tools/save_load_core.py`, `tools/validate_save_snapshot.py`, `tools/tests/test_save_load_snapshot.py`, and a Godot headless snapshot round trip in `tools/godot/run_godot_tests.gd`.
- **Known limitations**: no mid-combat resume, no pending-travel resume, no RNG stream-position persistence beyond seed plus day/tick, and no migration path beyond graceful schema rejection.

Commands to verify:

```powershell
python tools/validate_save_snapshot.py
python -m unittest discover -s tools/tests -p test_save_load_snapshot.py
python tools/run_all_tests.py
python tools/run_visual_smoke.py
```

## SVG Token Loading Fix (Antigravity)

- **Branch**: `feature/svg-token-loading-fix-v1`
- **Root Cause**: `CombatBoard.gd` and `RoadMapCanvas.gd` either duplicated fallback loading logic incorrectly, completely lacked it, or failed to handle headless Godot environments (where `.import` files for SVGs aren't generated). Furthermore, `RoadMapCanvas` hardcoded settlement icons to `icon_settlement_town` instead of using the settlement's `market_tier`.
- **Fix Summary**: Added a robust `load_asset_texture` helper method in `DataStore.gd` that handles `ResourceLoader.exists()` checking and falls back to `Image.load_svg_from_string` for loose SVG files. `CombatBoard.gd` and `RoadMapCanvas.gd` were updated to use this helper. `RoadMapCanvas.gd` now supports unique route statuses (blocked, secure, stabilizing) and correctly calculates settlement tiers (village, town, city) dynamically based on `market_tier`.
- **SVG Assets Load Status**: SVG assets now load and render correctly even in headless runs.
- **Fallback Status**: The procedural rendering fallback remains intact and functional if the SVG asset file is missing or fails to parse.
- **Visual Smoke Result**: Passed. The baseline for `combat_board.png` was updated (differs by 2.576%) because SVGs now visibly replace procedural drawing. `road_map.png` didn't differ sufficiently to break threshold but was confirmed working via test scripts.
- **Remaining Limitations**: The SVGs are still simple placeholders. Some route features (e.g. dynamic blocked/secured icons) might overlap if paths are densely clustered.


## Latest Main Status

- Contract generator v1 merged into `main`.
- Settlement factions v1 spec merged into `main` as docs/schema/prompt only.
- Settlement factions runtime implementation is intentionally deferred.
- Visual Regression Harness merged into `main`.
- MiniMax/Qwen branches remain unmerged.

Commands run:

```powershell
python tools/run_all_tests.py
git push
git merge --no-ff feature/visual-regression-harness-v1 -m "test: merge visual regression harness"
python tools/run_all_tests.py
python tools/run_visual_smoke.py
git push
```

Results:

- Visual harness merge test: PASS.
- Pure Python tests: 67 passed.
- Godot headless: PASS through `.godot/bin/Godot_v4.6.2-stable_win64.exe`.
- Visual smoke test: PASS (5/5 screens matched created baselines).
- Skipped tests: none.

Known limitations:

- Generated contract boards are deterministic but not persisted.
- Settlement factions are spec-only; no runtime faction influence tick exists yet.
- Generated contract board UX is minimal debug-facing text.
- Visual smoke uses a windowed capture because headless OpenGL doesn't support rendering images in this Godot build.

Next recommended task: `feature/settlement-factions-v1`.

## Visual Regression Harness Merge (Antigravity)

- **feature/visual-regression-harness-v1** - merged into main.
- Added `tools/godot/capture_visual_screens.gd` to deterministically open and capture screens.
- Added `tools/run_visual_smoke.py` to trigger Godot captures.
- Added `tools/compare_visual_screens.py` to generate image diffs and reports.
- Added baseline screenshot images inside `tests/visual/baselines/`.
- Updated `docs/VALIDATION.md` and `docs/AGENT_HANDOFF.md` to instruct agents to use visual tests when touching UI.

## Combat Readability Polish V1 (Antigravity)

- **feature/combat-readability-polish-v1** - merged into main.
- **Purpose**: Improve tactical combat screen readability using procedural fallback and basic visual markers without adding new game mechanics or changing the rules.
- **Changes**:
  - HP (red), Armor (grey), and AP (yellow, active only) values draw as clear numerical badges on units in `CombatBoard.gd`.
  - Active and Selected units highlight via distinct hollow circular arcs rather than solid filled blocks.
  - Objective tokens (e.g. Wagons) render as distinct shapes (squares instead of circles) in the fallback procedural renderer.
  - Side panel UI uses rich BBCode color-coding to highlight Teams, Morale, HP, Armor, AP, Fatigue, and explicitly lists Injuries.
- **Visual Harness Result**: `python tools/run_visual_smoke.py` successfully caught the UI updates, requiring a manual update of `tests/visual/baselines/combat_board.png`. The baseline was updated, and all 5/5 screens now pass against the strict tolerance threshold (0.05% for the combat board).
- **SVG Loading**: Headless testing revealed that loading SVG assets via `Image.load(path)` fails to render them properly (producing blank white squares) without Godot's editor `.import` pipeline. The code correctly detects headless failure and preserves the robust procedural fallback rendering.
- **Remaining Limitations**: The combat visual presentation is still highly abstracted. Animations, hover previews (like range highlights or damage pathing), and dynamic status effects are not yet implemented.

## Settlement Factions V1 Merge (Antigravity)

- **feature/settlement-factions-v1-antigravity** - merged into main.
- **feature/event-rumor-memory-v1** - merged into main.
- **spec/deepseek-road-ui-playability-v1** - merged into main.
- Added `data/world/settlement_factions.json` with six faction types per settlement.
- Added `game/scripts/world/SettlementFactionSystem.gd`.
- `WorldEconomySystem.weekly_tick()` can apply faction drift when supplied faction data.
- `ContractGenerator.gd` can bias generated contract priority and rewards from dominant internal faction preferences.
- `RoadScreen.gd` has a simple internal faction debug readout.
- Added `tools/validate_settlement_factions.py` and `tools/tests/test_settlement_factions.py`.

### 5. Event/Rumor/Memory V1
**Status**: Merged into main.
**Next Steps**: Expand content templates in `data/world/event_templates.json`.

### 6. Road UI Playability Spec
**Status**: Spec merged into main (`docs/road_ui_playability_v1_spec.md`).

Commands run:
- `python tools/run_all_tests.py` on main after merge: **PASS** (10 validators, 67 simulation tests)
- `godot --headless ...` test suite: **PASS** (9/9 scenes load cleanly)

Known limitations:
- Placeholder visual assets are still primitive and lack polish.
- `CombatScreen` is purely a placeholder auto-resolve state and not fully playable.
- Events/rumors debug UI currently lives directly in `RoadScreen.gd` rather than an isolated view.
- No player control over camera or movement within settlements yet.

	
### 7. Road UI Playability V1 (Antigravity)
**Status**: Merged into main.
- **Pass A (Debug Readability)**: Added company resource strip and settlement economy text bars to `RoadScreen`. Updated route hover to show danger, traffic, bandits, patrols, trade flow, and status. `RoadMapCanvas` color-codes routes by danger and sizes settlements by market tier.
- **Pass B (Contract Board Clarity)**: `ContractBoard.gd` categorizes generated vs static contracts, adds type icons, and presents contract details (patron, expected effects, and generated reasons) cleanly.
- **Pass C (Aftermath Summary)**: `CampScreen.gd` groups consequence blocks and color-codes stat changes. `RoadScreen.gd` logs format rumors/memories with urgency-based bbcode highlighting.

Commands run for merge:
- `python tools/run_all_tests.py` on main: **PASS** (10 validators, 67 tests, Godot 9/9)
- `godot --headless` test suite: **PASS**

Remaining limitations:
- No real visual assets are used yet (everything is procedural or basic placeholder SVG).
- Layouts are still quite rigid and could use polish and animations.

## Contract Generator V1 Handoff

- Branch: `feature/contract-generator-v1`.
- Purpose: deterministic settlement contract boards from current settlement and route economy state.
- Static contracts remain in `data/contracts/contracts.json`; generated contracts are appended by `DataStore.contract_board_for_location()`.
- Added `data/contracts/contract_type_defaults.json`.
- Added `game/scripts/contracts/ContractGenerator.gd`.
- Added Python test mirror and validation in `tools/contract_generator_core.py`, `tools/validate_contract_generator.py`, and `tools/tests/test_contract_generator.py`.
- `ContractSystem.complete()` and `ContractSystem.fail()` can now apply generated settlement effects when passed `data.settlement_economy`.

Verification commands for this branch:

```powershell
python tools/validate_contract_generator.py
python -m unittest discover -s tools/tests -p test_contract_generator.py
python tools/run_all_tests.py
```

Known limitations:

- Generated boards are deterministic but not persisted across save/load.
- Board UX is still minimal; generated reasons are debug text only.
- The generator uses existing encounter IDs and does not introduce new combat content.
- Internal settlement factions are intentionally not implemented yet.

Next recommended task after merge: merge the settlement factions spec docs, then implement `feature/settlement-factions-v1`.

## Before Any Commit

Run:

1. `python tools/run_all_tests.py`
2. Godot headless test if available:
   `godot --headless --path . -s res://tools/godot/run_godot_tests.gd`
3. Visual regression testing if available and you touched UI:
   `python tools/run_visual_smoke.py`
4. A relevant targeted validator or test for the changed system.

Examples:

- World or contract data: `python tools/validate_data.py`
- Combat math or scripted autoplay: `python -m unittest discover -s tools/tests -p test_*.py`
- UI or scene wiring: `godot --headless --path . -s res://tools/godot/run_godot_tests.gd`
- UI design changes: run visual smoke tests and if intentional, `--accept-baseline`. Attach visual diffs/reports to handoff!

## Final Response Requirements

Every final agent response must include:

- commands run;
- pass/fail result;
- skipped tests and why;
- known broken behavior or residual risk.

## Determinism

Use seed `12345` for smoke and regression tests unless a task asks for a different seed. Random road events, ambush decisions, combat hit rolls, morale rolls, initiative ordering, and loot-like results should stay reproducible for a given seed.

## Rule Layer

Prefer adding testable logic to:

- `game/scripts/road/RoadSystem.gd`
- `game/scripts/contracts/ContractSystem.gd`
- `game/scripts/combat/CombatSystem.gd`
- `game/scripts/camp/CampSystem.gd`
- `game/scripts/core/AutoplaySmoke.gd`
- `game/scripts/world/WorldEconomySystem.gd`
- `game/scripts/world/RouteDynamicsSystem.gd`

UI screens should call those systems instead of duplicating rule logic.

## World Tick V1 Merge Status

- Merged into `main` from `feature/world-tick-v1`.
- Purpose: first deterministic settlement economy tick only.
- Main merge completed first: `integration/deepseek-docs-only` was merged into `main`; runtime changes from `design/deepseek-world-systems` remain intentionally excluded.
- MiniMax reference branches/data were not merged into runtime data.

## World Tick V1 Handoff

Implemented:

- deterministic weekly economy tick in `game/scripts/world/WorldEconomySystem.gd`;
- data files for trade goods, settlement economy, route economy, and settlement status effects under `data/world/`;
- validator `tools/validate_world_economy.py`;
- pure Python regression tests in `tools/tests/test_world_economy.py`;
- a small road-screen debug panel with an `Advance Week` button;
- Godot headless coverage for the economy tick.

Intentionally deferred:

- full world simulation;
- internal settlement factions;
- combat conditions from economy state;
- save/load persistence;
- procedural trade generation;
- MiniMax runtime data integration.

Verification commands run for merge:

```powershell
python tools/run_all_tests.py
python tools/validate_world_economy.py
python -m unittest discover -s tools/tests -p test_*.py
```

- Feature branch result before merge: `python tools/run_all_tests.py` passed.
- Main result after merge: `python tools/run_all_tests.py` passed.
- Godot headless result: passed through the local `.godot/bin/Godot_v4.6.2-stable_win64.exe` executable.
- Skipped tests: none.

Next recommended implementation task: connect the economy state to contract reward/danger modifiers through a small, testable adapter without changing combat rules.

## Route Dynamics V1 Handoff

- Merged into `main` from `feature/route-dynamics-v1`.
- Purpose: deterministic route economy changes from contract success/failure.
- Spec docs were merged to `main` first from `spec/deepseek-route-dynamics-v1`.
- Runtime behavior lives in `game/scripts/world/RouteDynamicsSystem.gd`.
- Existing contracts now define `route_effects_on_success` and `route_effects_on_failure`.
- Route economy entries now track `blocked_until_tick`, `route_history`, and `status`.
- `ContractSystem.complete()` and `ContractSystem.fail()` can apply route effects when passed a route economy entry.
- `WorldEconomySystem.weekly_tick()` clears expired route blocks, recalculates route status, and lets secure routes provide a small settlement benefit.
- Debug route delta UI is deferred; the rule layer and tests are in place first.

Verification commands run:

```powershell
python tools/validate_contracts.py
python tools/validate_world_economy.py
python -m unittest discover -s tools/tests -p test_*.py
python tools/run_all_tests.py
```

- Feature branch result before merge: `python tools/run_all_tests.py` passed.
- Main result after merge: `python tools/run_all_tests.py` passed.
- Godot headless result: passed through the local `.godot/bin/Godot_v4.6.2-stable_win64.exe` executable.
- Skipped tests: none.

Known limitations:

- There is no save/load persistence for `route_history` yet.
- Contract-driven route changes only apply when resolution code passes a route economy entry.
- Route status visuals and contract-board effect previews are deferred.
- No new contract types were added.

## Art Pipeline Spec Merge

- Merged into `main` from `spec/deepseek-art-pipeline-v1`.
- Spec files imported:
  - `docs/art_pipeline_v1_spec.md`
  - `prompts/codex_next/art_placeholder_pipeline_v1.md`
  - `data/schema_drafts/art_asset_manifest_schema_draft.json`
- No art pipeline runtime implementation was added.
- No generated image assets were added.
- `design/deepseek-world-systems` and MiniMax branches remain intentionally unmerged.

Verification commands run:

```powershell
python tools/run_all_tests.py
```

- Main result after art spec merge: `python tools/run_all_tests.py` passed.
- Godot headless result: passed through the local `.godot/bin/Godot_v4.6.2-stable_win64.exe` executable.
- Skipped tests: none.

Next recommended task: create `feature/art-placeholder-pipeline-v1` and implement the text-first placeholder art manifest and validation workflow from the spec, without adding binary art or changing gameplay.

## Art Placeholder Pipeline V1 Handoff

- Branch: `feature/art-placeholder-pipeline-v1`.
- Purpose: manifest-driven placeholder art assets for the current 2D prototype.
- Added `data/art/asset_manifest.json` as the authoritative asset list.
- Added deterministic SVG generation under `assets/generated/`.
- Added `tools/generate_placeholder_assets.py` and `tools/validate_art_assets.py`.
- Added lightweight art manifest tests in `tools/tests/test_art_assets.py`.
- `DataStore` now loads the asset manifest and exposes `get_asset(asset_id)`.
- Existing procedural combat and road drawing remain the runtime fallback.
- No final-quality art, generated PNGs, 3D assets, or large binary dumps were added.

Verification commands:

```powershell
python tools/generate_placeholder_assets.py
python tools/validate_art_assets.py
python -m unittest discover -s tools/tests -p test_art_assets.py
python tools/run_all_tests.py
```

Known limitations:

- Combat and road screens still draw procedurally; SVG runtime replacement is deferred.
- The manifest contains placeholder paths only, not final Imagen requests.
- Placeholder SVGs are intentionally simple and not production art.

Merge status: Merged into `main` via `feature/art-placeholder-pipeline-v1`. All validators and 38 simulation tests pass. Godot headless passes (9/9).

Next recommended task: `feature/contract-generator-v1` - implement world-state-based contract generation from `docs/contract_generator_v1_spec.md`.

## Docs-Only DeepSeek Integration

- Integration branch: `integration/deepseek-docs-only`
- DeepSeek docs imported:
  - `docs/AGENT_HANDOFF_DEEPSEEK.md`
  - `docs/agent_implementation_roadmap.md`
  - `docs/combat_design_battlebrothers_plus_dnd.md`
  - `docs/data_schema_plan.md`
  - `docs/economy_trade_growth_design.md`
  - `docs/emergent_story_design.md`
  - `docs/faction_settlement_design.md`
  - `docs/world_simulation_design.md`
- Runtime changes from `design/deepseek-world-systems` were intentionally not imported.
- Test harness changes from `design/deepseek-world-systems` were intentionally not imported.
- Validation result on this branch: `python tools/run_all_tests.py` passed, including Godot headless tests through the local `.godot/bin` executable.

## Contract Generator Spec Status

- Spec branch: `spec/deepseek-contract-generator-v1`.
- Spec files already present on `main` (included via art pipeline merge):
  - `docs/contract_generator_v1_spec.md` — full specification (7 contract types, trigger conditions, reward formulas)
  - `prompts/codex_next/contract_generator_v1.md` — implementable Codex prompt
  - `data/schema_drafts/contract_generator_schema_draft.json` — JSON schema draft
- No runtime implementation yet — spec/docs only.
- No separate merge required (already on main).

## Art Pipeline Merge (latest)

- Merged `feature/art-placeholder-pipeline-v1` into `main` via `--no-ff`.
- Commit: `0441cce` (merge), `74820a3` (feature tip).
- Commands run:
  - `python tools/run_all_tests.py` on feature branch: **PASS** (8 validators, 38 tests, Godot 9/9)
  - `python tools/run_all_tests.py` on main after merge: **PASS** (8 validators, 38 tests, Godot 9/9)
- 85 files added: 72 SVG placeholders, manifest, generator, validator, tests, doc updates.
- Skipped: none.
- Godot headless: `Godot_v4.6.2` — 9/9 passed.

Next recommended task: `feature/contract-generator-v1` — implement `ContractGenerator.gd` following `prompts/codex_next/contract_generator_v1.md`.

## Visual Asset Wiring Merge (Antigravity)

- Merged `feature/antigravity-visual-asset-wiring-v1` into `main` via `--no-ff`.
- Purpose: Wiring placeholder art assets to the UI gracefully and ensuring layout and missing assets don't crash.
- Modified `CombatScreen.gd` to pass `DataStore` to `CombatBoard`.
- Modified `CombatBoard.gd` to load SVG tokens (`token_fighter_...`, `token_enemy_...`, `token_wagon`) via `DataStore.get_asset()` with a fallback to procedural circles.
- Modified `RoadScreen.gd` to pass `DataStore` to `RoadMapCanvas`.
- Modified `RoadMapCanvas.gd` to load SVG icons for settlements (`icon_settlement_town`) and route danger indicators (`icon_danger_1` to `5`) via `DataStore.get_asset()` with a fallback to procedural drawing.
- Commands run:
  - `python tools/run_all_tests.py` on feature branch: **PASS** (8 validators, 50 tests, Godot 9/9)
  - `python tools/run_all_tests.py` on main after merge: **PASS**
- Godot headless result: `Godot_v4.6.2` headless test suite passed 9/9.
- Remaining visual limitations: SVGs are basic placeholders; combat and road screens still lack animations, rich UI containers, and dynamic visual states for things like unit injuries or route blockades.
