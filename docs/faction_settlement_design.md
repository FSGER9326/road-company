# Faction and Settlement Design

## Purpose
Define how settlements contain internal power factions, how those factions fight for influence, how player actions shift internal power, and how internal faction states drive settlement-level events and emergent stories.

---

## 1. Internal Settlement Factions

### Purpose
Each settlement contains 2-6 internal factions competing for influence. These factions are not world-level factions (like the Ashen Crown) but micro-power groups within a single town.

### Core Data Model

```json
{
  "faction_id": "string (references world faction or internal-only)",
  "influence": "int (1-100)",
  "attitude": "friendly|neutral|hostile|afraid",
  "agenda": "string (short description of their goal)",
  "resources": "int (0-100, their wealth/power)",
  "enemy_factions": ["internal_faction_id"],
  "preferred_contracts": ["contract_type"],
  "policies_push": ["policy_id"],
  "events_can_trigger": ["event_id"],
  "reward_can_offer": ["reward_type"],
  "consequences_if_angered": ["consequence_id"],
  "special_abilities": ["ability_id"]
}
```

### Example Internal Factions for a Town

```json
[
  {
    "faction_id": "gate_nobility",
    "influence": 45,
    "attitude": "neutral",
    "agenda": "expand toll collection and guard contracts",
    "resources": 55,
    "enemy_factions": ["guild_council"],
    "preferred_contracts": ["patrol", "escort", "defend_settlement"],
    "policies_push": ["raise_tolls", "militarize"],
    "events_can_trigger": ["toll_dispute_event"],
    "reward_can_offer": ["contract_boon", "market_access"],
    "consequences_if_angered": ["trade_boycott", "hostile_pricing"],
    "special_abilities": ["bribe_guard", "call_militia"]
  },
  {
    "faction_id": "guild_council",
    "influence": 38,
    "attitude": "friendly",
    "agenda": "lower market fees and attract traders",
    "resources": 42,
    "enemy_factions": ["gate_nobility"],
    "preferred_contracts": ["deliver_goods", "smuggle"],
    "policies_push": ["lower_fees", "free_trade"],
    "events_can_trigger": ["strike_event", "market_protests"],
    "reward_can_offer": ["discount_prices", "exclusive_info"],
    "consequences_if_angered": ["price_hike", "information_blocked"],
    "special_abilities": ["negotiate_discount", "call_strike"]
  },
  {
    "faction_id": "lantern_cell",
    "influence": 15,
    "attitude": "neutral",
    "agenda": "spread faith and gain converts",
    "resources": 20,
    "enemy_factions": ["occult_covenant"],
    "preferred_contracts": ["investigate", "purge_cult"],
    "policies_push": ["religious_observance", "suppress_heresy"],
    "events_can_trigger": ["conversion_event", "inquisition"],
    "reward_can_offer": ["blessing", "healing"],
    "consequences_if_angered": ["social_ostracism", "inquisition"]
  },
  {
    "faction_id": "criminal_network",
    "influence": 22,
    "attitude": "hostile",
    "agenda": "control underground trade and avoid guards",
    "resources": 35,
    "enemy_factions": ["gate_nobility"],
    "preferred_contracts": ["smuggle", "theft", "information"],
    "policies_push": ["corruption", "lax_enforcement"],
    "events_can_trigger": ["heist_event", "extortion"],
    "reward_can_offer": ["black_market_access", "secret_routes"],
    "consequences_if_angered": ["theft_attempt", "informant_network"]
  }
]
```

### Settlement Types and Typical Factions

| Settlement Type | Typical Internal Factions |
|-----------------|--------------------------|
| **Hamlet** | peasant_commons, local_herdsman, shrine_keeper |
| **Village** | village_elder, militia_captain, merchant, traveling_priest |
| **Town** | gate_nobility, guild_council, priesthood, militia, merchants |
| **City** | noble_houses, guild_council, priesthood, city_guard, criminal_syndicate, foreign_envoys |
| **Fort** | garrison_commander, quartermaster, chaplain, prisoner_overseer |
| **Monastery** | abbot, chapter, lay_brothers, pilgrim_host, scholar_cell |
| **Caravanserai** | innkeeper_collective, caravan_master, beast_handlers, smugglers |
| **Mining Camp** | mine_foreman, miner_union, ore_merchant, camp_guard |
| **Freehold** | elder_council, raider_clan, exile_bloc, cult_cell |

