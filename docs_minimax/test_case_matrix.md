# Test Case Matrix - ROAD COMPANY

## Road Travel Tests

### Given/When/Then Format

```
Feature: Road Travel

  Scenario: Successful road travel between settlements
    Given company is at "Thornhaven" settlement
    And route "Thornhaven_to_Millbrook" exists with distance 8 hexes
    And route danger is 35
    And company has 6 members
    And company has 50 food stock
    When company travels route "Thornhaven_to_Millbrook"
    Then company arrives at "Millbrook" settlement
    And travel time is 2 ticks
    And food stock decreased by 6
    And route last_traveled_tick updated

  Scenario: Road travel with random encounter
    Given company travels route with danger 70
    When travel is executed
    Then encounter roll performed with 70% encounter chance
    And if encounter triggered, combat scenario generated

  Scenario: Road travel blocked by route danger
    Given route has danger_level 100
    And route is blockaded true
    When company attempts travel
    Then travel fails
    And company remains at origin
    And event "route_blocked" triggered

  Scenario: Road travel with insufficient supplies
    Given company food_stock is 2
    And travel requires 6 food
    When company attempts travel
    Then warning displayed
    And travel proceeds with starvation risk
    Or travel cancelled if confirm not given
```

## Route Danger Tests

```
Feature: Route Danger System

  Scenario: High danger route affects travel
    Given route danger is 85
    And patrol_coverage is 0
    When company travels
    Then bandit_activity increased by 15
    And encounter chance increased by 30%

  Scenario: Patrol reduces route danger
    Given route danger is 70
    And patrol_contract_active is true
    And patrol_coverage is 80
    When tick processed
    Then route danger decreases by patrol_effectiveness * 0.3

  Scenario: Multiple parties use dangerous route
    Given route danger is 60
    And 3 companies travel route in same tick
    When tick processed
    Then accumulated_danger modifier applied
```

## Trade Access Tests

```
Feature: Trade Access

  Scenario: High trade access improves settlement
    Given settlement trade_access is 85
    And settlement market_tier is 3
    When tick processed
    Then settlement prosperity increases by trade_income
    And recruitment_pool improves by trade_access * 0.01

  Scenario: Low trade access causes decline
    Given settlement trade_access is 20
    And settlement prosperity is 50
    When tick processed
    Then settlement prosperity decreases by 2
    And settlement unrest increases by 1

  Scenario: Trade route interruption
    Given settlement trade_access is 70
    And all connected routes have danger > 80
    When tick processed
    Then trade_access decreases by 15
    And settlement prosperity decreases by 3
```

## Settlement Economy Tick Tests

```
Feature: Settlement Economy Tick

  Scenario: Stable settlement economy
    Given settlement has default values
    When weekly tick is processed
    Then all values remain stable within ±2
    And population_change is approximately 0

  Scenario: Food shortage detection
    Given settlement food_stock is 30
    And settlement prosperity is 40
    When tick processed
    Then prosperity decreases by 2
    And unrest increases by 1
    And if food_stock < 20, population_loss_triggered

  Scenario: Production overflow handling
    Given settlement food_stock is 950
    And food_production results in 80 units
    When tick processed
    Then stock capped at 1000
    And surplus_effect applied (prosperity +0.5)

  Scenario: Complete stock depletion
    Given settlement food_stock is 5
    And weekly consumption is 40
    When tick processed
    Then stock becomes 0
    Then shortage_effects triggered
    And prosperity decreased by 3
    And unrest increased by 2

  Scenario: Market tier upgrade
    Given settlement prosperity is 85
    And settlement trade_access is 75
    And settlement population is 600
    And market_tier is 3
    When tick processed
    Then market_tier upgrade check performed
    And if random_roll < 0.05, market_tier becomes 4
```

## Settlement Growth/Decline Tests

```
Feature: Settlement Growth and Decline

  Scenario: Healthy settlement growth
    Given settlement prosperity is 70
    And settlement security is 65
    And settlement unrest is 15
    And population is 400
    When tick processed
    Then population increases by natural_growth + immigration

  Scenario: Declining settlement
    Given settlement prosperity is 25
    And settlement unrest is 50
    When tick processed
    Then population decreases by emigration
    And prosperity continues declining

  Scenario: Settlement abandonment threshold
    Given settlement population is 15
    When tick processed
    Then if population drops below 10, settlement_abandoned event triggered
```

## Internal Faction Influence Tests

```
Feature: Internal Faction System

  Scenario: Faction gains influence
    Given settlement has internal_faction "Merchant_Guild"
    And faction influence is 40
    And faction agenda is "trade_dominance"
    When tick processed
    Then faction influence may increase by agenda_progress * 0.1

  Scenario: Faction conflict escalation
    Given settlement has factions "Merchant_Guild" and "Craftsmen_Guild"
    And factions are in conflict
    When tick processed
    Then conflict_escalation_check performed
    And settlement_unrest affected

  Scenario: Faction takes control
    Given faction influence reaches 80
    When tick processed
    Then faction_control_check performed
    And if influence >= 90, faction becomes controlling_faction
```

