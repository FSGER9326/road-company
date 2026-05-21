# World Simulation Implementation Map

## Purpose
Concise, implementation-focused specification for Codex and coding agents building the dynamic world system. Bridges design docs to actionable implementation passes.

---

## 1. Current Prototype Baseline

The existing vertical slice (`main` branch) already has:

| System | Location | Capability |
|--------|----------|------------|
| Road map | `game/scripts/road/RoadScreen.gd`, `RoadSystem.gd` | 3 settlements, 7 routes, travel costs, ambush rolls |
| Contract board | `game/scripts/ui/ContractBoard.gd`, `ContractSystem.gd` | 4 static contracts, accept/complete/fail |
| Company state | `game/scripts/core/CompanyState.gd` | `crowns, food, tools, medicine, morale, vigor, renown, roster[], graveyard[], faction_reputation{}` |
| Tactical combat | `game/scripts/combat/CombatSystem.gd` | Axial hex, AP, fatigue, armor/HP split, morale, injuries, death, simple AI |
| Camp/aftermath | `game/scripts/camp/CampSystem.gd` | Rest, Repair, Treat Wounds |
| Data loading | `game/scripts/core/DataStore.gd` | Loads `locations.json, routes.json, contracts.json, factions.json, weapons.json, armor.json, enemies.json, encounters.json, road_events.json, company_start.json` |
| Validators | `tools/validate_*.py` | Reference-checking Python validators |
| Test harness | `tools/run_all_tests.py` | Runs validators + simulation tests + Godot headless |
| Deterministic RNG | `game/scripts/core/SeededRng.gd` | Seed-based reproducibility |

**What's missing**: No settlement economy, no route dynamics, no market prices, no internal factions, no contract generation from world state, no emergent events.

---

## 2. World Simulation Target

Long-term target (stages 2-10 of full roadmap):

```
Nations → Regions → Settlements → Internal Factions
           Routes (dynamic danger, traffic, closure)
           Economy (production, consumption, prices, stock Flow)
           Contracts (generated from faction needs, situations, route danger)
           Events / Rumors / World Memory
           Crisis Seeds
```

But the target is **modular** — each layer can be implemented and tested independently before the next layer depends on it.

---

## 3. Implementation Layers

### Layer 1: Deterministic Settlement Economy Tick

**Purpose**: Settlements produce, consume, and store goods. Population, prosperity, security, unrest, and trade_access change each tick. Player actions modify these values.

**Files likely touched**:
- `data/world/settlements.json` — new, 3+ settlements with full economy fields
- `data/economy/trade_goods.json` — new, 13 goods with production/consumption values
- `data/economy/market_tiers.json` — new, tier definitions
- `game/scripts/world/SettlementEconomySystem.gd` — new, tick logic
- `game/scripts/world/WorldTickSystem.gd` — new, orchestrates all settlement ticks
- `game/scripts/core/DataStore.gd` — extend to load new JSON files
- `tools/validate_settlements.py` — new
- `tools/validate_economy.py` — new
- `tools/tests/test_settlement_economy.py` — new

**Data needed**:
- `settlements.json`: 3 settlements with fields: `id, name, type, population, prosperity, security, food_stock, medicine_stock, tools_stock, arms_stock, unrest, corruption, trade_access, market_tier, recruitment_pool, faction_pressure, crisis_pressure`
- `trade_goods.json`: 13 goods (`grain, meat, salt, iron, timber, cloth, medicine, tools, weapons, relics, contraband, livestock, luxury_goods`) each with `id, name, category, base_price, weight, produced_in[], consumed_in[], perishable, contraband`
- `market_tiers.json`: 5 tiers, population thresholds, price modifiers

**Tests needed** (7 minimum):
1. Stable settlement maintains equilibrium (±2 per tick)
2. Food shortage triggers prosperity decrease and unrest increase
3. Prosperity increases with high trade access
4. Security decline with high unrest / low arms
5. Population growth/decline from conditions
6. Market tier upgrade check at high prosperity
7. Deterministic: same seed → same result

