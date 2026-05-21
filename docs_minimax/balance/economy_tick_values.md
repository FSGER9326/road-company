# Economy Tick Values - ROAD COMPANY

## Settlement Economy Variables

| Variable | Min | Max | Default | Description |
|----------|-----|-----|---------|-------------|
| population | 10 | 10000 | 500 | Citizens in settlement |
| prosperity | 0 | 100 | 50 | Economic health (affects prices) |
| security | 0 | 100 | 50 | Safety rating (affects growth) |
| food_stock | 0 | 1000 | 200 | Units of food stored |
| medicine_stock | 0 | 500 | 50 | Units of medicine stored |
| tools_stock | 0 | 500 | 50 | Units of tools stored |
| arms_stock | 0 | 500 | 30 | Units of weapons stored |
| unrest | 0 | 100 | 10 | Civil unrest level |
| corruption | 0 | 100 | 15 | Corruption level |
| trade_access | 0 | 100 | 50 | Trade route connectivity |
| market_tier | 1 | 5 | 2 | Market quality level |
| recruitment_pool | 0 | 100 | 20 | Available recruits quality |
| faction_pressure | 0 | 100 | 0 | External faction influence |
| crisis_pressure | 0 | 100 | 0 | Active crisis intensity |

## Goods Production/Consumption

### Weekly Production Formula

```
weekly_production = base_production * (prosperity/50) * (1 + trade_bonus) * (1 - corruption*0.002)
```

### Weekly Consumption Formula

```
weekly_consumption = base_consumption * (population/500) * (1 + unrest*0.005)
```

## Goods Table

| Good | Base Production | Base Consumption | Shortage Effect | Surplus Effect | Base Price |
|------|-----------------|------------------|-----------------|----------------|------------|
| grain | 50/week | 40/week | -1 prosperity/week | +0.5 prosperity | 2 |
| meat | 30/week | 25/week | -1 prosperity/week | +0.3 prosperity | 4 |
| salt | 10/week | 8/week | -0.5 prosperity/week | stable | 8 |
| iron | 20/week | 15/week | -2 security/week | +1 arms_stock | 12 |
| timber | 35/week | 25/week | -1 prosperity/week | +0.5 prosperity | 6 |
| cloth | 25/week | 20/week | -0.5 prosperity/week | stable | 10 |
| medicine | 8/week | 12/week | -2 population/week | +1 recruitment | 20 |
| tools | 15/week | 12/week | -2 prosperity/week | +1 prosperity | 15 |
| weapons | 5/week | 8/week | -3 security/week | +1 security | 30 |
| relics | 2/week | 3/week | -1 faction_pressure | +2 faction_pressure | 50 |
| contraband | 5/week | 5/week | +2 corruption if short | +3 corruption if surplus | 40 |
| livestock | 15/week | 10/week | -1 prosperity/week | +1 prosperity | 15 |
| luxury_goods | 5/week | 8/week | +1 prosperity if shortage | -1 prosperity if oversupply | 35 |

## Weekly Tick Logic

### Step 1: Production Phase
```
for each good:
    produced = base_production[good] * (prosperity/50) * (1 - corruption*0.002)
    stock[good] += produced
```

### Step 2: Consumption Phase
```
for each good:
    consumed = base_consumption[good] * (population/500)
    stock[good] -= consumed
```

### Step 3: Shortage/Surplus Check
```
for each good:
    if stock[good] < 0:
        shortage = -stock[good]
        apply_shortage_effects(good, shortage)
        stock[good] = 0
    else if stock[good] > max_stock[good]:
        surplus = stock[good] - max_stock[good]
        apply_surplus_effects(good, surplus)
        stock[good] = max_stock[good]
```

## Shortage Effects

