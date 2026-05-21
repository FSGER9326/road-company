# Combat Design — Battle Brothers Plus D&D

## Purpose
Tactical hex combat that keeps the brutal clarity of Battle Brothers but adds compact D&D-inspired RPG depth through attributes, skills, conditions, abilities, and rare low-fantasy magic.

---

## 1. Core Combat Stats

### Purpose
Define the complete stat model for every combatant (player fighter, enemy, companion).

### Stat Model

```json
{
  "id": "string (unique)",
  "name": "string",
  "side": "player|enemy|objective|neutral",
  "background": "string",
  "level": "int",
  "q": "int (hex q coordinate)",
  "r": "int (hex r coordinate)",
  "alive": "bool",
  "abbr": "string (2-char abbreviation for token)"
}
```

### Attributes (6 total, each 1-20 for fighters)

| Attribute | Primary Effect | Secondary Effects |
|-----------|---------------|------------------|
| **Might** | Melee damage | Carry capacity, intimidation checks |
| **Agility** | Ranged evasion, initiative | Fatigue cost reduction |
| **Endurance** | Max HP, max fatigue | Stamina checks |
| **Wits** | Ranged skill, initiative | Medicine, tracking, lore checks |
| **Will** | Resolve, morale resistance | Spell resistance, fear checks |
| **Presence** | Social checks | Companion approval, trade negotiations |

### Derived Stats (calculated from attributes, equipment, and level)

| Stat | Formula (baseline) | Notes |
|------|-------------------|-------|
| **Max HP** | 30 + (Endurance * 3) + (Might * 0.5) | |
| **Max Fatigue** | 50 + (Endurance * 4) + (Agility * 2) | |
| **Melee Skill** | 40 + (Might * 2) + (Wits * 0.5) + level | |
| **Ranged Skill** | 40 + (Wits * 2) + (Agility * 0.5) + level | |
| **Melee Defense** | 5 + (Endurance * 0.3) + (Agility * 0.2) + shield_bonus | |
| **Ranged Defense** | 5 + (Agility * 0.5) + (Wits * 0.2) | |
| **Resolve** | 30 + (Will * 1.5) + (Endurance * 0.5) | |
| **Initiative** | 50 + (Wits * 2) + (Agility * 1) | |
| **Armor Body** | from equipment | |
| **Armor Head** | from equipment | |
| **Action Points (AP)** | 9 baseline, modified by traits/conditions | |

### MVP Combat Stats (Current Prototype)

The prototype currently uses a simplified stat model directly on each fighter. For the full design, the attribute system above should be implemented as a derivation layer that computes combat stats from attributes + equipment + level. The MVP version keeps raw stats on the fighter record but adds an attribute layer for future expansion.

### Example Fighter JSON (Full Attribute Model)

```json
{
  "id": "bran_okes",
  "name": "Bran Okes",
  "side": "player",
  "background": "gate_levy",
  "level": 1,
  "attributes": {
    "might": 12,
    "agility": 9,
    "endurance": 11,
    "wits": 10,
    "will": 11,
    "presence": 8
  },
  "hp": 64,
  "max_hp": 64,
  "armor_body": 46,
  "armor_head": 18,
  "fatigue": 0,
  "max_fatigue": 88,
  "morale_state": "steady",
  "action_points": 9,
  "melee_skill": 58,
  "ranged_skill": 32,
  "melee_defense": 8,
  "ranged_defense": 5,
  "resolve": 48,
  "initiative": 82,
  "weapon_id": "militia_spear",
  "armor_id": "patched_mail",
  "traits": ["steadfast"],
  "injuries": [],
  "conditions": [],
  "q": 1,
  "r": 2,
  "alive": true
}
```

### Validation Requirements
- `id` unique per unit
- `hp` 0 to `max_hp`
- `fatigue` 0 to `max_fatigue`
- `armor_body`, `armor_head` >= 0
- `action_points` 0-15
- `morale_state` in ["steady", "wavering", "breaking"]
- `conditions` array of valid condition IDs

