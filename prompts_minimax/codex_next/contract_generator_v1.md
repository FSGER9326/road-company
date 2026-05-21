# Codex Next Prompt: Contract Generator V1

## Task
Implement a first contract generator that creates contracts from world state, not just static templates.

## Reading Materials
Before implementation, read:
- `docs/balance/contract_rewards.md` - Contract reward formulas and balance
- `docs/balance/combat_stat_ranges.md` - Difficulty scaling
- `data/examples/contract_templates_expansion.json` - Template structure
- `data/schema_drafts/world_state_schema_draft.json` - World state structure

## Requirements

### 1. World State Analysis Functions
Create contract need analysis based on:

**Settlement Needs:**
```
analyze_settlement_needs(settlement: Dictionary) -> Dictionary
```
- Food shortage → generates "deliver medicine" or "escort caravan" contracts
- Low security → generates "patrol route" or "defend settlement" contracts
- High unrest → generates "suppress riot" contracts
- Plague → generates "deliver medicine" contracts
- Monster threat → generates "monster lair" contracts

**Route Dangers:**
```
analyze_route_dangers(routes: Array) -> Array
```
- High danger routes → generate "patrol" or "escort" contracts
- Blockaded routes → generate "sabotage" or "clear" contracts

**Faction Agendas:**
```
analyze_faction_agendas(factions: Array) -> Array
```
- Merchant guild needs trade → escort contracts
- Noble houses compete → sabotage contracts
- Cults grow → investigation contracts

**Internal Faction Conflicts:**
```
analyze_faction_conflicts(settlement: Dictionary) -> Array
```
- Guild war brewing → "mediate" contracts
- Cult infiltration → "investigate" contracts
- Noble succession → "support claimant" contracts

### 2. Contract Generation Logic
Create `scripts/contract_generator.gd`:

```
generate_contract(need_type: String, context: Dictionary) -> Dictionary
```

**Generation Steps:**
1. Select base template from `data/examples/contract_templates_expansion.json`
2. Calculate base_reward using formula from design doc
3. Calculate all multipliers based on context
4. Set difficulty scaling based on company strength
5. Determine enemy tags based on danger level
6. Set battlefield tags based on location
7. Generate hidden complication (50% chance of complication)
8. Calculate success/failure/partial consequences

**Reward Formula:**
```
final_reward = base_reward
  * danger_mult (0.5-3.0 based on threat level)
  * distance_mult (0.8-2.0 based on hex distance)
  * urgency_mult (0.8-2.5 based on time limit)
  * patron_wealth_mult (0.5-3.0 based on patron)
  * faction_reputation_mult (0.5-2.0 based on relationships)
  * settlement_prosperity_mult (0.7-1.5 based on settlement tier)
```

### 3. Dynamic Contract Variation
Contracts should vary based on:
- Company size and strength
- Company reputation with relevant factions
- Current game state (war, plague, famine, etc.)
- Settlement needs at time of generation
- Previously completed contracts

### 4. Seeded Randomness
All contract generation must be deterministic:
- Use world_state seed for all random selections
- Same world state + same seed = same contract
- Record seed with generated contract for debugging

### 5. Integration Points
Update `main.gd` or create new `scripts/contract_manager.gd`:
```
get_available_contracts(settlement_id: String) -> Array
accept_contract(contract_id: String) -> bool
complete_contract(contract_id: String, result: String) -> Dictionary
fail_contract(contract_id: String) -> Dictionary
```

### 6. Contract Templates JSON
Ensure `data/examples/contract_templates_expansion.json` has all 30 contracts with:
- id, title, type, patron_type
- public_objective, hidden_complication
- tactical_objective
- route_effects, settlement_effects, faction_effects
- companion_hooks
- success_result, failure_result, partial_success_result
- suggested_enemy_tags, suggested_battlefield_tags
- reward_profile (with all multiplier values)

### 7. Test Cases
Add to `tools/run_all_tests.py`:
```python
def test_contract_generation_basic():
    """Test basic contract generation from settlement need"""
    pass

def test_contract_generation_reward_calculation():
    """Test reward formula matches design document"""
    pass

def test_contract_generation_determinism():
    """Test same seed produces same contract"""
    pass

def test_contract_generation_uses_templates():
    """Test contracts come from template pool"""
    pass

def test_contract_acceptance_prerequisites():
    """Test reputation and strength requirements enforced"""
    pass

def test_contract_completion_rewards():
    """Test rewards match formula on completion"""
    pass

def test_contract_failure_consequences():
    """Test failure consequences applied correctly"""
    pass
```

## Acceptance Criteria

### Must Pass
1. [ ] Contract generator analyzes settlement needs
2. [ ] Contract generator analyzes route dangers
3. [ ] Contract generator analyzes faction agendas
4. [ ] Reward formula matches design document exactly
5. [ ] All 30 contract templates are valid JSON and loadable
6. [ ] Generated contracts select from template pool
7. [ ] Contract variations based on context
8. [ ] Determinism maintained with seed
9. [ ] All 7 test cases pass
10. [ ] Existing prototype unaffected

### Should Pass
1. [ ] Hidden complications generate correctly
2. [ ] Companion hooks attach to appropriate contracts
3. [ ] Settlement effects apply on contract completion

## File Preservation
- Do NOT modify existing scenes
- Do NOT modify existing autoloads
- Add new script files only

## Execution
After implementation:
1. Run `python tools/run_all_tests.py`
2. Verify all new tests pass
3. Report results
