# Agent Handoff

ROAD COMPANY is designed so coding agents can verify the core loop without manual clicking. Keep changes small, deterministic, and data-first.

## Before Any Commit

Run:

1. `python tools/run_all_tests.py`
2. Godot headless test if available:
   `godot --headless --path . -s res://tools/godot/run_godot_tests.gd`
3. A relevant targeted validator or test for the changed system.

Examples:

- World or contract data: `python tools/validate_data.py`
- Combat math or scripted autoplay: `python -m unittest discover -s tools/tests -p test_*.py`
- UI or scene wiring: `godot --headless --path . -s res://tools/godot/run_godot_tests.gd`

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