---

## 2. Damage Formula

### Purpose
Define how armor, HP, and damage interact.

### Damage Resolution Order
1. Roll damage within weapon's `damage_min` to `damage_max`
2. Roll armor save (20% chance head, 80% body if both > 0)
3. Apply armor damage to armor piece (min(armor_before, damage * armor_damage_multiplier))
4. Apply HP damage: max(0, damage - armor_before)
5. If HP <= 0: unit dies
6. If HP damage >= 14 on living unit: morale check

### Damage Formula

```
raw_damage = roll(damage_min, damage_max)
armor_key = (random() < 0.2 and armor_head > 0) ? "armor_head" : "armor_body"
armor_before = defender[armor_key]
armor_damage = min(armor_before, raw_damage * weapon.armor_damage)
defender[armor_key] = max(0, armor_before - armor_damage)
hp_damage = max(0, raw_damage - armor_before)  // if armor_before <= 0, full damage
defender.hp = max(0, defender.hp - hp_damage)
```

### Current Prototype Formula (simplified)
```
chance = clamp(55 + attack_skill - defense + hit_bonus, 15, 95)
damage = roll(damage_min, damage_max)
armor_damage = min(armor_before, damage * armor_damage_multiplier)
hp_damage = max(0, damage - armor_before)
```

### Test Cases

```python
def test_damage_less_than_armor():
    weapon = {"damage_min": 10, "damage_max": 20, "armor_damage": 0.75}
    defender = {"armor_body": 50, "armor_head": 20, "hp": 50, "armor_damage": 0}
    damage = 15  # less than armor
    result = apply_damage(defender, damage, weapon)
    assert defender["armor_body"] == 50 - int(15 * 0.75)  # armor reduced
    assert defender["hp"] == 50  # no HP damage

def test_damage_exceeds_armor():
    defender = {"armor_body": 10, "armor_head": 5, "hp": 50}
    damage = 30
    result = apply_damage(defender, damage, weapon)
    assert defender["hp"] == 50 - (30 - 10)  # 30 damage, 10 absorbed = 20 HP damage

def test_full_penetration():
    defender = {"armor_body": 0, "armor_head": 0, "hp": 50}
    damage = 25
    result = apply_damage(defender, damage, weapon)
    assert defender["hp"] == 50 - 25
```

---

## 3. Fatigue Formula

### Purpose
Track and apply exhaustion from combat actions.

### Fatigue Sources
| Action | Fatigue Cost |
|--------|-------------|
| Moving (normal hex) | 3 |
| Moving (slow hex) | 4 |
| Basic melee attack | weapon.fatigue_cost |
| Ranged attack | weapon.fatigue_cost |
| Using ability | ability.fatigue_cost |
| Being hit | 2 |
| Morale shock | 5 |

### Fatigue Effects
- `fatigue < 25% max`: no effect
- `fatigue >= 25% max`: AP reduced by 1
- `fatigue >= 50% max`: AP reduced by 2, hit chance -5
- `fatigue >= 75% max`: AP reduced by 3, hit chance -10, cannot use abilities
- `fatigue >= 100% max`: unit collapses, removed from combat

### Restoring Fatigue
- Camp rest: -15 fatigue to all fighters
- Full day rest: reset to 0
- Certain traits reduce fatigue gain

### Test Cases

```python
def test_fatigue_ap_penalty():
    fighter = {"max_fatigue": 100, "fatigue": 30, "action_points": 9}
    apply_fatigue_penalty(fighter)
    assert fighter["action_points"] == 8  # -1 AP at 30%

def test_fatigue_collapse():
    fighter = {"max_fatigue": 100, "fatigue": 100, "action_points": 9}
    apply_fatigue_penalty(fighter)
    assert fighter["action_points"] == 0
    assert fighter["collapsed"] == True
```