| Good | Severity | Effect |
|------|----------|--------|
| grain | Low | -1 prosperity, -0.5 unrest |
| grain | Medium | -2 prosperity, +1 unrest, -2 population/week |
| grain | High | -4 prosperity, +3 unrest, -5 population/week, possible starvation event |
| medicine | Low | -1 population/week |
| medicine | Medium | -3 population/week, disease event |
| medicine | High | -8 population/week, plague event |
| iron | Low | -1 security/week |
| iron | Medium | -2 security/week, militia effectiveness -10% |
| iron | High | -4 security/week, possible raider attack |
| weapons | Any | -2 security/week, possible mutiny if security < 20 |

## Surplus Effects

| Good | Effect |
|------|--------|
| grain | +0.5 prosperity/week, may attract immigrants |
| meat | +0.3 prosperity/week |
| timber | +1 arms_stock if shortage |
| tools | +1 prosperity/week |
| weapons | +1 security/week (cap at 100) |
| luxury_goods | +1 prosperity if >150% stock, else -1 if shortage |

## Population Change

```
natural_growth = (prosperity - 50) * 0.1
immigration = (trade_access * prosperity * 0.01) * (1 - unrest*0.01)
emigration = (unrest * 0.5) + (prosperity < 30 ? prosperity * 0.1 : 0)
food_factor = 1.0 - (shortage_severity * 0.2)
medicine_factor = 1.0 - (medicine_shortage ? 0.3 : 0)

population_change = floor((natural_growth + immigration - emigration) * food_factor * medicine_factor)
population = clamp(population + population_change, 10, 10000)
```

## Prosperity Change

```
trade_income = (trade_access * market_tier * 0.1)
production_income = sum(surplus goods value) * 0.1
corruption_drain = corruption * 0.05
unrest_penalty = unrest * 0.02
security_bonus = security * 0.01

prosperity_change = trade_income + production_income - corruption_drain - unrest_penalty + security_bonus
prosperity = clamp(prosperity + prosperity_change, 0, 100)
```

## Security Change

```
patrol_effect = (arms_stock > 30 ? +2 : -1)
trade_access_bonus = trade_access * 0.01
unrest_effect = unrest * -0.1
raid_check = (route_danger > 70 ? random_roll < (route_danger - 70)/100 : false)

if raid_check:
    security_change = -5 - (arms_stock < 20 ? 3 : 0)
else:
    security_change = patrol_effect + trade_access_bonus + unrest_effect

security = clamp(security + security_change, 0, 100)
```

## Unrest Change

```
economic_distress = (prosperity < 30 ? (30 - prosperity) * 0.1 : 0)
food_shortage_effect = (food_stock < 50 ? (50 - food_stock) * 0.02 : 0)
corruption_effect = corruption * 0.02
repression = (security > 80 ? -1 : 0)
population_density = (population > 1000 ? (population - 1000) * 0.0005 : 0)

unrest_change = economic_distress + food_shortage_effect + corruption_effect - repression - population_density
unrest = clamp(unrest + unrest_change, 0, 100)
```

## Market Tier Changes

```
if prosperity > 80 and trade_access > 70 and population > 500:
    if random_roll < 0.05:
        market_tier += 1
        prosperity -= 10

if prosperity < 20 or population < 50:
    if random_roll < 0.1:
        market_tier -= 1
        market_tier = max(1, market_tier)
```

## Recruitment Pool Quality

```
base_quality = market_tier * 2 + prosperity/10 + security/10
faction_bonus = (faction_pressure > 50 ? 5 : 0)
crisis_penalty = crisis_pressure * 0.1

recruitment_pool = clamp(base_quality + faction_bonus - crisis_penalty, 0, 100)
```

## Route Danger Effects on Settlement

```
route_danger_avg = average_danger_of_connected_routes

if route_danger_avg > 60:
    trade_access -= (route_danger_avg - 60) * 0.1
    security -= (route_danger_avg - 60) * 0.05
    unrest += (route_danger_avg - 60) * 0.03

if route_danger_avg < 30 and security > 60:
    trade_access += (60 - route_danger_avg) * 0.05
    prosperity += (60 - route_danger_avg) * 0.02
```

