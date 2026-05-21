# Codex Next Prompt: Settlement Internal Factions V1

## Task
Implement internal settlement factions for ROAD COMPANY. Each settlement gets 2-6 competing power groups whose influence shifts with the economy, player contracts, and faction events. The dominant faction modifies settlement economy and biases contract generation.

## Prerequisites
Read before starting:
- `docs/settlement_factions_v1_spec.md` — full specification
- `docs/world_tick_v1.md` — current economy tick
- `data/world/settlement_economy.json` — settlement data to extend
- `game/scripts/world/WorldEconomySystem.gd` — weekly tick to extend

## Branch
Stay on the current feature branch. Do not switch branches.

## Implementation Steps

### Step 1: Create faction type definitions

New file: `data/factions/faction_types.json`

Define 6 faction types: `ruling_authority`, `merchant_guild`, `militia_command`, `temple_chapter`, `criminal_network`, `peasant_commons`. Each has: `type`, `name`, `default_influence`, `economy_modifiers`, `supported_contract_types`, `opposed_contract_types`, `agenda_tags`, `rival_type`.

### Step 2: Create internal faction data

New file: `data/factions/internal_factions.json`

Create 3-6 factions per settlement for all 3 settlements. Each faction needs: `faction_id`, `settlement_id`, `name`, `type`, `influence`, `attitude_to_company`, `rival_faction_ids`.

Use naming convention: `{settlement}_{descriptor}`. Example: `blackford_gate_nobility`.

### Step 3: Extend settlement economy with faction fields

In `data/world/settlement_economy.json`, add to each settlement:
```json
"dominant_faction_id": "",
"faction_tension": 0,
"local_policy_tags": [],
"active_internal_conflicts": [],
"last_faction_event_tick": 0
```

### Step 4: Create SettlementFactionSystem.gd

New file: `game/scripts/world/SettlementFactionSystem.gd`

Implement:
- `configure(faction_types, factions)` — load and index data
- `get_factions_for_settlement(sid)` — filter by settlement
- `faction_weekly_tick(settlement, current_tick)` — main tick function:
  - Apply economy-driven influence shifts (spec section 3)
  - Apply contract-driven shifts from settlement._pending_contract_results
  - Apply attitude decay toward 0
  - Recalculate dominant_faction_id
  - Recalculate faction_tension
  - Apply dominant faction economy modifiers
  - Check for faction events (cooldown: 4 ticks)
  - Return `{faction_changes, dominant_faction_id, tension, events_triggered}`

### Step 5: Create faction event definitions

New file: `data/events/faction_events.json`

Define 12 events following spec section 6. Events need trigger conditions and 2-3 choices.

### Step 6: Wire into WorldEconomySystem

In `game/scripts/world/WorldEconomySystem.gd`, in `_tick_settlement()`:
- After economy tick, call `faction_system.faction_weekly_tick(settlement, tick)`
- Apply dominant faction economy modifiers from result

### Step 7: Integrate with ContractGenerator (if exists)

In `ContractGenerator.gd` (if implemented):
- Boost priority ×1.3 if type matches dominant faction's supported types
- Penalize priority ×0.7 if type matches opposed types
- Adjust reward by `faction.attitude_to_company / 200.0`

### Step 8: Create validator and tests

- `tools/validate_internal_factions.py` — check IDs, references, ranges
- `tools/tests/test_internal_factions.py` — 13 tests following spec section 8
- Wire validator into `tools/run_all_tests.py`

## Acceptance Criteria
- `data/factions/faction_types.json` with 6 types
- `data/factions/internal_factions.json` with factions for 3 settlements
- `SettlementFactionSystem.gd` with weekly tick
- Settlement economy extended with faction state fields
- 12 faction events in `data/events/faction_events.json`
- Validator passes, 13 tests pass
- `python tools/run_all_tests.py` exits zero
- Existing autoplay smoke still passes

## File Preservation
- Do NOT modify `game/scenes/` or `project.godot`
- Extend `WorldEconomySystem.gd` (additive: call faction tick after economy tick)
- New files in `data/factions/`, `data/events/`, `game/scripts/world/`, `tools/`

## After Implementation
```
python tools/validate_internal_factions.py
python tools/run_all_tests.py
```
