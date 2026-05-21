# Validation

The default verification command is:

```powershell
python tools/run_all_tests.py
```

Run it from the project root, `road_company/`.

## What It Checks

`tools/run_all_tests.py` detects the project root, then runs:

- JSON parsing and data validators.
- Faction, world, contract, company, and combat reference checks.
- Pure Python gameplay simulation tests for travel, contracts, combat math, travel-to-combat consequences, camp actions, and seed reproducibility.
- Godot headless tests if Godot is available.

The command exits nonzero if any required layer fails. If Godot is unavailable, it prints a `SKIP` line explaining why and still reports the Python/data result.

## Godot Detection

The harness checks:

1. `GODOT_BIN`
2. common executable names on PATH: `godot`, `godot4`, `godot.exe`, `godot4.exe`

Set `GODOT_BIN` when auto-detection fails:

```powershell
$env:GODOT_BIN="C:\Path\To\Godot_v4.x-stable_win64.exe"
python tools/run_all_tests.py
```

Linux or WSL:

```bash
export GODOT_BIN=/path/to/godot
python tools/run_all_tests.py
```

## Direct Commands

All local tests:

```powershell
python tools/run_all_tests.py
```

Data validation only:

```powershell
python tools/validate_data.py
python tools/validate_factions.py
python tools/validate_world.py
python tools/validate_contracts.py
python tools/validate_company.py
python tools/validate_combat.py
```

Pure simulation tests only:

```powershell
python -m unittest discover -s tools/tests -p test_*.py
```

Godot headless tests:

```powershell
godot --headless --path . -s res://tools/godot/run_godot_tests.gd
```

Autoplay smoke scenario:

```powershell
godot --headless --path . res://game/scenes/main/Main.tscn -- --autoplay=escort_smoke --seed=12345
```

## Godot Headless Coverage

The Godot test runner checks:

- main scene loads;
- main menu instantiates;
- road map instantiates;
- combat screen instantiates with escort wagon objective;
- camp aftermath instantiates;
- deterministic escort autoplay reaches aftermath without crashing.

## Codex Verification Rule

Before committing or handing off changes, run:

```powershell
python tools/run_all_tests.py
```

Then run the most relevant targeted command for the changed system. Examples:

- data-only change: `python tools/validate_data.py`
- combat rule change: `python -m unittest discover -s tools/tests -p test_*.py`
- scene/UI change with Godot available: `godot --headless --path . -s res://tools/godot/run_godot_tests.gd`

GdUnit4 may be useful later, but this prototype intentionally uses a small custom runner for now.
