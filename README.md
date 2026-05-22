# ROAD COMPANY

ROAD COMPANY is a Godot 4.x 2D prototype for a dark fantasy mercenary caravan-company RPG. The current build is a playable vertical slice: start at a settlement, accept a contract, travel connected roads, consume supplies, enter a tactical ambush, resolve combat, review aftermath, take camp actions, and return to the road layer.

## Run the Prototype

1. Open Godot 4.x.
2. Import or open this folder: `road_company/`.
3. Run the project. The main scene is `game/scenes/main/Main.tscn`.
4. Choose `New Prototype Run`.

Godot was not found on PATH in the creation environment, so the project was prepared as text-first Godot files and validated with Python.

For multi-agent task flow and handoff conventions, see `docs/CODEX_ORCHESTRATION.md`.


## Run Validators

From the project folder:

```powershell
python tools/run_all_tests.py
python tools/validate_data.py
python tools/validate_world.py
python tools/validate_contracts.py
python tools/validate_combat.py
```

`tools/run_all_tests.py` is the default local verification command. It runs all validators, pure Python gameplay simulation tests, and Godot headless tests when a Godot executable is available.

If Godot is not auto-detected, set `GODOT_BIN`:

```powershell
$env:GODOT_BIN="C:\Path\To\Godot_v4.x-stable_win64.exe"
python tools/run_all_tests.py
```

Direct Godot headless command:

```powershell
godot --headless --path . -s res://tools/godot/run_godot_tests.gd
```

Autoplay smoke run, if Godot is available:

```powershell
godot --headless --path . res://game/scenes/main/Main.tscn -- --autoplay=escort_smoke --seed=12345
```

## Current Prototype Includes

- Main menu / debug launcher.
- JSON-driven world with 3 settlements and 7 routes.
- Runtime company state with supplies, morale, vigor, reputation, roster, graveyard, and active contract.
- Contract board with escort, hunt, recovery, and bounty contract data.
- Travel costs, danger checks, low-vigor consequences, route terrain tags, and combat entry.
- Axial hex tactical combat with AP, fatigue, armor/HP split, morale checks, injuries, death, basic AI, and combat log.
- Escort ambush objective with a wagon token that enemies can attack.
- Aftermath and camp panel with Rest, Repair, Treat Wounds, and Continue.
- Python data validators.
- Deterministic rule helpers for road, contract, camp, and combat setup/math.
- One-command automated test harness with pure simulation tests and optional Godot headless tests.

## Next Development Steps

- Add proper save/load after the prototype loop stabilizes.
- Improve tactical UX with reachable hex highlights and target previews.
- Add more road events and non-combat contract resolutions.
- Add a small token art generator or layered 2D paper-doll assets.
- Expand AI behavior only after the core loop feels reliable.
- Consider GdUnit4 later if the project outgrows the lightweight custom test runner.
