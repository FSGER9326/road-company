# Data Schema Plan

## Purpose
Master schema reference for all JSON data files in the ROAD COMPANY project. Every system's data contract is defined here so coding agents can implement consistently.

---

## 1. Directory Layout

```
data/
  world/
    nations.json
    regions.json
    settlements.json
    routes.json
    sites.json
  factions/
    factions.json
    internal_faction_types.json
  economy/
    trade_goods.json
    market_tiers.json
  company/
    backgrounds.json
    traits.json
    camp_actions.json
  combat/
    weapons.json
    armor.json
    enemies.json
    encounters.json
    abilities.json
    conditions.json
  contracts/
    contracts.json
    contract_templates.json
  events/
    event_templates.json
    situation_definitions.json
    rumor_templates.json
```

---

## 2. Core Data Files

### nations.json

```json
[
  {
    "id": "string (unique, lowercase_underscores)",
    "name": "string",
    "government_type": "kingdom|duchy|republic|theocracy|clan|free_cities",
    "culture_tags": ["string"],
    "religion_tags": ["string"],
    "legal_strictness": "int (1-10)",
    "military_strength": "int (1-100)",
    "trade_priorities": ["good_id"],
    "enemy_nations": ["nation_id"],
    "allied_nations": ["nation_id"],
    "crisis_tendencies": ["famine|plague|rebellion|invasion"],
    "color_hex": "#RRGGBB",
    "icon_placeholder": "string",
    "description": "string"
  }
]
```

**Validation**: `id` unique, `military_strength` 1-100, enums valid.

### regions.json

```json
[
  {
    "id": "string (unique)",
    "name": "string",
    "type": "borderland|forest|mountain|plains|swamp|coast|desert|haunted",
    "danger_modifier": "int (-3 to +3)",
    "encounter_table_override": "string|null",
    "trade_goods_bonus": ["good_id"],
    "weather_types": ["clear|rain|fog|snow|blizzard"],
    "travel_season_modifier": {
      "spring": "int",
      "summer": "int",
      "autumn": "int",
      "winter": "int"
    },
    "description": "string"
  }
]
```

**Validation**: `id` unique, `danger_modifier` -3..+3, 4 season keys.

### settlements.json

```json
[
  {
    "id": "string (unique)",
    "name": "string",
    "nation_id": "string",
    "region_id": "string",
    "type": "hamlet|village|town|city|fort|monastery|caravanserai|mining_camp|freehold",
    "population": "int (10-50000)",
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
    "trade_access": "int (1-100)",
    "market_tier": "int (1-6)",
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
        "consequences_if_angered": ["consequence_id"],
        "special_abilities": ["ability_id"]
      }
    ],
    "local_laws": ["law_id"],
    "market_modifiers": {"good_id": "float"},
    "available_contracts": ["contract_id"],
    "current_situations": ["situation_id"],
    "settlement_history": [
      {
        "day": "int",
        "event": "string",
        "details": {}
      }
    ],
    "map_pos": ["float", "float"],
    "description": "string",
    "is_under_siege": "bool"
  }
]
```

**Validation**: `nation_id` and `region_id` resolve, `prosperity`/`security`/`unrest`/`corruption`/`piety` 0-100, `population` 10-50000, `map_pos` [0-1, 0-1].

### routes.json

```json
[
  {
    "id": "string (unique)",
    "name": "string",
    "from": "settlement_id",
    "to": "settlement_id",
    "days": "int (1-14)",
    "food_cost": "int",
    "vigor_cost": "int",
    "danger": "int (1-10)",
    "road_quality": "int (1-10)",
    "terrain_tags": ["road|mud|forest|hill|river|mountain|swamp|desert|farmland"],
    "encounter_table": "string",
    "battlefield_tags": ["open|forest|mud|hills|stones|shallows|ruins"],
    "controlling_faction": "faction_id",
    "patrol_presence": "int (0-100)",
    "bandit_pressure": "int (0-100)",
    "monster_pressure": "int (0-100)",
    "tolls": "int",
    "weather_exposure": ["clear|rain|snow|blizzard|fog"],
    "caravan_frequency": "int (0-20)",
    "hidden_sites": ["site_id"],
    "route_history": [{"day": "int", "event": "string"}],
    "is_closed": "bool",
    "closure_reason": "string|null",
    "traffic": "int (0-20, calculated)",
    "description": "string"
  }
]
```

**Validation**: `from`/`to` reference valid settlements, `danger` 1-10, all pressure stats 0-100.

### sites.json

