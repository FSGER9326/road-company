# Antigravity Handoff V1 — Road Company Continuation Roadmap

## Purpose
Practical handoff document for continuing ROAD COMPANY development in Antigravity (Gemini 3.1 Pro High / Gemini 3.5 Flash High) after DeepSeek/Codex quota runs low. Defines current project state, branch map, model usage, task order, and focused prompts.

---

## 1. Current Project State (main branch)

### What's Implemented and Working

| System | Status | Key Files |
|--------|--------|-----------|
| Playable prototype | Working | `game/scenes/main/Main.tscn`, autoplay smoke passes |
| Automated test harness | Working | `tools/run_all_tests.py` — 8 validators, 50+ Python tests, Godot headless |
| World economy tick | Working | `WorldEconomySystem.gd` — weekly production/consumption/unrest/prosperity |
| Route dynamics | Working | `RouteDynamicsSystem.gd` — contract-driven route state changes |
| Placeholder art pipeline | Working | 72 SVG assets, manifest, generator, validator |
| Contract generator V1 | Working | `ContractGenerator.gd` — world-state-driven contract generation |
| Settlement factions | Spec only | Docs/schema on main; runtime implementation on `feature/settlement-factions-v1` |
| Event/rumor/memory | Spec only | Full spec on `spec/deepseek-event-rumor-memory-v1` |
| Combat | Working | Axial hex, AP/fatigue/armor/HP, simple AI |
| Company/camp | Working | Rest, repair, treat wounds, basic roster |

### Test Results (latest main)
- `python tools/run_all_tests.py`: PASS — 8 validators, 50+ simulation tests, Godot 9/9
- Godot: `Godot_v4.6.2-stable` headless — all tests pass
- No regressions since contract generator merge

---

## 2. Branch Map

| Branch | Purpose | Merge Status |
|--------|---------|-------------|
| `main` | Authoritative playable build | Active |
| `feature/settlement-factions-v1` | Runtime faction implementation | **Needs review/merge** — implementation complete, tests pass |
| `feature/art-placeholder-pipeline-v1` | Art pipeline (already merged to main) | Merged |
| `feature/contract-generator-v1` | Contract generator (already merged to main) | Merged |
| `feature/route-dynamics-v1` | Route dynamics (already merged to main) | Merged |
| `feature/world-tick-v1` | Economy tick (already merged to main) | Merged |
| `feature/antigravity-godot-visual-smoke-v1` | Placeholder for visual smoke pass | Exists, empty |
| `spec/deepseek-settlement-factions-v1` | Faction spec (merged to main as docs) | Merged |
| `spec/deepseek-event-rumor-memory-v1` | Event spec (spec only, not merged) | **Ready for implementation** |
| `spec/deepseek-contract-generator-v1` | Contract spec (already merged to main) | Merged |
| `spec/deepseek-route-dynamics-v1` | Route spec (already merged to main) | Merged |
| `design/deepseek-world-systems` | Initial DeepSeek design docs | **DO NOT MERGE** — reference only |
| `design/minimax-content-systems` | MiniMax balance/schema drafts | **DO NOT MERGE** — reference only |
| `integration/deepseek-docs-only` | DeepSeek docs integration (merged to main) | Merged |

---

## 3. Antigravity Model Usage

| Model | Best For | Avoid |
|-------|----------|-------|
| **Gemini 3.1 Pro High** | Godot runtime fixes, system implementation, branch merge review, test-driven changes, GDScript authoring | Trivial UI tweaks, single-line fixes |
| **Gemini 3.5 Flash High** | UI polish, layout fixes, documentation updates, screenshot review, small text/color changes, README updates | Major GDScript refactors, combat system changes |

**Rule**: Never use Flash for code that touches `CombatSystem.gd`, `WorldEconomySystem.gd`, or `ContractGenerator.gd`. Pro High for all gameplay systems.

---

## 4. Immediate Task Order (Recommended)

| # | Task | Model | Branch |
|---|------|-------|--------|
| **A** | Godot visual smoke pass | 3.5 Flash | `feature/antigravity-godot-visual-smoke-v1` |
| **B** | Merge/review settlement factions v1 | 3.1 Pro | `feature/settlement-factions-v1` |
| **C** | UI readability polish | 3.5 Flash | `feature/antigravity-ui-polish-v1` |
| **D** | Event/rumor/memory v1 implementation | 3.1 Pro | `feature/event-rumor-memory-v1` |
| **E** | Combat readability polish | 3.5 Flash | `feature/antigravity-combat-polish-v1` |
| **F** | Save/load snapshot (later) | 3.1 Pro | `feature/save-load-v1` |

**Rationale**: A establishes visual confidence. B adds faction depth safely. C makes the game readable. D adds narrative layer. E-F are polish and persistence.

---

## 5. Visual Smoke Checklist (Task A)

Open Godot, load the project, and verify:

- [ ] Project opens without errors in Godot 4.x
- [ ] Main scene runs (F5 or play button)
- [ ] "New Prototype Run" button works
- [ ] Road map displays with 3 settlements and 7 routes
- [ ] Settlement selection shows economy debug info
- [ ] "Advance Week" button works — settlement stats change
- [ ] Generated contracts appear (static + generated)
- [ ] "Accept Contract" selects a contract
- [ ] Route selection highlights route
- [ ] "Travel" triggers travel — costs deducted, combat may start
- [ ] Combat scene loads — hex grid visible, tokens visible
- [ ] Combat AI moves and attacks
- [ ] Combat ends — victory/defeat determined
- [ ] Aftermath/camp screen appears — Rest/Repair/Treat/Continue visible
- [ ] "Continue" returns to road map
- [ ] No missing resource errors in console
- [ ] Placeholder assets (SVGs) load without errors
- [ ] Faction debug readout visible (if settlement-factions merged)

---

## 6. Settlement Factions Merge Review (Task B)

### Review Checklist

1. **Checkout**: `git checkout feature/settlement-factions-v1`
2. **Tests**: `python tools/run_all_tests.py` — must pass
3. **Scope check**: Verify only these files were changed:
   - `data/world/settlement_factions.json` (new)
   - `game/scripts/world/SettlementFactionSystem.gd` (new)
   - `game/scripts/world/WorldEconomySystem.gd` (extended)
   - `game/scripts/contracts/ContractGenerator.gd` (extended)
   - `game/scripts/road/RoadScreen.gd` (extended)
   - `tools/validate_settlement_factions.py` (new)
   - `tools/tests/test_settlement_factions.py` (new)
4. **Data validation**: `python tools/validate_settlement_factions.py` — passes
5. **Non-regression**: All existing tests pass. Autoplay smoke reaches aftermath.
6. **Contract generator integration**: Generated contracts reflect dominant faction preferences
7. **Debug readability**: RoadScreen faction readout shows influence bars and dominant faction
8. **Decision**: If all pass → merge. If any fail → report issues, do not merge.

### Merge Command (if passing)
```
git checkout main
git pull
git merge --no-ff feature/settlement-factions-v1 -m "world: merge settlement factions v1"
python tools/run_all_tests.py
git push
```

---

## 7. Event/Rumor/Memory Implementation Guardrails (Task D)

### Keep It Small
The DeepSeek spec (`spec/deepseek-event-rumor-memory-v1`) has 15 event templates, a rumor system, and a memory log. For Antigravity, implement the **minimum viable layer**:

**Phase D1 (events only)**:
- Create `data/events/event_templates.json` with 8 events (not 15)
- Skip `rumor_templates.json` initially — events generate rumors from their `rumor_entry` field
- Implement `EventSystem.gd` — trigger evaluation, cooldowns, choice resolution
- Wire into `WorldEconomySystem.weekly_tick()` after settlement/route ticks
- Debug panel: show last 3 fired events and their reasons

**Phase D2 (rumors + memory, if time)**:
- Implement `RumorSystem.gd` — generate from events + economy thresholds
- Implement `WorldMemorySystem.gd` — 200-entry ring buffer
- Wire rumors into RoadScreen debug panel
- Wire memory into contract resolution and combat aftermath

### What NOT to Build
- No procedural prose generation
- No quest chains or multi-stage events
- No event art or illustrations
- No rumor propagation across distant settlements (local only)
- No save/load for memory

---

## 8. UI/Readability Priorities (Task C)

### Top Issues Likely to Matter

| Priority | Screen | Issue | Fix |
|----------|--------|-------|-----|
| 1 | Contract Board | Generated contracts hard to distinguish from static | Add section headers, color coding |
| 2 | Road Map | Route danger not visually obvious | Vary line color/thickness by danger level |
| 3 | Road Map | Settlement economy stats not visible | Show prosperity/security/unrest bars |
| 4 | Combat Board | Tokens are same-size circles, hard to identify | Use larger labels, side-colored borders |
| 5 | Aftermath | Summary is text-heavy, no visual hierarchy | Group by category (rewards, losses, effects) |
| 6 | Faction Debug | Influence bars look same for all factions | Color-code by faction type |
| 7 | Contract Board | "Why this contract exists" text missing | Show `generated_from.world_state_reason` |

### Scope: Keep changes to font sizes, colors, layout spacing. No new scenes. No new assets. No structural refactors.

---

## 9. Testing Protocol

Every Antigravity task MUST run before commit:

```powershell
python tools/run_all_tests.py
```

If Godot available:
```powershell
godot --headless --path . -s res://tools/godot/run_godot_tests.gd
```

For visual tasks (smoke, UI):
- Capture screenshot if tool supports it
- Note: "Visual verification: [what you saw]"

### Commit Rules
- Branch off main: `git checkout main && git pull && git checkout -b feature/...`
- Run tests before commit
- `git add` only intended files
- `git commit -m "system: what changed"`
- `git push -u origin feature/...`
- Report: branch, commit, test results

---

## 10. Final Handoff Summary

| Item | Status |
|------|--------|
| Main build | Stable, all tests pass |
| Next merge | `feature/settlement-factions-v1` — review and merge |
| Next implement | Event/rumor/memory V1 (from DeepSeek spec) |
| Next polish | UI readability pass |
| Godot version | 4.6.2 (confirmed working) |
| Python version | 3.12 (confirmed working) |
| Seed for tests | 12345 |
| Godot bin path | `.godot/bin/Godot_v4.6.2-stable_win64.exe` |
