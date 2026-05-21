# Antigravity Task C: UI Readability Polish

## Task
Improve the readability of Road Company's existing UI without structural refactors. Focus on text visibility, color contrast, layout spacing, and debug information clarity.

## Branch
Create: `feature/antigravity-ui-polish-v1` (off main)

## Model
Use Gemini 3.5 Flash High. This involves small UI tweaks, not system refactors.

## Priorities (in order)

### 1. Contract Board Readability
- Add section header separating "Static Contracts" from "Generated Contracts"
- Color-code contract types (escort=gold, hunt=red, deliver=green, patrol=blue)
- Show `generated_from.world_state_reason` under each generated contract in smaller text
- Ensure contract reward/danger numbers are readable

### 2. Road Map Visuals
- Route line color varies by danger: green(<30), yellow(30-50), orange(50-70), red(70+)
- Route line thickness varies by traffic: thin(<30), medium(30-60), thick(60+)
- Settlement circles show a small prosperity bar (green fill) and unrest bar (red fill)
- Blocked routes shown as dashed red lines

### 3. Settlement Economy Debug
- Group stats logically: Population & Growth, Security & Order, Trade & Prosperity, Stocks
- Show trend arrows: ↑ if stat increased this tick, ↓ if decreased
- Color thresholds: prosperity<30=red, security<30=red, unrest>60=red

### 4. Combat Token Readability
- Larger 2-char labels on tokens (current 13px → 16px minimum)
- Side-colored token borders: blue stroke for player, red for enemy, gold for objective
- Wounded tokens (HP < 30%): slight red tint on token circle
- Show active unit highlight more prominently (brighter gold circle)

### 5. Aftermath Summary
- Group results by category: "Rewards", "Casualties", "Route Effects", "Faction Changes"
- Bold important numbers (crowns earned, fighters lost)
- Color-code positive/negative changes (green=good, red=bad)

### 6. Faction Debug (if settlement factions merged)
- Color-code faction types: nobility=gold, merchant=tan, militia=blue, temple=white, criminal=dark red, peasant=brown
- Show dominant faction with a star or bold marker
- Show faction attitude with +/- prefix and color (green=positive, red=negative)

## Rules
- Do NOT create new scenes or new Godot nodes
- Do NOT restructure existing GDScript logic
- Do NOT add new asset dependencies
- Changes should be: font sizes, colors, draw positions, text formatting
- If a change requires more than 5 lines of new GDScript, flag it as "deferred"

## Testing
```
python tools/run_all_tests.py
```
Must pass. Visual smoke must still reach aftermath.

## After
```
git add [files]
git commit -m "ui: readability polish v1"
git push -u origin feature/antigravity-ui-polish-v1
```

Report which items were completed and which were deferred with reasons.
