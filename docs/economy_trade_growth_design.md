# Economy, Trade, and Settlement Growth Design

## Purpose
Define a manageable but meaningful economic simulation where trade matters, settlements grow or decline based on player actions and world state, and the economy is deep through interaction rather than impossible complexity.

---

## 1. Resources and Trade Goods

### Purpose
Define a compact, meaningful set of trade goods that drive market behavior and settlement production/consumption.

### Trade Goods Schema

```json
{
  "id": "string",
  "name": "string",
  "category": "food|construction|material|luxury|dangerous|service",
  "base_price": "int (in crowns)",
  "weight": "int (per unit, affects carry capacity)",
  "produced_in": ["region_type"],
  "consumed_in": ["settlement_type"],
  "perishable": "bool",
  "contraband": "bool"
}
```

### Core Trade Goods (14 Total)

| ID | Name | Category | Base Price | Weight | Notes |
|----|------|----------|------------|--------|-------|
| **grain** | Grain | food | 8 | 2 | Staple, perishable |
| **meat** | Dried Meat | food | 15 | 3 | Non-perishable |
| **salt** | Salt | food | 20 | 2 | Preservative, luxury |
| **iron** | Iron Ore | material | 25 | 5 | Heavy |
| **timber** | Timber | construction | 12 | 4 | Bulky |
| **cloth** | Cloth | material | 18 | 2 | |
| **medicine** | Medicine | service | 35 | 1 | Rare |
| **tools** | Tools | construction | 30 | 3 | |
| **weapons** | Weapons | material | 45 | 4 | Contraband in some areas |
| **relics** | Relics | luxury | 80 | 1 | Religious, valuable |
| **contraband** | Contraband | dangerous | 60 | 1 | Illegal |
| **livestock** | Livestock | food | 25 | 0 (live) | |
| **luxury_goods** | Luxury Goods | luxury | 70 | 1 | |
| **fuel** | Fuel/Charcoal | construction | 10 | 3 | |

### Example Trade Good JSON

```json
{
  "id": "medicine",
  "name": "Medicine",
  "category": "service",
  "base_price": 35,
  "weight": 1,
  "produced_in": ["city", "monastery"],
  "consumed_in": ["town", "village", "hamlet", "mining_camp"],
  "perishable": false,
  "contraband": false
}
```

---

## 2. Settlement Economy Model

### Settlement Core Economy Stats

```json
{
  "id": "settlement_id",
  "population": "int",
  "prosperity": "int (1-100)",
  "security": "int (1-100)",
  "food_stock": "int",
  "medicine_stock": "int",
  "tools_stock": "int",
  "arms_stock": "int",
  "unrest": "int (0-100)",
  "corruption": "int (0-100)",
  "trade_access": "int (1-100)",
  "market_tier": "int (1-6)",
  "food_balance": "int (production - consumption per day)",
  "market_modifiers": {"good_id": "float"}
}
```

### Market Tier Definition

| Tier | Population Range | Market Types | Base Price Modifier |
|------|-----------------|--------------|---------------------|
| 1 | 10-100 | hamlet, freehold | 1.4 |
| 2 | 100-500 | village | 1.2 |
| 3 | 500-2000 | town | 1.0 |
| 4 | 2000-10000 | large town | 0.9 |
| 5 | 10000-30000 | city | 0.8 |
| 6 | 30000+ | capital | 0.7 |

### Settlement Production and Consumption

#### Daily Consumption
```
daily_consumption = {
    "grain": population / 100,      # units of grain per day
    "medicine": population / 500,   # medicine demand is rare
    "tools": population / 1000,     # tools wear out slowly
    "fuel": population / 200        # for heating/cooking
}
```

#### Production Based on Settlement Type and Region
```
production_modifiers = {
    "hamlet": {"grain": 1.5, "livestock": 1.2},
    "village": {"grain": 1.3, "timber": 1.2},
    "town": {"grain": 1.0, "tools": 1.3, "cloth": 1.2},
    "city": {"medicine": 1.5, "relics": 1.3, "luxury_goods": 1.4},
    "mining_camp": {"iron": 2.0, "fuel": 1.5},
    "caravanserai": {"grain": 0.8, "fuel": 1.2}
}
```

---

## 3. Market Price Derivation

### Formula
```
supply_factor = settlement.food_stock / (population * 2)  # 1.0 = well stocked
demand_factor = population / 1000.0  # 1.0 = 1000 people
market_modifier = settlement.market_modifiers.get(good_id, 1.0)
tier_modifier = MARKET_TIER_PRICE_MODIFIER[settlement.market_tier]

price = base_price * (1.0 / supply_factor) * demand_factor * market_modifier * tier_modifier
price = clamp(price, base_price * 0.5, base_price * 3.0)
```

