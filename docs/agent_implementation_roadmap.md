# Agent Implementation Roadmap

## Purpose
Staged implementation plan for coding agents to build ROAD COMPANY incrementally. Each stage has exact goals, files touched, tests, and acceptance criteria.

---

## Roadmap Table

| Stage | Goal | Files Touched | Tests | Risk |
|-------|------|--------------|-------|------|
| **0** | Stabilize current vertical slice | All existing | All existing | Low |
| **1** | Add automated test harness | tools/ tests | New tests | Low |
| **2** | World simulation data model | data/world/, data/factions/ | New validators | Low |
| **3** | Settlement economy tick | game/scripts/ | New tests | Medium |
| **4** | Internal settlement factions | data/factions/, game/scripts/ | New tests | Medium |
| **5** | Route dynamics | game/scripts/road/ | New tests | Medium |
| **6** | Contract generator from world state | data/contracts/, game/scripts/contracts/ | New tests | Medium |
| **7** | Combat stat refactor | game/scripts/combat/, data/combat/ | New tests | High |
| **8** | Conditions and abilities | data/combat/, game/scripts/combat/ | New tests | High |
| **9** | Camp roles and companion opinions | data/company/, game/scripts/camp/ | New tests | Medium |
| **10** | Emergent story and rumor engine | data/events/, game/scripts/ | New tests | High |
| **11** | Economy and trade UI | game/scripts/, game/scenes/ | New tests | Medium |
| **12** | UI polish and debug panels | game/scripts/ui/, game/scenes/ | Manual/QE | Low |
| **13** | Content expansion | data/ | New data validators | Low |
| **14** | Balancing and simulation dashboards | tools/ | New tools | Medium |

---

## Stage 0: Stabilize Current Vertical Slice

**Goal**: Ensure the current prototype passes all existing tests consistently.

**Files Likely Touched**:
- All existing `.gd` files
- All existing `.json` files
- `tools/run_all_tests.py`
- `tools/tests/test_gameplay_sim.py`

**Data Added**: None new, validate existing data.

**Systems Added**: Bug fixes only.

**Tests Added**: Fix any failing tests.

**Acceptance Criteria**:
- `python tools/run_all_tests.py` passes
- Headless Godot autoplay smoke passes
- No JSON validation errors
- All 4 contracts resolvable

**Risks**: Low. Just bug fixes.

**Next Prompt for Codex**:
> "Run `python tools/run_all_tests.py` and fix any failing tests. Ensure all validators pass. Verify the escort smoke autoplay reaches aftermath without crashing. Fix any armor repair cap issues. Report results."

---

## Stage 1: Add Automated Test Harness

**Goal**: Establish comprehensive test infrastructure that future stages depend on.

**Files Likely Touched**:
- `tools/run_all_tests.py` - extend to discover more tests
- `tools/tests/test_economy.py` - new
- `tools/tests/test_faction_influence.py` - new
- `tools/tests/test_event_triggers.py` - new
- `tools/tests/test_combat_deep.py` - new
- `tools/tests/test_settlement_sim.py` - new
- `tools/test_helpers.py` - new fixture helpers

**Data Added**: None, test infrastructure only.

**Systems Added**:
- Deterministic test helpers (seeded world state)
- Snapshot comparison tests
- Combat replay tests
- Economy tick tests

**Tests Added**:
- All test files above

**Acceptance Criteria**:
- `python -m unittest discover -s tools/tests` runs all new test files
- Every test file has at least 3 test cases
- Tests use seed 12345 for reproducibility
- Snapshot tests record expected outputs

**Risks**: Low. Tests only, no game changes.

**Next Prompt for Codex**:
> "Create comprehensive test infrastructure. Add test helper fixtures in tools/test_helpers.py that create seeded world states, companies, and settlements. Add test files for economy, faction influence, event triggers, combat math (deep), and settlement simulation. Each file must have 3+ test cases. All tests must pass. Use seed 12345 for determinism."

---

## Stage 2: World Simulation Data Model

**Goal**: Add nations, regions, settlements (full model), routes (full model), and sites data. Create WorldState runtime class.

