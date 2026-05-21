# Codex Next Prompt: Route Dynamics V1

## Task
Implement player-contract-driven route state modification on top of `feature/world-tick-v1`. Make contracts the primary lever players use to stabilize or destabilize routes.

## Prerequisites
Read before starting:
- `docs/route_dynamics_v1_spec.md` — full specification
- `docs/world_tick_v1.md` — current tick system overview
- `game/scripts/world/WorldEconomySystem.gd` — existing route tick logic
- `game/scripts/contracts/ContractSystem.gd` — current contract resolution
- `tools/tests/test_world_economy.py` — existing tests (must keep passing)

## Branch
Work on `feature/world-tick-v1`. Do not switch branches.

## Implementation Steps

### Step 1: Extend contract data with route effects

In `data/contracts/contracts.json`, add `route_effects_on_success` and `route_effects_on_failure` to all 4 contracts:

```
escort_embermill:
  success: bandit_pressure=-15, patrol_presence=5, traffic=10
  failure: bandit_pressure=10, traffic=-10, block_duration_ticks=3

hunt_red_sashes:
  success: bandit_pressure=-25, monster_pressure=-5
  failure: bandit_pressure=15

recover_wagon:
  success: bandit_pressure=-10
  failure: bandit_pressure=10

capture_gravetithe:
  success: bandit_pressure=-5, patrol_presence=5
  failure: bandit_pressure=5
```

### Step 2: Extend route economy data

In `data/world/route_economy.json`, add to each route entry:
```json
"blocked_until_tick": null,
"route_history": [],
"status": "normal"
```

### Step 3: Add settlement status effect

In `data/world/settlement_status_effects.json`, add:
```json
{
  "id": "route_secure",
  "name": "Route Secure",
  "duration_ticks": 1,
  "modifiers": { "prosperity": 1, "unrest": -1 },
  "description": "Connected roads are patrolled and safe, easing local fears."
}
```

### Step 4: Create RouteDynamicsSystem.gd

New file: `game/scripts/world/RouteDynamicsSystem.gd`

```
class_name RouteDynamicsSystem
extends RefCounted

const STATUS_NORMAL = "normal"
const STATUS_STABILIZING = "stabilizing"
const STATUS_SECURE = "secure"
const HISTORY_MAX = 20
const STABILIZING_SUCCESSES = 3
const SECURE_SUCCESSES = 6
const SECURE_DANGER_MAX = 30

func apply_contract_success(contract: Dictionary, route_data: Dictionary, current_tick: int) -> Dictionary:
    # Apply route_effects_on_success deltas, clamp 0..100
    # Append {tick, contract: contract.id, outcome: "success", effects: applied_deltas} to route_history
    # Trim history to HISTORY_MAX
    # Call recalculate_status()
    # Return {route_id, before: dict, after: dict}

func apply_contract_failure(contract: Dictionary, route_data: Dictionary, current_tick: int) -> Dictionary:
    # Apply route_effects_on_failure deltas, clamp 0..100
    # If block_duration_ticks in effects: set blocked=true, blocked_until_tick = current_tick + block_duration_ticks
    # Append to route_history
    # Return {route_id, before: dict, after: dict, blocked_for: int|null}

func recalculate_status(route_data: Dictionary) -> String:
    # Count "outcome":"success" entries in route_history
    # If >= SECURE_SUCCESSES and danger <= SECURE_DANGER_MAX: return STATUS_SECURE
    # Elif >= STABILIZING_SUCCESSES: return STATUS_STABILIZING
    # Else: return STATUS_NORMAL

func get_settlement_effect_ids(route_data: Dictionary) -> Array:
    # If status == STATUS_SECURE: return ["route_secure"]
    # Elif status == STATUS_STABILIZING: return []
    # Else: return []

func clear_expired_blocks(route_data: Dictionary, current_tick: int) -> void:
    # If blocked_until_tick != null and current_tick >= blocked_until_tick:
    #    blocked = false, blocked_until_tick = null

func apply_status_modifiers(route_data: Dictionary) -> void:
    # Called during weekly tick after normal danger/traffic calculation
    # If status == STATUS_STABILIZING: halve bandit_pressure autonomous growth
    # If status == STATUS_SECURE: floor patrol_presence at 30, quarter bandit growth
    # The autonomous growth that comes from the tick itself should be multiplied by 0.5 or 0.25
    # This means bandit_pressure should be nudged BACK toward pre-growth after the tick
    # OR: the tick formula should read the status multiplier and apply it during growth calculation
```

