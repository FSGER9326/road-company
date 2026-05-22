# ROAD COMPANY — Agent Operating Rules

You are working in **FSGER9326/road-company**, a Godot 4.x 2D dark fantasy mercenary caravan-company RPG.

## 1. Branch Rules

- **Never work directly on `main`.**
- Create a feature or fix branch off `main`: `feature/<system>-v<N>` or `fix/<description>`
- Spec branches use `spec/<system>-v<N>` and are docs-only
- Antigravity task branches use `feature/antigravity-<task>-v<N>`

## 2. Required Startup Command

Once implemented, run at the start of every session:
```powershell
python tools/agent_status.py
```
This prints your current branch, dirty state, diff against main, available tools, and recommended validation commands.

## 3. Required Tests Before Commit

```powershell
python tools/run_all_tests.py
```
Must exit zero. If Godot is available, this includes headless tests automatically.

## 4. Visual/UI Tests

If you changed any UI, combat, or road rendering:
```powershell
python tools/run_visual_smoke.py
```
Must exit zero. **Do not update visual baselines unless explicitly instructed.**

## 5. Required Finish Command

Before committing:
```powershell
python tools/agent_finish.py
```
This runs all validators, all tests, and writes an agent report.

## 6. Merge Restrictions

- **Do not merge `design/deepseek-world-systems`** — reference only
- **Do not merge `design/minimax-content-systems`** — reference only
- **Do not merge `review/qwen-*` branches** — review only
- **Do not merge any `spec/*` branch directly** — specs are docs-only and merge separately with explicit review

## 7. Scope Rules

- Keep each feature branch under 10 changed files
- Do not refactor unrelated systems in the same branch
- Do not change visual baselines unless the task explicitly says to
- Do not add new dependencies without updating `requirements-dev.txt`

## 8. Visual Screenshot Rules

If your tool supports image output:
- Capture before/after screenshots for UI changes
- Compare screenshots against `artifacts/screenshots/baselines/`
- Report diffs if automated comparison fails
- Do not overwrite baselines unless asked

## 9. Final Response Requirements

Every agent response must include:
- Branch name
- Commit hash (or "uncommitted")
- Files changed (list or count)
- Tests run and result (pass/fail/skipped)
- Visual smoke result (pass/fail/skipped, with reason if skipped)
- Godot headless result (pass/fail/skipped, with reason if skipped)
- Known limitations or residual risk

## 10. Godot Missing Handling

If Godot is not found locally:
- `run_all_tests.py` still runs Python validators and simulation tests
- `run_visual_smoke.py` skips gracefully with a clear message
- Report "Godot not available" — do NOT fail the task for missing Godot
- Python-only test results are still valid for data, math, and rule changes
