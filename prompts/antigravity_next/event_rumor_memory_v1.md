# Antigravity Task D: Event/Rumor/Memory V1 Implementation

## Task
Implement the minimum viable event, rumor, and world memory layer from the DeepSeek spec. Start with events only; add rumors and memory if scope allows.

## Branch
Create: `feature/event-rumor-memory-v1` (off main)

## Model
Use Gemini 3.1 Pro High. This involves GDScript system implementation.

## Prerequisites
Read before starting:
- `docs/event_rumor_memory_v1_spec.md` — full specification (if on main)
- `spec/deepseek-event-rumor-memory-v1` — DeepSeek spec branch (reference)
- `game/scripts/world/WorldEconomySystem.gd` — integration point
- `game/scripts/contracts/ContractSystem.gd` — contract resolution hook

## Implementation (Phased)

### Phase 1: Events Only (must complete)

1. Create `data/events/event_templates.json` with 8 priority events:
   - `food_shortage` (settlement)
   - `medicine_crisis` (settlement)
   - `rising_unrest` (settlement)
   - `bandit_surge` (road)
   - `route_blocked_event` (road)
   - `route_reopened` (road)
   - `route_secured` (road)
   - `caravan_destroyed` (route_trade)

2. Create `game/scripts/world/EventSystem.gd`:
   - `configure(templates)` — load event templates
   - `evaluate_and_fire(world_state, tick)` — check trigger conditions, apply cooldowns, cap at 3 events/tick, apply choice auto-effects, return fired events
   - Trigger operators: `lt`, `lte`, `gt`, `gte`, `eq`, `neq`

3. Wire into `WorldEconomySystem.weekly_tick()`:
   - After all settlement/route ticks complete, call `event_system.evaluate_and_fire(world_state, tick)`
   - Apply any settlement/route deltas from fired events

4. Wire into `ContractSystem`:
   - After `fail()`, if contract caused route effects, fire `caravan_destroyed` event if applicable

5. Create `tools/validate_event_rumor_memory.py` (validate event templates)

6. Create `tools/tests/test_event_rumor_memory.py` with 6 tests:
   - Food shortage triggers event
   - Cooldown prevents spam
   - Bandit surge triggers from high bandit_pressure
   - Same seed same events
   - Changed state changes priorities
   - Invalid event ref fails validation

### Phase 2: Rumors + Memory (if time permits)

7. Create `game/scripts/world/RumorSystem.gd`:
   - Generate rumors from fired events' `rumor_entry` fields
   - Generate from settlement economy thresholds
   - Deduplicate, sort by urgency, top 5
   - Expire old rumors

8. Create `game/scripts/world/WorldMemorySystem.gd`:
   - 200-entry ring buffer
   - `record(entry)` — add memory entry
   - `recent(n)` — get last N entries
   - Minor entries expire after 52 ticks

9. Add debug text to RoadScreen showing:
   - "Last events:" with 3 most recent event titles
   - "Active rumors:" with 5 most urgent rumors

## What NOT to Build
- No rumor propagation across distant settlements
- No memory persistence (save/load)
- No procedural prose generation
- No event art
- No quest chains

## Acceptance Criteria
- 8 event templates in JSON
- EventSystem.gd fires events based on world state
- Anti-spam: cooldowns enforced, max 3 events/tick
- Validator passes
- 6 tests pass
- `python tools/run_all_tests.py` exits zero
- Existing autoplay smoke still passes

## After
```
python tools/validate_event_rumor_memory.py
python tools/run_all_tests.py
git add [files]
git commit -m "world: add event rumor memory v1"
git push -u origin feature/event-rumor-memory-v1
```
