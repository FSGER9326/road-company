# Emergent Story Design

## Purpose
Design an emergent narrative system that generates compelling stories from world state without hand-written quests. Stories arise from faction interactions, economic shifts, contract outcomes, battle results, and player choices.

---

## 1. Core Principles

1. **No hardcoded narrative branches** - stories emerge from simulation state
2. **Causality is visible** - players can trace why something happened
3. **Consequences accumulate** - small actions compound over time
4. **Rumors bridge knowledge gaps** - not everything should be known
5. **Memory persists** - the world remembers player actions

---

## 2. World Facts System

### Purpose
Define atomic facts about the world that event templates reference.

### Fact Schema

```json
{
  "id": "string",
  "fact_type": "famine|war|plague|prosperity|crime|blessing|curse|invasion|wonder|catastrophe",
  "origin_settlement": "settlement_id|null",
  "origin_route": "route_id|null",
  "origin_site": "site_id|null",
  "severity": "int (1-10)",
  "start_day": "int",
  "expires_day": "int|null",
  "is_active": "bool",
  "effects": {"field": "value"},
  "propagation_speed": "float (settlements per day)",
  "affected_settlements": ["settlement_id"],
  "source_note": "string (how this fact started)"
}
```

### Fact Propagation
```
propagate_fact(fact, world):
    for each settlement within propagation_radius:
        if not already affected:
            if random() < fact.propagation_speed:
                settlement.add_situation(fact.fact_type)
                settlement["affected_settlements"].append(settlement.id)
    fat.propagation_radius += fact.propagation_speed
```

---

## 3. Event Template System

### Purpose
Generate specific events from templates + world state snapshots.

### Event Template Schema

```json
{
  "id": "string",
  "name": "string",
  "category": "road|settlement|contract|faction|combat|camp|world",
  "trigger_conditions": {
    "min_day": "int|null",
    "max_day": "int|null",
    "cooldown_days": "int",
    "settlement_min_population": "int|null",
    "settlement_min_unrest": "int|null",
    "settlement_min_corruption": "int|null",
    "faction_required": "faction_id|null",
    "faction_min_influence": "int|null",
    "player_min_renown": "int|null",
    "reputation_required": {"faction_id": "int"},
    "player_has_contract_type": "contract_type|null",
    "player_company_min": "int|null",
    "not_if_any_situation": ["situation_id"],
    "random_weight": "float (0.0-1.0)"
  },
  "event_text": {
    "headline": "string",
    "flavor_text": "string",
    "outcome_text_good": "string",
    "outcome_text_bad": "string",
    "outcome_text_nothing": "string"
  },
  "choices": [
    {
      "id": "string",
      "label": "string",
      "requirement": {
        "skill": "string|null",
        "dc": "int|null",
        "cost_crowns": "int|null",
        "cost_health": "int|null"
      },
      "outcome": {
        "companion_approval": {"companion_id": "int"},
        "company_effects": {"stat": "int"},
        "item_gain": "item_id|null",
        "unlock_settlement_event": "event_id|null",
        "consequence_flag": "string"
      },
      "preview_text": "string"
    }
  ],
  "automatic_outcome": {
    "description": "string",
    "effects": {}
  }
}
```

---

## 4. Example Emergent Story Chains

### Chain 1: The Starving Town

```
Day 0: Blackford Gate production normal.
Day 7: Route to Embermill dangerous (bandit_pressure 80). Caravan destroyed.
Day 14: Blackford Gate grain stock down to 30 (was 200).
Day 21: Blackford unrest rises. Food riots begin.
Day 28: Guild Council loses influence. Gate nobility seizes emergency powers.
Day 35: Player arrives. Sees "Food shortage" situation.
Day 42: Without grain delivery, Blackford population drops 15%.
Day 56: Refugees flee to Saintsfall. Blackford enters decline.
```

**Story fork A (player intervenes)**: Player clears bandit route, delivers grain. Blackford recovers. Guild Council regains influence. Player becomes local hero.

**Story fork B (player ignores)**: Blackford becomes a ghost town. Bandits establish permanent camp. Route becomes permanently dangerous. Refugee crisis spreads to neighboring settlements.

### Events Triggered in This Chain

