# Art Pipeline

ROAD COMPANY uses an AI-friendly 2D modular art approach. The prototype avoids imported binary assets and renders readable placeholder shapes directly in Godot.

## Tactical Units

Tactical units should use a layered paper-doll or token approach:

- body
- head
- helmet
- armor
- weapon
- shield
- wounds
- status overlays

Each layer should be a small reusable 2D image with limited palettes and transparent backgrounds. Tokens should remain readable at low resolution.

## Event Art

Future road and contract events can use dark fantasy parchment illustrations. Event images should be optional data references, not required for core simulation.

## Terrain

Terrain should use reusable 2D tiles and overlays. Forest, mud, road, hill, reeds, stones, and cart wrecks can be built from small modular tile sets.

## Avoid

- 3D models or a 3D pipeline.
- Full animation rigs.
- Complex isometric walk cycles.
- Large binary asset dumps.
- Copyrighted assets, copied layouts, or recognizable names from other games.
