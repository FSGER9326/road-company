# Codex: Implement Agent Workflow Tools V1

## Task
Create `tools/agent_status.py`, `tools/agent_finish.py`, and `requirements-dev.txt` for ROAD COMPANY. These tools give every coding agent a consistent start and finish workflow.

## Branch
Create: `feature/agent-workflow-tools-v1` (off main)

## Files to Create

### 1. tools/agent_status.py
Script that prints the agent's current context:

```
=== ROAD COMPANY Agent Status ===
Branch: feature/contract-generator-v1
Commit: e94d1dd contracts: add deterministic contract generator v1
Status: clean

Diff against origin/main:
  A  game/scripts/contracts/ContractGenerator.gd
  A  data/contracts/contract_type_defaults.json
  A  tools/tests/test_contract_generator.py
  ...

Tools:
  run_all_tests.py         FOUND
  run_visual_smoke.py      FOUND
  Godot executable         FOUND at .godot/bin/Godot_v4.6.2-stable_win64.exe

Latest agent report: artifacts/agent_reports/latest.md (tick 42, 50 tests pass)

Recommended validation:
  python tools/run_all_tests.py
```

Use only Python stdlib (`subprocess`, `pathlib`, `os`, `sys`). No external packages.

### 2. tools/agent_finish.py
Script that runs all tests and writes an agent report:

1. Print git status
2. Print diff against main
3. Run `python tools/run_all_tests.py` (subprocess, capture output)
4. Run `python tools/run_visual_smoke.py` if Godot found; else print skip message
5. Create `artifacts/agent_reports/` directory if missing
6. Write `artifacts/agent_reports/latest.md` with: date, branch, commit, files changed, test results, visual result, known limitations
7. Exit 0 if all pass, exit 1 if any fail

### 3. requirements-dev.txt
```
# ROAD COMPANY development dependencies
# Python 3.10+ required.
# No external packages — stdlib only.
# Godot 4.x required for headless and visual smoke tests (optional).
```

### 4. Ensure directories
Create `artifacts/agent_reports/` with `.gitkeep` if not present.

## Tests
- Run `python tools/agent_status.py` — verify it prints all sections without error
- Run `python tools/agent_finish.py` — verify it runs tests and writes report
- Verify `python tools/run_all_tests.py` still passes after adding new files

## Acceptance
- [ ] `tools/agent_status.py` prints branch, commit, diff, tools, recommendations
- [ ] `tools/agent_finish.py` runs tests and writes `artifacts/agent_reports/latest.md`
- [ ] `requirements-dev.txt` exists
- [ ] `python tools/agent_status.py` exits 0
- [ ] `python tools/agent_finish.py` exits 0 (all tests pass)
- [ ] `python tools/run_all_tests.py` exits 0

## After
```
python tools/agent_status.py
python tools/agent_finish.py
python tools/run_all_tests.py
git add tools/ requirements-dev.txt artifacts/
git commit -m "tools: add agent workflow tooling v1"
git push -u origin feature/agent-workflow-tools-v1
```