```json
[
  {
    "id": "food_shortage_blackford",
    "name": "Food Shortage in Blackford",
    "category": "settlement",
    "trigger_conditions": {
      "settlement_min_population": 500,
      "cooldown_days": 14,
      "random_weight": 0.8
    }
  },
  {
    "id": "food_riots_blackford",
    "name": "Food Riots",
    "category": "settlement",
    "trigger_conditions": {
      "settlement_min_unrest": 65,
      "cooldown_days": 20,
      "random_weight": 0.5
    }
  },
  {
    "id": "refugee_crisis_blackford",
    "name": "Refugees Flee Blackford",
    "category": "settlement",
    "trigger_conditions": {
      "cooldown_days": 30,
      "random_weight": 0.4,
      "not_if_any_situation": ["quarantine"]
    }
  }
]
```

### Chain 2: The Rising Merchant Cartel

```
Day 0: Guild Council weak (influence 28) in Blackford.
Day 7: Player completes 3 delivery contracts for Guild Council.
Day 14: Guild Council influence rises to 45.
Day 21: Player helps guild in Toll Dispute event. Influence now 55.
Day 28: Guild Council pushes "Lower Market Fees" policy. It passes.
Day 35: Blackford market prices drop 15%. Trade increases.
Day 42: More caravans arrive. Blackford prosperity rises.
Day 56: Gate nobility tries to suppress guild. Guild triggers Strike Event.
Day 60: Player backs guild again. Gate nobility influence collapses.
Day 70: Guild Council now dominant. Blackford policies change. New contracts available.
```

**Story fork**: Guild becomes dominant, but may become corrupt. New tension with remaining factions. Player must decide between old alliance or curbing the guild.

### Chain 3: The Cult in the Dark

```
Day 0: Saintsfall corruption high (65), prosperity low (25).
Day 7: Occult pressure detected. Strange events reported.
Day 14: Cult Discovery event triggers.
Day 21: Player ignores it. Cult influence grows (occult_covenant now 25 influence).
Day 28: Cult begins abducting travelers on routes.
Day 35: Lantern Church offers purge contract. Player accepts.
Day 42: Player raids cult lair. Finds evidence of larger network.
Day 56: New cult cells form in Embermill. Chain continues...
```

### Chain 4: Rival Company Emergence

```
Day 0: Player fame = 0.
Day 14: Player achieves 5 successful contracts. Renown = 15.
Day 21: Rival company "Iron Freighters" spawns in Blackford.
Day 28: Iron Freighters undercuts player prices. Takes a contract.
Day 35: Iron Freighters attacks player contract (sabotage).
Day 42: Player defeats Iron Freighters in combat or negotiation.
Day 56: Remaining Iron Freighters become permanent enemy or ally.
```

### Chain 5: Settlement Transformation

```
Day 0: Mining Camp "Ironpit" population 120.
Day 7: Iron vein discovered (random event). Prosperity +25.
Day 14: Player delivers tools and medicine. Population grows.
Day 21: Ironpit prosperity > 60 for 10 days. Upgrade to Village.
Day 28: New factions form: Miner's Union, Ore Merchant, Camp Guard.
Day 35: Ironpit market tier increases. New goods produced.
Day 49: Rival noble house claims ownership. Tension rises.
Day 56: Player must choose side in emerging ownership war.
```

### Chain 6: Companion Defection

```
Day 0: Companion "Mara Vetch" (ditch poacher background) in company.
Day 7: Player takes 3 contracts for Lantern Church. Mara disapproves.
Day 14: Player accepts "Purge Cult" contract. Mara approval = -20.
Day 21: Mara argues with player at camp. Camp event: "Dispute in Ranks".
Day 28: Player takes another Lantern Church contract. Mara leaves at night.
Day 35: Mara joins rival faction (criminal_network). Now an enemy NPC.
Day 49: Player encounters Mara leading ambush. Emotional combat.
```

### Chain 7: The Refugees Become a Settlement

```
Day 0: Refugee Wave event in Saintsfall.
Day 7: Player protects refugees. +20 refugee_bloc influence.
Day 14: Saintsfall can't support them. Refugees move to route.
Day 21: Player delivers grain and tools to refugee camp on route.
Day 28: Camp population reaches 80. Site transforms to "freehold".
Day 35: New settlement "Refuge" appears on map.
Day 42: Refugees grateful to player. Freehold offers exclusive contracts.
```

### Chain 8: Plague and Quarantine Nightmare

