# Task: <short title>

## Goal

Describe the desired outcome in one or two paragraphs.

## Current problem

Explain what is wrong, missing, ugly, confusing, brittle, or incomplete.

## Required changes

- [ ] Change 1
- [ ] Change 2
- [ ] Change 3

## Files or systems to inspect first

- `README.md`
- `AGENTS.md`
- `docs/AGENT_HANDOFF.md`
- Add likely files here.

## Asset requirements

Set one:

- [ ] No new assets required.
- [ ] Use existing assets.
- [ ] Use assets under `assets/generated/`.
- [ ] Needs ChatGPT/image generation first.
- [ ] Needs local worker/tooling first.

If assets are involved, list:

- Asset paths.
- Manifest paths.
- Intended in-game use.
- Import/slicing/compression requirements.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Verification

Run:

```bash
python tools/run_all_tests.py
python tools/run_visual_smoke.py
python tools/agent_finish.py
```

If Godot is unavailable, report that Godot headless/visual coverage was skipped rather than pretending it passed.

## Non-goals

- Do not rewrite unrelated systems.
- Do not remove validation coverage.
- Do not commit secrets or local machine-specific configuration.

## PR response format

The implementation PR should include:

1. Branch name and commit hash.
2. Summary.
3. Changed files/systems.
4. Validation results.
5. Screenshots/assets if relevant.
6. Known limitations or follow-ups.
