# World Simulation Design

## Purpose
Defines the layered world model: nations, regions, settlements, routes, and sites. Serves as the authoritative data structure for all world-state simulation.

---

## 1. Nations

### Purpose
Top-level political entities that own settlements and define macro-level faction relationships.

### Player-Facing Behavior
- Player sees nation names on settlement info panels
- Nations provide legitimacy or hostility based on player reputation
- War between nations closes routes and changes trade access

### Core Data Model

```json
{
  "id": "string (unique)",
  "name": "string",
  "government_type": "kingdom|duchy|republic|theocracy|clan|free_cities",
  "culture_tags": ["string"],
  "religion_tags": ["string"],
  "legal_strictness": "int (1-10)",
  "military_strength": "int (1-100)",
  "trade_priorities": ["grain","iron","tools"],
  "enemy_nations": ["nation_id"],
  "allied_nations": ["nation_id"],
  "crisis_tendencies": ["famine","plague","rebellion","invasion"],
  "color_hex": "#RRGGBB",
  "icon_placeholder": "nation_name_banner",
  "description": "string"
}
```

### Example JSON

```json
{
  "id": "vale_kings",
  "name": "Vale of Kings",
  "government_type": "duchy",
  "culture_tags": ["riverlander", "lowlander"],
  "religion_tags": ["old_faith", "saint_cults"],
  "legal_strictness": 5,
  "military_strength": 65,
  "trade_priorities": ["grain", "timber", "iron"],
  "enemy_nations": ["iron_reach"],
  "allied_nations": [],
  "crisis_tendencies": ["famine", "rebellion"],
  "color_hex": "#4a7c59",
  "icon_placeholder": "vale_kings_banner",
  "description": "A loose river duchy held together by toll roads and marriage contracts."
}
```

### Simulation Rules
- Nations tick weekly
- High military_strength reduces bandit pressure on owned routes
- Nations in war reduce trade priority → settlement prosperity drops
- Crisis tendency can trigger nation-level events (famine, plague)

### UI Implications
- Nation banner on settlement panel
- Diplomatic status indicator (war/peace/neutral)
- Macro political map layer (later expansion)

### Validation Requirements
- `id` must be unique, lowercase_with_underscores
- `government_type` must be one of allowed enum values
- `military_strength` 1-100
- `enemy_nations`/`allied_nations` must reference valid nation IDs

### MVP Version
- 2-3 nations with basic properties
- No war simulation, just relationship flags

### Later Expansion
- Dynamic war declaration
- Nation-level crisis propagation
- Vassal/liege relationships

### Automated Test Cases

```python
def test_nation_data_validity():
    for nation in nations:
        assert nation["id"] == nation["id"].lower()
        assert nation["government_type"] in VALID_GOVERNMENTS
        assert 1 <= nation["military_strength"] <= 100
        assert all(n in ALL_NATION_IDS for n in nation["enemy_nations"])

def test_nation_has_settlements():
    for nation in nations:
        owned = [s for s in settlements if s["nation_id"] == nation["id"]]
        assert len(owned) >= 0  # nations can have zero settlements (exiles)
```

---

## 2. Regions

### Purpose
Intermediate geographic zones that affect route danger, encounter tables, trade goods, and environmental conditions.

### Player-Facing Behavior
- Route selection shows region terrain tags
- Travel events reference region type
- Battlefield terrain influenced by region

### Core Data Model

```json
{
  "id": "string (unique)",
  "name": "string",
  "type": "borderland|forest|mountain|plains|swamp|coast|desert|haunted",
  "danger_modifier": "int (-3 to +3)",
  "encounter_table_override": "string (optional)",
  "trade_goods_bonus": ["good_id"],
  "weather_types": ["clear","rain","fog","snow","blizzard"],
  "travel_season_modifier": {"spring":"int","summer":"int","autumn":"int","winter":"int"},
  "description": "string"
}
```

### Example JSON

