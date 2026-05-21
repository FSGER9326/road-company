# Codex Next Prompt: Event, Rumor, and World Memory V1

## Task
Implement event, rumor, and world memory systems. Events fire from world-state conditions. Rumors spread partial info. Memory records outcomes.

## Prerequisites
Read: `docs/event_rumor_memory_v1_spec.md`, `docs/world_tick_v1.md`, `game/scripts/world/WorldEconomySystem.gd`

## Steps

### 1. Create event templates
`data/events/event_templates.json` — 15 events per spec.

### 2. Create rumor templates
`data/events/rumor_templates.json` — 8 rumor text templates.

### 3. EventSystem.gd
`game/scripts/world/EventSystem.gd` — evaluate triggers (lt/lte/gt/gte/eq/neq/change_gt), apply anti-spam caps, fire events, resolve choice effects.

### 4. RumorSystem.gd
`game/scripts/world/RumorSystem.gd` — generate from events + economy thresholds + route state. Deduplicate, sort, top 5, expire old.

### 5. WorldMemorySystem.gd
`game/scripts/world/WorldMemorySystem.gd` — 200-entry ring buffer. record(), recent(), for_settlement(), visible_to_player().

### 6. Wire into WorldEconomySystem weekly_tick() — fire events, generate rumors, record memory after all ticks.

### 7. Wire into ContractSystem — record contract_outcome memory.

### 8. Validator: `tools/validate_event_rumor_memory.py`

### 9. Tests: `tools/tests/test_event_rumor_memory.py` — 10 tests

### 10. Wire validator into `run_all_tests.py`

## Acceptance
- 15 events, 3 system scripts, events fire, rumors appear, memory logs
- Anti-spam enforced, 10 tests pass, `run_all_tests.py` exits zero

## After
```
python tools/validate_event_rumor_memory.py
python tools/run_all_tests.py
```