### Example Price Calculation
```
settlement: Blackford (town, tier 3, population 2400)
good: medicine (base 35)
supply_factor = 25 / (2400 * 2) = 0.0052  # very low supply
demand_factor = 2400 / 1000 = 2.4
market_modifier = 1.0 (no special modifier)
tier_modifier = 1.0

price = 35 * (1.0 / 0.0052) * 2.4 * 1.0 * 1.0
price = 35 * 192 * 2.4 = 16,128  # clamped to 105 (3x base)
clamped_price = min(105, max(17, 35 * 3.0)) = 105
```

Wait, let me recalculate - the formula needs adjustment:
```
price = base_price * (1.0 / supply_factor) * demand_factor * market_modifier
```
But supply_factor in my example is way too small. Let me use different numbers:

```
settlement: Blackford (town, population 2400, medicine_stock 25)
supply_factor = min(1.0, 25 / (2400 * 0.5)) = min(1.0, 0.0208) = 0.0208
demand_factor = 2400 / 1000 = 2.4
market_modifier = 1.0

price = 35 * (1.0 / 0.0208) * 2.4 * 1.0
price = 35 * 48 * 2.4 = 4,032  # clearly too high

# Better formula using stock relative to weekly consumption:
medicine_weekly_consumption = population / 500 * 7 = 2400/500*7 = 33.6
stock_ratio = medicine_stock / medicine_weekly_consumption = 25/33.6 = 0.74
# Low stock (< 1.0) increases price, high stock decreases
price_modifier = 2.0 - stock_ratio  # = 1.26

price = base_price * price_modifier * demand_factor * tier_modifier
price = 35 * 1.26 * 2.4 * 1.0 = 106  # clamped to 105
```

### Simplified Market Price Formula (Implementable)
```
# Calculate stock ratio (stock vs weekly consumption)
weekly_consumption = (population / CONSUMPTION_DIVISOR[good_category]) * 7
stock_ratio = stock / weekly_consumption  # < 1.0 = shortage, > 1.0 = surplus

# Price modifier: shortages raise prices, surpluses lower them
if stock_ratio >= 1.5: price_mult = 0.7  # oversupplied
elif stock_ratio >= 1.0: price_mult = 0.85
elif stock_ratio >= 0.5: price_mult = 1.0
elif stock_ratio >= 0.25: price_mult = 1.3  # shortage
else: price_mult = 1.8  # severe shortage

# Apply market tier modifier
price = base_price * price_mult * MARKET_TIER_MODIFIER[market_tier]
price = clamp(price, base_price * 0.5, base_price * 3.0)
```

---

## 4. Settlement Growth and Decline

### Purpose
Settlements grow when prosperous and secure, decline when poor or unstable.

### Growth Factors

| Factor | Effect on Growth |
|--------|-----------------|
| **Prosperity > 60** | +population growth |
| **Prosperity > 80** | +bonus growth |
| **Security < 30** | -population, emigration |
| **Food stock = 0** | -population (starvation) |
| **Food stock < population/10** | -growth, +unrest |
| **Unrest > 70** | -growth, possible revolt |
| **War in region** | -prosperity, -security |
| **Plague** | -population, -prosperity |
| **Trade route open** | +prosperity |
| **Trade route closed** | -prosperity, -trade_access |

### Settlement Tick (Daily)

```
settlement_tick(settlement, world_state):
    # 1. Calculate consumption
    for good_id in CONSUMED_GOODS:
        consumption = settlement.population / CONSUMPTION_DIVISOR[good_id]
        settlement["{}_stock".format(good_id)] = max(0, settlement["{}_stock".format(good_id)] - consumption)
    
    # 2. Calculate production
    for good_id in settlement.trade_goods_produced:
        production = BASE_PRODUCTION[good_id] * REGION_MODIFIER[settlement.region_id].get(good_id, 1.0)
        settlement["{}_stock".format(good_id)] += production
    
    # 3. Update unrest
    if settlement.food_stock < settlement.population / 10:
        settlement.unrest += 5
    if settlement.security < 30:
        settlement.unrest += 3
    if settlement.corruption > 70:
        settlement.unrest += 2
    settlement.unrest = clamp(settlement.unrest - 0.5, 0, 100)  # natural drift toward calm
    
    # 4. Update prosperity
    trade_access_factor = settlement.trade_access / 50.0
    security_factor = settlement.security / 100.0
    unrest_factor = (100 - settlement.unrest) / 100.0
    settlement.prosperity = clamp((security_factor * 30 + trade_access_factor * 30 + unrest_factor * 20 + 20), 1, 100)
    
    # 5. Population growth/decline
    if settlement.prosperity > 60 and settlement.food_stock > settlement.population / 5:
        settlement.population += int(settlement.population * 0.001)  # 0.1% growth
    elif settlement.prosperity < 20 or settlement.food_stock == 0:
        settlement.population -= int(settlement.population * 0.01)  # 1% decline
    
    # 6. Market tier recalculation
    if settlement.population < 100 and settlement.market_tier > 1:
        settlement.market_tier = 1
    elif settlement.population < 500 and settlement.market_tier > 2:
        settlement.market_tier = 2
    # ... etc for each tier threshold
```

