# Visual Regression Testing

Road Company uses a visual regression harness to automatically capture screenshots of key scenes (Main Menu, Road Map, Contract Board, Combat Board, Aftermath Camp) and compare them against baselines.

## How it works

1. **Capture**: A Godot headless script (`tools/godot/capture_visual_screens.gd`) loads each core UI scene, populates it deterministically (using a fixed seed), and captures a screenshot.
2. **Compare**: A Python script (`tools/compare_visual_screens.py`) uses Pillow to compare the new screenshots in `tests/visual/runs/latest/` against `tests/visual/baselines/`.
3. **Report**: An automated report is generated indicating whether the screens match exactly or if differences were found.

## How to run screenshots

Run the full suite using Python:
```bash
python tools/run_visual_smoke.py
```

This will automatically execute the Godot script and then run the comparison script.
You can find the run results in `tests/visual/runs/latest/`, including:
- Captured PNGs
- `report.json`
- `report.md`
- `*_diff.png` (if there are differences)

## How to compare manually

If you only want to re-run the comparison step against an existing run:
```bash
python tools/compare_visual_screens.py
```

## How to accept new baselines

If you intentionally changed the UI and want to update the baselines:
```bash
python tools/run_visual_smoke.py --accept-baseline
```
Or just for the compare step:
```bash
python tools/compare_visual_screens.py --accept-baseline
```

## For Agents

- **Handoff**: When completing a task that modifies the UI, you should run the visual regression harness and attach the `tests/visual/runs/latest/report.md` (or relevant diffs/images) to the handoff so the user can verify the change.
- **Accidental Noise**: Make sure you do not commit anything inside `tests/visual/runs/` as they are ignored. Only `tests/visual/baselines/` and its contents should be committed.
- **Missing Godot**: If Godot is unavailable in the environment, the `run_visual_smoke.py` script will fail cleanly. In this case, notify the user that visual testing was skipped.
