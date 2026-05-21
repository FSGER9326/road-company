# Route Dynamics V1 — Specification

## Purpose
Add player-contract-driven route state modification on top of the existing `world_tick_v1` autonomous route tick. Make contracts the primary lever players use to stabilize or destabilize routes, linking contract outcomes to settlement economy health through route trade_flow.

## Scope
Single Codex pass. Builds on `feature/world-tick-v1`. Does not add new contract types, new settlement systems, or event generation.

---

## 1. Current State (world_tick_v1)

### What Already Exists

| File | Contents |
|------|----------|
| `data/world/route_economy.json` | 7 routes with `traffic, danger, road_quality, trade_flow, patrol_presence, bandit_pressure, monster_pressure, blocked` |
| `data/world/settlement_economy.json` | 3 settlements responding to connected route `trade_flow` |
| `game/scripts/world/WorldEconomySystem.gd` | `weekly_tick()` and `_tick_route()` with autonomous drift: traffic shifts from safety minus pressure, danger shifts from pressure minus safety, trade_flow is clamped average |
| `tools/validate_world_economy.py` | Validates all route and settlement economy fields |
| `tools/tests/test_world_economy.py` | 7 tests covering food, trade, danger, clamping, determinism |
| `data/contracts/contracts.json` | 4 static contracts with `target_route` field |
| `game/scripts/contracts/ContractSystem.gd` | `accept()`, `complete()`, `fail()` |

### What the Autonomous Tick Does Today

Route tick (passive, no player input):
```
if blocked: traffic=0, trade_flow=0, danger += 2
else:
    pressure = bandit_pressure + monster_pressure
    safety = patrol_presence + road_quality
    traffic_delta = round((safety - pressure - danger) / 25)
    traffic = clamp(traffic + traffic_delta, 0, 100)
    danger_delta = round((pressure - safety) / 35)
    danger = clamp(danger + danger_delta, 0, 100)
    trade_flow = clamp(round((traffic + road_quality + patrol_presence - danger) / 3), 0, 100)
```

**Gap**: Player contracts don't touch route economy at all. Completing an escort contract gives crowns and reputation but doesn't lower bandit_pressure on the route.

---

## 2. What Route Dynamics V1 Adds

### Core Concept
Contracts become the primary player lever on route state. Each contract type has defined effects on route economy fields on success and failure. These effects are applied immediately when a contract is resolved, not just during the autonomous weekly tick.

### Player-Facing Behavior
- Completing an escort contract: route feels safer, traffic improves
- Failing an escort contract: route degrades, bandits emboldened
- Completing a hunt bandits contract: bandit_pressure drops significantly
- Repeated success on the same route: visible stabilization (danger trending down, trade_flow trending up)
- Neglecting a route: danger rises autonomously, eventually blocking trade

### Contract → Route Effect Map

| Contract Type | Success Effect | Failure Effect |
|--------------|---------------|----------------|
| **escort_caravan** | `bandit_pressure -15, patrol_presence +5, traffic +10` | `bandit_pressure +10, traffic -10, blocked=true` (3 weeks) |
| **hunt_bandits** | `bandit_pressure -25, monster_pressure -5` | `bandit_pressure +15` |
| **patrol_route** (new data, future) | `patrol_presence +20, danger -10` | `patrol_presence -10` |
| **recover_wagon** | `bandit_pressure -10` | `bandit_pressure +10` |
| **monster_lair** (new data, future) | `monster_pressure -30, danger -10` | `monster_pressure +15` |
| **bounty_capture** | `bandit_pressure -5, patrol_presence +5` | `bandit_pressure +5` |
| **raid_caravan** (player aggression) | `bandit_pressure +15, traffic -20, trade_flow -10` | `patrol_presence +15` (guards alerted) |

All values clamped to `0..100`. `blocked` is a boolean, but failure block durations are tracked in a new `blocked_until_tick` field.

---

## 3. How Route State Feeds Settlement Economy

This already works in world_tick_v1: settlement `trade_access` changes each tick based on average `trade_flow` of connected routes. Route dynamics adds the contract-driven layer that makes trade_flow respond to player actions rather than only passive drift.

### Cascade Chain

