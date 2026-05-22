# Codex PR-context test for issue #4

This branch exists only to provide a pull-request context for Codex Web / GitHub `@codex` delegation.

## Task

Implement issue #4 with a tiny documentation-only change:

- Add a concise note to `README.md` that this repo supports issue-driven Codex / ChatGPT orchestration.
- Reference `docs/CODEX_ORCHESTRATION.md`.
- Do not change gameplay, Godot scenes, data files, validators, workflows, or visual baselines.
- Run `python tools/run_all_tests.py` if available and report results.
- If Godot is unavailable, report skipped Godot/visual coverage clearly.

## Cleanup

After implementing the README change, remove this temporary task file from the branch so the final PR only contains the intended README change.