```json
[
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
    "discovery_requirements": {
      "skill_check": "string",
      "dc": "int",
      "item_required": "string|null"
    },
    "events": ["event_id"],
    "enemies": ["enemy_id"],
    "description": "string"
  }
]
```

### factions.json

External/world factions that operate across settlements.

```json
[
  {
    "id": "string (unique)",
    "name": "string",
    "type": "nation|church|guild|criminal|mercenary|peasant|cult",
    "home_settlement": "settlement_id|null",
    "description": "string"
  }
]
```

### internal_faction_types.json

Template definitions for settlement internal factions.

```json
[
  {
    "id": "gate_nobility",
    "name": "Gate Nobility",
    "appears_in": ["town", "city"],
    "agenda": "control tolls and military contracts",
    "preferred_contracts": ["patrol", "escort", "defend"],
    "enemy_of": ["guild_council", "merchant_cartel"],
    "policies_push": ["raise_tolls", "militarize"],
    "events_can_trigger": ["toll_dispute", "succession_crisis"],
    "reward_can_offer": ["contract_boon", "market_access"],
    "consequences_if_angered": ["trade_boycott"],
    "special_abilities": ["call_militia", "bribe_guard"]
  }
]
```

---

## 3. Economy Files

### trade_goods.json

```json
[
  {
    "id": "string",
    "name": "string",
    "category": "food|construction|material|luxury|dangerous|service",
    "base_price": "int",
    "weight": "int",
    "produced_in": ["settlement_type"],
    "consumed_in": ["settlement_type"],
    "perishable": "bool",
    "contraband": "bool"
  }
]
```

### market_tiers.json

```json
[
  {
    "tier": "int (1-6)",
    "population_min": "int",
    "population_max": "int",
    "price_modifier": "float",
    "description": "string"
  }
]
```

---

## 4. Combat Files

### weapons.json

```json
[
  {
    "id": "string",
    "name": "string",
    "family": "sword|axe|mace|spear|polearm|dagger|bow|crossbow|staff|shield|hammer|whip",
    "range": "int (1-4)",
    "ap_cost": "int",
    "fatigue_cost": "int",
    "damage_min": "int",
    "damage_max": "int",
    "armor_damage": "float (0.0-2.0)",
    "hit_bonus": "int",
    "offhand": "bool (can be paired with shield)",
    "abilities": ["ability_id"],
    "tags": ["string"],
    "description": "string"
  }
]
```

### armor.json

```json
[
  {
    "id": "string",
    "name": "string",
    "body_armor": "int",
    "head_armor": "int",
    "fatigue_penalty": "int",
    "description": "string"
  }
]
```

### enemies.json

```json
[
  {
    "id": "string",
    "name": "string",
    "archetype": "cutthroat|thug|archer|knave|militia|guard|deserter|cultist|plague|hound|wolf|ogre",
    "background": "string",
    "level": "int",
    "hp": "int",
    "max_hp": "int",
    "armor_body": "int",
    "armor_head": "int",
    "fatigue": "int",
    "max_fatigue": "int",
    "morale_state": "steady",
    "action_points": "int",
    "melee_skill": "int",
    "ranged_skill": "int",
    "melee_defense": "int",
    "ranged_defense": "int",
    "resolve": "int",
    "initiative": "int",
    "weapon_id": "string",
    "armor_id": "string",
    "traits": ["string"],
    "injuries": [],
    "abilities": ["ability_id"],
    "loot_table": "string|null"
  }
]
```

### encounters.json

```json
[
  {
    "id": "string",
    "name": "string",
    "enemies": ["enemy_id"],
    "min_enemies": "int",
    "max_enemies": "int",
    "terrain_tags": ["string"],
    "objectives": ["objective_id"]
  }
]
```

### abilities.json

```json
[
  {
    "id": "string",
    "name": "string",
    "archetype": "shield|spear|polearm|archer|skirmisher|hunter|duelist|surgeon|priest|occultist|captain|rogue|grenadier",
    "ap_cost": "int",
    "fatigue_cost": "int",
    "range": "int",
    "target_type": "single|self|zone|adjacent",
    "uses_per_combat": "int (-1 = unlimited)",
    "effects": [
      {
        "type": "damage|heal|buff|debuff|condition|knockback",
        "value": "int or string",
        "condition_id": "string",
        "description": "string"
      }
    ],
    "requirements": {
      "weapon_tags": ["string"],
      "min_level": "int",
      "traits": ["string"]
    }
  }
]
```

### conditions.json

