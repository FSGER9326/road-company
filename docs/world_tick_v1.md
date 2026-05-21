# World Tick V1

This slice adds a deterministic weekly settlement economy tick. It is intentionally small: the goal is to make settlement and route pressure testable without starting the full world simulation.

## Implemented

- Trade goods data in `data/world/trade_goods.json`.
- Settlement economy state in `data/world/settlement_economy.json`.
- Route economy state in `data/world/route_economy.json`.
- Settlement status effect definitions in `data/world/settlement_status_effects.json`.
- Rule logic in `game/scripts/world/WorldEconomySystem.gd`.
- World economy validation in `tools/validate_world_economy.py`.
- Deterministic Python tests in `tools/tests/test_world_economy.py`.
- Godot headless smoke coverage for the weekly economy tick.
- Minimal road-screen debug UI showing current settlement economy and an `Advance Week` action.

## Deferred

- Full world simulation.
- Internal settlement factions.
- Contract generation from economy state.
- Combat conditions from settlement or route economy.
- Save/load persistence.
- Random economy events.
- MiniMax reference data integration.

## Weekly Tick Formula

Routes tick first:

- blocked routes set `traffic` and `trade_flow` to `0`;
- blocked routes gain a small danger increase;
- open route traffic changes from road quality and patrol presence versus pressure and danger;
- route danger changes from pressure versus road quality and patrol presence;
- trade flow is the clamped average of traffic, road quality, patrol presence, and inverse danger.

Settlements tick after routes:

- weekly food need is `ceil(population / 250)`;
- food stock is reduced by weekly need and clamped at `0`;
- hunger is detected when starting food is less than two weeks of need;
- hunger increases unrest and reduces prosperity;
- trade access changes from connected route trade flow;
- prosperity changes from food, trade access, security, and unrest;
- population changes slightly based on prosperity, security, unrest, and shortage;
- market tier is derived from population and prosperity and clamped to `1..5`;
- recruitment quality is derived from prosperity, security, and unrest.

All public values are clamped to sane ranges after each tick.

## Data Ranges

- `prosperity`, `security`, `unrest`, `trade_access`, and `recruitment_pool_quality`: `0..100`.
- `market_tier`: `1..5`.
- settlement stocks: nonnegative integers.
- route `traffic`, `danger`, `road_quality`, `trade_flow`, `patrol_presence`, `bandit_pressure`, and `monster_pressure`: `0..100`.

## Adding A Settlement Economy Entry

1. Add the settlement to `data/world/locations.json` first.
2. Add one matching object to `data/world/settlement_economy.json`.
3. Use the location `id` as `settlement_id`.
4. Add only status effect IDs that exist in `data/world/settlement_status_effects.json`.
5. Run:

```powershell
python tools/validate_world_economy.py
python tools/run_all_tests.py
```

## Running Tests

Full verification:

```powershell
python tools/run_all_tests.py
```

Targeted world economy checks:

```powershell
python tools/validate_world_economy.py
python -m unittest discover -s tools/tests -p test_*.py
```

Godot headless, when available:

```powershell
godot --headless --path . -s res://tools/godot/run_godot_tests.gd
```

## Known Limitations

- The debug UI mutates runtime data only; it is not saved.
- Trade goods are validated but not yet priced or traded by markets.
- Status effect modifiers are data-only in V1.
- Route economy affects settlement trade access only through simple connected-route averages.
- The Python tests mirror the current formulas; update them with the GDScript when formulas intentionally change.
