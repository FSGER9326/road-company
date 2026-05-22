You are Codex repairing a failing Road Company CI run.

Read first:

1. `AGENTS.md`
2. `README.md`
3. `docs/AGENT_HANDOFF.md`
4. The failing workflow logs
5. The recent diff or PR that caused the failure

Rules:

- Fix the actual failure, not just the symptom.
- Do not remove or weaken tests to make CI pass.
- Do not rewrite unrelated systems.
- Keep changes small and reviewable.
- If the failure depends on missing Godot binaries in CI, improve graceful skipping/reporting rather than pretending the test passed.

Run verification:

```bash
python tools/run_all_tests.py
python tools/run_visual_smoke.py
python tools/agent_finish.py
```

Return:

1. Root cause.
2. Fix summary.
3. Validation commands/results.
4. Remaining risks.