## Contract Acceptance Tests

```
Feature: Contract System

  Scenario: Contract offered by patron
    Given settlement has patron_available true
    And settlement needs contract type "escort_caravan"
    When contract_generation triggered
    Then contract_template selected based on needs
    And contract added to available_contracts

  Scenario: Contract acceptance
    Given company has sufficient members
    And company has required reputation
    When company accepts contract
    Then contract status becomes "active"
    And company gains contract objectives

  Scenario: Contract acceptance insufficient reputation
    Given contract requires reputation 40
    And company reputation is 25
    When company attempts to accept
    Then acceptance denied
    And requirement_gap displayed

  Scenario: Contract deadline missed
    Given contract urgency is 1.5
    And days_remaining becomes 0
    When tick processed
    Then contract failure triggered
    And failure_consequences applied
```

## Contract Completion/Failure Tests

```
Feature: Contract Resolution

  Scenario: Contract success
    Given contract public_objective completed
    And no hidden_complication triggered failure
    When contract resolution calculated
    Then full_reward = base * danger_mult * distance_mult * urgency_mult
    And reputation increased by faction_reputation_mult
    And settlement_effects applied

  Scenario: Contract partial success
    Given contract tactical_objective partially completed
    When contract resolution calculated
    Then partial_reward = full_reward * 0.5
    And reduced reputation effect

  Scenario: Contract failure consequences
    Given contract failed due to objective not met
    When failure resolution calculated
    Then failure_consequences applied as defined
    And reputation decreased
    And settlement_effects negative applied
```

## Combat AP/Fatigue Tests

```
Feature: Combat Action Points and Fatigue

  Scenario: Standard attack AP usage
    Given fighter has 6 max_ap
    And fighter uses standard attack with AP cost 2
    When attack executed
    Then fighter current_ap reduced by 2
    And if current_ap < action_cost, action denied

  Scenario: Move and attack in same turn
    Given fighter has 6 max_ap
    And fighter moves 2 hexes (AP cost 2)
    And fighter attacks (AP cost 2)
    When turn ends
    Then fighter current_ap is 2 remaining

  Scenario: Fatigue from heavy attack
    Given fighter has 25 max_fatigue
    And fighter uses heavy attack with fatigue cost 8
    When attack executed
    Then fighter current_fatigue reduced by 8
    And if current_fatigue < fatigue_cost, action costs extra AP

  Scenario: Overhead strike fatigue overflow
    Given fighter current_fatigue is 5
    And overhead strike costs 6 fatigue
    When attack executed
    Then fatigue exceeds max, -2 fatigue applied
    And no HP damage from fatigue overflow

  Scenario: Spell casting with fatigue
    Given spell costs 6 fatigue
    And caster has 8 current_fatigue
    When spell cast
    Then fatigue reduced to 2
    And spell effect applies
```

## Armor/HP Damage Tests

```
Feature: Combat Damage System

  Scenario: Armor absorbs physical damage
    Given attack deals 20 damage
    And target armor provides 45% physical reduction
    When damage calculated
    Then physical_damage_taken = 20 * 0.55 = 11
    And HP reduced by 11

  Scenario: Armor penetrating attack
    Given attack deals 20 damage
    And attack has 40% armor ignore
    And target armor is 45%
    When damage calculated
    Then effective_armor = 45% * (1 - 0.40) = 27%
    And damage_taken = 20 * 0.73 = 14.6

  Scenario: HP reaches zero
    Given fighter has 15 HP
    And attack deals 20 damage
    When damage applied
    Then HP becomes 0
    And fighter status becomes "defeated"
    And morale_event triggered if applicable

  Scenario: Recall armor vs physical armor
    Given attack deals 20 physical damage
    And target has physical_armor 50 and recall_armor 30
    When damage calculated
    Then physical_armor applies to physical damage portion
    And recall_armor applies to recall damage portion
```

## Morale Checks Tests

```
Feature: Morale System

  Scenario: Ally casualty morale impact
    Given party morale is 60
    And ally dies in combat
    When morale_event calculated
    Then morale reduced by ally_death_penalty = 10
    And if morale < 30, wavering_check triggered

  Scenario: Enemy morale break
    Given enemy morale is 15
    And enemy suffers heavy casualties
    When morale_check performed
    Then if random_roll < (25 - morale)%, enemy flees

  Scenario: Inspired morale bonus
    Given fighter morale is 85
    When combat actions calculated
    Then accuracy +10%
    And resolve +10%
    And fighter gains +1 max_ap

  Scenario: Morale below break threshold
    Given fighter morale is 5
    When turn starts
    Then fighter must pass resolve check or flee
    And if check failed, fighter status "fled"
```

## Conditions Tests

