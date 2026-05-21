# Settlement Factions V1

Settlement Factions V1 adds small deterministic internal power groups to each settlement. It is a rule layer and data slice, not a full politics or quest system.

## Implemented

- `data/world/settlement_factions.json` defines six internal faction types for each current settlement.
- `data/world/settlement_economy.json` now stores derived faction state:
  - `dominant_internal_faction`
  - `faction_tension`
  - `local_policy_tags`
  - `active_internal_conflicts`
  - `last_faction_events`
- `game/scripts/world/SettlementFactionSystem.gd` implements deterministic influence drift, contract result effects, dominance, tension, and dominant economy modifiers.
- `WorldEconomySystem.weekly_tick()` can call the faction system when faction data is supplied.
- `ContractGenerator.gd` can bias generated contract priority/reward from the dominant internal faction.
- `RoadScreen.gd` shows a simple debug readout for internal factions at the current settlement.
- `tools/validate_settlement_factions.py` validates faction data and settlement-level derived state.
- `tools/tests/test_settlement_factions.py` covers the V1 rules.

## Rules

- Low security raises militia and criminal influence.
- Food shortage raises peasant commons influence.
- High prosperity raises merchant guild influence.
- Contract success raises patron influence and attitude.
- Helping a patron lowers rival attitudes.
- Dominance is deterministic: highest influence wins, with a fixed type-order tiebreaker.
- Tension is derived from rival pairs with both factions above 30 influence.
- Dominant faction economy modifiers are applied during weekly tick.
- Dominant faction contract preferences multiply generated contract score by `1.3` for supported types or `0.7` for opposed types.

## Deferred

- Event/rumor/memory systems.
- Faction event choices.
- Full nation politics.
- Dialogue, negotiation, and quest chains.
- Save/load persistence for faction drift.

## Validation

Run all checks:

```powershell
python tools/run_all_tests.py
```

Targeted checks:

```powershell
python tools/validate_settlement_factions.py
python -m unittest discover -s tools/tests -p test_settlement_factions.py
```

## Adding A Faction

Add an entry to `data/world/settlement_factions.json` with a unique `id`, a valid `settlement_id`, one of the six known `type` values, influence and attitude ranges, same-settlement rivals, contract preferences, and modifier dictionaries.

Run the targeted validator before committing.
