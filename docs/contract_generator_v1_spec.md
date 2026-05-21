# Contract Generator V1 — Specification

## Purpose
Replace the 4 static contracts in `contracts.json` with contracts generated dynamically from world state. A starving settlement generates food-delivery contracts. A dangerous route generates patrol or hunt contracts. The same seed + same world state always produces the same contract board.

## Scope
Single Codex pass. Builds on `feature/world-tick-v1` (economy tick) and `feature/route-dynamics-v1` (contract-driven route effects). Adds no new contract categories beyond the 7 listed below. Stays purely deterministic. Does not rewrite the contract board UI — extends it to show generated contracts alongside existing static ones.

---

## 1. Contract Categories for V1

| Type | Purpose | Trigger Condition |
|------|---------|-------------------|
| **escort_caravan** | Protect a wagon from A to B | Route danger 40+, or food shortage at target |
| **patrol_route** | Patrol a route for N days | Bandit pressure 40+, or route blocked |
| **hunt_bandits** | Eliminate a bandit camp near route | Bandit pressure 55+ |
| **recover_wagon** | Find and recover a lost wagon | Traffic 30+ but danger 50+ (low traffic on busy route) |
| **deliver_medicine** | Transport medicine to a settlement | Medicine stock ≤ population/400 |
| **defend_settlement** | Protect settlement from imminent threat | Security < 35 or active monster_pressure > 30 on connected route |
| **bounty_target** | Capture a fleeing criminal or cultist | Unrest 50+, or settlement has cult/smuggler faction presence |

Keep it to these 7. The static `capture_gravetithe` and `hunt_red_sashes` remain as hand-authored named contracts. The generator produces unnamed variants (e.g. `deliver_medicine_embermill_001`).

---

## 2. Generator Inputs

The generator function takes:

```gdscript
func generate_contracts(
    current_location: String,              # where player is standing
    settlement_economies: Array[Dictionary], # all settlement economy entries
    route_economies: Array[Dictionary],      # all route economy entries
    route_links: Array[Dictionary],          # routes.json for from/to lookups
    faction_reputation: Dictionary,          # company.faction_reputation
    existing_contracts: Array[Dictionary],   # currently active contracts (avoid duplicates)
    seed: int                                # deterministic seed
) -> Array[Dictionary]
```

### Input Data Mapped to Contract Triggers

| World State Field | Range | Triggers Contract Type When |
|------------------|-------|---------------------------|
| `settlement.food_stock / (population/250)` | < 2 weeks | `escort_caravan` (food to settlement), `deliver_medicine` |
| `settlement.medicine_stock / (population/400)` | < 1.0 | `deliver_medicine` |
| `settlement.security` | < 35 | `defend_settlement` |
| `settlement.unrest` | > 50 | `bounty_target` |
| `settlement.trade_access` | < 30 | `escort_caravan`, `recover_wagon` |
| `route.bandit_pressure` | > 40 | `patrol_route` |
| `route.bandit_pressure` | > 55 | `hunt_bandits` |
| `route.danger` | > 40 | `escort_caravan`, `patrol_route` |
| `route.blocked` | true | `patrol_route`, `hunt_bandits` |
| `route.traffic` | > 30 AND `route.danger` > 50 | `recover_wagon` |

---

## 3. Generator Output Schema

Each generated contract follows the existing contract schema plus new generator-specific fields:

```json
{
  "id": "string (generated, e.g. 'escort_blackford_embermill_003')",
  "title": "string (generated from template)",
  "type": "escort_caravan|patrol_route|hunt_bandits|recover_wagon|deliver_medicine|defend_settlement|bounty_target",
  "patron_faction": "faction_id",
  "origin_location": "settlement_id",
  "target_location": "settlement_id",
  "target_route": "route_id",
  "urgency": "int (1-5)",
  "danger": "int (1-10, calculated from route + modifiers)",
  "reward_crowns": "int",
  "reward_renown": "int",
  "description": "string (generated from template)",
  "success_text": "string",
  "failure_text": "string",
  "encounter_id": "string",
  "required_cargo_or_objective": "string|null",
  "faction_effects": {"faction_id": "int"},
  "failure_faction_effects": {"faction_id": "int"},
  "route_effects_on_success": {"field": "int"},
  "route_effects_on_failure": {"field": "int"},
  "settlement_effects_on_success": {"settlement_id": {"field": "int"}},
  "settlement_effects_on_failure": {"settlement_id": {"field": "int"}},
  "generated_from": {
    "world_state_reason": "string (why this contract was generated)",
    "trigger_fields": {"field": "current_value"},
    "seed_offset": "int"
  },
  "expires_after_ticks": "int (0 = never)",
  "seed": "int"
}
```

