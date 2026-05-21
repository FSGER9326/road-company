# Contract Rewards - ROAD COMPANY

## Reward Formula

```
final_reward = base_reward
  * danger_mult
  * distance_mult
  * urgency_mult
  * patron_wealth_mult
  * faction_reputation_mult
  * settlement_prosperity_mult
  + bonus_rewards
```

### Component Definitions

| Variable | Range | Description |
|----------|-------|-------------|
| base_reward | 50-2000 | Base coin reward |
| danger_mult | 0.5-3.0 | Based on enemy strength |
| distance_mult | 0.8-2.0 | Based on hex distance |
| urgency_mult | 0.8-2.5 | Days until deadline |
| patron_wealth_mult | 0.5-3.0 | Patron's financial status |
| faction_reputation_mult | 0.5-2.0 | Faction relationship |
| settlement_prosperity_mult | 0.7-1.5 | Settlement economic status |

## Contract Type Tables

### 1. Escort Caravan

| Factor | Value |
|--------|-------|
| base_reward | 150-400 |
| danger_mult | 1.0-2.0 |
| distance_mult | 1.0-1.8 |
| urgency_mult | 0.9-1.4 |
| patron_wealth_mult | 0.8-1.5 |
| faction_reputation_mult | 1.0 |
| settlement_prosperity_mult | 1.0 |
| non-money rewards | Reputation with trading faction, caravan access |
| partial success | 40-60% reward, -reputation |
| failure | -50% potential reputation, bounty标记 |

**Hidden Complication Modifiers:**
- Ambush en route: +30% danger_mult
- Double-cross reveal: -30% base_reward, +faction_reputation
- Cargo secretly contraband: +20% danger_mult, +10% reward if delivered

---

### 2. Patrol Route

| Factor | Value |
|--------|-------|
| base_reward | 80-250 |
| danger_mult | 0.8-1.5 |
| distance_mult | 0.5-1.2 |
| urgency_mult | 0.8-1.2 |
| patron_wealth_mult | 0.7-1.3 |
| faction_reputation_mult | 1.0-1.3 |
| settlement_prosperity_mult | 1.0 |
| non-money rewards | Salvage rights, patrol route exclusivity |
| partial success | 50-70% reward, no salvage |
| failure | -reputation with settlement, unrest+1 |

**Route Length Modifier:** distance_mult = 1.0 + (hex_distance * 0.05)

---

### 3. Hunt Bandits

| Factor | Value |
|--------|-------|
| base_reward | 120-350 |
| danger_mult | 1.2-2.5 |
| distance_mult | 0.9-1.5 |
| urgency_mult | 0.8-1.6 |
| patron_wealth_mult | 0.6-1.2 |
| faction_reputation_mult | 1.0-1.5 |
| settlement_prosperity_mult | 1.0-1.2 |
| non-money rewards | Bandit loot/salvage, improved security |
| partial success | 60% reward, bandit remnants remain |
| failure | Bandit retaliation, -security |

**Kill Bonus:** +20-50 coin per bandit killed above quota

---

### 4. Monster Lair

| Factor | Value |
|--------|-------|
| base_reward | 300-800 |
| danger_mult | 2.0-3.5 |
| distance_mult | 1.0-2.0 |
| urgency_mult | 0.7-1.8 |
| patron_wealth_mult | 0.8-2.0 |
| faction_reputation_mult | 1.0-1.6 |
| settlement_prosperity_mult | 1.0-1.4 |
| non-money rewards | Monster parts, trophies, fame |
| partial success | 50% reward, lair dormant but not cleared |
| failure | Monster activity increases, -population |

**Monster Tier Multiplier:**
- Tier 1 (weak): danger_mult = 1.5-2.0
- Tier 2 (standard): danger_mult = 2.0-2.5
- Tier 3 (elite): danger_mult = 2.5-3.0
- Tier 4 (boss): danger_mult = 3.0-3.5

---

### 5. Capture Bounty Target

| Factor | Value |
|--------|-------|
| base_reward | 200-600 |
| danger_mult | 1.5-3.0 |
| distance_mult | 1.0-1.6 |
| urgency_mult | 1.0-2.0 |
| patron_wealth_mult | 0.7-1.5 |
| faction_reputation_mult | 0.8-1.3 |
| settlement_prosperity_mult | 1.0 |
| non-money rewards | Bounty license, lawkeeper reputation |
| partial success | 30% reward, target wounded/escaped |
| failure | Target escapes, -reputation with bounty guild |

**Target Alive Bonus:** +50-100% reward if target must be captured alive

---

### 6. Recover Missing Wagon

| Factor | Value |
|--------|-------|
| base_reward | 180-450 |
| danger_mult | 1.0-2.0 |
| distance_mult | 1.2-1.8 |
| urgency_mult | 0.7-1.5 |
| patron_wealth_mult | 0.8-1.4 |
| faction_reputation_mult | 1.0-1.2 |
| settlement_prosperity_mult | 0.9-1.1 |
| non-money rewards | Partial cargo salvage, route knowledge |
| partial success | 50% reward, partial cargo recovered |
| failure | Cargo lost, -trade_access for settlement |

**Cargo Condition Modifier:** Recovered damaged cargo = 60-80% reward

---

### 7. Suppress Riot