```json
[
  {
    "id": "string",
    "name": "string",
    "type": "major|minor",
    "duration": "int (-1 = permanent)",
    "effects": {
      "ap_mod": "int",
      "hit_mod": "int",
      "defense_mod": "int",
      "fatigue_per_round": "int",
      "hp_per_round": "int",
      "morale_penalty": "int",
      "speed_mod": "int",
      "special": "string"
    }
  }
]
```

---

## 5. Company Files

### backgrounds.json

```json
[
  {
    "id": "string",
    "name": "string",
    "attribute_bonuses": {"might": "int", "agility": "int", "endurance": "int", "wits": "int", "will": "int", "presence": "int"},
    "starting_weapons": ["weapon_id"],
    "starting_armor": "armor_id",
    "traits": ["trait_id"],
    "camp_aptitude": ["role"],
    "starting_skills": {"skill": "int"},
    "description": "string"
  }
]
```

### traits.json

```json
[
  {
    "id": "string",
    "name": "string",
    "type": "passive|combat|camp|social|negative",
    "effects": {
      "hit_mod": "int",
      "defense_mod": "int",
      "morale_mod": "int",
      "fatigue_mod": "int",
      "damage_mod": "int",
      "special": "string"
    },
    "description": "string"
  }
]
```

### camp_actions.json

```json
[
  {
    "id": "string",
    "name": "string",
    "cost": {"food": "int", "tools": "int", "medicine": "int", "crowns": "int", "fatigue": "int"},
    "effects": {
      "hp_heal": "int",
      "armor_repair": "int",
      "condition_removed": "string|null",
      "morale_change": "int",
      "vigor_change": "int",
      "special": "string"
    },
    "requires_tools": "bool",
    "requires_medicine": "bool",
    "requires_food": "bool",
    "description": "string"
  }
]
```

---

## 6. Contracts

### contracts.json (existing, extended)

```json
[
  {
    "id": "string",
    "title": "string",
    "type": "escort_caravan|patrol_route|hunt_bandits|monster_lair|bounty_capture|debt_collection|recover_wagon|suppress_riot|protect_witness|sabotage|smuggle|deliver_medicine|defend_settlement|investigate|purge_cult|rescue_prisoners|train_militia|raid_caravan",
    "patron_faction": "faction_id",
    "hidden_patron": "faction_id|null",
    "origin_location": "settlement_id",
    "target_location": "settlement_id",
    "target_route": "route_id|null",
    "reward_crowns": "int",
    "reward_renown": "int",
    "danger": "int (1-10)",
    "moral_tags": ["honorable|deceptive|violent|merciful|criminal|holy"],
    "description": "string",
    "success_text": "string",
    "failure_text": "string",
    "encounter_id": "string",
    "faction_effects": {"faction_id": "int"},
    "failure_faction_effects": {"faction_id": "int"},
    "settlement_effects": {"prosperity|security|unrest|food_stock|medicine_stock": "int"},
    "route_effects": {"bandit_pressure|patrol_presence|caravan_frequency|danger": "int"},
    "companion_approval": {"companion_id": "int"},
    "required_cargo_or_objective": "string|null",
    "hidden_objective": "string|null",
    "partial_success_possible": "bool"
  }
]
```

### contract_templates.json

```json
[
  {
    "id": "string",
    "type": "string",
    "base_reward_crowns": "int",
    "base_reward_renown": "int",
    "base_danger": "int",
    "moral_tags": ["string"],
    "patron_weight": {"faction_id": "float"},
    "spawn_weight": "float",
    "spawn_conditions": {
      "min_settlement_population": "int|null",
      "min_bandit_pressure": "int|null",
      "situation_required": "situation_id|null",
      "min_day": "int|null"
    }
  }
]
```

---

## 7. Events

### event_templates.json

```json
[
  {
    "id": "string",
    "name": "string",
    "category": "road|settlement|contract|faction|combat|camp|world",
    "trigger_conditions": {
      "min_day": "int|null",
      "cooldown_days": "int",
      "settlement_filters": {},
      "faction_filters": {},
      "player_filters": {},
      "random_weight": "float"
    },
    "event_text": {
      "headline": "string",
      "flavor_text": "string",
      "outcome_text_good": "string",
      "outcome_text_bad": "string"
    },
    "choices": [
      {
        "id": "string",
        "label": "string",
        "requirement": {"skill": "string|null", "dc": "int|null"},
        "outcome": {"company_effects": {}, "faction_effects": {}, "consequence_flag": "string"}
      }
    ],
    "automatic_outcome": {"effects": {}}
  }
]
```

### situation_definitions.json

```json
[
  {
    "id": "string",
    "name": "string",
    "badge_text": "string",
    "settlement_effects": {"stat": "int"},
    "icon_placeholder": "string",
    "duration_days": "int (-1 = permanent until resolved)"
  }
]
```