```
Player completes escort contract
  → route.bandit_pressure -= 15
  → route.traffic += 10
  → on next weekly tick: route.trade_flow recalculates higher
  → settlement.trade_access increases
  → settlement.prosperity improves
  → settlement.recruitment_pool_quality improves
```

```
Player fails hunt bandits contract
  → route.bandit_pressure += 15
  → on next weekly tick: route.danger recalculates higher
  → route.trade_flow recalculates lower
  → settlement.trade_access decreases
  → settlement.prosperity declines
  → settlement.unrest increases
```

```
Player lets route degrade (no contracts for 4+ weeks)
  → autonomous tick: bandit_pressure drifts up, traffic drifts down
  → eventually route becomes blocked
  → settlement trade_access tanks
  → settlement suffers food shortages, population decline
```

---

## 4. Route Stabilization from Repeated Player Success

### Visibility Rules

Each time a contract modifies a route, the route records an event in a new `route_history` array:

```json
"route_history": [
  {"tick": 14, "contract": "escort_embermill", "outcome": "success", "effects": {"bandit_pressure": -15}},
  {"tick": 28, "contract": "hunt_red_sashes", "outcome": "success", "effects": {"bandit_pressure": -25}}
]
```

After 3+ successful contracts on the same route, the route gains a status flag:
- `"status": "stabilizing"` — visible on road map as safer color
- `"status": "secure"` — after 6+ successes, danger ≤ 30 for 4+ weeks