---

## 2. Faction Influence System

### Purpose
Track and modify internal faction power within a settlement.

### Influence Ranges

| Influence | Label | Effect |
|-----------|-------|--------|
| 70-100 | **dominant** | Controls settlement policy, can trigger major events |
| 50-69 | **influential** | Can push policies, offer major rewards |
| 30-49 | **established** | Normal operation, can trigger minor events |
| 10-29 | **marginal** | Limited power, may be suppressed |
| 1-9 | **suppressed** | Barely present, may be purged |

### Influence Change Mechanics

#### Natural Drift
- All factions drift toward 30 (equilibrium) at rate of ±1 per week
- Dominant factions drift faster: -2 per week when >70
- Suppressed factions drift faster: +2 per week when <10

#### Player Contract Impact
```
complete_contract(contract, settlement, internal_faction):
    if contract.type in internal_faction.preferred_contracts:
        internal_faction.influence += 5
        internal_faction.resources += 2
    if contract.type in opposite_faction.disliked_contracts:
        opposite_faction.influence -= 3
```

#### Direct Interaction
| Action | Faction Effect | Enemy Faction Effect |
|--------|---------------|---------------------|
| **Bribe** | +5 influence, -10 crowns | 0 |
| **Intimidate** | +3 influence, enemy -5 influence | enemy -5 influence |
| **Help faction quest** | +15 influence, +10 resources | enemy -10 influence |
| **Betray faction** | -20 influence, enemy +10 | enemy +10 |
| **Kill enemy agent** | +5 influence, enemy -15 influence | enemy -15 |
| **Complete contract for faction** | +8 influence | enemy -3 influence |

### Faction Attitude Changes
```
attitude_shift(faction, delta):
    if faction.attitude == "afraid" and faction.influence > 30:
        faction.attitude = "hostile"
    elif faction.attitude == "hostile" and faction.influence < 20:
        faction.attitude = "neutral"
    elif faction.attitude == "neutral" and faction.influence > 50:
        faction.attitude = "friendly"
    elif faction.attitude == "friendly" and faction.influence < 20:
        faction.attitude = "neutral"
```

### Faction Victory/Defeat Conditions
- If one faction reaches 80 influence and next highest is <30: faction controls settlement
- If lowest faction reaches <5: faction is purged, removed from settlement
- If two enemy factions both reach >60: civil conflict event triggers

---

## 3. Internal Settlement Events

### Purpose
Drive emergent stories through internal faction competition.

### Event Schema

```json
{
  "id": "string",
  "name": "string",
  "type": "influence_shift|conflict|reform|disaster|discovery",
  "trigger_conditions": {
    "min_influence_threshold": "int (optional)",
    "required_faction": "faction_id (optional)",
    "required_settlement_type": ["type (optional)"],
    "random_chance": "float (0.0-1.0, optional)"
  },
  "influence_effects": {
    "faction_id": "int (delta)"
  },
  "settlement_effects": {
    "prosperity": "int (delta)",
    "security": "int (delta)",
    "unrest": "int (delta)",
    "corruption": "int (delta)"
  },
  "player_options": [
    {
      "id": "string",
      "label": "string",
      "requirement": "string (skill_check or item)",
      "outcome": "string (success_text)",
      "effects": {}
    }
  ],
  "automatic_outcome": "string (if player doesn't intervene)",
  "cooldown_days": "int"
}
```

### 10 Example Internal Settlement Conflict Events

