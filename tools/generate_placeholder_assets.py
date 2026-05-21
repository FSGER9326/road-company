from __future__ import annotations

import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "data/art/asset_manifest.json"
PALETTE = {
    "fighter": "#3a4a6a",
    "bandit": "#6a2a2a",
    "undead": "#4a4a4a",
    "beast": "#5c4a2c",
    "cultist": "#4a2a5c",
    "objective": "#c4a84a",
    "terrain": "#2c3a24",
    "route": "#8a6a3a",
    "condition": "#6a2a2a",
    "ui": "#4a3a2a",
    "emblem": "#2a2a2a",
}


def res_to_path(res_path: str) -> Path:
    if not res_path.startswith("res://"):
        raise ValueError(f"Not a res:// path: {res_path}")
    return ROOT / res_path.removeprefix("res://")


def label_for(asset_id: str) -> str:
    if asset_id.startswith("icon_danger_"):
        return asset_id.rsplit("_", 1)[-1]
    parts = asset_id.split("_")
    if len(parts) >= 2:
        return "".join(part[0] for part in parts[-2:]).upper()[:2]
    return asset_id[:2].upper()


def color_for(asset: dict) -> str:
    asset_id = asset["asset_id"]
    subcategory = asset.get("subcategory") or asset.get("category")
    if "bandit" in asset_id or "bounty" in asset_id:
        return PALETTE["bandit"]
    if "undead" in asset_id:
        return PALETTE["undead"]
    if "beast" in asset_id:
        return PALETTE["beast"]
    if "cultist" in asset_id:
        return PALETTE["cultist"]
    return PALETTE.get(subcategory, PALETTE.get(asset.get("category"), "#4a4a4a"))


def svg_shell(size: int, body: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" '
        f'width="{size}" height="{size}">{body}</svg>\n'
    )


def text(label: str, x: int, y: int, size: int, fill: str = "#f3ead2") -> str:
    return (
        f'<text x="{x}" y="{y}" text-anchor="middle" font-family="serif" '
        f'font-size="{size}" font-weight="700" fill="{fill}">{html.escape(label)}</text>'
    )


def generate_token_svg(asset: dict) -> str:
    size = int(asset["size_px"])
    color = color_for(asset)
    label = label_for(asset["asset_id"])
    body = [
        f'<circle cx="{size/2}" cy="{size/2}" r="{size*0.43:.1f}" fill="#12120f" stroke="#8a6a3a" stroke-width="3"/>',
        f'<circle cx="{size/2}" cy="{size/2}" r="{size*0.31:.1f}" fill="{color}" stroke="#c4a84a" stroke-width="1"/>',
        text(label, size // 2, int(size * 0.57), max(12, size // 4)),
    ]
    if "wagon" in asset["asset_id"]:
        body.insert(1, f'<rect x="{size*0.24:.1f}" y="{size*0.33:.1f}" width="{size*0.52:.1f}" height="{size*0.26:.1f}" rx="3" fill="#8a6a3a"/>')
        body.append(f'<circle cx="{size*0.32:.1f}" cy="{size*0.66:.1f}" r="{size*0.08:.1f}" fill="#2a2a2a"/>')
        body.append(f'<circle cx="{size*0.68:.1f}" cy="{size*0.66:.1f}" r="{size*0.08:.1f}" fill="#2a2a2a"/>')
    return svg_shell(size, "".join(body))


def generate_tile_svg(asset: dict) -> str:
    size = int(asset["size_px"])
    asset_id = asset["asset_id"]
    colors = {
        "tile_grass": "#2c3a24",
        "tile_road": "#5c4a2c",
        "tile_mud": "#4a3a2a",
        "tile_forest": "#24351f",
        "tile_ruins": "#4a4a4a",
        "tile_water": "#3a4a6a",
        "tile_stone": "#56504a",
    }
    color = colors.get(asset_id, "#2c3a24")
    label = label_for(asset_id)
    points = f"{size/2},4 {size-6},{size*0.28:.1f} {size-6},{size*0.72:.1f} {size/2},{size-4} 6,{size*0.72:.1f} 6,{size*0.28:.1f}"
    body = [
        f'<polygon points="{points}" fill="{color}" stroke="#8a6a3a" stroke-width="2"/>',
        f'<path d="M{size*0.25:.1f} {size*0.40:.1f} C{size*0.38:.1f} {size*0.32:.1f}, {size*0.58:.1f} {size*0.48:.1f}, {size*0.75:.1f} {size*0.38:.1f}" fill="none" stroke="#c4a84a" stroke-width="2" opacity="0.5"/>',
        text(label, size // 2, int(size * 0.62), max(10, size // 5)),
    ]
    return svg_shell(size, "".join(body))


def generate_icon_svg(asset: dict) -> str:
    size = int(asset["size_px"])
    color = color_for(asset)
    label = label_for(asset["asset_id"])
    body = [
        f'<rect x="2" y="2" width="{size-4}" height="{size-4}" rx="4" fill="#171511" stroke="#8a6a3a" stroke-width="1"/>',
        f'<path d="M{size/2} 5 L{size-5} {size/2} L{size/2} {size-5} L5 {size/2} Z" fill="{color}" opacity="0.9"/>',
        text(label, size // 2, int(size * 0.61), max(8, size // 3)),
    ]
    return svg_shell(size, "".join(body))


def generate_ui_svg(asset: dict) -> str:
    size = int(asset["size_px"])
    color = "#4a3a2a" if "button" not in asset["asset_id"] else "#5c4a2c"
    body = [
        f'<rect x="2" y="2" width="{size-4}" height="{size-4}" rx="6" fill="{color}" stroke="#8a6a3a" stroke-width="2"/>',
        f'<path d="M8 14 H{size-8} M8 {size-14} H{size-8}" stroke="#c4a84a" stroke-width="1" opacity="0.35"/>',
    ]
    return svg_shell(size, "".join(body))


def generate_svg(asset: dict) -> str:
    category = asset["category"]
    if category == "token":
        return generate_token_svg(asset)
    if category == "tile":
        return generate_tile_svg(asset)
    if category == "ui":
        return generate_ui_svg(asset)
    return generate_icon_svg(asset)


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    generated = 0
    skipped = 0
    for asset in manifest.get("assets", []):
        if asset.get("generated_by") != "svg":
            skipped += 1
            continue
        path = asset.get("path")
        if not path:
            skipped += 1
            continue
        out_path = res_to_path(path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(generate_svg(asset), encoding="utf-8")
        generated += 1
    print(f"Generated {generated} SVG files, skipped {skipped} non-SVG entries.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