**Acceptance criteria**:
- [ ] 3+ settlements with full economy fields in `settlements.json`
- [ ] 13 goods with production/consumption in `trade_goods.json`
- [ ] `settlement_tick(settlement_id)` function returns correct before/after dictionary
- [ ] Food shortage → unrest +5, prosperity −2 in one tick
- [ ] All values clamped within defined ranges
- [ ] Tick is deterministic under seeded RNG
- [ ] All 7 tests pass
- [ ] Existing prototype loop still works (contracts, travel, combat, camp)

**Risks**: Medium. Must not break existing `locations.json`-based DataStore loading. Existing prototype uses `locations.json` — the new `settlements.json` is additive, not a replacement yet.

**What not to build yet**: Route dynamics, faction influence, contract generation, UI displays. Just the tick function and data. The settlement tick should be callable headlessly: `settlement_tick("blackford")` returns `{"before": {...}, "after": {...}}`.

---

### Layer 2: Route Dynamics

**Purpose**: Routes have dynamic danger (bandit_pressure − patrol_presence), traffic (from settlement prosperity), and closure states. Player actions modify route state.

**Files likely touched**:
- `data/world/routes.json` — extend with dynamic fields
- `game/scripts/road/RouteSimSystem.gd` — new
- `game/scripts/road/RoadSystem.gd` — extend `travel()` to use dynamic danger

**Data needed**: Routes need `bandit_pressure, patrol_presence, monster_pressure, caravan_frequency, is_closed, closure_reason, controlling_faction, traffic` — all with current values (not just base).

**Tests needed**:
1. Traffic scales with connected settlement prosperity
2. Effective danger = base_danger + bandit_factor − patrol_factor
3. Route closes when settlement is_under_siege
4. Player escort completion reduces bandit_pressure by 10
5. Deterministic

**Acceptance criteria**:
- [ ] Routes have dynamic danger recalculation
- [ ] Player contract effects modify route state
- [ ] Route closure/reopening works
- [ ] Settlement trade_access responds to connected route state

---

### Layer 3: Contract Generator from World State

**Purpose**: Contracts are generated dynamically based on settlement situations, faction needs, and route states — not just static JSON.

**Files likely touched**:
- `game/scripts/contracts/ContractGenerator.gd` — new
- `data/contracts/contract_templates.json` — new
- `game/scripts/contracts/ContractSystem.gd` — extend

**Data needed**: `contract_templates.json` with spawn conditions (`min_settlement_population, min_bandit_pressure, situation_required, min_day`), reward scaling formulas.

**Tests needed**:
1. Starving settlement generates food delivery contracts
2. High bandit pressure generates hunt contracts
3. Faction influence gates contract availability
4. Reward scales with danger
5. Deterministic contract generation from seed

**Acceptance criteria**:
- [ ] Contract board shows contracts generated from world state
- [ ] Contract types vary by settlement conditions
- [ ] Rewards scale with danger
- [ ] Existing 4 static contracts still work

---

### Layer 4: Settlement Internal Factions

**Purpose**: Each settlement has 2-6 internal factions with influence, attitudes, and agendas. Player contracts shift influence. Faction dominance changes settlement policies.

**Files likely touched**:
- `data/factions/internal_faction_types.json` — new
- `game/scripts/world/SettlementFactionSystem.gd` — new
- `game/scripts/world/SettlementEventSystem.gd` — new

**Data needed**: Internal faction definitions with `preferred_contracts[], policies_push[], events_can_trigger[], enemy_factions[]`.

**Tests needed**:
1. Contract completion shifts influence
2. Betrayal causes −20 influence
3. Dominant factions drift toward equilibrium
4. Civil conflict triggers when two enemies both >60 influence

---

### Layer 5: Event / Rumor / Memory Engine

**Purpose**: Events fire based on world conditions. Rumors spread partial information. World memory records history.

**Files likely touched**:
- `data/events/event_templates.json` — new
- `data/events/rumor_templates.json` — new
- `game/scripts/world/EventSystem.gd` — new
- `game/scripts/world/WorldMemorySystem.gd` — new
- `game/scripts/world/RumorSystem.gd` — new

**Data needed**: Event templates with `trigger_conditions, cooldown_days, choices[], automatic_outcome`.

**Tests needed**:
1. Event cooldown prevents spam
2. Events fire when conditions met
3. Rumors match current world state
4. Memory log records significant events (severity >= 3)