```json
{
  "id": "oldwood_border",
  "name": "Oldwood Border",
  "type": "forest",
  "danger_modifier": 2,
  "encounter_table_override": "oldwood_encounters",
  "trade_goods_bonus": ["timber", "furs", "herbs"],
  "weather_types": ["clear", "fog", "rain"],
  "travel_season_modifier": {"spring": 0, "summer": -1, "autumn": 0, "winter": 2},
  "description": "Ancient forest edge where outlaws and deserters hide."
}
```

### Simulation Rules
- Region danger_modifier adds to route base danger
- Seasonal modifiers apply to travel costs
- Region type influences available encounter tables

### UI Implications
- Region name on route tooltip
- Travel cost adjustment indicator
- Season indicator affecting route selection

### Validation Requirements
- `id` unique
- `type` in enum
- `danger_modifier` -3 to +3
- `travel_season_modifier` keys match four seasons

### MVP Version
- 4-6 regions with basic modifiers
- No seasonal variation yet

### Later Expansion
- Dynamic weather system
- Region-specific events
- Terrain transformation over time

### Automated Test Cases

```python
def test_region_types_valid():
    VALID_TYPES = {"borderland","forest","mountain","plains","swamp","coast","desert","haunted"}
    for region in regions:
        assert region["type"] in VALID_TYPES

def test_region_danger_modifier_range():
    for region in regions:
        assert -3 <= region["danger_modifier"] <= 3
```

---

## 3. Settlements

### Purpose
Owned by nations, contain internal factions, produce/consume trade goods, offer contracts, and serve as player hubs.

### Player-Facing Behavior
- Settlement panel shows name, type, prosperity, internal faction influence bars
- Market shows buy/sell prices for goods
- Contract board shows available contracts
- Player can interact with internal factions

### Core Data Model

```json
{
  "id": "string (unique)",
  "name": "string",
  "nation_id": "string (references nation)",
  "region_id": "string (references region)",
  "type": "hamlet|village|town|city|fort|monastery|caravanserai|mining_camp|freehold",
  "population": "int (10 to 50000)",
  "prosperity": "int (1-100)",
  "security": "int (1-100)",
  "food_stock": "int",
  "medicine_stock": "int",
  "tools_stock": "int",
  "arms_stock": "int",
  "unrest": "int (0-100)",
  "corruption": "int (0-100)",
  "piety": "int (0-100)",
  "trade_goods_produced": ["good_id"],
  "trade_goods_demanded": ["good_id"],
  "internal_factions": [
    {
      "faction_id": "string",
      "influence": "int (1-100)",
      "attitude": "friendly|neutral|hostile|afraid",
      "agenda": "string",
      "resources": "int (0-100)",
      "enemy_factions": ["faction_id"],
      "preferred_contracts": ["contract_type"],
      "policies_push": ["policy_id"],
      "events_can_trigger": ["event_id"],
      "reward_can_offer": ["reward_type"],
      "consequences_if_angered": ["consequence_id"
      ]
    }
  ],
  "local_laws": ["law_id"],
  "market_modifiers": {"good_id": "float (price_multiplier)"},
  "available_contracts": ["contract_id"],
  "current_situations": ["situation_id"],
  "settlement_history": [{"day": "int", "event": "string", "details": {}}],
  "map_pos": ["float (0.0-1.0)", "float (0.0-1.0)"],
  "description": "string"
}
```

### Example JSON

