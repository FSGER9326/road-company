# Road Layer UI/Playability V1 — Specification

## Purpose
Make the road-layer interface readable and playable. The player should understand where they are, what contracts exist and why, settlement condition, route danger, faction influence, and what changed after each action. No huge UI redesign — just clear information hierarchy using existing procedural drawing.

## Scope
Three small passes for Antigravity (Gemini 3.5 Flash). Builds on existing `RoadScreen.gd`, `RoadMapCanvas.gd`, `ContractBoard.gd`. No new scenes. No new assets. No gameplay system changes.

---

## 1. Road Screen Layout

```
┌──────────────────────────────────────────────────────────┐
│ COMPANY:  Blackford Gate  │  680c  34f  8t  6m  M:58    │
├────────────────────────────────┬─────────────────────────┤
│                                │ SETTLEMENT: Blackford   │
│                                │ Prosperity ████░░ 54    │
│                                │ Security   ███░░░ 48    │
│        ROAD MAP                │ Unrest     █░░░░░ 22    │
│    (settlement circles,        │ Trade Acc  ████░░ 58    │
│     route lines, danger        │ Market Tier 3           │
│     icons)                     │                         │
│                                │ FACTIONS:               │
│                                │ ▸ Gate Nobility 45      │
│                                │   Merchant Guild 38     │
│                                │   Militia 28 · Peasants │
│                                │ Tension: 15             │
│                                │                         │
│                                │ CONTRACTS (2):          │
│                                │ [E] Escort Grain 380c   │
│                                │     Reason: food low    │
│                                │ [H] Hunt Oldwood 520c   │
│                                │     Reason: bandits 54  │
├────────────────────────────────┴─────────────────────────┤
│ RUMORS: "Oldwood bandits growing bolder." · "Grain       │
│ prices climbing in Blackford."                           │
│ LOG: [t42] Food shortage · [t41] Route danger rose      │
├──────────────────────────────────────────────────────────┤
│ [Advance Week]  [Accept Contract]  [Travel Selected Route]│
└──────────────────────────────────────────────────────────┘
```

### Section Responsibilities

| Section | Shows | Source |
|---------|-------|--------|
| Company strip | Location, crowns, food, tools, medicine, morale | `CompanyState` |
| Road map | Settlements, routes, danger, traffic, blocked | `RoadMapCanvas` |
| Settlement panel | Economy stats, faction bars, dominant faction | `settlement_economy.json`, `SettlementFactionSystem` |
| Contract board | Generated + static contracts with reasons | `ContractGenerator` |
| Rumor/memory feed | Active rumors, recent memory entries | `RumorSystem`, `WorldMemorySystem` |
| Action bar | Advance Week, Accept, Travel | `RoadScreen` |

---

## 2. Required Visible Info

### Always Visible (Company Strip)
```
Blackford Gate  |  680c  34f  8t  6m  M:58  V:72  R:15
```
- `c` = crowns, `f` = food, `t` = tools, `m` = medicine, `M` = morale, `V` = vigor, `R` = renown

### Settlement Panel (when settlement selected or current)
| Field | Display | Threshold Colors |
|-------|---------|-----------------|
| Prosperity | Bar + number | <30 red, 30-59 yellow, 60+ green |
| Security | Bar + number | <30 red, 30-59 yellow, 60+ green |
| Unrest | Bar + number | >60 red, 30-59 yellow, <30 green |
| Trade Access | Bar + number | <30 red, 30-59 yellow, 60+ green |
| Market Tier | "Tier 3" | — |
| Population | "Pop 2,400" | — |
| Food Stock | "Grain: 210" | < weekly_need×2 → red marker |
| Medicine Stock | "Med: 26" | < pop/400 → red marker |

### Route Hover/Selection Info
```
Route: Blackford-Embermill Highroad
Danger: ████░░ 34   Traffic: ██████ 62
Bandits: ███░░░ 26   Patrols: ████░░ 42
Trade Flow: ██████ 64   Status: Normal
```
- Danger bar: red-tinged
- Traffic bar: green-tinged
- Blocked routes: red "BLOCKED" badge
- Stabilizing: yellow badge
- Secure: green badge

---

## 3. Contract Board Readability

