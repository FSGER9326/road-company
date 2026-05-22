# Agent Workflow — ROAD COMPANY

## Purpose
Define the standard operating procedure for coding agents (Codex, Antigravity, DeepSeek) working on ROAD COMPANY. Every agent follows the same start → work → test → finish loop so branches stay clean, tests stay green, and handoffs are complete.

---

## 1. Agent Roles

| Agent | Best For | Restrictions |
|-------|----------|-------------|
| **Codex** | GDScript systems, JSON data, Python validators, deterministic tests | No visual assets, no UI polish |
| **Antigravity (Gemini 3.1 Pro)** | Merge reviews, careful GDScript implementation, system fixes | No visual smoke (no image output) |
| **Antigravity (Gemini 3.5 Flash)** | UI polish, text layout, color fixes, documentation | No gameplay system changes |
| **DeepSeek** | Design docs, schemas, implementation roadmaps, spec writing | No runtime code, no merging |

---

## 2. Starting Work

1. `git checkout main && git pull`
2. Decide what type of branch to create:
   - Feature implementation: `feature/<system>-v<N>`
   - Bug fix: `fix/<description>`
   - Antigravity task: `feature/antigravity-<task>-v<N>`
   - Spec/docs only: `spec/<system>-v<N>`
3. `git checkout -b <branch-name>`
4. Run startup status (once implemented):
   ```powershell
   python tools/agent_status.py
   ```
5. Read `AGENTS.md` and `docs/AGENT_HANDOFF.md` for current context

---

## 3. Task Scope

- **Maximum 10 changed files per branch**
- One system per branch (economy, or contracts, or combat, not all three)
- Spec branches: docs/schema only, zero runtime files
- Do not refactor unrelated code
- Do not change visual baselines unless asked

---

## 4. Running Tests

### Every Commit
```powershell
python tools/run_all_tests.py
```
This runs: 8+ validators, 50+ simulation tests, Godot headless (if available).

### For UI/Rendering Changes
```powershell
python tools/run_visual_smoke.py
```
This captures screenshots, compares against baselines, and reports diffs.

### For Specific Systems
```powershell
python tools/validate_<system>.py                    # single validator
python -m unittest tools/tests/test_<system>.py -v   # single test file
```

---

## 5. Visual Baselines

- Baselines live in `artifacts/screenshots/baselines/`
- Visual smoke captures to `artifacts/screenshots/latest/`
- Comparison diffs go to `artifacts/screenshots/diffs/`
- **Do not overwrite baselines unless explicitly instructed**
- If `run_visual_smoke.py` fails: report the diff, do NOT auto-fix

---

## 6. Screenshot Reports

If your agent supports image output:
- Capture a screenshot before and after each UI change
- Describe what changed visually in text
- If comparison tools exist, run `python tools/compare_visual_screens.py`

If your agent does NOT support image output:
- Describe the visual change in text (e.g. "Route lines are now color-coded: green below danger 30, red above 70")
- Note "visual verification deferred — agent has no image output"

---

## 7. Finishing Work

1. Run the finish script (once implemented):
   ```powershell
   python tools/agent_finish.py
   ```
   This runs all validators, all tests, visual smoke, and writes `artifacts/agent_reports/latest.md`.

2. Manual verification checklist:
   - [ ] `python tools/run_all_tests.py` passes
   - [ ] No unintended files in `git diff --name-status origin/main..HEAD`
   - [ ] Branch has 1-10 changed files
   - [ ] No modified visual baselines (unless task required it)

3. Commit:
   ```powershell
   git add <intended files>
   git commit -m "<system>: <what changed>"
   git push -u origin <branch>
   ```

4. Report final response per `AGENTS.md` section 9.

---

## 8. Godot Missing Handling

If Godot is not found:
- `run_all_tests.py` still passes and reports all Python-side tests
- Godot headless line shows "SKIP: Godot not found"
- This is acceptable — the Python tests cover data, math, and rule logic
- Do NOT fail the task
- Do NOT try to install Godot

---

## 9. Scope Drift Prevention

- Before adding a function to an existing file: ask "does this belong in its own system script?"
- Before changing a data file: ask "does this field already exist somewhere else?"
- Before adding a new JSON file: ask "is this covered by an existing schema?"
- If you touch 6+ files and the task didn't ask for it: stop and re-scope

---

## 10. Merge Tasks

When asked to merge a branch:
1. `git checkout <branch> && git pull`
2. `python tools/run_all_tests.py` — must pass
3. `git diff main..<branch> --stat` — verify scope
4. `git checkout main && git pull`
5. `git merge --no-ff <branch> -m "<system>: merge <description>"`
6. `python tools/run_all_tests.py` — must pass on main
7. `git push`
8. Report merge commit and test results

Do NOT merge if:
- Tests fail on the feature branch
- Diff includes unexpected files (scenes, project.godot, unrelated systems)
- Visual baselines were modified without instruction
- The branch touches 15+ files without a documented reason

---

## 11. Future Tools (to be implemented by Codex/Antigravity)

### tools/agent_status.py
```powershell
python tools/agent_status.py
```
**Expected behavior**:
- Print current branch name
- Print latest commit hash and message
- Print working tree status (clean/dirty, list modified files)
- Print `git diff --name-status origin/main..HEAD` (files different from main)
- Detect `GODOT_BIN` environment variable
- Detect local Godot executable path (if any)
- Confirm `tools/run_all_tests.py` exists
- Confirm `tools/run_visual_smoke.py` exists (if applicable)
- Check if latest visual report exists at `artifacts/agent_reports/latest.md` and summarize
- Recommend next validation commands based on dirty files

**Exit code**: 0 on success, 0 even with dirty tree (just reports state).

### tools/agent_finish.py
```powershell
python tools/agent_finish.py
```
**Expected behavior**:
1. Print `=== Git Status ===`
2. Run `git status --short`
3. Print `=== Diff Against Main ===`
4. Run `git diff --name-status origin/main..HEAD`
5. Print `=== Running All Tests ===`
6. Run `python tools/run_all_tests.py` — capture output
7. Print `=== Visual Smoke ===`
8. If Godot found: run `python tools/run_visual_smoke.py`
9. If Godot not found: print "SKIP: Godot not available"
10. Print `=== Writing Report ===`
11. Write `artifacts/agent_reports/latest.md` with:
    - Agent name, date, branch, commit
    - Files changed list
    - Test results (pass/fail/skipped)
    - Visual smoke result
    - Known limitations
12. Print summary to console

**Exit code**: 0 if all tests pass, 1 if any test fails.

### requirements-dev.txt
```
# ROAD COMPANY development dependencies
# Python 3.10+
# No external packages required for core tooling.
# Godot 4.x required for headless tests (optional for data/sim tests).
```
Currently minimal — the project uses only Python stdlib. Add packages if future tools need them.

---

## 12. Choosing the Right Agent for a Task

| Task Type | Use |
|-----------|-----|
| New GDScript system implementation | Codex or Antigravity 3.1 Pro |
| JSON data creation/extension | Codex |
| Python validator/test writing | Codex |
| Merge review (test + scope check) | Antigravity 3.1 Pro |
| UI text/color/layout polish | Antigravity 3.5 Flash |
| Documentation update | Antigravity 3.5 Flash or DeepSeek |
| Spec/schema writing | DeepSeek |
| Visual smoke pass | Antigravity 3.5 Flash (if supports screenshots) |
| Balancing, formula tuning | Codex (with Python sim tests) |
