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

## Current Verification Snapshot

- Branch: `design/deepseek-world-systems`
- Latest commit before this stabilization pass: `dc43930 docs: design dynamic world simulation systems`
- Commands run:
  - `git status`
  - `python tools/run_all_tests.py`
  - `python tools/run_all_tests.py` with local Godot executable available through `.godot/bin`
- Result: PASS
- Godot headless result: PASS with `Godot_v4.6.2-stable_win64.exe` copied locally under `.godot/bin`
- Skipped tests: none in the final run
- Known broken behavior: no known validation or headless smoke-test failure after this pass
- Remaining worktree note: DeepSeek design documents may be present on this branch and should not be merged into gameplay branches until intentionally reviewed
- Next recommended implementation task: keep the next pass focused on a small UI/test polish item, or intentionally merge/review design documents before starting world simulation implementation
