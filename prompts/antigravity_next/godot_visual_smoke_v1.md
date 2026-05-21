# Antigravity Task A: Godot Visual Smoke Pass

## Task
Open the Road Company project in Godot 4.x and verify the full prototype loop works visually. Document what you see. Take screenshots if supported. Report any visual bugs.

## Branch
Create: `feature/antigravity-godot-visual-smoke-v1` (off main)

## Model
Use Gemini 3.5 Flash High for this task. It's purely visual verification.

## Steps

1. `git checkout main && git pull && git checkout -b feature/antigravity-godot-visual-smoke-v1`
2. Open Godot 4.x, import/open the project folder
3. Run the project (F5)
4. Walk through the full prototype loop:
   - Main menu appears → click "New Prototype Run"
   - Road map appears with settlements and routes
   - Select a settlement → see economy debug info
   - Click "Advance Week" 2-3 times → verify numbers change
   - View contract board → see static + generated contracts
   - Accept a contract
   - Select route matching the contract → click "Travel"
   - If combat triggers: verify hex grid, tokens, AI moves
   - Fight to conclusion → aftermath/camp screen appears
   - Click Rest/Repair/Treat → verify resources change
   - Click Continue → return to road map
5. Check console for errors (red text, missing resources, script errors)
6. Verify placeholder SVG assets load (no "missing resource" errors)
7. If faction debug panel visible: note influence bars and dominant faction

## What to Report
- [ ] Each step passed or failed
- [ ] Visual description: "Road map shows 3 circles connected by colored lines"
- [ ] Any console errors (copy exact text)
- [ ] Screenshot if tool supports image capture
- [ ] Known visual issues (misaligned text, unreadable colors, missing labels)

## After
```
python tools/run_all_tests.py
```
Report test results. Do NOT commit code changes unless you fixed a visual bug.

Push if changes made:
```
git add [files]
git commit -m "visual: smoke pass documentation"
git push -u origin feature/antigravity-godot-visual-smoke-v1
```
