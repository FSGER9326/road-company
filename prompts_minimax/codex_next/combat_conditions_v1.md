# Codex Next Prompt: Combat Conditions V1

## Task
Implement the first combat condition system for ROAD COMPANY tactical combat.

## Reading Materials
Before implementation, read:
- `docs/balance/combat_stat_ranges.md` - Condition resist formulas
- `data/schema_drafts/combat_schema_draft.json` - Condition data structure
- `docs/test_case_matrix.md` - Test scenarios for conditions

## Requirements

### 1. Initial Conditions Set
Implement these 8 conditions first:

| Condition | Category | Base Effect | Duration | Removable By |
|-----------|----------|------------|----------|--------------|
| bleeding | physical | 3 damage/turn | 2 turns | medicine, rest |
| stunned | physical | -2 AP, cannot act | 1 turn | will check |
| staggered | physical | -1 AP, -10% accuracy | 2 turns | endurance check |
| frightened | mental | -15% accuracy, may flee | 2 turns | will check |
| guarded | combat | +20% defense | 1 turn | automatic end |
| exposed | combat | +25% damage taken | 2 turns | combat end |
| poisoned | environmental | 2 damage/turn | 3 turns | medicine |
| burning | environmental | 3 damage/turn | 2 turns | dodge roll |

### 2. Condition Data Schema
Add to `data/conditions.json`:
```json
{
  "conditions": [
    {
      "id": "bleeding",
      "name": "Bleeding",
      "category": "physical",
      "effects": {
        "hp_per_tick": -3
      },
      "stackable": true,
      "max_stacks": 3,
      "duration_ticks": 2,
      "severity_based": false,
      "removable_by": ["medicine", "rest"]
    }
  ]
}
```

### 3. Condition Application
Create `scripts/combat_conditions.gd`:
```
apply_condition(target: Fighter, condition_id: String, severity: int = 1) -> bool
remove_condition(target: Fighter, condition_id: String) -> bool
process_conditions(fighter: Fighter) -> void
tick_conditions(fighter: Fighter) -> Dictionary
```

**apply_condition rules:**
- Check condition_resist = (endurance * 2) + (will * 1) + equipment_modifier
- If resist_check > severity * 20, condition resisted
- Stackable conditions add severity
- Non-stackable conditions refresh duration

### 4. Condition Effects on Combat
Update combat system to apply condition effects:

**During action calculation:**
```
get_action_modifiers(fighter: Fighter, action: String) -> Dictionary
```
- AP cost modified by conditions
- Accuracy modified by conditions
- Damage modified by conditions
- Fatigue cost modified by conditions

**During damage application:**
```
apply_damage_with_conditions(target: Fighter, damage: int) -> void
```
- Exposed condition increases damage taken
- Guarded condition decreases damage taken
- Bleeding/Burning/Poisoned apply tick damage

### 5. Condition Resolution
Implement end-of-turn condition processing:

**tick_conditions(fighter: Fighter):**
- Decrement duration for all conditions
- Apply hp_per_tick and fatigue_per_tick effects
- Remove conditions with duration <= 0
- Trigger will checks for frightened if duration expired

**will_check(fighter: Fighter, condition: String):**
- roll = random_1d100 + will
- threshold = 50 + condition_severity * 10
- If roll >= threshold, condition removed early

### 6. UI/Log Display
Update combat UI to show conditions:
- Icon display next to affected fighter
- Tooltip showing condition name and remaining duration
- Log entry when condition applied: "Kira is Bleeding (2 turns)"
- Log entry when condition removed: "Kira's Bleeding has stopped"

### 7. Medicine/Rest Interaction
Implement condition removal:

**Using medicine at camp:**
```
treat_companion(companion: Fighter, condition_id: String) -> bool
```
- Requires medicine_stock >= 3
- Removes condition if companion has medicine_skill >= 30
- Higher skill = better chance on difficult conditions

**Rest and conditions:**
- Conditions do NOT automatically clear on rest
- Only guarded automatically ends
- Other conditions persist through rest

### 8. Combat Integration
Update `combat.gd` or relevant combat script:
- Apply conditions from attacks and abilities
- Process conditions at end of each fighter's turn
- Display condition effects in combat log
- Block actions for stunned condition

### 9. Test Cases
Add to `tools/run_all_tests.py`:
```python
def test_condition_application():
    """Test conditions apply correctly to fighters"""
    pass

def test_condition_resistance():
    """Test endurance/will resistance works"""
    pass

def test_bleeding_tick_damage():
    """Test bleeding deals 3 damage per turn"""
    pass

def test_stunned_blocks_action():
    """Test stunned prevents action"""
    pass

def test_condition_stacking():
    """Test stacking works for stackable conditions"""
    pass

def test_condition_removal_medicine():
    """Test medicine can remove conditions"""
    pass

def test_condition_duration_expires():
    """Test conditions expire after duration"""
    pass

def test_will_check_removes_frightened():
    """Test will check can remove frightened"""
    pass

def test_deterministic_conditions():
    """Test same state produces same condition results"""
    pass
```

## Acceptance Criteria

### Must Pass
1. [ ] All 8 conditions implemented with correct effects
2. [ ] Condition application respects resistance formula
3. [ ] Conditions display in UI during combat
4. [ ] Conditions appear in combat log
5. [ ] Bleeding, Poisoned, Burning deal correct tick damage
6. [ ] Stunned blocks action selection
7. [ ] Duration countdown works correctly
8. [ ] All 9 test cases pass
9. [ ] No combat rewrite unless absolutely necessary

### Should Pass
1. [ ] Medicine treatment works at camp
2. [ ] Will checks function for frightened
3. [ ] Condition tooltips show duration

## File Preservation
- Do NOT rewrite entire combat system
- Add condition processing to existing combat flow
- Preserve existing combat scenes

## Execution
After implementation:
1. Run `python tools/run_all_tests.py`
2. Verify all new tests pass
3. Report results