```
Feature: Combat Conditions

  Scenario: Bleeding condition application
    Given attack applies bleeding condition
    When condition attached to target
    Then target takes 3 damage per turn for 2 turns
    And condition stackable true

  Scenario: Stunned condition blocks action
    Given target has stunned condition with severity 3
    When target attempts action
    Then action denied
    And AP cost increased by stunned_severity

  Scenario: Multiple conditions stack
    Given target has bleeding (severity 2) and poisoned (severity 1)
    When tick processed
    Then both conditions apply damage
    And total condition damage = 3*2 + 2*1 = 8

  Scenario: Condition removal by medicine
    Given companion has medicine_skill >= 40
    And target has condition "bleeding"
    When medicine treatment applied
    Then condition removed
    And medicine_stock decreased by 3

  Scenario: Condition resistance
    Given target has endurance 45 and will 35
    When condition_attack with severity 5 attempted
    Then resist_check = (45*2) + (35*1) = 125
    And if resist_check > severity*20, condition resisted
```

## Camp Rest/Repair/Treatment Tests

```
Feature: Camp Management

  Scenario: Full rest recovers all resources
    Given company establishes camp
    And members have various HP and fatigue levels
    When rest period completed
    Then HP fully recovered
    And fatigue fully recovered
    And conditions may persist unless treated

  Scenario: Partial rest with watch
    Given company rests but maintains watch
    When rest period completed
    Then fatigue recovered at 50% rate
    And random_encounter chance reduced by watch effectiveness

  Scenario: Armor repair at camp
    Given armor durability is 15, max 100
    And settlement has tools_stock >= 10
    When repair action selected
    Then durability restored by repair_amount
    And tools_stock decreased by repair_cost
    And time tick increased by 1

  Scenario: Companion medical treatment
    Given companion has condition "infected_wound"
    And healer_companion has medicine_skill 55
    When treatment applied
    Then condition duration reduced by heal_amount
    Or condition removed if skill > threshold
```

## Reputation Changes Tests

```
Feature: Reputation System

  Scenario: Faction reputation increase
    Given action benefits faction "Merchant_Guild"
    And current reputation is 30
    When reputation_change calculated
    Then reputation increases by action_value * faction_mult

  Scenario: Faction reputation decrease
    Given action harms faction interests
    When reputation_change calculated
    Then reputation decreased by appropriate amount
    And if reputation < -20, contract access reduced

  Scenario: Multiple faction effects
    Given action benefits one faction but harms another
    When reputation_change calculated
    Then both effects applied simultaneously
```

## Event Trigger Validity Tests

```
Feature: Event System

  Scenario: Event trigger conditions met
    Given event has trigger_conditions {route_danger: [30,60], time: any}
    And current route_danger is 45
    When event_check performed
    Then event eligible for selection

  Scenario: Event cooldown prevents triggering
    Given event was triggered 5 days ago
    And event cooldown is 14 days
    When event_check performed
    Then event not eligible (cooldown active)

  Scenario: Event weight affects selection
    Given multiple events eligible
    When event selection performed
    Then events selected by weight / total_weight probability
```

## Emergent Story Chain Tests

```
Feature: Story Chain Tracking

  Scenario: Chain initiated by event
    Given event "bandit_attack" triggered
    And bandid_leader named "Vex" escapes
    When chain recorded
    Then chain status "active"
    And chain_triggers includes "Vex_location_unknown"

  Scenario: Chain mutation by player choice
    Given chain "refugee_crisis" active
    And player chooses to close gates
    When tick processed
    Then chain_mutation "refugees_turn_hostile" triggered
    And chain effects modified

  Scenario: Chain discovery via rumor
    Given chain has discoverable flag true
    And chain is active for 3+ ticks
    When rumor generation occurs
    Then rumor_text revealed to player
```

## Test Case Summary Table

| System | Test Count | Priority | Deterministic |
|--------|-----------|----------|---------------|
| Road Travel | 8 | High | Yes |
| Route Danger | 6 | High | Yes |
| Trade Access | 5 | Medium | Yes |
| Settlement Economy Tick | 12 | Critical | Yes |
| Settlement Growth/Decline | 5 | High | Yes |
| Internal Faction | 6 | Medium | Partial |
| Contract Acceptance | 7 | High | Yes |
| Contract Completion | 5 | High | Yes |
| Combat AP/Fatigue | 8 | Critical | Yes |
| Armor/HP Damage | 7 | Critical | Yes |
| Morale Checks | 6 | High | Yes |
| Conditions | 9 | High | Yes |
| Camp Management | 6 | Medium | Yes |
| Reputation Changes | 5 | Medium | Yes |
| Event Triggers | 5 | Medium | Partial |
| Emergent Story Chains | 5 | Low | Partial |

## Automated Test Execution

Tests should be executable via:
```bash
python -m pytest tests/ -v
python tools/run_all_tests.py
```

Each test should:
1. Set up known initial state
2. Execute single action or tick
3. Assert expected final state
4. Reset state after test
5. Log pass/fail with details