```
Day 0: Plague_outbreak_event in Saintsfall.
Day 7: Lantern Cell +15 influence. Quarantine policy enacted.
Day 14: All routes to Saintsfall close. Trade freezes.
Day 21: Embermill loses Saintsfall grain supply. Shortage begins.
Day 28: Desperate merchants try to run quarantine (smuggling contracts).
Day 35: Player delivers medicine. Plague contained.
Day 42: Quarantine lifts. Routes reopen. But some never recovered.
```

### Chain 9: Criminal Syndicate Takeover

```
Day 0: Criminal Network influence 22 in Blackford.
Day 7: Player contracts for criminals (smuggling, debt collection).
Day 14: Criminal influence reaches 50. Gate nobility loses 15.
Day 21: Criminal Network pushes "lax enforcement" policy. It passes.
Day 28: Blackford security drops. Crime rises.
Day 35: Other factions collapse. Criminal Network dominates.
Day 42: Settlement becomes lawless. Good contracts disappear.
Day 56: Lawful factions hire player to purge criminals.
```

### Chain 10: War Comes to the Roads

```
Day 0: Nations "Vale of Kings" and "Iron Reach" at peace.
Day 14: Diplomatic event fails. War declared between nations.
Day 18: Borders close. Multiple routes blocked.
Day 21: Embermill (border town) is_under_siege. All routes close.
Day 28: Militias raised. Men recruited. Player offered lucrative soldier contracts.
Day 35: Food and trade routes shift. New smuggling routes open.
Day 42: Front-line settlements need supplies. High-risk/high-reward contracts.
Day 70: Player actions can influence war outcome through supply delivery or sabotage.
```

---

## 5. Consequence Chain Rules

### Purpose
Events in one system cascade into other systems.

### Cascade Pathways

| Source System | Affects | Via |
|--------------|---------|-----|
| Faction influence change | Settlement stability | Policy changes |
| Settlement population decline | Route traffic | Fewer caravans |
| Route bandit pressure increase | Settlement food stock | Fewer deliveries |
| Settlement food shortage | Population decline | Starvation |
| Settlement prosperity loss | Faction resource decline | Weaker factions |
| War between nations | Route closure | Trade collapse |
| Plague event | Population decline, route closure | Trade freeze |
| Player kills leader | Power vacuum | New faction rises |

### Cascade Implementation

```python
def cascade_food_shortage(settlement, world):
    # 1. Settlement effects
    settlement.unrest += 5
    settlement.prosperity -= 3
    settlement.population -= settlement.population * 0.01
    
    # 2. Faction effects
    faction_with_least_food = find_faction_in_need(settlement, "grain")
    faction_with_least_food.influence -= 5
    
    # 3. Route effects
    for route in routes_from(settlement):
        route.caravan_frequency -= 1  # fewer caravans want to go to starving place
    
    # 4. Neighbor effects
    for neighbor in connected_settlements(settlement, world):
        neighbor.food_stock += 5  # refugees bring some grain
        neighbor.population += 10  # refugees arrive
        neighbor.unrest += 2  # refugee pressure

def cascade_war_declaration(nation_a, nation_b, world):
    # 1. Nation effects
    nation_a.military_strength -= 10  # war costs
    nation_b.military_strength -= 10
    
    # 2. Settlement effects on border
    for settlement in border_settlements(nation_a, nation_b):
        settlement.security -= 20
        settlement.prosperity -= 15
        settlement.is_under_siege = True
    
    # 3. Route effects
    for route in cross_nation_routes(nation_a, nation_b):
        close_route(route, "war")
    
    # 4. Trade effects
    for settlement in nation_a.settlements:
        settlement.trade_access -= 20
    
    # 5. Refugee wave
    spawn_refugee_wave(border_settlements(nation_a, nation_b))
```

---

## 6. Rumor System

### Purpose
Give players partial information about the world through rumors.

### Rumor Schema

```json
{
  "id": "string",
  "topic": "event_id|settlement_id|route_id|faction_id|npc_id",
  "accuracy": "float (0.0-1.0, 1.0 = confirmed fact)",
  "type": "danger|opportunity|warning|gossip|contract",
  "location_relevance": "settlement_id|null",
  "expires_day": "int|null",
  "text": "string"
}
```

### Rumor Generation

