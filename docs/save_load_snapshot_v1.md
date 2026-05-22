# Save/Load Snapshot V1

Save/load snapshot v1 is a small explicit JSON persistence layer for the current prototype state.

## Save Path

- Autosave: `user://saves/autosave.json`
- Optional manual slot constant: `user://saves/manual_1.json`

In Godot, these paths resolve under the project user data directory.

## Schema

- `schema_version`: `1`
- Format: human-readable JSON
- Godot runtime: `game/scripts/core/SaveLoadSystem.gd`
- Python mirror: `tools/save_load_core.py`
- Optional validator: `python tools/validate_save_snapshot.py`

Required top-level fields:

- `schema_version`
- `saved_at_unix_time` or `saved_at_text`
- `game_day`
- `current_location`
- `company`
- `world`
- `contracts`
- `factions`
- `rumors`
- `memory`
- `rng_seed`
- `notes` or `debug_metadata`

## Persisted

- Current game day/tick.
- Current company location.
- Company resources: crowns, food, tools, medicine, ammunition, morale, vigor, renown.
- Party roster, graveyard, faction reputation, active contract, and last company summary.
- Current generated contract board snapshot for the current location.
- Settlement economy state.
- Route economy state, including route history and block/status fields.
- Settlement internal faction state.
- Active rumors.
- Memory log entries.
- Recent event summaries and event cooldowns.
- Deterministic run seed used by road, combat, and generated contract systems.

Static data such as locations, routes, base contracts, combat data, art manifests, and event templates still load from `data/` first. The save applies only mutable runtime sections over that clean data baseline.

## Runtime Use

`SaveLoadSystem.gd` can be called without UI:

- `build_snapshot(data, company, game_day, rng_seed, event_system, rumor_system, memory_system)`
- `save_snapshot(snapshot, SaveLoadSystem.AUTOSAVE_PATH)`
- `load_snapshot(SaveLoadSystem.AUTOSAVE_PATH)`
- `apply_snapshot(snapshot, data, company, event_system, rumor_system, memory_system)`

`Main.gd` exposes:

- `save_game()`
- `load_game()`

Debug shortcuts are available without visible UI changes:

- `F5`: save autosave
- `F9`: load autosave

## Validation

Run all tests:

```powershell
python tools/run_all_tests.py
```

Targeted save/load tests:

```powershell
python -m unittest discover -s tools/tests -p test_save_load_snapshot.py
python tools/validate_save_snapshot.py
```

Visual smoke should remain unchanged because no visible UI was added:

```powershell
python tools/run_visual_smoke.py
```

## Graceful Failure

Malformed JSON returns a clear load error instead of applying partial state. Missing `schema_version`, unsupported schema versions, and missing required top-level fields fail validation. Missing optional subsections inside required containers normalize to safe empty lists or objects.

## Not Persisted Yet

- In-progress combat screen tactical state.
- Pending travel state between route selection and aftermath.
- Full random generator internal stream position; v1 stores the deterministic run seed and current day/tick instead.
- UI layout, selected route, scroll positions, hover state, and screen-specific temporary labels.
- Static data file content; saves expect compatible project data for schema v1.

## Known Limitations

- Save/load is intended for road/company/world prototype state, not mid-combat resumes.
- Generated contract board state is saved for inspection and restoration safety, but the current UI still regenerates boards from world state, seed, and day when opened.
- There is no migration path beyond rejecting unsupported schema versions with a clear error.