---

### Layer 6: Crisis Seeds

**Purpose**: Large-scale crises (famine, plague, war, cult uprising) begin small and grow if unchecked.

---

### Layer 7: UI Dashboards

**Purpose**: Settlement info panel, market panel, route detail panel, debug overlay.

---

### Layer 8: Balancing Tools

**Purpose**: Python tools for running 200-day simulations and analyzing settlement health curves.

---

## 4. Data Dependency Map

```
trade_goods.json
    ↓
settlements.json ──→ settlement economy tick
    ↓                     ↓
routes.json ────→ route dynamics ──→ settlement trade_access
    ↓
factions.json ──→ internal factions ──→ contract generation
    ↓                     ↓
contract_templates.json ──┘
    ↓
event_templates.json → events → world_memory → rumors
    ↓
situation_definitions.json → settlement status effects
```

**Key integration**: `route.effective_danger` → `settlement.trade_access` → `settlement.prosperity` → `settlement.population`. This is the primary feedback loop that makes player actions on routes matter to settlement health.

---

## 5. Recommended Schemas (Compact)

### Trade Good

```json
{
  "id": "grain",
  "name": "Grain",
  "category": "food",
  "base_production": 50,
  "base_consumption": 40,
  "base_price": 8,
  "weight": 2,
  "perishable": true,
  "contraband": false,
  "produced_in": ["hamlet", "village", "town"],
  "consumed_in": ["village", "town", "city", "fort", "caravanserai"],
  "shortage_effect": "+2 unrest, -1 prosperity",
  "surplus_effect": "+0.5 prosperity"
}
```

### Settlement Economy (keys on each settlement)

```json
{
  "population": 450,
  "prosperity": 52,
  "security": 48,
  "food_stock": 200,
  "medicine_stock": 42,
  "tools_stock": 38,
  "arms_stock": 22,
  "unrest": 12,
  "corruption": 18,
  "trade_access": 55,
  "market_tier": 2,
  "recruitment_pool": 24,
  "faction_pressure": 15,
  "crisis_pressure": 0,
  "trade_goods_produced": ["grain", "meat", "timber"],
  "trade_goods_demanded": ["salt", "iron", "medicine"],
  "market_modifiers": {},
  "current_situations": [],
  "settlement_history": []
}
```

### Route Economy (keys on each route)

```json
{
  "bandit_pressure": 25,
  "patrol_presence": 40,
  "monster_pressure": 5,
  "caravan_frequency": 8,
  "traffic": 6,
  "effective_danger": 4,
  "is_closed": false,
  "closure_reason": null,
  "tolls": 15
}
```

### Settlement Status Effect

```json
{
  "id": "food_shortage",
  "name": "Food Shortage",
  "ticks_remaining": 14,
  "severity": 2,
  "modifiers": {
    "prosperity_mult": 0.8,
    "unrest_add": 3,
    "recruitment_mult": 0.5
  }
}
```

### Economy Tick Result

```json
{
  "settlement_id": "blackford",
  "tick": 42,
  "day": 294,
  "before": { "population": 450, "prosperity": 52, "...": "..." },
  "after": { "population": 453, "prosperity": 54, "...": "..." },
  "deltas": { "population": 3, "prosperity": 2, "unrest": -1 },
  "events_triggered": [],
  "warnings": []
}
```

### World Memory Entry

```json
{
  "id": "mem_00142",
  "tick": 42,
  "day": 294,
  "category": "settlement_event",
  "title": "Food Shortage in Blackford Gate",
  "summary": "Grain stocks fell below weekly consumption. Unrest rises.",
  "entities_involved": ["blackford", "gate_nobility"],
  "settlement_effects": ["blackford:unrest+2"],
  "significance": "minor",
  "discoverable_via_rumor": true,
  "rumor_text": "They say Blackford's granaries are running thin."
}
```

---

## 6. Tick Formula Recommendations

These formulas are simplified from the full design docs and tuned for implementability. All use integer math where possible.

### Weekly consumption per good

```
consumed = round(population / divisor)
divisors: grain=100, meat=120, medicine=500, tools=800, fuel=200, cloth=150
```

### Weekly production per good

