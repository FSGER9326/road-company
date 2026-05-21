# Codex Next Prompt: Contract Generator V1

## Task
Implement deterministic world-state-based contract generation for ROAD COMPANY. Replace the static-only contract board with a system that reads settlement economy and route economy data to generate contracts that address actual world conditions.

## Prerequisites
Read before starting:
- `docs/contract_generator_v1_spec.md` — full specification
- `docs/world_tick_v1.md` — current settlement/route tick
- `docs/route_dynamics_v1_spec.md` — contract → route effect map
- `data/world/settlement_economy.json` — current settlement state
- `data/world/route_economy.json` — current route state
- `data/contracts/contracts.json` — existing contract schema (with route_effects)
- `game/scripts/contracts/ContractSystem.gd` — current contract resolution
- `game/scripts/world/WorldEconomySystem.gd` — `_connected_route_economies()`

## Branch
Stay on the current feature branch. Do not switch branches.

## Implementation Steps

### Step 1: Create contract type template data

New file: `data/contracts/contract_type_defaults.json`

Defines default values for each of the 7 contract types. Each entry has:
```json
{
  "type": "escort_caravan",
  "base_crowns": 350,
  "base_renown": 10,
  "encounter_id": "escort_ambush",
  "required_objective": "wagon_survives",
  "route_effects_success": {"bandit_pressure": -15, "danger": -3, "patrol_presence": 5, "traffic": 10, "trade_flow": 5},
  "route_effects_failure": {"bandit_pressure": 10, "danger": 5, "traffic": -10, "trade_flow": -5, "block_duration_ticks": 3},
  "settlement_effects_success": {"food_stock": 80, "trade_access": 5},
  "settlement_effects_failure": {"unrest": 5, "prosperity": -3},
  "trigger_condition": "food_shortage",
  "title_template": "Escort {cargo} to {target}",
  "description_template": "{target_name}'s {goods} are running thin. {patron_name} is hiring escorts.",
  "success_template": "The {cargo} reaches {target_name}. {patron_name} pays with relief.",
  "failure_template": "The {cargo} never arrived. {target_name}'s shortages deepen."
}
```

Fill out one entry for each of the 7 types with full template strings.

### Step 2: Create ContractGenerator.gd

New file: `game/scripts/contracts/ContractGenerator.gd`

```gdscript
class_name ContractGenerator
extends RefCounted

const SeededRngScript = preload("res://game/scripts/core/SeededRng.gd")

var defaults: Array = []          # loaded from contract_type_defaults.json
var rng: SeededRng

func configure(new_defaults: Array, seed: int) -> void:
    defaults = new_defaults
    rng = SeededRngScript.new()
    rng.configure(seed)

func generate_contracts(
    current_location: String,
    settlement_economies: Array,
    route_economies: Array,
    route_links: Array,
    faction_reputation: Dictionary,
    existing_contracts: Array,
    locations: Array,
    factions: Array,
    tick: int
) -> Array:
    # 1. For each connected settlement, evaluate trigger conditions
    # 2. Score each contract type based on world state
    # 3. Select top 1-3 by score + deterministic weighted random
    # 4. Build full contract dictionary from type defaults + generated fields
    # 5. Return array of contract dictionaries
```

### Step 3: Implement core generation functions

In `ContractGenerator.gd`, implement these private functions:

```gdscript
func _evaluate_triggers(settlement, connected_routes) -> Dictionary:
    # Returns {"escort_caravan": score, "deliver_medicine": score, ...}
    # Score based on spec section 4 trigger conditions

func _build_contract(type, settlement, target_settlement, route, urgency, danger, reward, tick, seed) -> Dictionary:
    # Assembles full contract from defaults + generated fields
    # Generates id from type + origin + target + seed_counter
    # Fills in title, description, success/failure text from templates

func _calculate_reward(base, danger, urgency, route_days, prosperity) -> int:
    # reward = round(base * danger_mult * urgency_mult * distance_mult * wealth_mult)

func _calculate_danger(settlement, route) -> int:
    # For routed contracts: clamp(round(route.danger * 0.08 + bandit_pressure * 0.04), 1, 10)
    # For settlement contracts: clamp(round((100 - security + unrest) / 20), 1, 10)

func _calculate_urgency(score) -> int:
    # clamp(ceil(score / 20), 1, 5)

func _pick_target_settlement(current, candidates) -> Dictionary:
    # For delivery contracts: pick settlement with worst relevant stat
    # For patrol/hunt: pick route's other end

func _pick_patron_faction(settlement, faction_reputation) -> String:
    # Pick faction present in settlement with highest relationship
    # Default to first faction with influence in that settlement

func _assign_danger_encounter(type, danger) -> String:
    # Map contract type + danger to encounter_id
    # escort: escort_ambush, hunt: oldwood_raiders, patrol: road_raiders, etc.
```