---

## 4. Armor Formula

### Purpose
Track armor degradation and calculate effective protection.

### Armor Degradation
- Armor damage from combat reduces armor value
- Armor can be repaired at camp using tools
- Armor cannot exceed original max value (cap from equipment JSON)

### Effective Armor Calculation
```
effective_armor = floor(armor_value * (1.0 - degradation_penalty))
degradation_penalty = 0.0  // camp repair removes this
```

### Current Prototype Behavior
- Armor repair at camp adds +12 body, +6 head (no cap in prototype)
- Should add proper max cap from equipment data

### Test Cases

```python
def test_armor_repair_caps_at_max():
    fighter = {"armor_body": 70, "armor_id": "patched_mail"}  # patched_mail max is 52
    # After proper repair: armor_body should cap at 52
    repair_armor(fighter, data)
    assert fighter["armor_body"] <= 52
```

---

## 5. Morale Formula

### Purpose
Track unit psychological state and breaking.

### Morale States
| State | Threshold | Effect |
|-------|-----------|--------|
| **steady** | default | normal combat |
| **wavering** | morale check failed once | -5 all checks, warns before breaking |
| **breaking** | morale check failed twice | unit flees or surrenders |

### Morale Check Function
```
morale_check(unit, penalty) {
    company_morale = company ? company.morale : 50
    target = clamp(resolve + (company_morale * 0.25) - penalty, 10, 95)
    roll = d100()
    if roll <= target: return true  // pass
    // fail: degrade morale state
    if unit.morale_state == "steady": unit.morale_state = "wavering"
    elif unit.morale_state == "wavering": unit.morale_state = "breaking"
    return false
}
```

### Morale Triggers
| Event | Penalty |
|-------|---------|
| Ally dies | 24 |
| Heavy HP damage (>=14) | 18 |
| Unit is wounded | 8 |
| Low company morale (<30) | +10 to penalty |
| Traits: steadfast | -10 penalty |
| Traits: grim | -5 penalty |

### Breaking Behavior
- Unit removed from combat
- Drops loot based on unit type
- May reappear as prisoner/rescued later

### Test Cases

```python
def test_morale_penalty_from_ally_death():
    units = [make_unit("p1"), make_unit("p2"), make_unit("e1")]
    units[2]["alive"] = False
    ally_death_morale(units, "player")
    # remaining player units should have morale check called

def test_wavering_to_breaking():
    unit = {"morale_state": "wavering", "resolve": 40}
    result = morale_check(unit, 18)
    assert result == False
    assert unit["morale_state"] == "breaking"
```

---

## 6. Initiative Formula

### Purpose
Determine turn order each round.

### Initiative Order
```
initiative_order = roster.sort_by(-unit.initiative)
```
- Units with same initiative: d100 tiebreaker (reroll or compare Will)
- Dead, collapsed, or breaking units skipped
- Objective units (wagon) always go last (initiative = 0)

### Current Prototype
```
ids.sort_custom(func(a, b): return int(_unit_by_id(units, a).get("initiative", 0)) > int(_unit_by_id(units, b).get("initiative", 0)))
```

### Round Structure
1. Roll initiative (sorted list of unit IDs)
2. Each unit takes actions until AP <= 0 or passes
3. When all units have gone, next round begins
4. Combat ends when: all enemies dead, all player units dead, or objective destroyed/captured

---

## 7. Conditions

### Purpose
Modify unit capabilities temporarily. Stack up to 3 numeric conditions, exclusive for major states.

### Condition Schema

```json
{
  "id": "string",
  "name": "string",
  "type": "major|minor",
  "duration": "int (-1 = permanent until cured)",
  "effects": {
    "ap_mod": "int",
    "hit_mod": "int",
    "defense_mod": "int",
    "fatigue_mod": "int",
    "morale_penalty": "int",
    "speed_mod": "int",
    "special": "string (ability_id)"
  }
}
```

