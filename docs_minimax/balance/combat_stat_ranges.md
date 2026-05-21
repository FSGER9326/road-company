# Combat Stat Ranges - ROAD COMPANY

## Core Attributes

| Attribute | Abbr | Primary Scaling |
|-----------|------|-----------------|
| Might | MIG | Melee damage, carry capacity, intimidate |
| Agility | AGI | AP, initiative, ranged defense, scout checks |
| Endurance | END | HP, fatigue capacity, condition resist |
| Wits | WIT | Ranged accuracy, scouting, medicine, repair |
| Will | WIL | Resolve, morale resistance, occult checks |
| Presence | PRE | Social checks, leadership, companion loyalty |

## Derived Stat Formulas

```
max_hp = 20 + (endurance * 3) + (might * 0.5)
max_fatigue = 10 + (endurance * 2) + (agility * 1)
initiative = agility + (wits * 0.5)
resolve = will + (presence * 0.5)
melee_skill = (might * 0.6) + (agility * 0.3) + (wits * 0.1)
ranged_skill = (wits * 0.6) + (agility * 0.3) + (might * 0.1)
melee_defense = (agility * 0.5) + (endurance * 0.3) + (wits * 0.2)
ranged_defense = (agility * 0.6) + (wits * 0.2) + (endurance * 0.2)
carry_capacity = 10 + (might * 2) + (endurance * 1)
```

## Actor Archetype Tables

### Humanoid Combatants

| Archetype | HP | FAT | INIT | RES | M.SKL | R.SKL | M.DEF | R.DEF | AP | Move AP | Atk AP |
|-----------|-----|-----|------|-----|-------|-------|-------|-------|----|--------|-------|
| Weak Civilian | 8-12 | 5-8 | 4-6 | 3-5 | 15-20 | 10-15 | 8-12 | 5-10 | 3 | 1 | 2-3 |
| Raw Recruit | 15-20 | 10-12 | 6-8 | 5-8 | 25-30 | 20-25 | 12-15 | 10-14 | 4 | 1 | 2-3 |
| Trained Recruit | 22-28 | 14-18 | 8-10 | 8-12 | 35-42 | 30-35 | 16-20 | 14-18 | 5 | 1 | 2-3 |
| Veteran Mercenary | 35-45 | 22-28 | 10-13 | 14-18 | 50-58 | 42-50 | 22-26 | 20-24 | 6 | 1 | 2-3 |
| Elite Human Fighter | 55-70 | 30-38 | 13-16 | 20-25 | 65-75 | 55-65 | 28-34 | 26-32 | 7 | 1 | 2-3 |
| Champion/Boss Human | 85-110 | 42-52 | 16-20 | 28-35 | 80-95 | 70-80 | 36-44 | 34-42 | 8 | 1 | 2-3 |

### Monsters

| Archetype | HP | FAT | INIT | RES | M.SKL | R.SKL | M.DEF | R.DEF | AP | Move AP | Atk AP |
|-----------|-----|-----|------|-----|-------|-------|-------|-------|----|--------|-------|
| Light Monster | 18-28 | 8-14 | 10-14 | 4-8 | 40-50 | - | 14-20 | 8-14 | 5 | 1-2 | 2 |
| Heavy Monster | 70-100 | 15-25 | 5-8 | 10-15 | 55-70 | - | 24-32 | 10-18 | 6 | 2-3 | 3-4 |

### Undead

| Archetype | HP | FAT | INIT | RES | M.SKL | R.SKL | M.DEF | R.DEF | AP | Move AP | Atk AP |
|-----------|-----|-----|------|-----|-------|-------|-------|-------|----|--------|-------|
| Undead Weak | 18-25 | ∞ | 4-7 | 2-5 | 30-38 | 20-28 | 10-15 | 8-12 | 4 | 1 | 2 |
| Undead Elite | 55-80 | ∞ | 8-12 | 8-14 | 55-68 | 45-55 | 22-30 | 18-26 | 6 | 1 | 2-3 |

### Casters/Specialists