### rumor_templates.json

```json
[
  {
    "id": "string",
    "topic_type": "event|settlement|route|faction|npc",
    "format": "string (with {settlement_name}, {route_name} etc)",
    "weight": "float"
  }
]
```

---

## 8. Runtime Data Structures

### CompanyState (GDScript)

Current prototype fields, extended for design:

```
company_name: String
current_location: String
crowns: int
food: int
tools: int
medicine: int
ammunition: int
morale: int
vigor: int
renown: int
corruption: int           # new
roster: Array[Fighter]
graveyard: Array[Fighter]
inventory: Dictionary     # new - trade goods
faction_reputation: Dictionary
active_contract: Dictionary
last_summary: Dictionary
company_chronicle: Array  # new
camp_actions_available: Array  # new
```

### Fighter (GDScript)

```
id: String
name: String
background: String
level: int
hp: int
max_hp: int
armor_body: int
armor_head: int
fatigue: int
max_fatigue: int
morale_state: String ("steady"|"wavering"|"breaking")
action_points: int
melee_skill: int
ranged_skill: int
melee_defense: int
ranged_defense: int
resolve: int
initiative: int
weapon_id: String
armor_id: String
traits: Array
conditions: Array        # new
injuries: Array
abilities: Array         # new
attributes: Dictionary   # new - for attribute model
camp_role: String        # new
alive: bool
```

---

## 9. Naming Conventions

| Entity | Convention | Example |
|--------|-----------|---------|
| **IDs** | lowercase_underscores | `blackford_gate_nobility` |
| **Route IDs** | from_to_descriptor | `blackford_embermill_highroad` |
| **Contract IDs** | action_target | `escort_embermill`, `hunt_red_sashes` |
| **Event IDs** | type_descriptor | `toll_dispute_event`, `food_shortage_event` |
| **Faction IDs** | singular naming | `ashen_crown`, `lantern_church` |
| **Good IDs** | singular | `grain`, `medicine` |
| **Traits** | lowercase | `steadfast`, `sharp_eyes`, `field_medic` |
| **JSON keys** | snake_case | `food_cost`, `trade_access` |
| **Enum values** | lowercase_underscores | `highwayman`, `gate_levy` |

---

## 10. Data Validation Rules

Every JSON file must have a corresponding Python validator in `tools/`.

### Validator Checklist

| File | Validator | Key Checks |
|------|-----------|------------|
| nations.json | validate_nations.py | unique ids, enum values |
| regions.json | validate_regions.py | unique ids, danger range |
| settlements.json | validate_settlements.py | ref constraints, range checks |
| routes.json | validate_routes.py | ref constraints, range checks |
| sites.json | validate_sites.py | enum types, ref constraints |
| factions.json | validate_factions.py | existing validators |
| trade_goods.json | validate_economy.py | unique ids, ranges |
| weapons.json | validate_combat.py | existing validators |
| armor.json | validate_combat.py | existing validators |
| enemies.json | validate_combat.py | existing validators |
| encounters.json | validate_combat.py | existing validators |
| conditions.json | validate_combat.py | enum types |
| abilities.json | validate_combat.py | valid references |
| backgrounds.json | validate_company.py | unique ids, ref checks |
| traits.json | validate_company.py | unique ids |
| contracts.json | validate_contracts.py | existing validators |
| contract_templates.json | validate_contracts.py | new |
| event_templates.json | validate_events.py | new |

### Universal Validator

`python tools/validate_data.py` should discover and run all validators.

```python
def validate_all():
    validators = discover_validators()
    for validator in validators:
        try:
            importlib.import_module(validator)
            validator.validate()
            print(f"PASS: {validator}")
        except Exception as e:
            print(f"FAIL: {validator}: {e}")
```

---

## 11. Save/Load Schema (Future)

```json
{
  "version": "1.0",
  "day": "int",
  "seed": "int",
  "company": {},       // serialized CompanyState
  "world_states": [],   // serialized settlement/route states
  "world_memory": [],   // memory log
  "rng_state": ""       // seed + sequence counter
}
```

---

## 12. Version Tracking

| Schema Version | Date | Changes |
|---------------|------|---------|
| 1.0 | MVP | Current prototype |
| 1.5 | Economy Add | Trade goods, market tiers, settlement economy |
| 2.0 | World Sim | Nations, regions, full settlements, full routes |
| 2.5 | Faction Deep | Internal factions, policies, settlement events |
| 3.0 | Combat Deep | Attributes, conditions, abilities, magic |
| 4.0 | Story | Event templates, memory, chronicles, rumors |