```
produced = base_production * (prosperity / 50.0) * (1 - corruption * 0.002)
```

### Unrest change

```
unrest += 0
if food_stock < population * 0.5: unrest += 3
if security < 30: unrest += 1
if corruption > 70: unrest += 1
unrest -= 0.5  // natural drift
clamp(unrest, 0, 100)
```

### Prosperity change

```
trade_factor = trade_access / 50.0
security_factor = security / 100.0
unrest_factor = (100 - unrest) / 100.0
prosperity = round(security_factor * 30 + trade_factor * 40 + unrest_factor * 20 + 10)
clamp(prosperity, 1, 100)
```

### Trade access change

```
if any connected route is_closed: trade_access -= 2 per closed route
trade_access += min(connected_routes) * 0.5  // from traffic
if player completed escort contract for this settlement: trade_access += 5
clamp(trade_access, 1, 100)
```

### Route traffic (effective danger components)

```
traffic = caravan_frequency * (from.prosperity + to.prosperity) / 100
effective_danger = base_danger + (bandit_pressure / 100.0 * 3) - (patrol_presence / 100.0 * 2)
clamp(effective_danger, 1, 10)
clamp(traffic, 0, 20)
```

### Market tier change

```
if prosperity > 80 and trade_access > 70 and population > tier_threshold and random() < 0.05:
    market_tier += 1
if prosperity < 20 or population < tier_threshold_lower and random() < 0.10:
    market_tier -= 1
clamp(market_tier, 1, 5)
```

### Recruitment quality

```
recruitment_pool = round(market_tier * 2 + prosperity / 10 + security / 10)
clamp(recruitment_pool, 0, 100)
```

### Market price

```
stock_ratio = stock / (weekly_consumption * 2)
if stock_ratio >= 1.5: price_mult = 0.7
elif stock_ratio >= 1.0: price_mult = 0.85
elif stock_ratio >= 0.5: price_mult = 1.0
elif stock_ratio >= 0.25: price_mult = 1.3
else: price_mult = 1.8
price = base_price * price_mult * tier_price_modifier[tier]
clamp(price, base_price * 0.5, base_price * 3.0)
```

---

## 7. Testing Map

### Layer 1 Tests

```
GIVEN settlement with default values (pop 450, prosperity 52, security 48, food 200)
WHEN settlement_tick() runs
THEN all values stay within ±2 of original, no events triggered

GIVEN settlement with food_stock = 10, population = 500
WHEN settlement_tick() runs
THEN unrest increases by >= 3, prosperity decreases, possible population loss

GIVEN settlement with trade_access = 90, market_tier = 4
WHEN settlement_tick() runs
THEN prosperity increases, recruitment_pool improves

GIVEN settlement with security = 10, arms_stock = 5
WHEN settlement_tick() runs
THEN prosperity declines, unrest surges

GIVEN two calls to settlement_tick() with same seed and same input state
THEN both produce identical output (determinism)

GIVEN settlement with population = 15
WHEN settlement_tick() runs and population drops below 10
THEN population clamped to 10, not negative

GIVEN settlement with prosperity = 85, trade_access = 75, population = 600, market_tier = 2
WHEN settlement_tick() runs and random() < 0.05
THEN market_tier becomes 3
```

### Layer 2 Tests

```
GIVEN route with bandit_pressure = 80, patrol_presence = 0
WHEN route_tick() runs
THEN effective_danger = base_danger + (0.8 * 3) - (0 * 2) = base_danger + 2.4

GIVEN player completes escort contract on route
WHEN route state updates
THEN bandit_pressure decreases by 10, caravan_frequency unchanged (not raided)

GIVEN both settlements on route have is_under_siege = false
WHEN route_tick() runs
THEN is_closed remains false
```

### Non-regression test (for all layers)

```
GIVEN the existing prototype scenario (escort_embermill contract)
WHEN the full autoplay runs
THEN the prototype loop still completes (travel → combat → camp → settlement)
```

---

## 8. Merge Safety Notes

