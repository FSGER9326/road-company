You are Codex implementing a GitHub issue for Road Company.

Read first:

1. `AGENTS.md`
2. `README.md`
3. `docs/AGENT_HANDOFF.md`
4. `docs/CODEX_ORCHESTRATION.md`
5. The issue body and comments

Work rules:

- Follow all existing rules in `AGENTS.md`.
- Make the smallest coherent implementation that satisfies the issue.
- Do not rewrite unrelated systems.
- Preserve the prototype loop and validation harness.
- Prefer deterministic data and small focused code changes.
- Use generated assets only when the issue or manifest explicitly asks for them.
- Never commit secrets, local user paths, or machine-specific config.

Verification:

```bash
python tools/run_all_tests.py
python tools/run_visual_smoke.py
python tools/agent_finish.py
```

If Godot is unavailable, report skipped Godot/visual coverage clearly.

PR body must include:

1. Branch name and commit hash.
2. Summary.
3. Changed files/systems.
4. Validation commands and results.
5. Screenshots or asset notes if relevant.
6. Known limitations/follow-ups.

If blocked, open a PR or issue comment explaining exactly what is missing. Do not silently stop.