### Settlement Level/Market Tier Changes

| Tier Change | Trigger | Effect |
|-------------|---------|--------|
| **Decline** | Population drops below threshold | Prices worsen, fewer contracts |
| **Growth** | Population exceeds threshold for 30 days | Better prices, more contracts, more goods |
| **Special** | Event (plague, war, festival) | Temporary modifier |

---

## 5. Route Effects on Economy

### Purpose
Routes connect settlements and enable trade. Closed routes strangle economies.

### Route Traffic Calculation
```
route_traffic(route, settlement1, settlement2):
    base_traffic = (settlement1.prosperity + settlement2.prosperity) / 20
    security_factor = (settlement1.security + settlement2.security) / 200
    bandit_factor = 1.0 - (route.bandit_pressure / 100.0)
    return clamp(base_traffic * security_factor * bandit_factor, 0, 20)
```

### Route Effects on Settlement Trade Access
```
if route.is_closed:
    settlement.trade_access -= 5  # per closed route
else:
    settlement.trade_access = min(100, settlement.trade_access + route_traffic(route) * 0.5)
```

### Player Route Effects

| Player Action | Effect |
|--------------|--------|
| **Complete escort contract** | +5 trade_access to both settlements |
| **Hunt bandits on route** | -10 bandit_pressure, +2 trade_access |
| **Raid caravan** | -20 caravan_frequency, +15 bandit_pressure |
| **Clear monster lair** | -20 monster_pressure |
| **Patrol contract** | +15 patrol_presence, +5 trade_access |
| **Fail to protect caravan** | -10 trade_access, -5 prosperity |
| **Build new route** | +30 trade_access to both settlements (later expansion) |

---

## 6. Player Trade Actions

### Purpose
Allow players to buy and sell goods at settlements.

### Buy/Sell System
```
can_buy(company, good_id, quantity):
    total_cost = get_market_price(settlement, good_id) * quantity
    return company.crowns >= total_cost

buy_goods(company, settlement, good_id, quantity):
    cost = get_market_price(settlement, good_id) * quantity
    if not can_buy(company, good_id, quantity): return false
    company.crowns -= cost
    settlement["{}_stock".format(good_id)] -= quantity * 0.8  # 20% lost to handling
    company["{}_stock".format(good_id)] += quantity  # add to company inventory
    return true

sell_goods(company, settlement, good_id, quantity):
    if company["{}_stock".format(good_id)] < quantity: return false
    revenue = get_market_price(settlement, good_id) * quantity * 0.7  # 70% of buy price
    company.crowns += revenue
    settlement["{}_stock".format(good_id)] += quantity * 0.9  # 90% arrives
    company["{}_stock".format(good_id)] -= quantity
    return true
```

### Company Inventory Schema Extension
```
company.inventory = {
    "grain": 0,
    "meat": 0,
    "salt": 0,
    "iron": 0,
    "timber": 0,
    "cloth": 0,
    "medicine": 0,
    "tools": 0,
    "weapons": 0,
    "relics": 0,
    "contraband": 0,
    "livestock": 0,
    "luxury_goods": 0,
    "fuel": 0
}
```

---

## 7. Caravan/Escort Economy

### Purpose
Escort contracts and caravan protection affect settlement supply.

### Caravan Spawning
```
if random() < settlement.trade_access / 200.0:  # higher trade = more caravans
    spawn_caravan(settlement, connected_settlement)
```

### Caravan Effects on Settlement
```
if caravan_arrives(caravan, settlement):
    for good in caravan.cargo:
        settlement["{}_stock".format(good)] += caravan.cargo[good] * 0.9
    settlement.prosperity += 2

if caravan_destroyed(caravan):
    # settlements lose supply
    origin = caravan.origin
    origin.trade_access -= 3
    origin.prosperity -= 5
```

