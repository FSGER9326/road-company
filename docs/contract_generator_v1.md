# Contract Generator V1

Contract Generator V1 creates deterministic settlement contract boards from the current world economy and route economy state. Static contracts remain available; generated contracts are appended to the board for the current settlement.

## Implemented

- `game/scripts/contracts/ContractGenerator.gd` generates contracts from seed plus world state.
- `data/contracts/contract_type_defaults.json` defines the seven V1 contract type defaults.
- `DataStore.contract_board_for_location()` combines static and generated contracts.
- `ContractBoard.gd` displays generated contract reasons in a small debug line.
- `ContractSystem.gd` can apply generated settlement economy effects on success or failure.
- Python mirror logic in `tools/contract_generator_core.py` supports deterministic simulation tests.
- `tools/validate_contract_generator.py` validates defaults and generated contract schemas.

Supported generated types:

- `escort_caravan`
- `patrol_route`
- `hunt_bandits`
- `recover_wagon`
- `deliver_medicine`
- `defend_settlement`
- `bounty_target`

## Deferred

- Internal settlement factions.
- Multi-stage quest chains.
- New encounter types.
- Save/load persistence for generated boards.
- Final contract-board UX for sorting, filtering, previews, and expiry.

## Trigger Rules

The generator evaluates the current settlement, connected settlements, and connected route economy entries:

- Low food stock creates `escort_caravan`.
- Low medicine stock creates `deliver_medicine`.
- Low trade access creates `escort_caravan` or `recover_wagon`.
- Low security creates `defend_settlement`.
- High unrest creates `bounty_target`.
- High route danger creates `patrol_route`, `escort_caravan`, or `recover_wagon`.
- High bandit pressure creates `hunt_bandits` or `patrol_route`.

Candidates are scored deterministically, adjusted by a small seed-based jitter, sorted by score, deduplicated by type/target, and capped to 1-3 contracts based on local pressure.

## Validation

Run all checks:

```powershell
python tools/run_all_tests.py
```

Targeted checks:

```powershell
python tools/validate_contract_generator.py
python -m unittest discover -s tools/tests -p test_contract_generator.py
```

The validator checks default type coverage, valid encounter references, generated contract required fields, location/route/faction references, reward ranges, route effects, and settlement effects.

## Adding A Contract Type Default

Add one entry to `data/contracts/contract_type_defaults.json` with:

- type and base rewards;
- an existing `encounter_id`;
- route success/failure effects compatible with `RouteDynamicsSystem`;
- settlement success/failure effects compatible with settlement economy fields;
- title, description, success, and failure templates.

Then update `CONTRACT_TYPES` in both:

- `game/scripts/contracts/ContractGenerator.gd`
- `tools/contract_generator_core.py`

Run the targeted validator and full harness before committing.