### Example Generated Contract

```json
{
  "id": "escort_blackford_embermill_001",
  "title": "Escort Grain Convoy to Embermill",
  "type": "escort_caravan",
  "patron_faction": "millers_compact",
  "origin_location": "blackford",
  "target_location": "embermill",
  "target_route": "blackford_embermill_highroad",
  "urgency": 4,
  "danger": 4,
  "reward_crowns": 380,
  "reward_renown": 14,
  "description": "Embermill's granaries are running thin. The Millers' Compact is hiring escorts to push a grain convoy through before shortages turn into unrest.",
  "success_text": "The grain convoy reaches Embermill. The millers pay with relief in their voices.",
  "failure_text": "The grain never arrived. Embermill's shortages deepen and the Compact holds the company responsible.",
  "encounter_id": "escort_ambush",
  "required_cargo_or_objective": "wagon_survives",
  "faction_effects": {"millers_compact": 8},
  "failure_faction_effects": {"millers_compact": -10},
  "route_effects_on_success": {"bandit_pressure": -15, "danger": -3, "patrol_presence": 5, "traffic": 10, "trade_flow": 5},
  "route_effects_on_failure": {"bandit_pressure": 10, "danger": 5, "traffic": -10, "trade_flow": -5, "block_duration_ticks": 3},
  "settlement_effects_on_success": {"embermill": {"food_stock": 80}},
  "settlement_effects_on_failure": {"embermill": {"unrest": 5, "prosperity": -3}},
  "generated_from": {
    "world_state_reason": "embermill food_stock 190 < 2 weeks of need (14) — food shortage risk",
    "trigger_fields": {"embermill.food_stock": 190, "embermill.weekly_food_need": 8, "highroad.bandit_pressure": 26},
    "seed_offset": 0
  },
  "expires_after_ticks": 6,
  "seed": 12345
}
```

---

## 4. Deterministic Generation Rules

### Contracts Per Settlement

A settlement generates 1-3 contracts depending on its state:

| Settlement State | Min Contracts | Max Contracts |
|-----------------|---------------|---------------|
| Stable (no shortages, low danger routes) | 0 | 1 |
| Mild pressure (1 shortage or 1 dangerous route) | 1 | 2 |
| Crisis (multiple shortages, high unrest, blocked routes) | 2 | 3 |

The generator also respects `existing_contracts` to avoid generating the same type/target/settlement combination that's already active.

### Priority Calculation

Each contract type is scored and ranked. Highest-scoring types get generated first:

```
score = base_need * urgency_mult * scarcity_mult

base_need:
  escort_caravan: 30 if target has food shortage, 15 if route danger > 40, else 5
  patrol_route: 25 if route bandit_pressure > 40, 40 if blocked, else 5
  hunt_bandits: 35 if bandit_pressure > 55, 15 if > 40, else 0
  recover_wagon: 20 if traffic > 30 and danger > 50, else 5
  deliver_medicine: 30 if medicine_stock / (pop/400) < 1, else 10
  defend_settlement: 25 if security < 35, else 5
  bounty_target: 20 if unrest > 50, else 5

urgency_mult = clamp((shortage_severity + danger_level) / 10, 0.5, 2.0)
scarcity_mult = clamp(1.0 + (1.0 - stock_ratio), 0.5, 2.5)

stock_ratio = food_stock / (weekly_food_need * 4)  # weeks of food remaining
```

### Urgency Calculation

