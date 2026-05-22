# Antigravity: Verify Agent Workflow Tools V1

## Task
Verify (or implement if not yet done) the agent workflow tools: `agent_status.py`, `agent_finish.py`, and `requirements-dev.txt`. These are infrastructure — every future agent session starts and ends with them.

## Branch
If implementing: create `feature/agent-workflow-tools-v1` (off main)
If verifying: checkout the existing branch

## Model
Gemini 3.1 Pro High (this involves Python script verification)

## Steps

### If not yet implemented:
1. Create `tools/agent_status.py` — prints branch, commit, diff against main, available tools, recommended commands. Uses only stdlib.
2. Create `tools/agent_finish.py` — runs `run_all_tests.py`, runs `run_visual_smoke.py` if Godot found, writes `artifacts/agent_reports/latest.md`. Exits 1 if tests fail.
3. Create `requirements-dev.txt` — minimal, stdlib only note.
4. Create `artifacts/agent_reports/` directory with `.gitkeep`.

### If already implemented:
1. `python tools/agent_status.py` — verify output has all required sections
2. `python tools/agent_finish.py` — verify it runs tests and writes report
3. Read `artifacts/agent_reports/latest.md` — verify format
4. Run `python tools/run_all_tests.py` — verify passes

### Visual Smoke Awareness
When `agent_finish.py` runs visual smoke:
- If Godot available: run visual smoke, capture result
- If Godot missing: print "SKIP: Godot not available — visual smoke skipped"
- Do NOT fail if visual smoke is skipped due to missing Godot

## Acceptance
- [ ] `agent_status.py` works and prints all sections
- [ ] `agent_finish.py` works and writes report
- [ ] `run_all_tests.py` passes

## After
```
git add tools/ requirements-dev.txt artifacts/
git commit -m "tools: add agent workflow tooling v1"
git push -u origin feature/agent-workflow-tools-v1
```

Report: branch, commit, agent_status output summary, test results.
