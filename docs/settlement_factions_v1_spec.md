# Settlement Internal Factions V1 — Specification

## Purpose
Make settlements reactive through internal power groups. Each settlement contains 2-6 factions competing for influence. Faction dominance shifts based on settlement economy state, player contracts, and faction events. The dominant faction biases contract generation and modifies settlement economy modifiers. No giant quest system required — just data, formulas, and consequences.

## Scope
Single Codex pass. Builds on `feature/world-tick-v1` (economy tick) and the contract generator (if implemented). Adds faction influence tracking, weekly drift, contract integration, simple events, and settlement-level faction state. Stays deterministic. No dialogue trees, no hand-authored quest chains.

---

## 1. V1 Internal Faction Types

Six faction types, each with distinct simulation behavior:

| Type ID | Name | Default Agenda | Favored Economy State |
|---------|------|---------------|----------------------|
| `ruling_authority` | Ruling Authority | Maintain order, collect taxes | High security, low unrest |
| `merchant_guild` | Merchant Guild | Maximize trade, lower fees | High prosperity, high trade_access |
| `militia_command` | Militia Command | Expand patrols, arm the watch | Low security, high bandit_pressure |
| `temple_chapter` | Temple/Church Chapter | Spread faith, heal | High piety, low corruption |
| `criminal_network` | Criminal Network | Control smuggling, avoid guards | High corruption, high unrest |
| `peasant_commons` | Peasant Commons | Secure food, lower demands | Low food_stock, high unrest |

### Faction Data Schema

```json
{
  "faction_id": "blackford_gate_nobility",
  "settlement_id": "blackford",
  "name": "Gate Nobility",
  "type": "ruling_authority",
  "influence": 45,
  "attitude_to_company": 0,
  "agenda_tags": ["tax_collection", "toll_roads", "keep_order"],
  "rival_faction_ids": ["blackford_merchant_guild"],
  "supported_contract_types": ["patrol_route", "escort_caravan", "defend_settlement"],
  "opposed_contract_types": ["bounty_target"],
  "economy_modifiers": {"prosperity": 0, "security": 3, "unrest": -2, "corruption": -1},
  "market_modifiers": {},
  "event_tags": ["toll_dispute", "tax_levy", "guard_captain_demand"]
}
```

### Attitude Scale

| Value | Label | Effect |
|-------|-------|--------|
| 50 to 100 | Allied | +20% contract reward from this faction, +1 random contract per visit |
| 10 to 49 | Friendly | +10% contract reward |
| -9 to 9 | Neutral | No modifier |
| -49 to -10 | Hostile | -20% contract reward, may block contracts |
| -100 to -50 | Hated | -50% reward, faction actively opposes company |

---

## 2. Settlement-Level Faction State

### New fields on settlement economy entries (`settlement_economy.json`)

```json
{
  "settlement_id": "blackford",
  "dominant_faction_id": "blackford_gate_nobility",
  "faction_tension": 15,
  "local_policy_tags": [],
  "active_internal_conflicts": [],
  "last_faction_event_tick": 0
}
```

| Field | Range | Description |
|-------|-------|-------------|
| `dominant_faction_id` | faction ID or "" | Highest-influence faction (tiebreaker: ruling > merchant > militia > temple > criminal > peasant) |
| `faction_tension` | 0-100 | Aggregate rivalry. Rises when two rival factions are close in influence. |
| `local_policy_tags` | string[] | Active policies ("raised_tolls", "market_open", "curfew") |
| `active_internal_conflicts` | string[] | Ongoing conflicts ("guild_vs_nobility") |
| `last_faction_event_tick` | int | Cooldown tracker for faction events |

### Dominant Faction Economy Effects

| Dominant Faction | Modifier |
|-----------------|----------|
| `ruling_authority` | `security +3, unrest -2, corruption -2` |
| `merchant_guild` | `prosperity +3, trade_access +5, corruption +2` |
| `militia_command` | `security +5, prosperity -2, unrest -1` |
| `temple_chapter` | `unrest -3, corruption -3, prosperity -1` |
| `criminal_network` | `corruption +8, security -5, prosperity -2` |
| `peasant_commons` | `unrest -2, prosperity -2, trade_access -2` |

---

## 3. Simulation Rules

### Weekly Faction Tick

Called inside `WorldEconomySystem.weekly_tick()` after settlement economy tick.

```
faction_weekly_tick(settlement, factions):
    1. Economy-state-driven influence shifts
    2. Contract-driven influence shifts (completed since last tick)
    3. Attitude decay toward 0 (rate: 2 per tick)
    4. Recalculate dominant faction
    5. Recalculate faction_tension
    6. Apply dominant faction economy modifiers
    7. Check for faction events (cooldown: 4 ticks)
```

### Economy-State Influence Shifts (per tick)

| Condition | Affected Faction | Shift |
|-----------|-----------------|-------|
| `security < 35` | militia_command | +3 |
| `security < 35` | criminal_network | +1 |
| `prosperity > 65` | merchant_guild | +2 |
| `trade_access < 30` | merchant_guild | -2 |
| `food_stock < weekly_need * 2` | peasant_commons | +3 |
| `unrest > 50` | criminal_network | +2 |
| `unrest > 50` | ruling_authority | -2 |
| `corruption > 50` | criminal_network | +3 |
| `corruption > 50` | temple_chapter | -2 |

### Contract-Driven Shifts