```
urgency = ceil(score / 20)
clamp(urgency, 1, 5)
```

### Danger Calculation

```
danger = clamp(round(route.danger * 0.08 + bandit_pressure * 0.04), 1, 10)
```

For contracts without a target route (defend_settlement, bounty_target):
```
danger = clamp(round((100 - security + unrest) / 20), 1, 10)
```

### Expiration

Contracts expire after `expires_after_ticks` weekly ticks. Formula:

```
expires_after_ticks = max(3, round(urgency * 2 - danger * 0.5))
```

Urgent contracts expire faster. Low-danger contracts can sit on the board longer.

---

## 5. Reward Formulas

### Base Rewards by Contract Type

| Type | Base Crowns | Base Renown |
|------|------------|-------------|
| `escort_caravan` | 350 | 10 |
| `patrol_route` | 280 | 8 |
| `hunt_bandits` | 400 | 14 |
| `recover_wagon` | 320 | 10 |
| `deliver_medicine` | 300 | 12 |
| `defend_settlement` | 450 | 16 |
| `bounty_target` | 380 | 12 |

### Reward Formula

```
reward_crowns = round(base_crowns * danger_mult * urgency_mult * distance_mult * patron_wealth_mult)
reward_renown = round(base_renown * urgency_mult * distance_mult)
```

### Multipliers

```
danger_mult = 0.8 + danger * 0.05         # danger 1 = 0.85, danger 5 = 1.05, danger 10 = 1.30
urgency_mult = 0.8 + urgency * 0.05        # urgency 1 = 0.85, urgency 3 = 0.95, urgency 5 = 1.05
distance_mult = 0.8 + route_days * 0.05   # 1 day = 0.85, 4 days = 1.0, 7 days = 1.15
patron_wealth_mult = 0.9 + (settlement.prosperity / 500)  # poor = 0.9, rich = 1.1
```

### Partial Success Reward

If partial success is possible (cargo delivered but wagon destroyed, or bandits scattered but leader escaped):

```
partial_reward = reward_crowns * 0.5
partial_renown = reward_renown * 0.5
```

### Failure Penalty

```
failure_faction_effect = -base_renown  # faction reputation loss
failure_renown_loss = 0  # renown never goes down (you just don't gain it)
```

---

## 6. Settlement Effects of Generated Contracts

When a generated contract is completed, it modifies settlement economy:

| Contract Type | Success Settlemenet Effects |
|--------------|---------------------------|
| `escort_caravan` | `target: food_stock +80, trade_access +5` |
| `deliver_medicine` | `target: medicine_stock +30, remove food_shortage status effect` |
| `patrol_route` | `origin: security +5. Both connected: trade_access +3` |
| `hunt_bandits` | `Both connected: security +3, trade_access +5` |
| `recover_wagon` | `origin: tools_stock +20, trade_access +3` |
| `defend_settlement` | `target: security +10, unrest -10` |
| `bounty_target` | `target: security +5, unrest -5, corruption -3` |

| Contract Type | Failure Settlement Effects |
|--------------|--------------------------|
| `escort_caravan` | `target: food_stock unchanged, unrest +5, prosperity -3` |
| `deliver_medicine` | `target: unrest +8, add food_shortage if medicine now low` |
| `patrol_route` | `origin: security -3` |
| `hunt_bandits` | `Both connected: unrest +3, bandit_pressure +15 (route effect)` |
| `recover_wagon` | `origin: tools_stock unchanged, unrest +2` |
| `defend_settlement` | `target: security -10, unrest +15, population -max(1, pop*0.01)` |
| `bounty_target` | `target: corruption +5, unrest +3` |

---

## 7. Integration with Route Dynamics

The existing `route_effects_on_success` and `route_effects_on_failure` fields on contracts already call into `RouteDynamicsSystem`. The generator produces these fields populated correctly for each contract type. No new integration code is needed — the generator fills in the right values, and the existing resolution pipeline applies them.

### Default Route Effects by Contract Type

