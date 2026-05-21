# Codex Next Prompt: World Tick V1

## Task
Implement the first deterministic settlement economy tick system for ROAD COMPANY.

## Reading Materials
Before implementation, read these files:
- `docs/balance/economy_tick_values.md` - Full economic simulation design
- `data/schema_drafts/world_state_schema_draft.json` - Settlement data structure
- `docs/test_case_matrix.md` - Test scenarios for economy tick

## Requirements

### 1. Settlement Data Structure
Create `data/settlements.json` with:
- Minimum 3 settlements: Thornhaven (town), Millbrook (village), Crossfield (trading_post)
- Each settlement must have all economy variables from design doc
- Include population, prosperity, security, food_stock, medicine_stock, tools_stock, arms_stock, unrest, corruption, trade_access, market_tier, recruitment_pool, faction_pressure, crisis_pressure

### 2. Goods Production/Consumption
Implement in `data/goods.json`:
- All 13 goods from design doc: grain, meat, salt, iron, timber, cloth, medicine, tools, weapons, relics, contraband, livestock, luxury_goods
- Base production and consumption values per good
- Shortage and surplus effects per good

### 3. Tick Logic (New File: `scripts/settlement_tick.gd`)
Create a new Godot script implementing:
```
settlement_tick(settlement_id: String) -> Dictionary
```

Core tick function that processes one settlement per call:
1. **Production Phase** - Calculate weekly production for each good
2. **Consumption Phase** - Calculate weekly consumption for each good
3. **Stock Update** - Apply production - consumption
4. **Shortage Check** - Apply shortage effects if stock < 0
5. **Surplus Check** - Apply surplus effects if stock > max
6. **Population Change** - Calculate natural_growth + immigration - emigration
7. **Prosperity Change** - Calculate trade_income + production_income - corruption_drain - unrest_penalty + security_bonus
8. **Security Change** - Calculate patrol_effect + trade_access_bonus - unrest_effect - raid_check
9. **Unrest Change** - Calculate economic_distress + food_shortage + corruption_effect - repression
10. **Market Tier Check** - Evaluate for upgrade or downgrade
11. **Recruitment Pool Update** - Calculate based on market_tier + prosperity + security - crisis_penalty

### 4. Route Effects (New File: `data/routes.json`)
Create route data:
- Routes connecting settlements with hex distances
- danger_level per route
- patrol_coverage per route

### 5. Validation Functions
Add to tick system:
```
validate_settlement_data(settlement: Dictionary) -> bool
validate_tick_result(before: Dictionary, after: Dictionary) -> Dictionary
```
- All values must stay within defined min/max ranges
- Population cannot go below 10
- Market tier must be 1-5

### 6. Determinism
- All random_rolls must use seeded RNG
- Tick results must be identical for same input state + seed
- Record seed used per tick for debugging

### 7. Test Cases
Add to `tools/run_all_tests.py`:
```python
def test_settlement_tick_stable():
    """Test stable settlement maintains equilibrium"""
    pass

def test_settlement_tick_food_shortage():
    """Test food shortage effects"""
    pass

def test_settlement_tick_prosperity_growth():
    """Test prosperity increases with high trade access"""
    pass

def test_settlement_tick_security_collapse():
    """Test security decline with high unrest"""
    pass

def test_settlement_tick_population_change():
    """Test population growth/decline based on conditions"""
    pass

def test_settlement_tick_market_tier_change():
    """Test market tier upgrades at high prosperity"""
    pass

def test_settlement_tick_determinism():
    """Test same seed produces same results"""
    pass
```

### 8. Debug UI Panel (Optional)
If feasible within current prototype structure:
- Display all settlement economy variables
- Show before/after tick values
- Highlight changes
- Manual tick trigger button

## Acceptance Criteria

### Must Pass
1. [ ] `data/settlements.json` contains valid settlement data for 3+ settlements
2. [ ] `data/goods.json` contains all 13 goods with production/consumption values
3. [ ] `data/routes.json` contains routes connecting settlements
4. [ ] `settlement_tick()` function produces correct output for stable settlement
5. [ ] Food shortage correctly triggers prosperity decrease and unrest increase
6. [ ] Population change formula matches design document
7. [ ] All clamp rules enforced (population 10-10000, prosperity 0-100, etc.)
8. [ ] Tick is deterministic under seed
9. [ ] All 7 test cases pass
10. [ ] Existing prototype runs without modification

### Should Pass
1. [ ] Debug panel shows tick results clearly
2. [ ] Validation functions catch invalid data
3. [ ] Route danger affects settlement trade_access

## File Preservation
- Do NOT modify existing scene files
- Do NOT modify existing autoload scripts
- Do NOT modify `project.godot`
- Add new files only

## Execution
After implementation:
1. Run `python tools/run_all_tests.py`
2. Verify all new tests pass
3. Verify existing tests still pass
4. Report test results