```json
{
  "id": "blackford",
  "name": "Blackford Gate",
  "nation_id": "vale_kings",
  "region_id": "river_lowlands",
  "type": "town",
  "population": 2400,
  "prosperity": 52,
  "security": 44,
  "food_stock": 180,
  "medicine_stock": 25,
  "tools_stock": 40,
  "arms_stock": 60,
  "unrest": 22,
  "corruption": 35,
  "piety": 28,
  "trade_goods_produced": ["grain", "timber"],
  "trade_goods_demanded": ["salt", "iron"],
  "internal_factions": [
    {
      "faction_id": "gate_nobility",
      "influence": 45,
      "attitude": "neutral",
      "agenda": "expand toll collection",
      "resources": 55,
      "enemy_factions": ["guild_council"],
      "preferred_contracts": ["patrol", "escort"],
      "policies_push": ["raise_tolls"],
      "events_can_trigger": [" toll_dispute"],
      "reward_can_offer": ["contract_boon"],
      "consequences_if_angered": ["trade_boycott"]
    },
    {
      "faction_id": "guild_council",
      "influence": 38,
      "attitude": "friendly",
      "agenda": "lower market fees",
      "resources": 42,
      "enemy_factions": ["gate_nobility"],
      "preferred_contracts": ["deliver_goods"],
      "policies_push": ["lower_fees"],
      "events_can_trigger": ["strike"],
      "reward_can_offer": ["market_access"],
      "consequences_if_angered": ["price_hike"]
    },
    {
      "faction_id": "plague_doctors",
      "influence": 12,
      "attitude": "neutral",
      "agenda": "get medicine supplies",
      "resources": 20,
      "enemy_factions": [],
      "preferred_contracts": ["deliver_medicine"],
      "policies_push": ["quarantine"],
      "events_can_trigger": ["plague_outbreak"],
      "reward_can_offer": ["medicine_discount"],
      "consequences_if_angered": []
    }
  ],
  "local_laws": ["no_open_flames", "toll_on_goods"],
  "market_modifiers": {"grain": 0.9, "salt": 1.3},
  "available_contracts": ["escort_embermill", "hunt_red_sashes"],
  "current_situations": ["highway_robbery"],
  "settlement_history": [
    {"day": 0, "event": "founded", "details": {}}
  ],
  "map_pos": [0.18, 0.56],
  "description": "A toll town built around a river gate and an old gallows square."
}
```

### Simulation Rules

#### Settlement Tick (Daily)
```
1. Food production: +population/100 units if food_stock < population*2
2. Medicine consumption: -population/500 per day
3. Tool consumption: -population/1000 per day
4. Unrest calculation:
   - If food_stock < population/10: unrest += 5
   - If security < 30: unrest += 3
   - If corruption > 70: unrest += 2
   - If unrest > 80: chance of riot event
5. Prosperity recalculation:
   - prosperity = clamp((security + trade_access + food_balance + market_tier) / 4, 1, 100)
6. Population growth: if prosperity > 60 and food_stock充足: population += population * 0.001
7. Population decline: if prosperity < 20 or food_stock == 0: population -= population * 0.01
```

#### Market Price Derivation
```
base_price = GOOD_BASE_PRICES[good_id]
supply_factor = settlement.prosperity / 50.0
demand_factor = settlement.population / 1000.0
local_modifier = settlement.market_modifiers.get(good_id, 1.0)
final_price = base_price * (1.0 / supply_factor) * demand_factor * local_modifier
final_price = clamp(final_price, base_price * 0.5, base_price * 3.0)
```

### UI Implications
- Settlement info panel with all stats
- Internal faction influence bars (horizontal bars)
- Market panel with price list
- Contract board filtered by settlement
- Situation/status effect badges

### Validation Requirements
- `id` unique
- `nation_id` references valid nation
- `region_id` references valid region
- `type` in enum
- `population` 10-50000
- `prosperity`, `security`, `unrest`, `corruption`, `piety` all 0-100
- `internal_factions` each have valid `faction_id`
- `map_pos` is [x, y] each 0.0-1.0
- At least one `available_contract` or empty array

### MVP Version
- Settlements with basic stats (no full economy)
- 2-3 internal factions per settlement
- Simple market modifiers
- No settlement tick yet

### Later Expansion
- Full economy simulation
- Internal faction wars
- Settlement situation system
- Government transformation
- Settlement history log

### Automated Test Cases

