from __future__ import annotations

import sys
from pathlib import Path

from save_load_core import build_snapshot, load_snapshot_file, validate_snapshot


def validate(path: Path | None = None) -> list[str]:
    if path is not None:
        _, errors = load_snapshot_file(path)
        return errors
    sample = build_snapshot(
        game_day=0,
        current_location="blackford",
        company={
            "company_name": "Ash Road Company",
            "current_location": "blackford",
            "resources": {},
            "roster": [],
            "graveyard": [],
            "faction_reputation": {},
            "active_contract": {},
        },
        rng_seed=12345,
        saved_at_unix_time=0,
    )
    return validate_snapshot(sample)


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    errors = validate(path)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Save snapshot validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