| Branch | Contents | Merge Status |
|--------|----------|-------------|
| `integration/deepseek-docs-only` | All design docs from design pass | **SAFE** — docs only, no runtime changes. Can be merged into main anytime. |
| `design/deepseek-world-systems` | Design docs + AGENT_HANDOFF_DEEPSEEK.md | **DO NOT MERGE DIRECTLY** — reference only. Superseded by docs on main. |
| `design/minimax-content-systems` | Balance values, schema drafts, test matrix, Codex prompts | **ISOLATED REFERENCE** — useful consultative material. Do not merge into main. Treat `data_minimax/`, `docs_minimax/`, `prompts_minimax/` as design-phase artifacts. |
| `spec/world-sim-implementation-map` (this branch) | This implementation map | **SAFE** — docs only. Merge into main for Codex reference. |
| `feature/world-tick-v1` (Codex branch, not yet created) | Runtime implementation | **CODE ONLY** — this is where Codex writes GDScript, JSON data, and tests. |

**Rule**: Only Codex branches touch `game/scripts/`, `game/scenes/`, or `tools/`. Design/spec branches are docs-only.

---

## 9. Next Three Codex Prompts

### Prompt 1: world_tick_v1

> "Implement deterministic settlement economy tick. Create data/world/settlements.json with 3 settlements (Blackford Gate, Embermill, Saintsfall) using the economy schema from docs/WORLD_SIM_IMPLEMENTATION_MAP.md section 5. Create data/economy/trade_goods.json with 13 goods and base production/consumption values from docs_minimax/balance/economy_tick_values.md. Create data/economy/market_tiers.json with 5 tiers. Implement SettlementEconomySystem.gd with settlement_tick(sid) that processes production, consumption, stock update, shortage/surplus checks, and recalculates prosperity, unrest, population, trade_access, market_tier, recruitment_pool. All formulas from the implementation map section 6. Tick must be deterministic via SeededRng. Write 7 automated tests per the testing map section 7 Layer 1. Do NOT modify existing RoadSystem, ContractSystem, or CombatSystem. Ensure existing prototype still works."

### Prompt 2: route_dynamics_v1

> "Implement route dynamics on top of the settlement economy tick. Extend data/world/routes.json with fields: bandit_pressure, patrol_presence, monster_pressure, caravan_frequency, traffic, effective_danger, is_closed, closure_reason, controlling_faction. Create RouteSimSystem.gd with route_tick(rid) that recalculates: traffic from connected settlement prosperity, effective_danger from bandit_pressure minus patrol_presence, and closure checks. Extend RoadSystem.gd travel() to use dynamic effective_danger instead of static danger. Add player effect functions: lower_bandit_pressure(route, amount), raise_patrol_presence(route, amount), close_route(route, reason). Write tests: traffic scales with prosperity, danger formula correct, player escort reduces bandit pressure, closure works."

### Prompt 3: contract_generator_v1

> "Implement dynamic contract generation from world state. Create ContractGenerator.gd that generates contracts based on: settlement food_stock < threshold → food_delivery contracts, route bandit_pressure > 60 → hunt_bandits contracts, settlement situation = 'plague' → deliver_medicine contracts. Create data/contracts/contract_templates.json with templates for each contract type, spawn conditions, and reward scaling formulas. Contracts should scale reward with danger and urgency. Extend ContractBoard.gd to show generated contracts alongside static ones. Write tests: starving settlement generates food contracts, high bandit pressure generates hunt contracts, reward scales with danger, deterministic generation from seed."

---

## 10. Final Recommendation

### Immediate Next Five Implementation Passes

| Pass | Who | What | Depends On |
|------|-----|------|-----------|
| **1** | Codex | Stabilize current vertical slice (Stage 0) | Nothing |
| **2** | Codex | `world_tick_v1` — settlement economy tick (Layer 1) | Pass 1 |
| **3** | Codex | `route_dynamics_v1` — route danger and traffic (Layer 2) | Pass 2 |
| **4** | Codex | `contract_generator_v1` — contracts from world state (Layer 3) | Pass 2, 3 |
| **5** | Codex | Settlement internal factions (Layer 4) | Pass 2, 4 |

**Reasoning**: This order builds the core feedback loop first (routes affect settlements, settlements affect contracts), which is the minimum viable "dynamic world." Factions and events are richer simulation layers that depend on the economic foundation.

**Highest priority single action**: Pass 2 (settlement economy tick). Every future system reads settlement state. Get this right first.