| Factor | Value |
|--------|-------|
| base_reward | 100-300 |
| danger_mult | 1.2-2.0 |
| distance_mult | 1.0 |
| urgency_mult | 1.5-2.5 |
| patron_wealth_mult | 0.6-1.2 |
| faction_reputation_mult | 0.5-1.0 |
| settlement_prosperity_mult | 0.7-1.0 |
| non-money rewards | Settlement gratitude, recruitment pool boost |
| partial success | 60% reward, unrest reduced but not eliminated |
| failure | Settlement sacked, -population, -security |

**Casualty Requirement:** More company casualties = lower reward scaling

---

### 8. Deliver Medicine

| Factor | Value |
|--------|-------|
| base_reward | 100-280 |
| danger_mult | 0.8-1.5 |
| distance_mult | 1.2-2.0 |
| urgency_mult | 1.5-3.0 |
| patron_wealth_mult | 0.5-1.0 |
| faction_reputation_mult | 1.0-1.3 |
| settlement_prosperity_mult | 0.6-0.9 |
| non-money rewards | Medical supplies discount, healer faction rep |
| partial success | 70% reward, some medicine lost |
| failure | Plague spreads, -population, -settlement_tier |

**Urgency Scaling:** urgency_mult = 1.5 + ((max_days - days_remaining) * 0.1)

---

### 9. Defend Settlement

| Factor | Value |
|--------|-------|
| base_reward | 200-500 |
| danger_mult | 1.5-2.5 |
| distance_mult | 1.0 |
| urgency_mult | 1.0-1.4 |
| patron_wealth_mult | 0.6-1.2 |
| faction_reputation_mult | 1.0-1.5 |
| settlement_prosperity_mult | 0.8-1.2 |
| non-money rewards | Fortification access, settlement loyalty |
| partial success | 50-70% reward, settlement damaged but standing |
| failure | Settlement overrun, -population, -faction_influence |

**Victory Bonus:** +20-40% if settlement takes no structural damage

---

### 10. Sabotage Rival Faction

| Factor | Value |
|--------|-------|
| base_reward | 250-600 |
| danger_mult | 1.8-3.0 |
| distance_mult | 1.0-1.5 |
| urgency_mult | 0.9-1.4 |
| patron_wealth_mult | 1.0-2.0 |
| faction_reputation_mult | 0.3-0.7 |
| settlement_prosperity_mult | 1.0 |
| non-money rewards | Rival weakness intel, blackmail material |
| partial success | 40% reward, rival weakened but not destroyed |
| failure | Blamed, -reputation with multiple factions |

**Discovery Risk:** Higher danger_mult = higher risk of attribution

---

### 11. Investigate Disappearances

| Factor | Value |
|--------|-------|
| base_reward | 150-400 |
| danger_mult | 1.0-2.0 |
| distance_mult | 1.0-1.3 |
| urgency_mult | 0.8-1.2 |
| patron_wealth_mult | 0.7-1.3 |
| faction_reputation_mult | 1.0-1.4 |
| settlement_prosperity_mult | 0.8-1.0 |
| non-money rewards | Investigation intel, occult lore, cult insight |
| partial success | 50% reward, partial information |
| failure | Real culprit hidden, cult grows, -population |

**Information Value:** Detailed reports = +10-30% reward

---

### 12. Train Militia

| Factor | Value |
|--------|-------|
| base_reward | 80-200 |
| danger_mult | 0.5-0.8 |
| distance_mult | 0.8-1.0 |
| urgency_mult | 0.8-1.0 |
| patron_wealth_mult | 0.5-0.9 |
| faction_reputation_mult | 1.0-1.4 |
| settlement_prosperity_mult | 1.0-1.3 |
| non-money rewards | Recruitment pool access, trained soldiers |
| partial success | 60-80% reward, militia partially trained |
| failure | Militia mutinies, -security, -settlement_morale |

**Training Quality Bonus:** Well-trained militia = +15-25% reward

---

## Faction Reputation Modifiers

| Standing | Faction Rep | Reward Mult |
|----------|------------|-------------|
| Hostile | -100 to -50 | 0.5 |
| Unfriendly | -49 to -20 | 0.7 |
| Neutral | -19 to +19 | 1.0 |
| Friendly | +20 to +49 | 1.2 |
| Allied | +50 to +100 | 1.5 |

## Settlement Prosperity Modifiers

| Tier | Prosperity | Reward Mult |
|------|------------|-------------|
| Destitute | 0-20 | 0.7 |
| Poor | 21-40 | 0.85 |
| Average | 41-60 | 1.0 |
| Prosperous | 61-80 | 1.15 |
| Wealthy | 81-100 | 1.3 |

## Failure Consequences Table

| Consequence | Severity | Trigger |
|-------------|----------|---------|
| -Reputation (single faction) | Low | Any failure |
| -Security | Medium | Protection contracts |
| -Trade access | Medium | Escort/trade contracts |
| -Population | High | Defense/medicine contracts |
| Bounty mark | High | Bounty/faction contracts |
| Territory lost | Critical | Settlement defense |
| Plague spread | Critical | Medicine delivery |

## Non-Monetary Rewards

| Type | Value Range |
|------|-------------|
| Faction reputation | +10 to +50 |
| Salvage (weapons) | 20-200 value |
| Salvage (armor) | 15-150 value |
| Salvage (goods) | 30-250 value |
| Information | Future contract access |
| Recruitment access | +1-3 potential recruits |
| Settlement discount | 5-20% for X days |
| Route exclusivity | Y days |
| Bounty license | Access to bounty contracts |