| Archetype | HP | FAT | INIT | RES | M.SKL | R.SKL | M.DEF | R.DEF | AP | Move AP | Atk AP |
|-----------|-----|-----|------|-----|-------|-------|-------|-------|----|--------|-------|
| Cult/Occult Caster | 20-30 | 15-22 | 7-10 | 16-24 | 22-30 | 35-45 | 10-16 | 14-22 | 4 | 1 | 2-3 |
| Beast Pack Enemy | 12-18 | 10-15 | 9-13 | 5-10 | 35-45 | 25-35 | 12-18 | 10-16 | 4 | 1 | 2 |

## Combat Constants

### AP System

| Action | AP Cost |
|--------|---------|
| Move (1 hex) | 1 |
| Walk (2 hexes) | 2 |
| Standard Attack | 2-3 (weapon dependent) |
| Aim + Shoot | 3 |
| Reload Crossbow | 2 |
| Cast Minor Spell | 2 |
| Cast Major Spell | 3-4 |
| Use Item | 1 |
| Defend | 1 |
| Switch Weapon | 1 |
| Dash (double move) | 2 |

### Fatigue System

| Action | Fatigue Cost |
|--------|-------------|
| Standard Attack | 3-5 |
| Heavy Attack | 6-9 |
| Charge Attack | 5-7 |
| Block/Parry | 2-3 |
| Spell Casting | 4-8 |
| Overhead Strike | 4-6 |
| Lunging Strike | 4-6 |
| Sweeping Strike | 5-7 |

### Morale Thresholds

| Morale Level | Value Range | Effect |
|--------------|-------------|--------|
| Broken | 0-10 | Flee, surrender, panic attacks |
| Wavering | 11-25 | -1 to all actions, may break on casualties |
| Steady | 26-50 | Normal combat |
| Confident | 51-75 | +5% accuracy, +5% resolve |
| Inspired | 76-90 | +10% accuracy, +10% resolve, +1 AP |
| Unbreakable | 91-100 | Immune to break, morale events have reduced effect |

### Armor Ranges

| Armor Type | Physical Armor | Recall Armor | Penalty |
|------------|---------------|--------------|---------|
| Cloth/Light | 10-25 | 5-15 | None |
| Leather/Medium | 26-45 | 15-30 | -5% speed |
| Chain/Hardened | 46-65 | 25-45 | -10% speed, -5 AP recovery |
| Plate/Heavy | 66-85 | 40-60 | -15% speed, -10 AP recovery |
| Super Heavy | 86-100 | 55-75 | -20% speed, -15 AP recovery |

### Damage Ranges

| Source | Damage Range |
|--------|-------------|
| Weak civilian weapon | 3-6 |
| Light weapon | 6-12 |
| Medium weapon | 12-20 |
| Heavy weapon | 20-32 |
| Elite weapon | 32-48 |
| Weak monster | 6-12 |
| Heavy monster | 25-40 |
| Occult spell | 15-30 |

### Accuracy Ranges

| Source | Hit Modifier |
|--------|-------------|
| Point-blank | +15 to +20 |
| Close range | +5 to +10 |
| Medium range | +0 to +5 |
| Long range | -5 to -10 |
| Extreme range | -15 to -20 |
| Flanking | +10 to +15 |
| Rear attack | +15 to +20 |
| Elevated | +5 to +10 |
| Prone target | +10 to +15 |

## Starting Company Ranges (Level 1)

| Stat | Minimum | Recommended | Maximum |
|------|---------|--------------|---------|
| Company Size | 3 | 4-6 | 8 |
| Average HP | 25 | 30-40 | 50 |
| Average Fatigue | 15 | 20-25 | 30 |
| Average Skill | 30 | 35-45 | 55 |
| Average Defense | 14 | 16-22 | 28 |
| Total Carry Capacity | 40 | 60-100 | 140 |
| Average Resolve | 10 | 14-20 | 28 |
| Armor Quality | 0-15 | 10-25 | 40 |

## Condition Resist Formula

```
condition_resist = (endurance * 2) + (will * 1) + (equipment_modifier)
```

| Condition Type | Base Resist |
|----------------|-------------|
| Physical (bleed, stun, knockback) | END based |
| Mental (fear, charm, sleep) | WILL based |
| Environmental (poison, burn, cold) | END + WIT based |
| Social (intimidate, seduce, lie) | PRE + WIL based |