### Core Conditions List

| Condition | AP | Hit | Def | Fatigue | Duration | Notes |
|-----------|----|-----|-----|---------|----------|-------|
| **bleeding** | 0 | 0 | 0 | +3/round | 3 rounds | HP -5/round |
| **stunned** | -3 | 0 | 0 | 0 | 1 round | cannot use abilities |
| **staggered** | -2 | -10 | 0 | 0 | 1 round | move only |
| **frightened** | 0 | -15 | -5 | 0 | 2 rounds | cannot attack closest |
| **pinned** | -2 | 0 | +10 | 0 | 1 round | ranged attacks only |
| **poisoned** | 0 | 0 | 0 | +2/round | 4 rounds | HP -3/round |
| **burning** | -2 | 0 | 0 | +5/round | 2 rounds | HP -8/round |
| **exhausted** | -3 | -5 | -3 | 0 | 2 rounds | from fatigue |
| **exposed** | 0 | +10 | -15 | 0 | 1 round | armor ignored |
| **inspired** | +2 | +5 | +2 | 0 | 2 rounds | from morale boost |
| **guarded** | 0 | 0 | +8 | 0 | 1 round | ally adjacent |
| **cursed** | -1 | -8 | -5 | +5 | 3 rounds | from occult |
| **marked** | 0 | +15 | 0 | 0 | 2 rounds | enemies hit +10 |
| **disarmed** | 0 | -20 | 0 | 0 | 2 rounds | no weapon attacks |
| **prone** | -2 | -10 | -8 | +2 | 1 round | from knockback |
| **rallied** | 0 | +5 | +5 | -10 | 1 round | breaks wavering |

### Adding/Removing Conditions
- `add_condition(unit, condition_id)` - appends to conditions array
- `remove_condition(unit, condition_id)` - removes from conditions array
- `has_condition(unit, condition_id)` - returns bool
- Conditions auto-decrement duration at round end

### Test Cases

```python
def test_conditions_stack():
    unit = {"conditions": []}
    add_condition(unit, "bleeding")
    add_condition(unit, "stunned")
    assert len(unit["conditions"]) == 2

def test_condition_duration_tick():
    unit = {"conditions": [{"id": "bleeding", "duration": 3}]}
    tick_conditions(unit)
    assert unit["conditions"][0]["duration"] == 2

def test_condition_expires():
    unit = {"conditions": [{"id": "bleeding", "duration": 1}]}
    tick_conditions(unit)
    assert len(unit["conditions"]) == 0
```

---

## 8. Abilities

### Purpose
Provide weapon-family and archetype-specific active skills beyond basic attacks.

### Ability Schema

```json
{
  "id": "string",
  "name": "string",
  "archetype": "shield|spear|polearm|archer|skirmisher|hunter|duelist|surgeon|priest|occultist|captain|rogue|grenadier",
  "ap_cost": "int",
  "fatigue_cost": "int",
  "range": "int (0 = self, 1 = melee, 2+ = ranged)",
  "target_type": "single|self|zone|adjacent",
  "uses_per_combat": "int (-1 = unlimited)",
  "effects": [
    {
      "type": "damage|heal|buff|debuff|condition|knockback",
      "value": "int",
      "condition_id": "string (if condition type)",
      "description": "string"
    }
  ],
  "requirements": {
    "weapon_tags": ["string"],
    "min_level": "int",
    "traits": ["string"]
  }
}
```

### Example Abilities by Archetype

#### Shield Fighter
```json
{
  "id": "shield_bash",
  "name": "Shield Bash",
  "archetype": "shield",
  "ap_cost": 3,
  "fatigue_cost": 4,
  "range": 1,
  "target_type": "single",
  "uses_per_combat": 3,
  "effects": [
    {"type": "damage", "value": "12-18", "description": "Pummels target"},
    {"type": "condition", "condition_id": "staggered", "description": "Target staggered"}
  ],
  "requirements": {"weapon_tags": ["shield"], "min_level": 1}
}
```