### Step 5: Wire ContractSystem → RouteDynamicsSystem

In `game/scripts/contracts/ContractSystem.gd`:
- Add a `var route_dynamics: RouteDynamicsSystem` member
- Add a `func configure_route_dynamics(system: RouteDynamicsSystem) -> void` setter
- In `complete()`, after company reward logic: look up route economy entry by contract.target_route, call `route_dynamics.apply_contract_success()`
- In `fail()`, after company penalty logic: call `route_dynamics.apply_contract_failure()`

### Step 6: Wire WorldTickSystem → RouteDynamicsSystem

In `game/scripts/world/WorldEconomySystem.gd` `_tick_route()`:
- Before existing logic: call `route_dynamics.clear_expired_blocks(route, current_tick)`
- After existing trade_flow calculation: call `route_dynamics.recalculate_status(route)`
- After status recalc: if status is stabilizing/secure, apply status modifiers to the autonomous drift

In `_tick_settlement()`:
- After computing connected routes: for each secure route, add `route_secure` to the settlement's status_effects (if not already present)
- The status effects table already handles applying modifiers

### Step 7: Wire DataStore to load route_dynamics data

In `game/scripts/core/DataStore.gd`:
- Already loads route_economy.json (world_tick_v1 added this)
- Add a method `get_route_economy(route_id: String) -> Dictionary` that looks up by route_id
- This is needed by ContractSystem to find the route to modify

### Step 8: Extend validators

In `tools/validate_world_economy.py`:
- Add checks for `blocked_until_tick` (int or null, >= 0)
- Add checks for `route_history` (list, each entry has tick/contract/outcome/effects)
- Add checks for `status` (one of normal/stabilizing/secure)

In `tools/validate_contracts.py`:
- Add checks for `route_effects_on_success` (dict, numeric values, allowed keys)
- Add checks for `route_effects_on_failure` (dict, numeric values, optional block_duration_ticks 1-52)

### Step 9: Write tests

New file: `tools/tests/test_route_dynamics.py`

Required tests (8 minimum, 9 recommended):
1. `test_escort_success_reduces_bandit_pressure`
2. `test_hunt_failure_increases_bandit_pressure`
3. `test_escort_failure_blocks_route`
4. `test_block_expires_after_duration`
5. `test_route_stabilizes_after_three_successes`
6. `test_route_becomes_secure_after_six_successes`
7. `test_route_effects_clamped_0_100`
8. `test_settlement_receives_route_secure_effect`
9. `test_nonregression_world_tick_still_passes`

All tests must use deterministic input (no random) — the functions are pure math.

Update `tools/tests/test_world_economy.py`:
- The `test_determinism` test must still pass with the extended route economy fields
- If needed, update test fixtures to include new fields (blocked_until_tick, route_history, status)

## Acceptance Criteria

- [ ] All 4 contracts have `route_effects_on_success` and `route_effects_on_failure`
- [ ] `apply_contract_success()` modifies route economy and appends history
- [ ] `apply_contract_failure()` with `block_duration_ticks` sets `blocked=true` and `blocked_until_tick`
- [ ] `clear_expired_blocks()` unblocks routes after duration expires
- [ ] `recalculate_status()` correctly returns normal/stabilizing/secure based on success count
- [ ] Secure routes add `route_secure` status effect to connected settlements
- [ ] All values clamped 0..100
- [ ] 8+ route dynamics tests pass
- [ ] All existing world_tick_v1 tests still pass
- [ ] All validators pass
- [ ] `python tools/run_all_tests.py` exits zero
- [ ] Existing autoplay smoke still reaches aftermath

## File Preservation
- Do NOT modify existing scene files
- Do NOT modify `project.godot`
- Do NOT modify `game/scenes/` or `game/scripts/ui/`
- New files go in `game/scripts/world/` and `tools/tests/`
- Data extensions go in existing `data/` files

## After Implementation
Run and report results:
```
python tools/run_all_tests.py
```