**Files Likely Touched**:
- `data/world/nations.json` - new
- `data/world/regions.json` - new
- `data/world/settlements.json` - new (full schema)
- `data/world/sites.json` - new
- `data/world/routes.json` - extend existing
- `data/world/locations.json` - migrate to settlements.json
- `data/factions/internal_faction_types.json` - new
- `game/scripts/core/WorldState.gd` - new
- `game/scripts/core/DataStore.gd` - extend to load new files
- `tools/validate_nations.py` - new
- `tools/validate_regions.py` - new
- `tools/validate_settlements.py` - new
- `tools/validate_sites.py` - new
- `tools/validate_data.py` - extend

**Data Added**:
- `nations.json`: 3 nations
- `regions.json`: 5 regions
- `settlements.json`: 3 existing + 5 new settlements
- `sites.json`: 8 sites
- `internal_faction_types.json`: 15 faction types

**Systems Added**:
- `WorldState.gd` - holds all world data loaded from JSON
- Extended `DataStore.gd` to load new files

**Tests Added**:
- Python validators for each new file
- WorldState construction test

**Acceptance Criteria**:
- All new JSON files validate
- DataStore loads all new files
- WorldState constructed with proper references
- Existing vertical slice still works
- Settlement references resolve correctly (nation_id, region_id)

**Risks**: Low. Data-only changes, no simulation yet.

**Next Prompt for Codex**:
> "Add the full world data model. Create nations.json (3 nations), regions.json (5 regions), settlements.json (8 settlements including 3 existing), sites.json (8 sites), and internal_faction_types.json (15 types). Extend DataStore to load these. Create WorldState.gd class. Write Python validators for each new file. Ensure existing data/locations.json is migrated to settlements.json format. Run all validators. The existing vertical slice must still work."

---

## Stage 3: Settlement Economy Tick

**Goal**: Implement settlement daily tick logic for food, medicine, tools consumption/production, and prosperity calculation.

**Files Likely Touched**:
- `game/scripts/world/SettlementEconomySystem.gd` - new
- `game/scripts/world/WorldTickSystem.gd` - new
- `game/scripts/core/WorldState.gd` - extend
- `data/economy/trade_goods.json` - new
- `data/economy/market_tiers.json` - new
- `tools/tests/test_settlement_sim.py` - extend
- `tools/validate_economy.py` - new

**Data Added**:
- `trade_goods.json`: 14 goods
- `market_tiers.json`: 6 tiers

**Systems Added**:
- `SettlementEconomySystem.gd` - daily production/consumption
- `WorldTickSystem.gd` - triggers weekly ticks
- Market price derivation
- Population growth/decline formulas

**Tests Added**:
- Settlement consumption reduces stock
- Shortage increases market price
- Prosperous settlements grow
- Starving settlements decline
- Market price clamping

**Acceptance Criteria**:
- 3+ automated settlement tick tests pass
- Market prices stay within 0.5x-3.0x of base
- Population responds to prosperity correctly
- Unrest tracks food/security/corruption

**Risks**: Medium. Must integrate with existing CompanyState.

**Next Prompt for Codex**:
> "Implement settlement economy tick system. Create SettlementEconomySystem.gd with daily settlement_tick() that handles food/medicine/tools consumption and production, unrest calculation, prosperity recalculation, and population growth/decline. Create WorldTickSystem.gd to trigger world ticks. Create trade_goods.json (14 goods) and market_tiers.json (6 tiers). Write automated tests for consumption, market prices, growth, and decline. Use the formulas from docs/economy_trade_growth_design.md."

---

## Stage 4: Internal Settlement Factions

**Goal**: Implement faction influence, attitudes, internal conflict events, and player interaction with settlement factions.

**Files Likely Touched**:
- `game/scripts/world/SettlementFactionSystem.gd` - new
- `game/scripts/world/SettlementEventSystem.gd` - new
- `game/scripts/world/SettlementPolicySystem.gd` - new
- `data/factions/internal_faction_types.json` - extend with policies
- `tools/tests/test_faction_influence.py` - extend

**Data Added**:
- Settlement policies in faction types
- Faction event templates

**Systems Added**:
- Faction influence change (contracts, interaction, time drift)
- Faction attitude shifts
- Internal settlement conflict event triggers
- Settlement policy application

**Tests Added**:
- Contract completion shifts faction influence
- Betrayal causes influence drop
- Dominant factions drift toward equilibrium
- Suppressed factions recover
- Civil conflict triggers when two big enemies clash