#### Spear Wall Defender
```json
{
  "id": "spear_wall",
  "name": "Spear Wall",
  "archetype": "spear",
  "ap_cost": 4,
  "fatigue_cost": 6,
  "range": 0,
  "target_type": "self",
  "uses_per_combat": 1,
  "effects": [
    {"type": "buff", "defense_mod": +15, "description": "Until hit or round ends"},
    {"type": "condition", "condition_id": "guarded", "description": "Adjacent allies +5 defense"}
  ],
  "requirements": {"weapon_tags": ["spear"], "min_level": 2}
}
```

#### Archer
```json
{
  "id": "precise_shot",
  "name": "Precise Shot",
  "archetype": "archer",
  "ap_cost": 4,
  "fatigue_cost": 5,
  "range": 4,
  "target_type": "single",
  "uses_per_combat": 2,
  "effects": [
    {"type": "damage", "value": "18-26", "description": "Ignores armor_head"},
    {"type": "condition", "condition_id": "exposed", "description": "Next ally attack +15"}
  ],
  "requirements": {"weapon_tags": ["bow"], "min_level": 3}
}
```

#### Captain/Sergeant
```json
{
  "id": "rally",
  "name": "Rally",
  "archetype": "captain",
  "ap_cost": 3,
  "fatigue_cost": 5,
  "range": 0,
  "target_type": "adjacent",
  "uses_per_combat": 2,
  "effects": [
    {"type": "condition", "condition_id": "rallied", "description": "Allies recover from wavering"},
    {"type": "buff", "morale_mod": +10, "description": "Company morale +5 for combat"}
  ],
  "requirements": {"min_level": 2, "traits": ["leader"]}
}
```

### Ability Resolution
```
can_use_ability(unit, ability):
    if unit.ap < ability.ap_cost: return false
    if unit.fatigue + ability.fatigue_cost > unit.max_fatigue: return false
    if ability.uses_per_combat > 0 and unit.ability_uses[ability.id] >= ability.uses_per_combat: return false
    if not meets_requirements(unit, ability.requirements): return false
    return true
```

---

## 9. Weapon Families (12 Total)

| Family | Tags | Role | Example Abilities |
|--------|------|------|-------------------|
| **Sword** | sword, one_handed | Versatile duelist | slash, parry, lunge |
| **Axe** | axe, one_handed | High armor damage | cleave, hack |
| **Mace** | mace, one_handed | Anti-armor, stunning | crush, stun_blow |
| **Spear** | spear, two_handed | Defensive wall | spear_wall, thrust |
| **Polearm** | polearm, two_handed | Reach backliner | sweep, hook |
| **Dagger** | dagger, thrown | Fast finisher | backstab, throw |
| **Bow** | bow, ranged | Ranged damage | precise_shot, suppression |
| **Crossbow** | crossbow, ranged | Armor piercing | piercing_shot, wind_up |
| **Staff** | staff, two_handed | Support/occult | smite, ward |
| **Shield** | shield, offhand | Defense | shield_bash, cover |
| **Hammer** | hammer, two_handed | Brutal crush | smash, stagger_blow |
| ** Whip** | whip, reach | Control | trip, disarm |

### Weapon Stat Requirements
```
weapon.damage_min = base + (might * multiplier)
weapon.damage_max = base + (might * multiplier)
weapon.hit_bonus = base_accuracy + (relevant_skill / 10)
```

---

## 10. Enemy Archetypes (12 Total)

