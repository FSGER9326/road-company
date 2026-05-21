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

UI screens should call those systems instead of duplicating rule logic.

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
