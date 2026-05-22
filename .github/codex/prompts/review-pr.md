You are reviewing a Road Company pull request.

Read first:

1. `AGENTS.md`
2. `README.md`
3. `docs/AGENT_HANDOFF.md`
4. The PR title, body, changed files, and diff

Review focus:

- Correctness and likely runtime errors.
- Godot 4.x compatibility.
- Whether the PR preserves the prototype loop.
- Whether tests/validators were updated when gameplay data changed.
- Whether generated assets are documented with manifests when relevant.
- Whether the PR is too broad or rewrites unrelated systems.
- Whether UI and visual changes respect visual smoke/baseline rules.

Return a structured review:

## Blocking issues

List only problems that should prevent merge.

## Non-blocking issues

List polish or follow-up suggestions.

## Suggested Codex follow-up prompt

Write a concise `@codex` prompt that can fix the blocking issues.

## Verdict

Use one of:

- APPROVE
- COMMENT
- REQUEST_CHANGES