### Step 4: Wire generator into ContractBoard

In `game/scripts/ui/ContractBoard.gd`:
- Add a `var generator: ContractGenerator` member
- In initialization, call `generator.generate_contracts(...)` to produce dynamic contracts
- Show generated contracts below existing static contracts
- Add a small debug label under each generated contract showing the generation reason

### Step 5: Wire generator trigger on world tick

In `game/scripts/main/Main.gd` or wherever the weekly tick happens:
- After `WorldEconomySystem.weekly_tick()` completes, re-generate contracts for the player's current location
- This makes the contract board refresh with the new world state each week

### Step 6: Create contract generator validator

New file: `tools/validate_contract_generator.py`

```python
def validate() -> list[str]:
    errors = []
    # Load all data files
    settlements = load("data/world/settlement_economy.json")
    routes = load("data/world/route_economy.json")
    route_links = load("data/world/routes.json")
    locations = load("data/world/locations.json")
    factions = load("data/factions/factions.json")
    contracts = load("data/contracts/contracts.json")
    defaults = load("data/contracts/contract_type_defaults.json")
    
    # Validate defaults: all 7 types present, required fields present
    # Run generator with seed 12345 and validate output
    # Check every generated contract has valid references
    # Check every reward is in range
    # Check every danger/urgency in range
    # Check no duplicate IDs
    
    return errors
```

### Step 7: Write contract generator tests

New file: `tools/tests/test_contract_generator.py`

Required tests (12 total):
1. `test_starving_settlement_generates_food_contract`
2. `test_dangerous_route_generates_hunt_or_patrol`
3. `test_low_medicine_generates_deliver_contract`
4. `test_high_unrest_generates_bounty`
5. `test_low_security_generates_defend`
6. `test_same_seed_produces_same_contracts`
7. `test_different_state_produces_different_priorities`
8. `test_generated_contract_has_valid_route_effects`
9. `test_generated_contract_has_valid_settlement_effects`
10. `test_stable_settlement_generates_fewer`
11. `test_nonregression_static_contracts_still_appear`
12. `test_reward_within_bounds`

All tests must be deterministic — use the Python port of the generation logic (no Godot dependency).

### Step 8: Wire into run_all_tests.py

In `tools/run_all_tests.py`, add:
```python
"tools/validate_contract_generator.py",
```
to the validators list.

### Step 9: Update docs

In `docs/AGENT_HANDOFF.md`, append under "## Docs-Only DeepSeek Integration":
```
- Contract generator V1: `docs/contract_generator_v1_spec.md`
```

## Acceptance Criteria

- [ ] `data/contracts/contract_type_defaults.json` has entries for all 7 contract types
- [ ] `ContractGenerator.gd` implemented with all core functions
- [ ] `generate_contracts()` produces contracts from world state deterministically
- [ ] Starving settlement → food delivery contracts
- [ ] Dangerous route → patrol/hunt contracts
- [ ] Same seed same state = identical output
- [ ] All generated contracts pass validation
- [ ] 12 contract generator tests pass
- [ ] `python tools/validate_contract_generator.py` passes
- [ ] `python tools/run_all_tests.py` exits zero
- [ ] Existing autoplay smoke still reaches aftermath

## File Preservation
- Do NOT modify `game/scenes/` files
- Do NOT modify `project.godot`
- Do NOT delete or rewrite existing static contracts in `contracts.json`
- New files in `game/scripts/contracts/`, `data/contracts/`, `tools/`
- Extend `ContractBoard.gd` (additive, show generated contracts below static ones)
- Extend `Main.gd` (add regeneration call on weekly tick, optional)

## After Implementation
Run and report:
```
python tools/validate_contract_generator.py
python tools/run_all_tests.py
```