**Acceptance Criteria**:
- Player contracts modify faction influence
- Faction attitudes change based on influence
- Internal settlement events trigger based on conditions
- Settlement policies apply correct modifiers

**Risks**: Medium. Must wire to existing contract system.

**Next Prompt for Codex**:
> "Implement settlement internal faction system. Create SettlementFactionSystem.gd with influence change logic (contract completion +5, betrayal -20, natural drift ±1). Create SettlementEventSystem.gd that checks trigger conditions and fires internal settlement events. Add 10 event templates (toll dispute, guild strike, plague outbreak, etc). Create SettlementPolicySystem.gd for faction policy pushing. Create tests for influence changes and event triggering. Follow docs/faction_settlement_design.md."

---

## Stage 5: Route Dynamics

**Goal**: Implement dynamic route state: bandit pressure, patrol presence, traffic, danger recalculation, route closure, and player effects.

**Files Likely Touched**:
- `game/scripts/road/RouteSimSystem.gd` - new
- `game/scripts/road/RoadSystem.gd` - extend
- `game/scripts/road/RoadScreen.gd` - extend for route info

**Systems Added**:
- Route daily traffic calculation
- Effective danger recalculation
- Route closure checks (war, siege, plague)
- Player route effects (escorting, hunting, raiding, patrolling)

**Tests Added**:
- Route traffic responds to settlement prosperity
- Bandit pressure increases effective danger
- Patrol presence decreases effective danger
- Player escort contract lowers bandit pressure
- War between nations closes routes

**Acceptance Criteria**:
- Route danger changes based on bandit/patrol pressure
- Route closure triggered by valid conditions
- Player actions modify route state
- Settlement trade access responds to connected route state

**Risks**: Medium. Must integrate with settlement economy.

**Next Prompt for Codex**:
> "Implement route dynamics system. Create RouteSimSystem.gd with daily route tick: traffic calculation, effective danger (bandit factor vs patrol factor), route closure checks (war, siege, plague). Extend RoadSystem.gd to apply player route effects. Write tests for traffic, danger, closure, and player effects. Follow docs/world_simulation_design.md section 4."

---

## Stage 6: Contract Generator from World State

**Goal**: Contracts now generated from faction needs, settlement situations, and route states, not just static JSON.

**Files Likely Touched**:
- `game/scripts/contracts/ContractGenerator.gd` - new
- `game/scripts/contracts/ContractSystem.gd` - extend
- `data/contracts/contract_templates.json` - new
- `game/scripts/ui/ContractBoard.gd` - extend

**Data Added**:
- `contract_templates.json`: 20 templates with spawn conditions

**Systems Added**:
- Contract generation from faction needs
- Contract generation from settlement situations
- Contract generation from route danger
- Contract reward scaling based on danger/urgency
- Hidden patron support
- Moral complication tags

**Tests Added**:
- Starving settlement generates food delivery contracts
- High bandit pressure generates hunt contracts
- Faction influence determines contract availability
- Contract rewards scale with danger

**Acceptance Criteria**:
- Contracts are generated dynamically from world state
- Contract board shows 3-5 appropriate contracts per settlement
- Contract types vary based on settlement conditions
- Hidden patrons can exist

**Risks**: Medium. Must not break existing static contract resolution.

**Next Prompt for Codex**:
> "Implement dynamic contract generation. Create ContractGenerator.gd that creates contracts from world state: faction needs, settlement situations, route danger. Create contract_templates.json with 20 templates and spawn conditions. Contracts should scale rewards with danger. Support hidden patrons. Extend ContractBoard.gd to show generated contracts. Tests: verify contracts spawn for correct conditions."

---

## Stage 7: Combat Stat Refactor

**Goal**: Add attribute system, expand weapon families, add enemy archetypes, and add battlefield objectives beyond kill_all.

**Files Likely Touched**:
- `game/scripts/combat/CombatSystem.gd` - extend
- `game/scripts/combat/CombatScreen.gd` - extend
- `game/scripts/combat/CombatBoard.gd` - extend
- `data/combat/weapons.json` - extend to 12 families
- `data/combat/enemies.json` - extend to 12 archetypes
- `data/combat/armor.json` - extend
- `data/combat/encounters.json` - extend with objectives

