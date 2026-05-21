# Art Asset Pipeline

The V1 art pipeline is manifest-first and placeholder-only. It creates deterministic SVG assets that are small, text-based, and replaceable by final PNGs later.

## Files

- `data/art/asset_manifest.json` is the authoritative asset list.
- `tools/generate_placeholder_assets.py` creates SVG placeholders from the manifest.
- `tools/validate_art_assets.py` validates IDs, paths, categories, and required coverage.
- `assets/generated/` contains generated placeholder SVG files.
- `data/schema_drafts/art_asset_manifest_schema_draft.json` documents the intended manifest schema.

## Commands

Generate placeholders:

```powershell
python tools/generate_placeholder_assets.py
```

Validate art assets:

```powershell
python tools/validate_art_assets.py
```

Run all validation and smoke tests:

```powershell
python tools/run_all_tests.py
```

## Current Scope

V1 includes player, enemy, wagon, terrain, settlement, route danger, condition, UI, and faction emblem placeholders. The assets are simple SVGs under `assets/generated/` and are designed to be replaced by final generated or hand-authored art without changing gameplay code.

## Deferred

- Final-quality art.
- Imagen request batches.
- Paper-doll layer compositing.
- Animation.
- Runtime replacement of current procedural combat and road rendering.
- Binary asset packs.