```python
def generate_rumors(company, world, count=3):
    rumors = []
    
    # Current events become rumors
    for settlement in world.settlements:
        for situation in settlement.current_situations:
            rumor = Rumor(
                topic=f"{settlement.id}_{situation}",
                accuracy=0.5 + random.random() * 0.5,
                text=generate_rumor_text(settlement, situation, 0.8)
            )
            rumors.append(rumor)
    
    # Faction tensions
    for settlement in world.settlements:
        for faction in settlement.internal_factions:
            if faction.influence >= 60:
                rumor = generate_faction_power_rumor(settlement, faction)
                rumors.append(rumor)
    
    # Dangerous routes
    for route in world.routes:
        if route.effective_danger >= 6:
            rumor = RouteDangerRumor(route)
            rumors.append(rumor)
    
    return random.sample(rumors, min(count, len(rumors)))
```

---

## 7. World Memory Log

### Purpose
Record significant events so the world reacts to history.

### Memory Log Schema

```json
{
  "id": "int (sequential)",
  "day": "int",
  "event_type": "contract_complete|contract_fail|combat_victory|combat_defeat|settlement_change|faction_shift|member_death|companion_join|companion_leave|world_event|player_choice",
  "settlement_id": "string|null",
  "route_id": "string|null",
  "faction_id": "string|null",
  "companion_id": "string|null",
  "description": "string",
  "consequences": "string",
  "severity": "int (1-5)"
}
```

### Memory Example
```json
[
  {
    "id": 1, "day": 7,
    "event_type": "contract_complete",
    "description": "Ash Road Company delivered medicine to Saintsfall during plague.",
    "consequences": "Saintsfall plague contained. Plague doctors grateful.",
    "severity": 4
  },
  {
    "id": 2, "day": 14,
    "event_type": "faction_shift",
    "description": "Gate nobility in Blackford lost 15 influence after failed toll dispute.",
    "consequences": "Guild council gained 8 influence.",
    "severity": 2
  }
]
```

---

## 8. Settlement History Log

### Purpose
Each settlement records its own history for storytelling.

### Settlement History Entry
```json
{
  "settlement_id": "blackford",
  "history": [
    {"day": 0, "event": "settlement_founded", "details": {}},
    {"day": 14, "event": "faction_shift", "faction": "guild_council", "details": {"change": "+8"}},
    {"day": 21, "event": "food_shortage", "details": {"population": 2400, "food_stock": 30}},
    {"day": 28, "event": "player_contract_complete", "details": {"contract": "escort_embermill", "effect": "+5 prosperity"}},
    {"day": 35, "event": "trade_route_closed", "details": {"route": "blackford_saintsfall_oldwood", "reason": "war"}}
  ]
}
```

---

## 9. Company Chronicle

### Purpose
The player's company has its own history visible as a chronicle.

### Chronicle Entry
```json
{
  "id": "int",
  "day": "int",
  "title": "string",
  "description": "string",
  "flavor": "string",
  "losses": ["fighter_name"],
  "rewards": {"crowns": "int", "renown": "int"},
  "choices_made": ["choice_id"]
}
```

### Example Chronicle
```
Day 7: "The Millers' Contract"
"Escorted meal wagons to Embermill. Two fighters wounded. The millers paid in full."
Losses: None. Rewards: 420 crowns, 12 renown.

Day 14: "Saintsfall Deliverance"
"Delivered medicine during plague outbreak. The Lantern Church offered healing in return."
Losses: None. Rewards: 610 crowns, 18 renown.

Day 28: "Ullen Grave Falls"
"Ullen Grave died holding the line against Red Sashes on the Oldwood road."
Losses: "Ullen Grave" Rewards: 520 crowns, 16 renown.
```

---

## 10. Named NPC Generation

### Purpose
Populate the world with named individuals that gain history.

### NPC Schema

```json
{
  "id": "string",
  "name": "string",
  "settlement_id": "string",
  "faction_id": "string",
  "role": "noble|merchant|priest|captain|smuggler|scholar|bandit_leader|militia_leader",
  "personality_tags": ["greedy","honorable","fearful","cruel","wise","desperate"],
  "relationship_to_player": "int (-100 to 100)",
  "alive": "bool",
  "death_day": "int|null",
  "died_by": "string|null",
  "notable_actions": ["string"]
}
```

---

## 11. Rival Company Generation

### Purpose
Other mercenary companies that compete with or oppose the player.

### Rival Company Schema

```json
{
  "id": "string",
  "name": "string",
  "leader_name": "string",
  "leader_background": "string",
  "current_location": "settlement_id",
  "size": "int",
  "reputation": "int",
  "faction_affiliation": "faction_id",
  "relationship_to_player": "int (-100 to 100)",
  "contracts_active": ["contract_id"],
  "is_hostile": "bool",
  "history_with_player": ["string"]
}
```

