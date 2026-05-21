# Antigravity Pass A: Road UI Debug Readability

## Task
Improve the road screen so the player can see: company resources, settlement economy with bars, route danger/traffic on hover, danger-colored route lines, and settlement sizes by market tier. No new scenes, no new assets, no gameplay changes.

## Branch
Create: `feature/antigravity-road-ui-debug-v1` (off main)

## Model
Gemini 3.5 Flash High

## Prerequisites
Read: `docs/road_ui_playability_v1_spec.md`, `game/scripts/road/RoadScreen.gd`, `game/scripts/road/RoadMapCanvas.gd`

## What to Implement

### 1. Company Resource Strip
At top of road screen, add a one-line strip:
```
Blackford Gate  |  680c  34f  8t  6m  M:58
```
Draw as a single `draw_string()` call. Read from `company.crowns, company.food, company.tools, company.medicine, company.morale`.

### 2. Settlement Economy Bars
When a settlement is selected/current, show in a panel:
```
Prosperity ████░░░░ 54
Security   ███░░░░░ 48
Unrest     █░░░░░░░ 22
Trade Acc  ████░░░░ 58
Market Tier 3 · Pop 2,400 · Grain: 210
```
- Bars: 40px wide, 6px tall, dark bg, green fill (red if <30)
- Unrest bar: red if >60
- Draw with `draw_rect()` in `RoadScreen._draw()`

### 3. Route Hover Info Panel
When a route is selected, show:
```
Route: Blackford-Embermill Highroad
Danger: ████░░ 34   Traffic: ██████ 62
Bandits: ███░░░ 26   Patrols: ████░░ 42
Trade Flow: ██████ 64   Status: Normal
```
- Read from `route_economy.json` for selected route
- Status: Normal / Stabilizing / Secure / Blocked
- Draw in RoadScreen, triggered by existing `selected_route_id` signal

### 4. Route Line Colors by Danger
In `RoadMapCanvas._draw()`:
- danger < 30: green (#4a7a3a), 3px
- danger 30-49: gold (#8a7a3a), 3px
- danger 50-69: orange (#9a5a2a), 4px
- danger 70+: red (#8a3a3a), 5px
- blocked: dark red dashed (#5a2a2a), 2px
- Use `draw_dashed_line()` for blocked routes (or just draw_line with a different color)
- Read `effective_danger` from route economy data

### 5. Settlement Size by Market Tier
In `RoadMapCanvas._draw()`:
- Market tier 1: radius 8px
- Market tier 2: radius 10px
- Market tier 3: radius 14px
- Market tier 4: radius 18px
- Market tier 5: radius 22px
- Current location: radius + 4px extra, gold color

## What NOT to Touch
- Do not modify `ContractBoard.gd`
- Do not modify `CombatSystem.gd` or `CombatBoard.gd`
- Do not modify `CampSystem.gd` or `CampScreen.gd`
- Do not create new scenes
- Do not add new assets
- Do not change any gameplay formulas

## Acceptance
- [ ] Resource strip visible at top with c/f/t/m/M
- [ ] Settlement panel shows 4 bars with numbers
- [ ] Route hover shows danger/traffic/bandits/patrols
- [ ] Route lines color-coded by danger
- [ ] Settlements sized by market tier
- [ ] `python tools/run_all_tests.py` PASS
- [ ] Visual smoke: road map displays correctly, bars visible, route hover works

## After
```
python tools/run_all_tests.py
git add game/scripts/road/
git commit -m "ui: road layer debug readability v1"
git push -u origin feature/antigravity-road-ui-debug-v1
```

Report: branch, commit, test results, visual description.