```python
def test_settlement_has_valid_nation():
    for s in settlements:
        assert s["nation_id"] in [n["id"] for n in nations]

def test_settlement_internal_factions_have_valid_ids():
    for s in settlements:
        valid_faction_ids = [f["id"] for f in factions]
        for if_data in s["internal_factions"]:
            assert if_data["faction_id"] in valid_faction_ids

def test_settlement_stats_in_range():
    for s in settlements:
        assert 0 <= s["prosperity"] <= 100
        assert 0 <= s["security"] <= 100
        assert 0 <= s["unrest"] <= 100

def test_settlement_market_price_derivation():
    for s in settlements:
        for good_id in GOOD_IDS:
            price = derive_market_price(s, good_id)
            base = GOOD_BASE_PRICES[good_id]
            assert base * 0.5 <= price <= base * 3.0
```

---

## 4. Routes

### Purpose
Active simulation objects connecting settlements. Carry traffic, danger, terrain, and dynamic state.

### Player-Facing Behavior
- Road map shows routes with danger stars
- Player selects route for travel
- Route info shows estimated time, costs, danger
- Combat encounter depends on route terrain tags

### Core Data Model

```json
{
  "id": "string (unique)",
  "name": "string",
  "from": "settlement_id",
  "to": "settlement_id",
  "days": "int (1-14)",
  "food_cost": "int",
  "vigor_cost": "int",
  "danger": "int (1-10)",
  "road_quality": "int (1-10, 10=best)",
  "terrain_tags": ["road|mud|forest|hill|river|mountain|swamp|desert"],
  "encounter_table": "string (table_id)",
  "battlefield_tags": ["open|forest|mud|hills|stones|shallows|ruins"],
  "controlling_faction": "faction_id",
  "patrol_presence": "int (0-100)",
  "bandit_pressure": "int (0-100)",
  "monster_pressure": "int (0-100)",
  "tolls": "int (crowns per caravan)",
  "weather_exposure": ["clear|rain|snow|blizzard|fog"],
  "caravan_frequency": "int (cars per week, 0-20)",
  "hidden_sites": ["site_id"],
  "route_history": [{"day": "int", "event": "string"}],
  "is_closed": "bool",
  "closure_reason": "string|null",
  "description": "string"
}
```

### Example JSON

```json
{
  "id": "blackford_embermill_highroad",
  "name": "Blackford to Embermill (High Road)",
  "from": "blackford",
  "to": "embermill",
  "days": 2,
  "food_cost": 6,
  "vigor_cost": 14,
  "danger": 3,
  "road_quality": 7,
  "terrain_tags": ["road", "farmland"],
  "encounter_table": "road_raiders",
  "battlefield_tags": ["open", "ditch"],
  "controlling_faction": "ashen_crown",
  "patrol_presence": 40,
  "bandit_pressure": 25,
  "monster_pressure": 5,
  "tolls": 15,
  "weather_exposure": ["clear", "rain"],
  "caravan_frequency": 8,
  "hidden_sites": [],
  "route_history": [],
  "is_closed": false,
  "closure_reason": null,
  "description": "A taxed road with burned mile posts and enough traffic to hide trouble."
}
```

### Simulation Rules

#### Route Tick (Daily)
```
1. Traffic calculation:
   - traffic = caravan_frequency * (settlement1.prosperity/50 + settlement2.prosperity/50) / 2
   - traffic = clamp(traffic, 0, 20)
2. Danger recalculation:
   - base_danger = route.danger
   - bandit_factor = bandit_pressure / 100.0
   - patrol_factor = patrol_presence / 100.0
   - effective_danger = base_danger + (bandit_factor * 3) - (patrol_factor * 2)
   - effective_danger = clamp(effective_danger, 1, 10)
3. Route closure check:
   - If from_settlement.is_under_siege OR to_settlement.is_under_siege: close_route()
   - If nation war crosses route region: close_route()
   - If plague_quarantine in region: close_route()
4. Site discovery chance:
   - If traffic > 10 and hidden_sites not empty and random < 0.01: reveal_next_site()
```

#### Player Route Effects
```
- Player escort contract: bandit_pressure -= 10 per trip (stacks up to -30)
- Player kills bandits on route: bandit_pressure -= 5 per encounter
- Player raids route: caravan_frequency -= 2, bandit_pressure += 10
- Player clears monster lair nearby: monster_pressure -= 20
- Player patrol contract fulfilled: patrol_presence += 15 (max 80)
```