| Contract Type | Success Route Effects | Failure Route Effects |
|--------------|----------------------|----------------------|
| `escort_caravan` | `bandit_pressure: -15, danger: -3, patrol_presence: +5, traffic: +10, trade_flow: +5` | `bandit_pressure: +10, danger: +5, traffic: -10, trade_flow: -5, block_duration_ticks: 3` |
| `patrol_route` | `patrol_presence: +20, danger: -5, traffic: +5` | `patrol_presence: -5` |
| `hunt_bandits` | `bandit_pressure: -25, danger: -8, monster_pressure: -5` | `bandit_pressure: +15, danger: +5` |
| `recover_wagon` | `bandit_pressure: -10, danger: -3` | `bandit_pressure: +10, danger: +4` |
| `deliver_medicine` | `traffic: +5, trade_flow: +3` | `trade_flow: -3` |
| `defend_settlement` | `patrol_presence: +10, danger: -3` | `danger: +5, traffic: -10` |
| `bounty_target` | `bandit_pressure: -5, danger: -2, patrol_presence: +5` | `bandit_pressure: +5, danger: +3` |

---

## 8. Integration with Settlement Economy

Generated contracts modify settlement economy on resolution. The settlement effect changes are applied directly to the `settlement_economy.json` runtime data. For stock fields (food_stock, medicine_stock, tools_stock), the delta is added. For 0-100 fields (prosperity, security, unrest, trade_access), the delta is clamped after addition.

Contracts also interact with status effects: completing a `deliver_medicine` removes `food_shortage` from the target settlement.

---

## 9. Validation Requirements

### New Validator: `tools/validate_contract_generator.py`

Checks:
1. Every generated contract has all required fields (id, type, origin_location, target_location, reward_crowns, danger, etc.)
2. Every `origin_location` and `target_location` references a valid settlement in `locations.json`
3. Every `target_route` references a valid route in `routes.json`
4. Every `patron_faction` references a valid faction in `factions.json`
5. `reward_crowns` is between 50 and 5000
6. `reward_renown` is between 2 and 50
7. `danger` is between 1 and 10
8. `urgency` is between 1 and 5
9. `expires_after_ticks` is between 0 and 52 (or -1 for permanent)
10. `generated_from.world_state_reason` is a non-empty string
11. `generated_from.trigger_fields` contains at least one key
12. No duplicate `id` values
13. `encounter_id` exists in `encounters.json` or is `null` (for non-combat contracts)
14. All `settlement_effects_*` keys reference valid settlement economy fields
15. All `route_effects_*` keys reference valid route economy fields

### Validation of Generated Contracts vs Current World State

The validator should also run the generator with seed 12345 and verify:
- Every generated contract's `generated_from.trigger_fields` values match the actual world state data
- The `world_state_reason` text is consistent with the trigger values

---

## 10. Test Cases

### File: `tools/tests/test_contract_generator.py`