#### 1. Toll Dispute
```json
{
  "id": "toll_dispute_event",
  "name": "Toll Dispute Erupts",
  "type": "conflict",
  "trigger_conditions": {
    "required_faction": "gate_nobility",
    "min_influence_threshold": 60
  },
  "influence_effects": {
    "gate_nobility": 10,
    "guild_council": -12
  },
  "settlement_effects": {
    "prosperity": -5,
    "security": -8,
    "unrest": 15
  },
  "player_options": [
    {
      "id": "support_nobility",
      "label": "Back the nobility's toll increase",
      "requirement": "presence_check DC 12",
      "outcome": "Nobility grateful, guild enraged",
      "effects": {"gate_nobility": 8, "guild_council": -10, "player_reputation_guild_council": -15}
    },
    {
      "id": "support_guild",
      "label": "Oppose the toll increase publicly",
      "requirement": "intimidation_check DC 14",
      "outcome": "Guild pleased, nobility furious",
      "effects": {"gate_nobility": -10, "guild_council": 8, "player_reputation_gate_nobility": -15}
    }
  ],
  "automatic_outcome": "Tolls rise. Guild calls strike. Settlement loses 10 prosperity and gains unrest.",
  "cooldown_days": 30
}
```

#### 2. Guild Strike
```json
{
  "id": "guild_strike_event",
  "name": "Guild Strike Closes Markets",
  "type": "conflict",
  "trigger_conditions": {
    "required_faction": "guild_council",
    "min_influence_threshold": 65,
    "random_chance": 0.15
  },
  "influence_effects": {
    "guild_council": 8,
    "gate_nobility": -5
  },
  "settlement_effects": {
    "prosperity": -15,
    "security": 5,
    "unrest": 20
  },
  "player_options": [
    {
      "id": "break_strike",
      "label": "Use hired muscle to force markets open",
      "requirement": "might_check DC 16",
      "outcome": "Strike broken violently. Markets open but unrest soars.",
      "effects": {"guild_council": -20, "gate_nobility": 5, "unrest": 25}
    },
    {
      "id": "mediate_strike",
      "label": "Offer to negotiate between parties",
      "requirement": "presence_check DC 15",
      "outcome": "Negotiated compromise. Both factions slightly pleased.",
      "effects": {"guild_council": 5, "gate_nobility": 3, "unrest": -5}
    }
  ],
  "automatic_outcome": "Strike lasts 3 days. Settlement loses prosperity and trade goods.",
  "cooldown_days": 45
}
```

#### 3. Plague Outbreak
```json
{
  "id": "plague_outbreak_event",
  "name": "Plague Reaches Critical Mass",
  "type": "disaster",
  "trigger_conditions": {
    "random_chance": 0.08,
    "required_settlement_type": ["town", "city"]
  },
  "influence_effects": {
    "plague_doctors": 15,
    "guild_council": -8,
    "gate_nobility": -5
  },
  "settlement_effects": {
    "prosperity": -20,
    "security": -10,
    "population": -100,
    "unrest": 30
  },
  "player_options": [
    {
      "id": "deliver_medicine",
      "label": "Deliver emergency medicine supplies",
      "requirement": "contract_deliver_medicine",
      "outcome": "Plague contained. Factions grateful.",
      "effects": {"plague_doctors": 10, "unrest": -20, "population_loss": 20}
    },
    {
      "id": "quarantine_settlement",
      "label": "Help enforce strict quarantine",
      "requirement": "gate_nobility_influence > 40",
      "outcome": "Plague contained but trade dies.",
      "effects": {"prosperity": -15, "security": 10, "plague_doctors": 5}
    }
  ],
  "automatic_outcome": "Plague runs its course. Settlement loses population and prosperity.",
  "cooldown_days": 60
}
```

#### 4. Succession Crisis
```json
{
  "id": "succession_crisis_event",
  "name": "Noble House Succession in Dispute",
  "type": "conflict",
  "trigger_conditions": {
    "required_faction": "gate_nobility",
    "min_influence_threshold": 70,
    "random_chance": 0.1
  },
  "influence_effects": {
    "gate_nobility": -15,
    "rival_noble_house": 15
  },
  "settlement_effects": {
    "prosperity": -8,
    "unrest": 15,
    "corruption": 10
  },
  "player_options": [
    {
      "id": "support_heir_a",
      "label": "Support the elder heir with force",
      "requirement": "combat_power > 5",
      "outcome": "Elder heir wins. You are paid and favored.",
      "effects": {"gate_nobility": 10, "rival_noble_house": -20}
    },
    {
      "id": "support_heir_b",
      "label": "Back the younger claimant",
      "requirement": "bribe_cost > 100 crowns",
      "outcome": "Younger heir wins. Payment received.",
      "effects": {"gate_nobility": -15, "rival_noble_house": 10, "crowns": -150}
    }
  ],
  "automatic_outcome": "Civil conflict erupts. Both heirs claim authority. Settlement torn.",
  "cooldown_days": 90
}
```