### UI Implications
- Route list on road map
- Danger indicator (skulls or stars)
- Travel cost preview
- Route status badges (safe, dangerous, closed, plague)
- Terrain icons

### Validation Requirements
- `id` unique
- `from` and `to` reference valid settlements (can be same for loops, but usually different)
- `days` 1-14
- `danger` 1-10
- `road_quality` 1-10
- `terrain_tags` subset of allowed terrain tags
- `battlefield_tags` subset of allowed battlefield tags
- `patrol_presence`, `bandit_pressure`, `monster_pressure` all 0-100
- `caravan_frequency` 0-20
- `is_closed` boolean, `closure_reason` nullable string

### MVP Version
- Routes with basic stats, no dynamic tick
- Simple danger calculation
- No route closure yet

### Later Expansion
- Full route tick simulation
- Dynamic bandit/patrol pressure
- Route discovery system
- Seasonal route variations
- Weather effects on routes

### Automated Test Cases

```python
def test_route_connects_valid_settlements():
    valid_ids = [s["id"] for s in settlements]
    for r in routes:
        assert r["from"] in valid_ids
        assert r["to"] in valid_ids

def test_route_danger_in_range():
    for r in routes:
        assert 1 <= r["danger"] <= 10

def test_route_effective_danger_calculation():
    for r in routes:
        eff = r["danger"] + (r["bandit_pressure"] / 100.0 * 3) - (r["patrol_presence"] / 100.0 * 2)
        assert 1 <= eff <= 10

def test_route_cannot_be_closed_without_reason():
    for r in routes:
        if r["is_closed"]:
            assert r["closure_reason"] is not None
```

---

## 5. Sites

### Purpose
Non-settlement locations that can be discovered, explored, cleared, or transformed.

### Core Data Model

```json
{
  "id": "string (unique)",
  "name": "string",
  "type": "ruins|bandit_camp|monster_lair|battlefield|shrine|witch_hut|old_fort|cave|plague_pit|secret_base",
  "location": ["float", "float"],
  "region_id": "string",
  "settlement_affiliation": "settlement_id|null",
  "danger": "int (1-10)",
  "size": "small|medium|large",
  "resources": {"good_id": "int"},
  "cleared": "bool",
  "cleared_date": "int|null",
  "transforms_into": "site_type|null",
  "discovery_requirements": {"skill_check": "string", "dc": "int", "item_required": "string|null"},
  "events": ["event_id"],
  "description": "string"
}
```

### Simulation Rules
- Sites can be discovered through scouting or random travel
- Cleared sites may transform into other types over time
- Sites can be used as encounter sources

### Automated Test Cases

```python
def test_site_types_valid():
    VALID_TYPES = {"ruins","bandit_camp","monster_lair","battlefield","shrine","witch_hut","old_fort","cave","plague_pit","secret_base"}
    for site in sites:
        assert site["type"] in VALID_TYPES

def test_site_cleared_has_date():
    for site in sites:
        if site["cleared"]:
            assert site["cleared_date"] is not None
```

---

## Implementation Task List

1. Create `data/world/nations.json` with 2-3 nations
2. Create `data/world/regions.json` with 4-6 regions
3. Extend `data/world/locations.json` schema to full settlement model
4. Extend `data/world/routes.json` schema to full route model
5. Create `data/world/sites.json` with 5-10 sites
6. Create `WorldState` GDScript class to hold all world data
7. Create `SettlementSystem.gd` with tick logic
8. Create `RouteSystem.gd` with dynamic danger logic
9. Create `SiteDiscoverySystem.gd`
10. Create Python validators for all new schemas
11. Create automated tests for settlement economy
12. Create automated tests for route dynamics
13. Create automated tests for site discovery

---

## Appendix: Complete World JSON Schema Reference

See `docs/data_schema_plan.md` for the master schema reference.