```
def test_starving_settlement_generates_food_contract():
    GIVEN: embermill food_stock = 10 (well below 2 weeks of need)
    WHEN: generate_contracts("embermill", ..., seed=12345)
    THEN: at least one contract is type "escort_caravan" or "deliver_medicine"
          and target_location == "embermill"
          and generated_from.world_state_reason mentions "food"

def test_dangerous_route_generates_hunt_or_patrol():
    GIVEN: blackford_saintsfall_oldwood bandit_pressure = 80, danger = 76
    WHEN: generate_contracts("blackford", ..., seed=12345)
    THEN: at least one contract targets that route
          and type is "hunt_bandits" or "patrol_route"

def test_low_medicine_generates_deliver_contract():
    GIVEN: blackford medicine_stock = 2, population = 2400
    WHEN: generate_contracts("blackford", ..., seed=12345)
    THEN: at least one contract is "deliver_medicine" with target_location = "blackford"

def test_high_unrest_generates_bounty():
    GIVEN: saintsfall unrest = 65
    WHEN: generate_contracts("saintsfall", ..., seed=12345)
    THEN: at least one contract is "bounty_target"

def test_low_security_generates_defend():
    GIVEN: embermill security = 22
    WHEN: generate_contracts("embermill", ..., seed=12345)
    THEN: at least one contract is "defend_settlement"

def test_same_seed_produces_same_contracts():
    GIVEN: identical world state
    WHEN: generate_contracts called twice with seed=12345
    THEN: both calls produce identical contract arrays

def test_different_world_state_produces_different_priorities():
    GIVEN: state A = food shortage, state B = no shortage
    WHEN: generate_contracts with both states
    THEN: state A generates food contracts with higher priority/urgency
          state B generates fewer or no food contracts

def test_generated_contract_has_valid_route_effects():
    GIVEN: any generated contract
    THEN: route_effects_on_success keys are in ALLOWED_ROUTE_FIELDS
          route_effects_on_failure keys are in ALLOWED_ROUTE_FIELDS

def test_generated_contract_has_valid_settlement_effects():
    GIVEN: any generated contract
    THEN: settlement_effects keys are in ALLOWED_SETTLEMENT_FIELDS

def test_stable_settlement_generates_fewer_contracts():
    GIVEN: settlement with prosperity=60, security=55, food_stock=500, unrest=10
    WHEN: generate_contracts with this settlement
    THEN: 0-1 contracts generated (not 2-3)

def test_nonregression_existing_static_contracts_still_appear():
    GIVEN: existing contracts = [escort_embermill, hunt_red_sashes, ...]
    WHEN: generate_contracts called
    THEN: generated contracts do not duplicate existing contract target_route + type combos

def test_reward_within_bounds():
    GIVEN: any generated contract
    THEN: 50 <= reward_crowns <= 5000
          2 <= reward_renown <= 50
```

---

## 11. Debug UI Requirements

### Contract Board Extension (minimal)

Add a debug section below the existing contract list:

```
--- Generated Contracts (seed: 12345) ---
[1] Escort Grain Convoy to Embermill  ESCORT  D4 U4  380c  Exp: 6w
    Reason: embermill food_stock low (190 < 2-week need)
[2] Hunt the Oldwood Band      HUNT    D7 U3  520c  Exp: 4w
    Reason: oldwood bandit_pressure 54 > 55 threshold
[3] Patrol the Fenway           PATROL  D5 U2  310c  Exp: 8w
    Reason: fenway danger 68 > 40 threshold

[Regenerate: seed ______] [Accept] [Advance Week]
```

The "Reason" line makes the generation visible to developers and players. It explains WHY a contract exists.

---

## 12. What NOT to Build Yet

- Do not generate contracts from internal faction agendas (that's layer 4)
- Do not generate multi-stage contracts or quest chains
- Do not generate contracts with moral dilemmas or companion approval hooks
- Do not generate contracts from events or crises (that's layer 5)
- Do not generate contracts that require new encounter types (use existing encounter IDs)
- Do not add hidden patrons or hidden objectives
- Do not add contract negotiation or haggling
- Do not generate contracts for settlements the player has never visited
- Do not implement the Imagen/art pipeline for contract board UI
- Do not create a full "Contract Generator UI" — debug panel is text only
- Do not change how combat is triggered from contracts

---

## 13. Acceptance Criteria

- [ ] `generate_contracts()` produces contracts from world state deterministically
- [ ] Starving settlement → escort or deliver contracts targeting that settlement
- [ ] Dangerous route → patrol or hunt contracts targeting that route
- [ ] Low medicine → deliver_medicine contracts
- [ ] High unrest → bounty_target contracts
- [ ] Low security → defend_settlement contracts
- [ ] Same seed + same world state = identical output
- [ ] All generated contracts validate (reference checks pass)
- [ ] Route effects on generated contracts use valid route economy field names
- [ ] Settlement effects on generated contracts use valid settlement economy field names
- [ ] All 7 contract types can be generated (under appropriate world states)
- [ ] Existing static contracts still work (non-regression)
- [ ] `python tools/validate_contract_generator.py` passes
- [ ] `tools/tests/test_contract_generator.py` passes all 12 tests
- [ ] `python tools/run_all_tests.py` exits zero
- [ ] Existing autoplay smoke still reaches aftermath