**Systems Added**:
- Attribute system (6 attributes mapped to derived stats)
- Attribute-to-combat-stat derivation
- 12 weapon families with stat profiles
- 12 enemy archetypes
- Battlefield objectives (kill_all, escort, capture_point, survive, etc.)
- Extraction zones
- Zone of control (adjacent hex movement penalty)

**Tests Added**:
- Attribute derivation produces correct values
- Weapon family tags match
- Objective victory/loss conditions
- ZOC movement penalty
- Extraction zone detection

**Acceptance Criteria**:
- Fighters have attributes affecting combat stats
- Weapons categorized by family with tags
- Enemies use 12 distinct archetypes
- Combat can end via non-kill-all objectives
- ZOC affects movement

**Risks**: High. Must not break existing combat loop. Keep backward compatibility.

**Next Prompt for Codex**:
> "Refactor combat with attribute system. Add 6 attributes (Might, Agility, Endurance, Wits, Will, Presence) to fighter schema. Create derivation function from attributes+equipment+level to combat stats. Extend weapons.json to 12 families with tags. Extend enemies.json to 12 archetypes. Add battlefield objectives (kill_all, escort, capture_point, survive, eliminate_leader) and objective check. Add Zone of Control. Keep backward compatibility with existing combat. Test attribute derivation and objectives."

---

## Stage 8: Conditions and Abilities

**Goal**: Add conditions, ability system, and magic/rituals to combat.

**Files Likely Touched**:
- `game/scripts/combat/ConditionSystem.gd` - new
- `game/scripts/combat/AbilitySystem.gd` - new
- `game/scripts/combat/MagicSystem.gd` - new
- `data/combat/conditions.json` - new
- `data/combat/abilities.json` - new
- `game/scripts/combat/CombatScreen.gd` - extend with ability UI
- `game/scripts/camp/CampSystem.gd` - extend with rituals

**Data Added**:
- `conditions.json`: 16 conditions
- `abilities.json`: 25+ abilities across 8 archetypes

**Systems Added**:
- Condition application and duration tracking
- Condition effect resolution per round
- Ability use validation (AP, fatigue, uses_per_combat, requirements)
- Ability effect resolution
- Magic/ritual system (8 spells, corruption, faction consequences)

**Tests Added**:
- Condition stacking and duration ticks
- Ability can_use validation
- Ability effects apply correctly
- Magic corruption tracking
- Magic costs and consequences

**Acceptance Criteria**:
- Conditions apply and expire correctly
- Abilities validated and executed
- Magic has costs and corruption risk
- UI shows conditions and available abilities

**Risks**: High. Complex state management. Must integrate with existing combat.

**Next Prompt for Codex**:
> "Add conditions and abilities to combat. Create conditions.json (16 conditions: bleeding, stunned, etc). Create abilities.json (25+ abilities across 8 archetypes). Build ConditionSystem.gd for applying/ticking/removing conditions. Build AbilitySystem.gd for ability validation and resolution. Build MagicSystem.gd for 8 rituals/magic spells with corruption tracking. Extend CombatScreen.gd to show conditions. Write tests for condition lifecycle and ability validation."

---

## Stage 9: Camp Roles and Companion Opinions

**Goal**: Add camp roles, companion approval system, camp actions beyond rest/repair/treat, and authored companion data.

**Files Likely Touched**:
- `game/scripts/camp/CampSystem.gd` - extend
- `game/scripts/company/CompanionSystem.gd` - new
- `game/scripts/company/RecruitSystem.gd` - new
- `data/company/backgrounds.json` - new
- `data/company/traits.json` - extend
- `data/company/camp_actions.json` - new
- `data/company/companions.json` - new
- `game/scripts/core/CompanyState.gd` - extend

**Data Added**:
- `backgrounds.json`: 20 recruit backgrounds
- `traits.json`: 12 traits extended
- `camp_actions.json`: 8 camp actions
- `companions.json`: 8 authored companions

**Systems Added**:
- Camp role assignment (medic, quartermaster, scout, cook, etc)
- Companion approval/disapproval from contracts
- Companion betrayal/retirement/death
- Procedural recruit generation from backgrounds
- Camp actions (train, scout, interrogate, bury, hold council, perform ritual, craft, manage prisoners)

**Tests Added**:
- Recruit generation produces valid fighters
- Companion approval shifts on contract type
- Companion betrays at threshold
- Camp actions consume correct resources
- Camp action effects apply correctly