### Per-Contract Display
```
┌─────────────────────────────────────────┐
│ [E] Escort Grain Convoy to Embermill    │
│     Patron: Millers' Compact            │
│     Route: Highroad (D4 U4)             │
│     Reward: 380c · 14 renown            │
│     ────────────────────────            │
│     Effect: +80 grain to Embermill      │
│     Route: bandits -15, traffic +10     │
│     ────────────────────────            │
│     Why: Embermill food low (190 < 14wk)│
│     Expires: 6 weeks                    │
│     [Accept]                            │
└─────────────────────────────────────────┘
```

### Contract Type Icons
| Type | Icon |
|------|------|
| escort_caravan | [E] |
| patrol_route | [P] |
| hunt_bandits | [H] |
| recover_wagon | [R] |
| deliver_medicine | [M] |
| defend_settlement | [D] |
| bounty_target | [B] |

---

## 4. Route Map Readability

### Line Rules
| Condition | Color | Thickness |
|-----------|-------|-----------|
| danger < 30 | `#4a7a3a` (green) | 3px |
| danger 30-49 | `#8a7a3a` (gold) | 3px |
| danger 50-69 | `#9a5a2a` (orange) | 4px |
| danger 70+ | `#8a3a3a` (red) | 5px |
| blocked | `#5a2a2a` (dark red, dashed) | 2px |
| stabilizing | `#8a8a3a` (yellow-green) | 3px |
| secure | `#3a8a3a` (bright green) | 5px |

### Settlement Size by Market Tier
| Tier | Radius | Example |
|------|--------|---------|
| 1 | 8px | Hamlet |
| 2 | 10px | Village |
| 3 | 14px | Town |
| 4 | 18px | Large Town |
| 5 | 22px | City |

### Danger Icons on Routes
- Display `D{n}` text at route midpoint
- If `icon_danger_{n}` SVG exists in manifest, draw icon instead of text
- If missing, fallback to text

---

## 5. Settlement/Faction Panel

### Compact Display
```
SETTLEMENT: Blackford Gate (Town · Pop 2,400 · Tier 3)
  Prosperity ████░░░░ 54   Security ███░░░░░ 48
  Unrest     █░░░░░░░ 22   Trade    ████░░░░ 58

FACTIONS:
▸ Gate Nobility    ████░░░░ 45  [Neutral]
  Merchant Guild   ███░░░░░ 38  [Friendly]
  Militia          ██░░░░░░ 22  [Neutral]
  Temple           █░░░░░░░ 15  [Neutral]
  Crime Ring       ██░░░░░░ 20  [Hostile · -10]
  Peasant Commons  ██░░░░░░ 25  [Neutral]

Dominant: Gate Nobility · Tension: 15
```

### Bar Drawing (procedural)
- 40px wide, 6px tall
- Background: dark brown (`#3a2a2a`)
- Fill: faction-type-colored
- Text: "45" to right of bar
- Dominant faction: starred prefix "▸"

### Faction Colors
| Type | Color |
|------|-------|
| ruling_authority | `#c4a84a` (gold) |
| merchant_guild | `#8a6a3a` (tan) |
| militia_command | `#3a5a8a` (blue) |
| temple_chapter | `#d4c8a8` (white) |
| criminal_network | `#6a2a2a` (dark red) |
| peasant_commons | `#5c4a2c` (brown) |

---

## 6. Rumor/Memory Feed

### Bottom Strip (2 lines)
```
RUMORS: "Oldwood bandits growing bolder." [U3·uncertain] · "Grain prices climbing in Blackford." [U3·high truth]
LOG: [t42] Food Shortage in Blackford · [t41] Route Oldwood danger rose to 78 · [t35] Escort completed: Embermill
```

### Display Rules
- Max 3 rumors shown in feed (urgency-sorted)
- Max 3 memory entries shown (most recent)
- Urgency 4-5: bright text
- Urgency 1-2: dim text
- Memory entries: dim text with tick prefix

---

## 7. After-Action Summary

After travel/contract/combat resolves, show compact changes:

```
═══ Aftermath ═══
Contract: Escort Grain Convoy — SUCCESS
  Rewards: 380 crowns · 14 renown
  Route: Highroad bandits -15, traffic +10
  Settlement: Embermill grain +80
  Factions: Merchant Guild +5 · Crime Ring -2

═══ Camp ═══
  [Rest]  [Repair]  [Treat Wounds]  [Continue]
─── Roster ───
  Bran Okes  HP64  ·  Mara Vetch  HP52  ·  ...
```

### Change Indicators
- Positive: green `+` prefix
- Negative: red `-` prefix
- No change: dimmed, no prefix

---

## 8. Visual Style Constraints

- 2D only, Godot `gl_compatibility`
- Parchment/dark iron palette: `#2a2a2a` (bg), `#3a342a` (cards), `#8a6a3a` (accents), `#c4a84a` (gold), `#d4c8a8` (text)
- Readable before beautiful — all text ≥ 12px, high contrast
- Use existing placeholder SVG assets from manifest where possible
- Fallback to procedural circles/text when SVG not loaded
- No large binary art, no 3D, no final illustration dependency

---

## 9. Antigravity Implementation Passes

### Pass A: Road UI Debug Readability
**Branch**: `feature/antigravity-road-ui-debug-v1`  
**Model**: Gemini 3.5 Flash High

**Scope**:
- Add company resource strip to road screen
- Improve settlement economy display (bars + numbers + thresholds)
- Add route hover info panel (danger, traffic, bandits, patrols, trade flow, status)
- Improve RoadMapCanvas route line colors by danger
- Add settlement size by market tier

**Files**:
- `game/scripts/road/RoadScreen.gd` — add resource strip, settlement panel, route panel
- `game/scripts/road/RoadMapCanvas.gd` — line colors, settlement sizes

**Acceptance**:
- Resource strip visible with c/f/t/m/M values
- Settlement shows prosperity/security/unrest bars
- Hovering route shows danger/traffic/bandits/patrols
- Route lines vary color by danger level

**Do NOT touch**: ContractBoard, combat, factions, events

---

### Pass B: Contract Board Clarity
**Branch**: `feature/antigravity-contract-board-v1`  
**Model**: Gemini 3.5 Flash High

**Scope**:
- Show contract type icon prefix [E] [H] [P] etc.
- Show patron, route, danger/urgency, reward
- Show expected effects (route + settlement)
- Show "Why this contract exists" reason line
- Separate static contracts from generated with a header

**Files**:
- `game/scripts/ui/ContractBoard.gd` — reformat display

**Acceptance**:
- Contracts show type, patron, route, reward, effects, reason
- Generated contracts have reason line visible
- Static contracts grouped under header

**Do NOT touch**: RoadScreen, combat, factions

---

### Pass C: After-Action Consequence Summary
**Branch**: `feature/antigravity-aftermath-ui-v1`  
**Model**: Gemini 3.5 Flash High

**Scope**:
- After contract/travel: show compact changes grouped by category
- Color-code positive/negative changes
- Add rumor/memory feed at bottom of road screen
- Show faction influence changes
- Improve camp/aftermath screen layout

**Files**:
- `game/scripts/road/RoadScreen.gd` — rumor/memory feed
- `game/scripts/camp/CampScreen.gd` — aftermath layout
- `game/scripts/camp/CampSystem.gd` — result grouping

**Acceptance**:
- Aftermath shows grouped changes with colors
- Rumor/memory feed visible on road screen
- Camp screen clearly separates rewards/casualties/effects

**Do NOT touch**: CombatBoard, economy tick

---

## 10. Testing Protocol

Every pass must:
```
python tools/run_all_tests.py
```
PASS. No regressions.

If Godot available:
```
godot --headless --path . -s res://tools/godot/run_godot_tests.gd
```
PASS.

Visual smoke: click through prototype loop, verify new UI elements visible.

---

## 11. Acceptance Criteria (All Passes)
- Road screen shows: resource strip, settlement economy bars, route info on hover
- Route lines vary by danger color/thickness
- Contract board shows type, reason, effects
- Aftermath groups changes with green/red indicators
- Rumor/memory feed visible
- No new assets required (uses existing SVG placeholders + procedural fallbacks)
- `run_all_tests.py` exits zero after each pass
- Autoplay smoke still reaches aftermath