| Archetype | HP | Armor | Skill | Traits | Abilities |
|-----------|----|-------|-------|--------|-----------|
| **Raider Cutthroat** | 42 | 18/6 | 46/20 | none | none |
| **Raider Thug** | 55 | 32/10 | 50/20 | none | none |
| **Raider Archer** | 40 | 16/6 | 35/55 | none | none |
| **Bounty Knave** | 60 | 40/14 | 54/30 | veteran | parry |
| **Militia Man** | 50 | 35/15 | 44/25 | steadfast | spear_wall |
| **Toll Guard** | 65 | 50/20 | 48/20 | armored | shield_bash |
| **Deserter** | 58 | 28/12 | 52/30 | veteran | cleave |
| **Cult Fanatic** | 45 | 20/8 | 40/35 | occult | blood_rite |
| **Plague Bearer** | 70 | 30/15 | 35/20 | plague | infect |
| **Beast Hound** | 35 | 15/5 | 50/15 | beast | charge |
| **Dire Wolf** | 55 | 20/8 | 55/10 | beast | pack_tactics |
| **Ogre Brute** | 120 | 60/25 | 45/10 | giant | smash |

### Enemy AI Behavior
1. If has objective token nearby: move toward objective
2. If has wounded ally: move to support
3. If in range to attack: attack lowest HP target
4. Otherwise: move toward nearest player unit

---

## 11. Magic / Ritual Systems (8 Total)

### Design Principles
- Magic is rare, costly, and has consequences
- Magic is divided into camp rituals and combat spells
- Each use risks injury, corruption, or faction enmity

### Ritual Systems

#### 1. Blood Ward
- **Type**: Combat spell
- **Cost**: 15 fatigue, 1 Will damage
- **Effect**: Place ward on hex. Enemies entering take 15 damage and become pinned
- **Corruption Risk**: 10% per use

#### 2. Corpse Whisper
- **Type**: Camp ritual
- **Cost**: 10 fatigue, 1 Will damage
- **Effect**: Learn enemy numbers, positions, and morale state from fallen
- **Corruption Risk**: 15% per use

#### 3. Oath of Iron
- **Type**: Combat spell
- **Cost**: 20 fatigue, 1 Will damage
- **Effect**: Self or ally gains +15 armor for 2 rounds, no AP cost
- **Corruption Risk**: 5% per use

#### 4. Fear Banishment
- **Type**: Combat spell
- **Cost**: 12 fatigue, 1 Will damage
- **Effect**: Remove frightened/staggered from ally, apply rallied
- **Corruption Risk**: 8% per use

#### 5. Wound Sealing
- **Type**: Camp ritual
- **Cost**: 1 medicine, 8 fatigue
- **Effect**: Heal ally 30 HP, remove bleeding condition
- **Corruption Risk**: 0%

#### 6. Curse Mark
- **Type**: Combat spell
- **Cost**: 18 fatigue, 2 Will damage
- **Effect**: Target takes +20% damage for 2 rounds, -10 defense
- **Corruption Risk**: 20% per use

#### 7. Lantern Rite
- **Type**: Camp ritual
- **Cost**: 5 crowns offering, 10 fatigue
- **Effect**: All company members remove 1 random negative condition
- **Corruption Risk**: 5% per use

#### 8. Binding Circle
- **Type**: Combat spell
- **Cost**: 25 fatigue, 3 Will damage
- **Effect**: Zone lockdown. Enemies in zone cannot move for 1 round
- **Corruption Risk**: 25% per use

### Magic Risk Table

| Corruption Level | Effect |
|-----------------|--------|
| 0-25% | No effect |
| 26-50% | Wits -1 permanently |
| 51-75% | Occult condition, hallucinations |
| 76-100% | Unit becomes hostile or dies |

### Faction Consequences
- Using occult magic in settlement: -10 with Lantern Church
- Using blood magic: -15 with all lawful factions
- Using healing magic: +5 with Lantern Church

---

## 12. Battlefield Objectives

### Purpose
Provide win conditions beyond "kill all enemies."

### Objective Types