**Acceptance Criteria**:
- Recruits generated with proper attributes from backgrounds
- Companions react to player contract choices
- Camp shows 5+ available actions
- Camp role bonuses apply

**Risks**: Medium. Must integrate companions with existing roster system.

**Next Prompt for Codex**:
> "Implement camp roles and companion opinions. Create backgrounds.json (20 backgrounds), traits.json (12 traits extended), camp_actions.json (8 actions: train, scout, interrogate, bury dead, hold council, perform ritual, craft gear, manage prisoners), and companions.json (8 authored companions with approval hooks). Build CompanionSystem.gd with approval tracking and betrayal logic. Build RecruitSystem.gd for procedural generation. Extend CampSystem.gd for new actions. Extend CompanyState.gd for camp role tracking. Write tests for recruitment, approval shifts, and betrayal."

---

## Stage 10: Emergent Story and Rumor Engine

**Goal**: Implement event template system, world memory, rumor generation, NPC generation, and consequence cascades.

**Files Likely Touched**:
- `game/scripts/world/EventSystem.gd` - new
- `game/scripts/world/WorldMemorySystem.gd` - new
- `game/scripts/world/RumorSystem.gd` - new
- `game/scripts/world/NPCSystem.gd` - new
- `game/scripts/world/RivalCompanySystem.gd` - new
- `game/scripts/company/CompanyChronicle.gd` - new
- `data/events/event_templates.json` - new
- `data/events/situation_definitions.json` - new
- `data/events/rumor_templates.json` - new

**Data Added**:
- `event_templates.json`: 30+ event templates
- `situation_definitions.json`: 20 situation types
- `rumor_templates.json`: 15 rumor formats

**Systems Added**:
- Event template evaluation and weighted selection
- World memory recording and querying
- Rumor generation from world state
- Named NPC generation
- Rival company generation and tracking
- Consequence cascade rules
- Company chronicle

**Tests Added**:
- Event cooldown prevents spam
- Events fire when conditions met
- Rumors match current world state
- Memory log records significant events
- Cascade effects propagate correctly

**Acceptance Criteria**:
- Events fire based on world state conditions
- Rumors appear at settlements (text only initially)
- Company chronicle records major actions
- NPCs generated with consistent attributes
- Rival companies spawn and compete

**Risks**: High. Complex interconnected systems. Must not generate events too aggressively.

**Next Prompt for Codex**:
> "Implement emergent story engine. Create event_templates.json with 30+ templates using trigger conditions from docs/emergent_story_design.md. Build EventSystem.gd for template evaluation and weighted selection. Build WorldMemorySystem.gd for event logging. Build RumorSystem.gd for rumor generation from world state. Build NPCSystem.gd and RivalCompanySystem.gd. Create CompanyChronicle.gd. Implement consequence cascade rules (food shortage -> unrest -> refugee -> neighbor pressure). Write tests for event triggers, cooldowns, and rumor accuracy."

---

## Stage 11: Economy and Trade UI

**Goal**: Add player trading UI, settlement market panel, and company inventory management.

**Files Likely Touched**:
- `game/scripts/ui/MarketScreen.gd` - new
- `game/scripts/world/EconomySystem.gd` - new
- `game/scripts/core/CompanyState.gd` - extend with inventory
- `game/scripts/ui/ContractBoard.gd` - extend

**Systems Added**:
- Player buy/sell functionality
- Market price display based on settlement state
- Company inventory tracking
- Trade good weight and carry capacity
- Settlement market panel

**Tests Added**:
- Buy reduces crowns, increases inventory
- Sell reduces inventory, increases crowns
- Prices respond to settlement stock
- Cannot buy without sufficient crowns

**Acceptance Criteria**:
- Player can buy/sell goods at settlements
- Prices reflect supply and demand
- Company inventory tracked and displayed
- Market panel shows all tradeable goods with prices

**Risks**: Low. UI work with existing-compatible systems.

**Next Prompt for Codex**:
> "Add economy and trade UI. Create EconomySystem.gd with buy/sell functions using price derivation from settlement state. Create MarketScreen.gd showing settlement market panel with all tradeable goods, current prices, and player inventory. Extend CompanyState.gd with inventory dictionary. Implement carry capacity from company roster. Write tests for buy/sell and price derivation."

---

## Stage 12: UI Polish and Debug Panels