#### 5. Cult Discovery
```json
{
  "id": "cult_discovery_event",
  "name": "Occult Activity Discovered",
  "type": "discovery",
  "trigger_conditions": {
    "required_faction": "lantern_cell",
    "min_influence_threshold": 50,
    "random_chance": 0.12
  },
  "influence_effects": {
    "lantern_cell": 10,
    "occult_covenant": 5,
    "gate_nobility": -8
  },
  "settlement_effects": {
    "prosperity": -5,
    "security": -10,
    "unrest": 12
  },
  "player_options": [
    {
      "id": "purge_cult",
      "label": "Raid the cult gathering",
      "requirement": "combat_power > 4",
      "outcome": "Cultists arrested or killed. Lantern Church pleased.",
      "effects": {"lantern_cell": 15, "occult_covenant": -25, "player_reputation_lantern_church": 10}
    },
    {
      "id": "infiltrate_cult",
      "label": "Infiltrate to learn more",
      "requirement": "wits_check DC 16",
      "outcome": "Learn of larger network. Gain dangerous knowledge.",
      "effects": {"occult_covenant": 5, "player_corruption": 5, "secret_information": "cult_network"}
    }
  ],
  "automatic_outcome": "Cult grows unchecked. Occult presence strengthens.",
  "cooldown_days": 45
}
```

#### 6. Militia Mutiny
```json
{
  "id": "militia_mutiny_event",
  "name": "Militia Refuses Orders",
  "type": "conflict",
  "trigger_conditions": {
    "required_settlement_type": ["town", "city"],
    "unrest > 60": true,
    "random_chance": 0.15
  },
  "influence_effects": {
    "militia_captain": 12,
    "gate_nobility": -15
  },
  "settlement_effects": {
    "security": -20,
    "unrest": 10,
    "corruption": 5
  },
  "player_options": [
    {
      "id": "negotiate_militia",
      "label": "Talk the militia back to duty",
      "requirement": "presence_check DC 14",
      "outcome": "Militia returns. Captain owes you favor.",
      "effects": {"gate_nobility": 5, "militia_captain": 5, "unrest": -10}
    },
    {
      "id": "suppress_mutiny",
      "label": "Help nobility crush the mutiny",
      "requirement": "combat_power > 6",
      "outcome": "Mutiny crushed. Militia resentful.",
      "effects": {"gate_nobility": 15, "militia_captain": -25, "unrest": 15}
    }
  ],
  "automatic_outcome": "Militia takes control of settlement. New power structure forms.",
  "cooldown_days": 60
}
```

#### 7. Refugee Wave
```json
{
  "id": "refugee_wave_event",
  "name": "Refugees Flood the Gates",
  "type": "disaster",
  "trigger_conditions": {
    "random_chance": 0.1,
    "settlement_type": ["town", "city", "caravanserai"]
  },
  "influence_effects": {
    "refugee_bloc": 20,
    "peasant_commons": 5,
    "gate_nobility": -5
  },
  "settlement_effects": {
    "prosperity": -10,
    "unrest": 25,
    "population": 200,
    "food_stock": -30
  },
  "player_options": [
    {
      "id": "accept_refugees",
      "label": "Help integrate the refugees",
      "requirement": "food > 20",
      "outcome": "Refugees settle. New bloc forms. Long-term labor supply.",
      "effects": {"refugee_bloc": 10, "prosperity": 5, "food_stock": -25, "population": 100}
    },
    {
      "id": "close_gates",
      "label": "Turn refugees away at gate",
      "requirement": "gate_nobility_influence > 35",
      "outcome": "Refugees desperate. Some sneak in. Resentment grows.",
      "effects": {"refugee_bloc": -15, "unrest": 10, "player_reputation_refugees": -20}
    }
  ],
  "automatic_outcome": "Refugees overwhelm settlement. Unrest rises, food drops.",
  "cooldown_days": 30
}
```

