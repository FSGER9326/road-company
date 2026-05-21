# Event, Rumor, and World Memory V1 — Specification

## Purpose
Make the simulated world readable to the player. Events fire when world-state conditions are met. Rumors spread partial information about changes. A world/company memory log records important outcomes. Together these turn a silent simulation into a living world without requiring hand-authored quests.

## Scope
Single Codex pass. Builds on world_tick_v1, route dynamics, and settlement factions. Adds road events, settlement events, rumor generation, and memory logging. Deterministic. No dialogue trees, no full quest chains.

---

## 1. Event System

| Category | Fires On | Example |
|----------|---------|---------|
| `road` | Weekly tick | Bandit surge, route blocked/reopened |
| `settlement` | Weekly tick | Food shortage, medicine crisis, unrest spike |
| `route_trade` | Weekly tick | Trade flow collapse, route stabilized |
| `faction` | Weekly tick | Dominant faction change, tension spike |
| `contract_outcome` | Immediate | Significant contract success/failure |
| `company` | Immediate | Fighter death, renown milestone |

### Event Template Schema
```json
{
  "event_id": "food_shortage",
  "category": "settlement",
  "title": "Granaries Run Thin",
  "trigger": {
    "conditions": [{"field": "settlement.food_stock", "op": "lt", "value_desc": "3x weekly_need"}],
    "cooldown_ticks": 8,
    "weight": 0.8
  },
  "text": "The granaries in {settlement} are running thin.",
  "choices": [
    {"id": "donate", "label": "Donate grain", "requirement": {"company_food": 20}, "effects": {"company": {"food": -20}, "settlement": {"food_stock": 15, "unrest": -5}}},
    {"id": "ignore", "label": "Move on", "effects": {"settlement": {"unrest": 3}}}
  ],
  "memory_entry": {"title": "Food shortage hit {settlement}", "significance": "minor"},
  "rumor_entry": {"text": "They say {settlement} is running out of grain.", "truth": 0.9, "urgency": 3}
}
```

### Operators: lt, lte, gt, gte, eq, neq, change_gt

### 15 V1 Event Templates
1. `food_shortage` — food < 3× weekly need
2. `medicine_crisis` — medicine < pop/400
3. `rising_unrest` — unrest > 60
4. `trade_boom` — trade_access > 80, prosperity > 60
5. `prosperity_collapse` — prosperity dropped 15+
6. `refugee_wave` — population gained 20+ in one tick
7. `population_exodus` — population lost 20+ in one tick
8. `bandit_surge` — bandit_pressure > 70
9. `route_blocked` — route blocked this tick
10. `route_reopened` — route unblocked this tick
11. `route_secured` — status changed to "secure"
12. `trade_route_decline` — trade_flow dropped 20+
13. `faction_takeover` — dominant_faction_id changed
14. `faction_tension_spike` — faction_tension > 60
15. `caravan_destroyed` — contract failed on route

---

## 2. Rumor System

### Schema
```json
{
  "rumor_id": "rumor_blackford_famine_042",
  "source_type": "event|settlement_tick|route_tick",
  "source_location": "blackford",
  "text": "They say Blackford's granaries are running thin.",
  "truth_level": 0.9,
  "urgency": 3,
  "expires_after_ticks": 6,
  "generated_tick": 42,
  "generated_from": "food_shortage",
  "revealed_state_tags": ["food_shortage"]
}
```

### Generation: from event memory (discoverable rumors, last 4 ticks), settlement thresholds, route thresholds. Deduplicate by settlement+tags, sort by urgency, top 5, expire old.

### Truth: 1.0=confirmed, 0.7-0.9=reliable, 0.4-0.6=uncertain. Urgency: 1-2=dim, 3=normal, 4=bright, 5=red.

---

## 3. World Memory Log

### Schema
```json
{
  "entry_id": "mem_142",
  "tick": 42,
  "category": "settlement_event|combat_result|contract_outcome|faction_change|route_change|company_event",
  "title": "Food Shortage in Blackford",
  "summary": "Grain fell below three weeks of need.",
  "tags": ["food_crisis"],
  "significance": "minor",
  "visible_to_player": true
}
```

### Retention: 200-entry ring buffer. Minor expire after 52 ticks. Major/critical never expire.

---

## 4. Integration
- Weekly tick: after all ticks, fire events, generate rumors, record memory
- Contract resolution: record contract_outcome memory
- Faction tick: fire faction events on dominant change or tension spike
- Combat/camp: record combat_result, fighter death memory

---

## 5. Anti-Spam
- Cooldown per template (min 4 ticks)
- Max 1 settlement + 1 route event per location per tick
- Max 5 rumors displayed
- Max 3 events total per tick
- Memory dedup: same category+location+tags within 4 ticks → skip

---

## 6. Test Cases (10)
Food shortage triggers event. Cooldown prevents spam. Dangerous route generates rumor. Escort success creates memory. Route secured generates rumor. Same seed same events. Changed state changes priorities. Memory respects cap. Invalid ref fails validation. Per-location cap enforced.

---

## 7. Acceptance Criteria
15 events, EventSystem.gd, RumorSystem.gd, WorldMemorySystem.gd. Events fire, rumors appear, memory logs. Anti-spam enforced. Validator + 10 tests pass. `run_all_tests.py` exits zero. Autoplay still passes.