---

## 12. Rules for Avoiding Event Spam

1. **Cooldown timers**: Every event template has `cooldown_days`
2. **Randome weighting**: Events use weighted random selection, not always-fire
3. **Maximum events per tick**: Max 1 settlement event + 1 world event per tick
4. **Priority queue**: Only highest-priority events fire when multiple are eligible
5. **Freshness**: Events don't repeat in the same location within cooldown
6. **Urgency cap**: Don't trigger new events while 2+ unresolved events exist

```
def tick_events(world, day):
    current = world.pending_events
    if len(current) >= 2: return  # don't pile up
    
    candidates = []
    for template in event_templates:
        if template.is_on_cooldown(day): continue
        if template.is_eligible(world, day):
            candidates.append(template)
    
    if candidates:
        chosen = weighted_choice(candidates)
        chosen.fire(world, day)
        chosen.start_cooldown(day)
```

---

## 13. Making Consequences Visible

1. **Rumor board** in settlements shows current events
2. **Settlement description** updates based on situation (e.g., "Blackford Gate (Food Shortage)")
3. **Road danger indicators** reflect player actions
4. **After-action report** shows ripple effects after contract/battle
5. **Camp log** shows cumulative company consequences
6. **World map** changes visually (settlement size, route thickness)

### UI Suggestions

```
Settlement Info Panel:
- Name: "Blackford Gate"
- Situation badges: ["Food Shortage", "Guild Strike"]
- "A strained tolltown. Grain stocks are low. The guilds argue in the square."

Route Info Panel:
- Name: "Oldwood Road"
- Badges: ["Dangerous", "Bandit Controlled", "Low Traffic"]
- "The Red Sashes still own this road. Only the desperate travel here now."

After-Action Summary:
- "Contract complete: Escort Embermill - 420 crowns
- Blackford Gate: Trade access improved to 60. Guild Council influence +5.
- Blackford-Embermill Highroad: Bandit pressure reduced by 10.
- Two fighters wounded. Bran Okes gained the 'Bloodied' trait."
```

---

## 14. Automated Test Cases

```python
def test_rumor_generation():
    rumors = generate_rumors(company, world)
    assert len(rumors) <= 3
    for rumor in rumors:
        assert rumor.accuracy > 0
        assert rumor.text is not None

def test_event_cooldown_prevents_spam():
    world = make_world()
    template = get_event_template("food_shortage")
    template.fire(world, 7)
    assert not template.is_eligible(world, 8)  # on cooldown
    assert template.is_eligible(world, 60)  # cooldown expired

def test_consequence_cascade():
    settlement = make_settlement()
    settlement.food_stock = 0
    cascade_food_shortage(settlement, world)
    assert settlement.unrest > 0
    assert settlement.population < initial_pop

def test_war_closes_routes():
    nation_a = make_nation("vale")
    nation_b = make_nation("iron")
    cascade_war_declaration(nation_a, nation_b, world)
    affected_routes = [r for r in world.routes if r.is_closed and r.closure_reason == "war"]
    assert len(affected_routes) > 0

def test_memory_log_accumulates():
    world.memory_log = []
    record_memory(7, "contract_complete", "Test contract done")
    record_memory(14, "combat_victory", "Test battle won")
    assert len(world.memory_log) >= 2

def test_settlement_history_records_player_actions():
    settlement.history = []
    record_settlement_history(settlement, 14, "player_contract_complete", "Escort done")
    assert len(settlement.history) >= 1
```

---

## 15. Implementation Task List

1. Create `data/events/event_templates.json` with 30+ templates
2. Create `data/events/situation_definitions.json`
3. Create `data/events/rumor_templates.json`
4. Create `EventSystem.gd` with trigger evaluation
5. Create `WorldMemorySystem.gd` with memory logging
6. Create `SettlementHistorySystem.gd`
7. Create `CompanyChronicle.gd`
8. Create `NPCCreationSystem.gd`
9. Create `RivalCompanySystem.gd`
10. Create `RumorSystem.gd`
11. Add event cascade rules to `SettlementEconomySystem.gd`
12. Add war/peace state tracking
13. Rewrite road events system to use template system
14. Create automated tests for event triggers
15. Create automated tests for cascade chains
16. Create automated tests for rumor accuracy
