# Asset Pipeline and ChatGPT-to-Codex Handoff

Generated and imported assets should move through the repo in a traceable way so Codex can integrate them without guessing.

## Folders

```text
assets/generated/   # raw generated outputs from ChatGPT/image tools or other generators
assets/manifests/   # JSON manifests explaining generated assets
assets/raw/         # manually imported source assets
assets/processed/   # atlases, sliced images, optimized outputs, generated import outputs
```

## Naming

Use stable descriptive names with version suffixes:

```text
assets/generated/ui/inventory_frame_v1.png
assets/generated/icons/supply_crate_v1.png
assets/manifests/inventory_frame_v1.json
```

## Manifest format

```json
{
  "id": "inventory_frame_v1",
  "type": "ui_frame",
  "source": "chatgpt-image-generation",
  "style": "dark fantasy parchment iron caravan RPG",
  "files": {
    "image": "assets/generated/ui/inventory_frame_v1.png"
  },
  "intended_use": "Main inventory panel background and frame.",
  "integration_notes": [
    "Preserve corner ornaments.",
    "Use nine-slice or equivalent scalable panel treatment if practical.",
    "Do not crop the outer metal rim."
  ],
  "status": "ready-for-codex"
}
```

## Integration rules

- Codex should read the manifest before using a generated asset.
- Codex should update any asset registry, preload table, import metadata, or documentation required by the project.
- If an asset cannot be used directly, Codex should explain why in the PR and propose the smallest processing step.
- Do not overwrite generated assets. Add a new version instead.

## Verification

After asset integration, run:

```bash
python tools/run_all_tests.py
python tools/run_visual_smoke.py
python tools/agent_finish.py
```

If Godot is unavailable, report that Godot headless/visual coverage was skipped rather than pretending it passed.

## Suggested labels

- `needs:asset`
- `needs:imagen`
- `codex:implement`