| Contract Completed | Patron Gains | Rivals Lose |
|-------------------|-------------|-------------|
| `escort_caravan` | merchant_guild +5 | criminal_network -2 |
| `patrol_route` | militia +4, ruling +2 | criminal -3 |
| `hunt_bandits` | militia +5, ruling +3 | criminal -4 |
| `recover_wagon` | merchant_guild +5 | — |
| `deliver_medicine` | temple +4, peasant +2 | — |
| `defend_settlement` | militia +5, ruling +3 | criminal -5 |
| `bounty_target` | ruling_authority +3 | criminal -3 |

Failure: patron faction loses 5 influence, no rival gain.

### Attitude Changes

```
Per contract completed for this faction (as patron): attitude += 5
Per contract completed for rival: attitude -= 2
Per faction event siding against: attitude -= 10
Natural decay: drift toward 0 at rate 2 per tick
```

### Faction Tension

```
tension = sum of min(infl_a, infl_b) * 0.3 for each rival pair where both > 30
If dominant influence > 70: tension -= 5
clamp(tension, 0, 100)
```

---

## 4. Contract Integration

When the contract generator runs, internal factions modify priority scores:

- Contract type matches dominant faction's `supported_contract_types`: priority × 1.3
- Contract type matches dominant faction's `opposed_contract_types`: priority × 0.7
- Faction attitude modifies reward: `reward_mult += faction.attitude / 200.0` (-50% to +50%)

| Faction | Prefers | Opposes |
|---------|---------|---------|
| `ruling_authority` | patrol, escort, defend, bounty | — |
| `merchant_guild` | escort, recover | hunt_bandits |
| `militia_command` | patrol, hunt, defend | bounty_target |
| `temple_chapter` | deliver_medicine | bounty_target |
| `criminal_network` | bounty_target | patrol, hunt |
| `peasant_commons` | escort, deliver_medicine | — |

---

## 5. Economy Integration

Dominant faction economy modifiers applied each tick after recalculation:

```
security = clamp(security + dominant.economy_modifiers.security, 0, 100)
prosperity = clamp(prosperity + dominant.economy_modifiers.prosperity, 0, 100)
unrest = clamp(unrest + dominant.economy_modifiers.unrest, 0, 100)
corruption = clamp(corruption + dominant.economy_modifiers.corruption, 0, 100)
trade_access = clamp(trade_access + dominant.economy_modifiers.trade_access, 0, 100)
```

---

## 6. 12 Faction Events

Events trigger during weekly tick when conditions met. Max 1 event per settlement per 4 ticks.

| # | Event | Faction | Min Influence | Other Condition |
|---|-------|---------|---------------|-----------------|
| 1 | guild_strike | merchant_guild | 50 | tension ≥ 30 |
| 2 | militia_crackdown | militia_command | 55 | unrest ≥ 40 |
| 3 | priestly_trial | temple_chapter | 45 | corruption ≥ 40 |
| 4 | refugee_riot | peasant_commons | 50 | food shortage |
| 5 | tax_levy | ruling_authority | 60 | prosperity ≥ 50 |
| 6 | criminal_extortion | criminal_network | 45 | trade_access ≥ 40 |
| 7 | grain_hoarding | merchant_guild | 50 | food_stock low |
| 8 | public_execution | ruling_authority | 55 | criminal influence ≥ 30 |
| 9 | protection_racket | criminal_network | 50 | merchant influence ≥ 40 |
| 10 | guard_captain_demand | militia_command | 40 | company.renown ≥ 5 |
| 11 | temple_shelter_dispute | temple_chapter | 40 | peasant influence ≥ 40 |
| 12 | smuggler_informant | criminal_network | 35 | company has active contract |

Each event has 2-3 choices shifting faction influence, attitude, and settlement economy.

---

## 7. Validation

### `tools/validate_internal_factions.py`

- `faction_id` unique, `settlement_id` valid, `type` in allowed 6
- influence 0-100, attitude -100 to 100
- `rival_faction_ids` all exist in same settlement
- `supported/opposed_contract_types` use valid contract type IDs
- Sum of influence NOT normalized (natural simulation values)

---

## 8. Test Cases

```
test_security_low_increases_militia: security=25 → militia +3
test_food_shortage_increases_peasant: food < 2×need → peasant +3
test_prosperity_increases_merchant: prosperity=70 → merchant +2
test_contract_success_boosts_patron: escort completed → merchant +5, attitude +5
test_contract_penalizes_rival: patrol completed → criminal -3
test_dominant_faction_calculation: highest influence = dominant
test_tension_rises_with_close_rivals: both >30 rivals → tension ≥ 12
test_tension_falls_with_dominance: dominant > 70 → tension ≤ 10
test_contracts_reflect_dominant_faction: dominant prefers type → higher priority
test_attitude_decays_toward_zero: attitude 20 → 18 after tick
test_bad_settlement_id_caught: nonexistent settlement → validator error
test_bad_rival_id_caught: rival not in same settlement → validator error
```

---

## 9. What NOT to Build Yet
- No assassination chains, no multi-stage faction quests
- No companion faction loyalty/romance
- No multi-settlement faction wars
- No procedural dialogue or negotiation UI
- No occult faction deep systems
- No save/load for faction state

---

## 10. Acceptance Criteria
- `data/factions/faction_types.json` with 6 types
- `data/factions/internal_factions.json` with factions for 3 settlements
- `SettlementFactionSystem.gd` with weekly tick, economy/contract/attitude shifts
- Settlement economy extended with faction state fields
- 12 faction events in `data/events/faction_events.json`
- Validator passes, 13 tests pass
- `python tools/run_all_tests.py` exits zero
- Existing economy tick, route dynamics, autoplay still pass