**Goal**: Make all systems visible through readable UI elements and debug panels.

**Files Likely Touched**:
- Multiple UI `.gd` files
- `game/scripts/ui/DebugPanel.gd` - new
- `game/scripts/ui/WorldInfoPanel.gd` - new
- Settlement screen, faction screen, market screen

**Systems Added**:
- Settlement info panel (stats, factions, situations)
- Route detail panel (danger breakdown, traffic)
- Debug overlay for simulation state
- Company dashboard (resources, roster, chronicle)

**Acceptance Criteria**:
- All simulation data visible somewhere in UI
- Debug panel shows world tick state
- Settlement panel shows all stats and factions

**Risks**: Low. UI only.

---

## Stage 13: Content Expansion

**Goal**: Expand from 3 settlements to 15-20, add more factions, events, contracts, and enemies.

**Files Likely Touched**:
- All `.json` data files

**Data Added**:
- 15-20 settlements total
- 8-10 regions
- 4-5 nations
- 30+ event templates
- 40+ contracts
- 15+ enemy types
- 20+ sites

**Acceptance Criteria**:
- All data validates
- World feels populated
- Variety in contracts and encounters

**Risks**: Low. Data only.

---

## Stage 14: Balancing and Simulation Dashboards

**Goal**: Create Python tools for balancing numbers and visualizing simulation state.

**Files Likely Touched**:
- `tools/balance_dashboard.py` - new
- `tools/sim_viz.py` - new
- `tools/run_simulation.py` - new

**Systems Added**:
- Simulation runner for 100+ days without UI
- Profit/loss analysis
- Settlemenet health tracking
- Combat balance calculator

**Acceptance Criteria**:
- `python tools/run_simulation.py --days 200` produces valid results
- Balance dashboard shows stats distributions
- Combat calculator estimates encounter difficulty

**Risks**: Medium. Pure analysis, no game changes.

---

## Highest-Risk Systems

1. **Combat refactor (Stage 7-8)**: Backward compatibility critical. High complexity.
2. **Emergent story (Stage 10)**: Risk of event spam. Must have aggressive cooldowns.
3. **Economy simulation (Stage 3)**: Risk of runaway death spirals. Must have clamping.
4. **Internal factions (Stage 4)**: Risk of overpowering settlement controllers.

---

## What NOT to Build Yet

1. **Procedural map generation** - use hand-authored world for 10+ passes
2. **3D or isometric rendering** - 2D only
3. **Complex animation rigs** - tokens and readable overlays only
4. **Full voice acting** - text only
5. **Multiplayer** - single player only
6. **Custom engine** - Godot 4.x only
7. **Procedural quest chains** - event templates only
8. **Full save/load** - MVP doesn't need it
9. **GdUnit4** - lightweight test harness works for now
10. **Web export** - desktop only initially

---

## Agent Workflow Before Commit

```
1. Make changes
2. python tools/run_all_tests.py
3. If godot available: godot --headless --path . -s res://tools/godot/run_godot_tests.gd
4. Targeted validator for changed system
5. Commit with descriptive message
```

---

## Recommended Order

Stages 0-2 can be done in parallel by separate agents (data, validation, tests). Stages 3-6 must be sequential (each builds on the last). Stages 7-8 can be parallel to 3-6 (combat is mostly separate from world sim). Stages 9-10 depend on stages 3-6. Stages 11-14 come after everything else.

**Suggested agent assignments**:
- **Agent A**: Stages 0-2 (stabilize, test harness, world data)
- **Agent B**: Stages 3-6 (economy, factions, routes, contracts)
- **Agent C**: Stages 7-8 (combat refactor)
- **Agent D**: Stages 9-10 (camp/companions, story engine)
- **Agent E**: Stages 11-14 (UI, content, balancing)

---

## First 10 Implementation Prompts

1. "Stabilize current vertical slice. Fix all failing tests. Run validators."
2. "Create comprehensive test infrastructure with test_helpers.py fixtures."
3. "Add full world data model: nations, regions, settlements, routes, sites."
4. "Implement settlement economy tick system."
5. "Implement internal settlement faction system."
6. "Implement route dynamics system."
7. "Implement dynamic contract generator from world state."
8. "Refactor combat with attribute system and 12 weapon families."
9. "Add conditions and abilities to combat."
10. "Implement camp roles and companion opinions."
