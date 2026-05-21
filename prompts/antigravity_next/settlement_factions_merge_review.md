# Antigravity Task B: Settlement Factions Merge Review

## Task
Review `feature/settlement-factions-v1` for merge readiness. Run tests, verify scope, check data, decide merge or fix.

## Branch
Review target: `feature/settlement-factions-v1`. Do not create a new branch unless you need to make fixes.

## Model
Use Gemini 3.1 Pro High. This involves code review and test validation.

## Steps

1. `git checkout feature/settlement-factions-v1 && git pull`
2. Run tests:
   ```
   python tools/run_all_tests.py
   ```
3. Run targeted tests:
   ```
   python tools/validate_settlement_factions.py
   python -m unittest tools/tests/test_settlement_factions.py -v
   ```
4. Verify scope — check `git diff main..feature/settlement-factions-v1 --stat`:
   - Only new files: `SettlementFactionSystem.gd`, `settlement_factions.json`, test/validator files
   - Only extended files: `WorldEconomySystem.gd`, `ContractGenerator.gd`, `RoadScreen.gd`
   - No scene file changes, no project.godot changes
5. Run Godot headless if available:
   ```
   godot --headless --path . -s res://tools/godot/run_godot_tests.gd
   ```
6. Verify autoplay smoke reaches aftermath without crash
7. Check contract generator integration:
   - Generated contracts should show faction influence in priority scores
   - Dominant faction should bias contract types offered
8. Check RoadScreen debug panel:
   - Faction names visible with influence bars
   - Dominant faction identified
9. Check data: `data/world/settlement_factions.json` — all factions have valid settlement_ids, valid types (6 allowed)

## Decision

**If all pass**:
```
git checkout main && git pull
git merge --no-ff feature/settlement-factions-v1 -m "world: merge settlement factions v1"
python tools/run_all_tests.py
git push
```

**If any fail**:
- Report exactly what failed
- Do NOT merge
- Create fix branch: `fix/settlement-factions-merge-v1` with the fix
- Submit fix as a PR or push directly to `feature/settlement-factions-v1`

## Report
- Tests passed/failed (list failures with error text)
- Scope review passed/failed (list unexpected files)
- Godot headless passed/failed
- Decision: merged or blocked
- Branch and commit hash of merge or fix