### Player Escort Contract Effects
```
complete_escort_contract(company, contract):
    # Reward given
    company.crowns += contract.reward_crowns
    
    # Settlement effects
    origin = get_settlement(contract.origin_location)
    target = get_settlement(contract.target_location)
    origin.prosperity += 5
    target.food_stock += contract.cargo_amount
    origin.trade_access += 8
    
    # Route effects
    route = get_route(contract.target_route)
    route.bandit_pressure -= 10  # player cleared bandits
    
    # Faction effects
    for faction_id, delta in contract.faction_effects.items():
        company.faction_reputation[faction_id] += delta
```

---

## 8. Settlement Before/After Example

### Before (Prosperous Town)
```json
{
  "id": "embermill",
  "name": "Embermill",
  "type": "town",
  "population": 1800,
  "prosperity": 58,
  "security": 42,
  "food_stock": 200,
  "medicine_stock": 30,
  "tools_stock": 50,
  "arms_stock": 45,
  "unrest": 18,
  "corruption": 25,
  "trade_access": 55,
  "market_tier": 3,
  "trade_goods_produced": ["grain", "meat"],
  "trade_goods_demanded": ["salt", "iron"]
}
```

### After (After 30 Days of Neglect + Failed Contracts)
```json
{
  "id": "embermill",
  "name": "Embermill",
  "type": "town",
  "population": 1650,
  "prosperity": 38,
  "security": 28,
  "food_stock": 80,
  "medicine_stock": 15,
  "tools_stock": 35,
  "arms_stock": 30,
  "unrest": 52,
  "corruption": 40,
  "trade_access": 30,
  "market_tier": 2,
  "trade_goods_produced": ["grain"],
  "trade_goods_demanded": ["salt", "iron", "medicine"],
  "current_situations": ["food_shortage", "bandit_threat"]
}
```

---

## 9. JSON Schema for Economy

### Trade Good Schema
```json
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
```

### Settlement Economy Extension
```json
{
  "trade_goods_produced": ["good_id"],
  "trade_goods_demanded": ["good_id"],
  "trade_access": "int (1-100)",
  "market_tier": "int (1-6)",
  "food_balance": "int",
  "market_prices": {"good_id": "int (calculated)"}
}
```

---

## 10. Automated Tests for Economy

```python
def test_market_price_in_range():
    for settlement in settlements:
        for good_id in GOOD_IDS:
            price = derive_market_price(settlement, good_id)
            base = GOOD_BASE_PRICES[good_id]
            assert base * 0.5 <= price <= base * 3.0

def test_shortage_increases_price():
    s = make_settlement()
    s.food_stock = 5  # severe shortage
    price = derive_market_price(s, "grain")
    assert price > GOOD_BASE_PRICES["grain"]

def test_surplus_decreases_price():
    s = make_settlement()
    s.food_stock = 1000  # large surplus
    price = derive_market_price(s, "grain")
    assert price < GOOD_BASE_PRICES["grain"]

def test_settlement_consumption_reduces_stock():
    s = make_settlement()
    initial = s.food_stock
    settlement_tick(s)
    assert s.food_stock < initial

def test_settlement_grows_when_prosperous():
    s = make_settlement()
    s.prosperity = 75
    s.food_stock = 1000
    initial_pop = s.population
    settlement_tick(s)
    assert s.population >= initial_pop

def test_settlement_declines_when_starving():
    s = make_settlement()
    s.food_stock = 0
    s.population = 1000
    settlement_tick(s)
    assert s.population < 1000

def test_trade_access_affects_prosperity():
    s = make_settlement()
    s.trade_access = 80
    s.security = 50
    s.unrest = 20
    recalc_prosperity(s)
    assert s.prosperity > 50

def test_player_buy_reduces_crowns():
    company = make_company()
    company.crowns = 100
    settlement = make_settlement()
    buy_goods(company, settlement, "grain", 10)
    assert company.crowns < 100

def test_player_sell_increases_crowns():
    company = make_company()
    company.grain = 20
    settlement = make_settlement()
    sell_goods(company, settlement, "grain", 10)
    assert company.crowns > 0
```

---

## 11. Implementation Task List

1. Create `data/economy/trade_goods.json` with 14 goods
2. Create `data/economy/market_tiers.json` with tier definitions
3. Extend settlement JSON schema with economy fields
4. Create `EconomySystem.gd` with price calculation
5. Create `SettlementEconomySystem.gd` with consumption/production
6. Create `TradeScreen.gd` for player buying/selling
7. Create `MarketUI.gd` showing current prices
8. Extend `CompanyState.gd` with inventory
9. Create automated tests for price derivation
10. Create automated tests for settlement tick
11. Create automated tests for player trade
12. Create route traffic simulation
13. Create caravan spawning and effects