| Objective | Description | Win Condition |
|-----------|-------------|---------------|
| **kill_all** | Default | All enemies dead |
| **escort** | Protect wagon/token | Wagon survives to extraction |
| **capture_point** | Hold hex for N rounds | Hold zone for 3 rounds |
| **survive** | Last N rounds | Survive 5 rounds |
| **eliminate_leader** | Kill specific enemy | Named enemy dies |
| **defend** | Protect NPC | NPC survives combat |
| **escape** | Reach exit hex | All living units reach exit |

### Extraction Zone
- Combat map has designated exit hexes
- Player units reaching exit can leave (but must have living unit in exit to win escort)
- Enemies cannot enter exit zone

### Test Cases

```python
def test_escort_objective_won():
    units = [..., {"id": "wagon", "alive": True, "side": "objective"}]
    result = check_victory(units, "escort")
    assert result["victory"] == True

def test_escort_objective_lost():
    units = [..., {"id": "wagon", "alive": False, "side": "objective"}]
    result = check_victory(units, "escort")
    assert result["victory"] == False
```

---

## 13. Terrain and Hex Effects

### Hex Grid
- Axial hex coordinates (q, r)
- 9x7 default map size
- Each hex has terrain type and effects

### Terrain Types

| Terrain | Blocked | Slow | Defense | Notes |
|---------|---------|------|---------|-------|
| **road** | No | No | +0 | Standard |
| **forest** | Some | Some | +5 | Blocks LOS for ranged |
| **mud** | No | Yes | +0 | +1 AP movement |
| **hills** | No | No | +10 | Ranged from hills +10 |
| **stones** | No | No | +8 | Difficult cover |
| **ruins** | Some | No | +15 | Scattered obstacles |
| **shallows** | No | Yes | +0 | River crossing |
| **wall** | Yes | N/A | N/A | Impassable |

### Zone of Control
- Adjacent occupied hexes cost +1 AP to leave
- Spear wall ability extends ZOC to 2 hexes

---

## 14. Implementation Task List

1. Add attribute system to fighter schema
2. Create attribute-to-stats derivation function
3. Add conditions array and condition system to fighters
4. Create conditions JSON data file
5. Create abilities JSON data file with 8 archetypes
6. Extend enemy JSON with full stat model
7. Create magic/rituals JSON data file
8. Add ability use validation and resolution
9. Add ability use tracking (uses_per_combat)
10. Add fatigue penalty application
11. Add condition duration ticking
12. Add battlefield objective check at round end
13. Extend combat result to include conditions and abilities used
14. Create automated tests for damage formula
15. Create automated tests for fatigue system
16. Create automated tests for morale system
17. Create automated tests for condition stacking
18. Create automated tests for ability use validation
19. Add corruption tracking to company state
20. Create magic use faction consequence system

---

## 15. Test Architecture

### Test Categories

```python
# tools/tests/test_combat.py
class CombatMathTests(unittest.TestCase):
    def test_damage_formula(self): ...
    def test_armor_degradation(self): ...
    def test_fatigue_accumulation(self): ...
    def test_fatigue_collapse_threshold(self): ...
    def test_morale_check_steady(self): ...
    def test_morale_check_breaking(self): ...
    def test_initiative_order(self): ...
    def test_condition_duration_tick(self): ...
    def test_condition_stacking(self): ...
    def test_ability_can_use(self): ...
    def test_ability_effects(self): ...
    def test_victory_check_kill_all(self): ...
    def test_victory_check_escort(self): ...

class CombatReplayTests(unittest.TestCase):
    def test_deterministic_combat_replay(self): ...
    def test_same_seed_same_result(self): ...
```

### Deterministic Replay
- Combat seeded with `seed` parameter
- All random rolls go through `SeededRng`
- Same seed = identical combat sequence

### Failure Categories
1. **Math errors**: damage, fatigue, morale calculations wrong
2. **State corruption**: conditions not cleaned, AP mis-tracked
3. **Timestep bugs**: durations not decremented, effects not applied
4. **Victory condition errors**: wrong win/loss determination
5. **Determinism violations**: non-seeded randomness introduced