#### 8. Trade Route Closure
```json
{
  "id": "trade_route_closure_event",
  "name": "Major Trade Route Closed",
  "type": "disaster",
  "trigger_conditions": {
    "random_chance": 0.08,
    "settlement_type": ["town", "city", "caravanserai"],
    "prosperity > 40": true
  },
  "influence_effects": {
    "guild_council": -20,
    "merchant_cartel": -15,
    "gate_nobility": 5
  },
  "settlement_effects": {
    "prosperity": -25,
    "trade_access": -40,
    "unrest": 15
  },
  "player_options": [
    {
      "id": "clear_route",
      "label": "Organize expedition to reopen route",
      "requirement": "contract_clear_route",
      "outcome": "Route reopened. Settlement grateful.",
      "effects": {"prosperity": 15, "trade_access": 30, "guild_council": 10}
    },
    {
      "id": "negotiate_alternative",
      "label": "Find alternative trade partners",
      "requirement": "presence_check DC 18",
      "outcome": "Partial trade restored. More expensive.",
      "effects": {"prosperity": -10, "trade_access": 15}
    }
  ],
  "automatic_outcome": "Trade never fully recovers. Settlement enters decline.",
  "cooldown_days": 90
}
```

#### 9. Corruption Exposure
```json
{
  "id": "corruption_exposure_event",
  "name": "Official Corruption Exposed",
  "type": "reform",
  "trigger_conditions": {
    "corruption > 60": true,
    "random_chance": 0.15
  },
  "influence_effects": {
    "gate_nobility": -20,
    "guild_council": 10,
    "lantern_cell": 8
  },
  "settlement_effects": {
    "corruption": -20,
    "security": 10,
    "unrest": -5,
    "prosperity": 5
  },
  "player_options": [
    {
      "id": "expose_corrupt",
      "label": "Provide evidence to investigators",
      "requirement": "evidence_item",
      "outcome": "Corrupt officials purged. Reformers take power.",
      "effects": {"corruption": -25, "gate_nobility": -15, "player_renown": 10}
    },
    {
      "id": "blackmail_corrupt",
      "label": "Use evidence for leverage",
      "requirement": "presence_check DC 16",
      "outcome": "You gain power over corrupt network.",
      "effects": {"player_crowns": 200, "corruption": 10, "player_corruption": 5}
    }
  ],
  "automatic_outcome": "Scandal buried. Corruption continues.",
  "cooldown_days": 60
}
```

#### 10. Foreign Envoy Arrival
```json
{
  "id": "foreign_envoy_event",
  "name": "Foreign Power Sends Envoy",
  "type": "discovery",
  "trigger_conditions": {
    "random_chance": 0.06,
    "settlement_type": ["city"],
    "prosperity > 50": true
  },
  "influence_effects": {
    "foreign_envoy": 25,
    "gate_nobility": -10,
    "guild_council": 5
  },
  "settlement_effects": {
    "prosperity": 10,
    "corruption": 5,
    "security": 5
  },
  "player_options": [
    {
      "id": "support_envoy",
      "label": "Offer escort and protection services",
      "requirement": "reputation > 10",
      "outcome": "Foreign power pleased. Rewards given.",
      "effects": {"foreign_envoy": 10, "player_renown": 8, "crowns": 300}
    },
    {
      "id": "sabotage_envoy",
      "label": "Disrupt the envoy's mission",
      "requirement": "wits_check DC 18",
      "outcome": "Foreign power angry. Local factions split.",
      "effects": {"foreign_envoy": -30, "gate_nobility": 10, "player_reputation_foreign": -25}
    }
  ],
  "automatic_outcome": "Envoy succeeds. Settlement shifts foreign policy.",
  "cooldown_days": 90
}
```

---

## 4. Faction Influence Change Test Cases