## Patrol/Escort Effects

```
if settlement has active patrol contract:
    security += patrol_strength * 0.5
    route_danger -= patrol_coverage * 0.3

if settlement has active escort mission on route:
    route_danger -= escort_effectiveness * 0.2
    trade_access += escort_effectiveness * 0.1
```

## Crisis Pressure Effects

```
crisis_pressure_sources:
- plague_active: +30 base, +5/week
- famine_active: +25 base, +3/week
- war_nearby: +20 base
- raider_horde: +15 base, +2/week
- cult_activity: +10 base, +2/week

total_crisis_pressure = sum(active crises)

if total_crisis_pressure > 70:
    all production *= 0.7
    unrest += (total_crisis_pressure - 70) * 0.1
    recruitment_pool -= 10

if total_crisis_pressure > 90:
    random_critical_event triggered
```

## Settlement Tick Example

### Before Tick - "Millbrook Village"

| Variable | Value |
|----------|-------|
| population | 450 |
| prosperity | 52 |
| security | 48 |
| food_stock | 180 |
| medicine_stock | 42 |
| tools_stock | 38 |
| arms_stock | 22 |
| unrest | 12 |
| corruption | 18 |
| trade_access | 55 |
| market_tier | 2 |
| recruitment_pool | 24 |
| faction_pressure | 15 |
| crisis_pressure | 0 |

### Week Operations
- Production: grain +50, meat +28, iron +18, etc.
- Consumption: grain -36, meat -22, iron -13, etc.
- Trade: +3 prosperity from trade_access

### After Tick - "Millbrook Village"

| Variable | Value | Change |
|----------|-------|--------|
| population | 453 | +3 |
| prosperity | 54 | +2 |
| security | 47 | -1 |
| food_stock | 200 | +20 |
| medicine_stock | 38 | -4 |
| tools_stock | 41 | +3 |
| arms_stock | 19 | -3 |
| unrest | 11 | -1 |
| corruption | 17 | -1 |
| trade_access | 56 | +1 |
| market_tier | 2 | 0 |
| recruitment_pool | 25 | +1 |
| faction_pressure | 15 | 0 |
| crisis_pressure | 0 | 0 |

## Clamping Rules

```
population = clamp(population, 10, 10000)
prosperity = clamp(prosperity, 0, 100)
security = clamp(security, 0, 100)
unrest = clamp(unrest, 0, 100)
corruption = clamp(corruption, 0, 100)
trade_access = clamp(trade_access, 0, 100)
market_tier = clamp(market_tier, 1, 5)
recruitment_pool = clamp(recruitment_pool, 0, 100)
stock[grain] = clamp(stock[grain], 0, 1000)
stock[medicine] = clamp(stock[medicine], 0, 500)
stock[iron] = clamp(stock[iron], 0, 500)
stock[weapons] = clamp(stock[weapons], 0, 500)
```

## Test Cases

### Test 1: Stable Settlement
```
Input: Default values, no external factors
Expected: All values stable within ±2 per tick
```

### Test 2: Food Shortage
```
Input: food_stock = 30, prosperity = 40
Expected: prosperity decreases, unrest increases, possible population loss
```

### Test 3: High Trade Access
```
Input: trade_access = 90, market_tier = 4
Expected: prosperity increases, recruitment_pool improves
```

### Test 4: Security Collapse
```
Input: security = 10, arms_stock = 5
Expected: rapid prosperity decline, unrest surge, possible settlement failure
```

### Test 5: Crisis Pressure
```
Input: crisis_pressure = 85, multiple crises active
Expected: production reduced, unrest high, recruitment poor
```

### Test 6: Recovery Scenario
```
Input: Poor settlement receiving patrol contract + trade escort
Expected: security improves, trade_access improves, prosperity slowly recovers
```