After a route becomes secure:
- `patrol_presence` floors at 30 (doesn't degrade below)
- Autonomous bandit_pressure growth is halved
- Settlement connected to secure routes gets a `route_secure` status effect (+1 prosperity/tick)

### Degradation

Secure routes decay if neglected:
- If no player contract touches the route for 4+ weeks: status drops to `stabilizing`
- If no contract for 8+ weeks: status drops to normal
- Autonomous danger growth resumes at full rate

---

## 5. JSON/Data Changes

### contracts.json — Add `route_effects`

Each contract gains two new fields:

```json
"route_effects_on_success": {
  "bandit_pressure": -15,
  "patrol_presence": 5,
  "traffic": 10
},
"route_effects_on_failure": {
  "bandit_pressure": 10,
  "traffic": -10,
  "block_duration_ticks": 3
}
```

Example for existing contracts:

```json
// escort_embermill
"route_effects_on_success": {"bandit_pressure": -15, "patrol_presence": 5, "traffic": 10},
"route_effects_on_failure": {"bandit_pressure": 10, "traffic": -10, "block_duration_ticks": 3}

// hunt_red_sashes
"route_effects_on_success": {"bandit_pressure": -25, "monster_pressure": -5},
"route_effects_on_failure": {"bandit_pressure": 15}

// recover_wagon
"route_effects_on_success": {"bandit_pressure": -10},
"route_effects_on_failure": {"bandit_pressure": 10}

// capture_gravetithe
"route_effects_on_success": {"bandit_pressure": -5, "patrol_presence": 5},
"route_effects_on_failure": {"bandit_pressure": 5}
```

### route_economy.json — Add `blocked_until_tick`, `route_history`, `status`

New fields per route:
```json
{
  "route_id": "blackford_embermill_highroad",
  "...existing fields...": "...",
  "blocked_until_tick": null,
  "route_history": [],
  "status": "normal"
}
```

- `blocked_until_tick`: int or null. When set, route remains blocked until world tick reaches this value. After expiry, blocked flips to false and blocked_until_tick sets to null.
- `route_history`: array of `{tick, contract, outcome, effects}`. Max 20 entries (ring buffer).
- `status`: `"normal"` | `"stabilizing"` | `"secure"`

### New: data/world/route_status_definitions.json

```json
[
  {
    "id": "normal",
    "name": "Normal",
    "min_successes": 0,
    "description": "Route behaves normally."
  },
  {
    "id": "stabilizing",
    "name": "Stabilizing",
    "min_successes": 3,
    "autonomous_bandit_growth_mult": 0.5,
    "description": "Route bandit growth is slowed by persistent patrols."
  },
  {
    "id": "secure",
    "name": "Secure",
    "min_successes": 6,
    "min_danger": 30,
    "min_weeks_below_danger": 4,
    "autonomous_bandit_growth_mult": 0.25,
    "patrol_presence_floor": 30,
    "settlement_effect_id": "route_secure",
    "description": "Route is actively maintained. Bandits avoid it. Connected settlements prosper."
  }
]
```

### settlement_status_effects.json — Add `route_secure`

```json
{
  "id": "route_secure",
  "name": "Route Secure",
  "duration_ticks": 1,
  "modifiers": {
    "prosperity": 1,
    "unrest": -1
  },
  "description": "Connected roads are patrolled and safe, easing local fears."
}
```

---

## 6. New GDScript: RouteDynamicsSystem.gd

A new system class that bridges contracts to route economy. Callable from contract resolution.

### Interface

```
class_name RouteDynamicsSystem
extends RefCounted

func apply_contract_success(contract: Dictionary, route_economy: Dictionary) -> Dictionary
    # Reads contract.route_effects_on_success, applies deltas to route_economy
    # Clamps all values 0..100
    # Appends to route_history
    # Recalculates route status
    # Returns {route_id, before, after, effects_applied}

func apply_contract_failure(contract: Dictionary, route_economy: Dictionary) -> Dictionary
    # Reads contract.route_effects_on_failure, applies deltas
    # If block_duration_ticks set, sets blocked=true and blocked_until_tick
    # Returns {route_id, before, after, effects_applied, blocked_duration}

func recalculate_status(route: Dictionary) -> String
    # Counts successful contracts in route_history
    # Checks danger level and weeks below threshold
    # Returns "normal", "stabilizing", or "secure"

func get_connected_settlement_effects(route: Dictionary) -> Array[String]
    # If route.status == "secure", returns ["route_secure"]
    # Else returns []

func clear_expired_blocks(route: Dictionary, current_tick: int) -> void
    # If blocked_until_tick is set and current_tick >= blocked_until_tick:
    #   set blocked=false, blocked_until_tick=null
```

---

## 7. Integration Points

### ContractSystem.gd — Extend `complete()` and `fail()`

After existing reward logic, call:
```
RouteDynamicsSystem.apply_contract_success(contract, route_economy_entry)
```

The contract system needs access to route economy data. Options:
- **Option A (preferred)**: DataStore loads route_economy.json. ContractSystem receives a DataStore reference.
- **Option B**: RouteDynamicsSystem is injected into ContractSystem.

### WorldEconomySystem.gd — Extend `_tick_route()`

Before existing logic, call:
```
RouteDynamicsSystem.clear_expired_blocks(route, current_tick)
RouteDynamicsSystem.recalculate_status(route)
```

After existing logic, apply status modifiers:
- If `status == "stabilizing"`: autonomous bandit_growth is halved
- If `status == "secure"`: patrol_presence floors at 30, bandit growth is quartered

### Combat Result → Contract Resolution

When combat ends and the contract is resolved (success/failure), the existing flow is:
`CombatScreen → ContractSystem.complete()/fail() → CompanyState.apply_contract_success()/failure()`

Route dynamics inserts between `ContractSystem` and route economy:
`ContractSystem.complete() → RouteDynamicsSystem.apply_contract_success() → route_economy updated`

---

## 8. Validator Changes

### tools/validate_world_economy.py — Extend

Add checks for new fields:
- `blocked_until_tick`: int or null, must be >= 0 if set
- `route_history`: must be a list, each entry must have `{tick: int, contract: string, outcome: "success"|"failure", effects: dict}`
- `status`: must be `"normal"` | `"stabilizing"` | `"secure"`

### tools/validate_contracts.py — Extend

Add checks:
- `route_effects_on_success`: must be a dict with numeric values for allowed keys (`bandit_pressure, patrol_presence, traffic, monster_pressure, trade_flow, danger`)
- `route_effects_on_failure`: same, plus optional `block_duration_ticks` (int, 1-52)
- All route_effect keys reference valid route_economy fields

### New: tools/validate_route_dynamics.py

Validates:
- `data/world/route_status_definitions.json` (if created)
- Cross-reference: contract `target_route` must have matching entry in `route_economy.json`
- All `status` values in route_economy reference valid status definition IDs

---

## 9. Pure Simulation Tests

### New: tools/tests/test_route_dynamics.py

```
def test_escort_success_reduces_bandit_pressure():
    GIVEN route with bandit_pressure=50, contract with route_effects_on_success={bandit_pressure: -15}
    WHEN apply_contract_success(contract, route)
    THEN route.bandit_pressure == 35, route_history has 1 entry

def test_hunt_failure_increases_bandit_pressure():
    GIVEN route with bandit_pressure=40, contract with route_effects_on_failure={bandit_pressure: 15}
    WHEN apply_contract_failure(contract, route)
    THEN route.bandit_pressure == 55

def test_escort_failure_blocks_route():
    GIVEN route with blocked=false, contract failure has block_duration_ticks=3
    WHEN apply_contract_failure(contract, route)
    THEN route.blocked == true, route.blocked_until_tick == current_tick + 3

def test_block_expires():
    GIVEN route blocked_until_tick=10, current_tick=15
    WHEN clear_expired_blocks(route, 15)
    THEN route.blocked == false, route.blocked_until_tick == null

def test_route_stabilizes_after_three_successes():
    GIVEN route_history with 3 success entries on same route
    WHEN recalculate_status(route)
    THEN route.status == "stabilizing"

def test_route_becomes_secure_after_six_successes():
    GIVEN route_history with 6 success entries, danger=25 for 4+ weeks
    WHEN recalculate_status(route)
    THEN route.status == "secure"

def test_route_effects_clamped():
    GIVEN route with bandit_pressure=95, success effect = -20
    WHEN apply_contract_success(contract, route)
    THEN route.bandit_pressure == 75 (not negative)

def test_settlement_receives_route_secure_effect():
    GIVEN route with status="secure"
    WHEN get_connected_settlement_effects(route)
    THEN returns ["route_secure"]

def test_nonregression_world_tick_still_passes():
    GIVEN existing settlement and route data
    WHEN weekly_tick runs
    THEN all existing world_tick_v1 behavior is preserved

def test_route_history_max_entries():
    GIVEN route_history with 20 entries
    WHEN new entry added
    THEN oldest entry is removed, length stays 20
```

---

## 10. Debug UI Requirements

### Road Map Panel Additions

- Route hover/selection shows: status badge (Normal / Stabilizing / Secure), bandit_pressure bar, danger rating
- Color indicators: green for secure routes, yellow for stabilizing, red for dangerous/unstable
- "Advance Week" button already exists; verify it propagates route effects to settlement panels

### Settlement Panel Additions

- Show connected routes with their status and trade_flow
- "Route Secure" status effect badge when applicable

### Contract Board Additions

- When contract is accepted, show preview of route effects (tooltip: "Completing this will reduce bandit activity on the Oldwood Road")

---

## 11. What NOT to Build Yet

- Do not add new contract types (patrol_route, monster_lair, raid_caravan, etc.) — the schema supports them but they're content for a later pass
- Do not add faction-driven route effects (factions hiring their own patrols)
- Do not add route weather/seasons
- Do not add site discovery from routes
- Do not add contract generation from route state — that's layer 3
- Do not add visual route animation or map fog of war
- Do not change the combat encounter table based on route dynamics
- Do not persist route_history across save/load (save/load not built yet)
- Do not create `route_status_definitions.json` unless it simplifies the GDScript implementation — hardcoded constants in `RouteDynamicsSystem.gd` with a `const` dictionary are acceptable for V1

---

## 12. Acceptance Criteria

- [ ] All 4 existing contracts have `route_effects_on_success` and `route_effects_on_failure` fields
- [ ] Completing an escort contract reduces `bandit_pressure` on the target route by 15
- [ ] Failing a hunt contract increases `bandit_pressure` by 15
- [ ] Failed escort contract blocks the route for 3 weekly ticks
- [ ] Blocked routes expire and reopen automatically
- [ ] Route status recalculates after each contract resolution: "normal" → "stabilizing" → "secure"
- [ ] Secure routes apply `route_secure` status effect to connected settlements
- [ ] All route economy values stay clamped 0..100
- [ ] All 8 route dynamics tests pass
- [ ] All existing world_tick_v1 tests still pass (non-regression)
- [ ] All existing validators pass (extended ones plus any new ones)
- [ ] `python tools/run_all_tests.py` exits zero
- [ ] Existing autoplay smoke still reaches aftermath
