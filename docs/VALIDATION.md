# Validation

The default verification command is:

```powershell
python tools/run_all_tests.py
```

Run it from the project root, `road_company/`.

Agents should also use the workflow helpers:

```powershell
python tools/agent_status.py
python tools/agent_finish.py --skip-visual
```

Use `python tools/agent_finish.py` without `--skip-visual` when Godot is available and visual smoke should be part of the finish pass.

## What It Checks

`tools/run_all_tests.py` detects the project root, then runs:

- JSON parsing and data validators.
- Faction, world, contract, company, and combat reference checks.
- World economy data checks for trade goods, settlement economy, route economy, and settlement status effects.
- Art asset manifest and generated placeholder path checks.
- Pure Python gameplay simulation tests for travel, contracts, combat math, travel-to-combat consequences, camp actions, and seed reproducibility.
- Pure Python world economy tests for deterministic weekly settlement and route updates.
- Pure Python route dynamics tests for deterministic contract-driven route changes.
- Save/load snapshot schema validation and round-trip tests.
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

Agent status:

```powershell
python tools/agent_status.py
```

Agent finish report:

```powershell
python tools/agent_finish.py --skip-visual
```

All local tests:

```powershell
python tools/run_all_tests.py
```

Data validation only:

```powershell
python tools/validate_data.py
python tools/validate_factions.py
python tools/validate_world.py
python tools/validate_world_economy.py
python tools/validate_settlement_factions.py
python tools/validate_contracts.py
python tools/validate_contract_generator.py
python tools/validate_company.py
python tools/validate_combat.py
python tools/validate_art_assets.py
python tools/validate_event_rumor_memory.py
python tools/validate_save_snapshot.py
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
- deterministic world economy weekly tick runs;
- deterministic route dynamics contract effect runs;
- save/load snapshot round trip runs;
- deterministic escort autoplay reaches aftermath without crashing.

## Visual Regression Testing

There is an automated visual screenshot and comparison harness available. It captures screenshots of key game screens and compares them against baselines.

**Note:** This is *not* run by `run_all_tests.py` by default because visual rendering can depend on local GPU/Godot environments.

Run it directly (requires Godot):
```powershell
python tools/run_visual_smoke.py
```

If it reports missing baselines or if you intentionally changed the UI, you can accept the new baselines:
```powershell
python tools/run_visual_smoke.py --accept-baseline
```

For more details, see `docs/visual_regression_testing.md`.

## Agent Workflow Helpers

`tools/agent_status.py` prints branch, commit, dirty status, diff against `origin/main` or `main`, Godot availability, harness file availability, latest visual report summary, and recommended validation commands.

`tools/agent_finish.py` runs `git status`, diff against main, `python tools/run_all_tests.py`, and visual smoke when Godot is available unless `--skip-visual` is passed. It writes `artifacts/agent_reports/latest.md`.

Supported finish flags:

```powershell
python tools/agent_finish.py --skip-visual
python tools/agent_finish.py --force-visual
python tools/agent_finish.py --no-tests
python tools/agent_finish.py --report-path artifacts/agent_reports/custom.md
```

## World Economy Validation

`tools/validate_world_economy.py` checks:

- `data/world/trade_goods.json` parses and has unique trade good IDs;
- `data/world/settlement_status_effects.json` parses and has unique effect IDs;
- `data/world/settlement_economy.json` references valid location IDs;
- `data/world/route_economy.json` references valid route IDs;
- settlement status effects reference known effect IDs;
- prosperity, security, unrest, trade access, recruitment quality, route danger, traffic, road quality, trade flow, patrol presence, bandit pressure, and monster pressure remain in `0..100`;
- food, medicine, tools, and arms stocks are nonnegative;
- market tiers remain in `1..5`.
- route `blocked_until_tick` is `null` or a nonnegative integer;
- route `route_history` entries contain `tick`, `contract`, `outcome`, and `effects`;
- route `status` is `normal`, `stabilizing`, or `secure`.

Targeted command:

```powershell
python tools/validate_world_economy.py
```

The weekly tick regression tests live in `tools/tests/test_world_economy.py` and are included in:

```powershell
python -m unittest discover -s tools/tests -p test_*.py
```

## Route Dynamics Validation

Route dynamics is covered by:

- `tools/validate_contracts.py`, which validates `route_effects_on_success` and `route_effects_on_failure`;
- `tools/validate_world_economy.py`, which validates route block/status/history fields;
- `tools/tests/test_route_dynamics.py`, which checks escort success/failure, patrol-style route effects, bandit pressure reduction, clamping, determinism, history trimming, and settlement economy cascade.

Targeted commands:

```powershell
python tools/validate_contracts.py
python tools/validate_world_economy.py
python -m unittest discover -s tools/tests -p test_route_dynamics.py
```

## Contract Generator Validation

Contract generator validation is covered by:

- `tools/validate_contract_generator.py`, which checks `data/contracts/contract_type_defaults.json`, generated contract schemas, valid settlement/route/faction/encounter references, sane reward and urgency ranges, and compatible route/settlement effects;
- `tools/tests/test_contract_generator.py`, which checks deterministic generation, food and medicine shortage triggers, route danger triggers, bandit pressure triggers, defend settlement triggers, schema validation, effect compatibility, and priority changes from different world states.

Targeted commands:

```powershell
python tools/validate_contract_generator.py
python -m unittest discover -s tools/tests -p test_contract_generator.py
```

## Settlement Faction Validation

Settlement faction validation is covered by:

- `tools/validate_settlement_factions.py`, which checks `data/world/settlement_factions.json`, settlement references, duplicate IDs, influence and attitude ranges, same-settlement rival references, known faction types, valid contract type preferences, and settlement-level derived faction state fields;
- `tools/tests/test_settlement_factions.py`, which checks economy-driven influence shifts, contract success effects, rival attitude effects, deterministic dominance, tension, contract generator faction preferences, and validator failure cases.

Targeted commands:

```powershell
python tools/validate_settlement_factions.py
python -m unittest discover -s tools/tests -p test_settlement_factions.py
```

## Art Asset Validation

Art pipeline validation is covered by:

- `tools/validate_art_assets.py`, which checks `data/art/asset_manifest.json`, required asset IDs, unique IDs, allowed categories, supported extensions, existing generated files, and path boundaries;
- `tools/tests/test_art_assets.py`, which checks required token, terrain, settlement, condition, and faction manifest coverage;
- `tools/generate_placeholder_assets.py`, which deterministically regenerates small SVG placeholders under `assets/generated/`.

Targeted commands:

```powershell
python tools/generate_placeholder_assets.py
python tools/validate_art_assets.py
python -m unittest discover -s tools/tests -p test_art_assets.py
```

## Save/Load Snapshot Validation

Save/load snapshot v1 is covered by:

- `tools/validate_save_snapshot.py`, which validates the v1 schema shape and can validate a provided snapshot path;
- `tools/tests/test_save_load_snapshot.py`, which checks minimal valid snapshots, round-trip preservation of day/location/resources/world state, optional-section normalization, malformed JSON handling, and schema version failures;
- Godot headless coverage in `tools/godot/run_godot_tests.gd`, which builds and applies a snapshot through `SaveLoadSystem.gd`.

Targeted commands:

```powershell
python tools/validate_save_snapshot.py
python -m unittest discover -s tools/tests -p test_save_load_snapshot.py
```

See `docs/save_load_snapshot_v1.md` for save path, persisted fields, and limitations.

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