```python
def test_contract_completion_shifts_influence():
    settlement = make_settlement_with_factions()
    guild_before = get_faction(settlement, "guild_council")
    complete_contract({"type": "deliver_goods"}, settlement, "guild_council")
    guild_after = get_faction(settlement, "guild_council")
    assert guild_after["influence"] > guild_before["influence"]

def test_betrayal_causes_influence_drop():
    settlement = make_settlement_with_factions()
    guild_before = get_faction(settlement, "guild_council")
    nobility_before = get_faction(settlement, "gate_nobility")
    betray_faction(settlement, "guild_council", "gate_nobility")
    guild_after = get_faction(settlement, "guild_council")
    assert guild_after["influence"] < guild_before["influence"]

def test_suppressed_faction_recovers():
    settlement = make_settlement_with_factions()
    faction = get_faction(settlement, "criminal_network")
    faction["influence"] = 5
    drift_factions(settlement, days=7)
    # suppressed factions drift toward equilibrium faster
    assert faction["influence"] > 5

def test_dominant_faction_declines():
    settlement = make_settlement_with_factions()
    faction = get_faction(settlement, "gate_nobility")
    faction["influence"] = 75
    drift_factions(settlement, days=7)
    # dominant factions drift away from dominance
    assert faction["influence"] < 75

def test_civil_conflict_triggers():
    settlement = make_settlement_with_factions()
    set_faction(settlement, "gate_nobility", influence=65)
    set_faction(settlement, "guild_council", influence=65)
    trigger_conflict(settlement)
    # should trigger civil conflict event
    assert settlement.get("pending_event") is not None
```

---

## 5. Settlement Policy System

### Purpose
Factions push for settlement policies that change market, security, or social rules.

### Policy Schema

```json
{
  "id": "string",
  "name": "string",
  "effects": {
    "market_modifiers": {"good_id": "float"},
    "settlement_stats": {"stat": "int"},
    "contract_types_available": ["contract_type"]
  },
  "pushed_by": ["faction_id"],
  "opposed_by": ["faction_id"],
  "implementation_cost": "int (crowns)"
}
```

### Example Policies

```json
[
  {
    "id": "raise_tolls",
    "name": "Raise Settlement Tolls",
    "effects": {
      "settlement_stats": {"prosperity": 5, "unrest": 8},
      "contract_types_available": ["patrol"]
    },
    "pushed_by": ["gate_nobility"],
    "opposed_by": ["guild_council", "merchant_cartel"],
    "implementation_cost": 0
  },
  {
    "id": "lower_market_fees",
    "name": "Lower Market Fees",
    "effects": {
      "market_modifiers": {"all": 0.85},
      "settlement_stats": {"prosperity": 8, "security": -3}
    },
    "pushed_by": ["guild_council"],
    "opposed_by": ["gate_nobility"],
    "implementation_cost": 200
  },
  {
    "id": "strict_quarantine",
    "name": "Strict Quarantine Laws",
    "effects": {
      "settlement_stats": {"security": 10, "prosperity": -15, "unrest": 5},
      "contract_types_available": ["deliver_medicine"]
    },
    "pushed_by": ["plague_doctors", "lantern_cell"],
    "opposed_by": ["guild_council", "merchant_cartel"],
    "implementation_cost": 100
  }
]
```

---

## 6. Faction-Based Contract Generation

### Purpose
Settlement internal factions generate contracts based on their needs.

### Contract Generation Rules
```
generate_faction_contract(settlement, faction):
    if faction.influence < 20: return null  # too weak
    if faction.resources < 10: return null  # too poor
    
    base_contract_type = random.choice(faction.preferred_contracts)
    contract = create_contract(base_contract_type)
    contract.patron_faction = faction.faction_id
    contract.reward += faction.resources / 5  # richer factions pay more
    contract.danger += (50 - faction.influence) / 20  # weaker factions need more help
    
    return contract
```

---

## 7. Implementation Task List

1. Create `data/factions/internal_factions.json` with faction definitions
2. Create `data/settlements/policies.json` with policy definitions
3. Extend settlement schema to include full internal_factions array
4. Create `SettlementFactionSystem.gd` with influence change logic
5. Create `SettlementEventSystem.gd` with event trigger logic
6. Create `SettlementPolicySystem.gd` with policy application logic
7. Add faction interaction UI (bribe, intimidate, help, betray)
8. Create contract generation from faction needs
9. Create automated tests for influence changes
10. Create automated tests for event triggers
11. Create automated tests for policy effects

---

## 8. Later Expansion

- Faction quests (multi-step, requiring multiple interactions)
- Faction-specific companion recruitment
- Faction equipment rewards
- Faction war between settlements
- Dynamic faction creation from events
