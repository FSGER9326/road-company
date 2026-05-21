from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


def project_root() -> Path:
    here = Path(__file__).resolve()
    for parent in [here.parent, *here.parents]:
        if (parent / "project.godot").exists():
            return parent
    raise RuntimeError("Could not locate project root containing project.godot")


def run_command(label: str, command: list[str], cwd: Path, fail_patterns: list[str] | None = None) -> tuple[bool, str]:
    print(f"\n== {label} ==")
    print(" ".join(command))
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    proc = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True)
    if proc.stdout:
        print(proc.stdout.rstrip())
    if proc.stderr:
        print(proc.stderr.rstrip())
    combined_output = f"{proc.stdout}\n{proc.stderr}"
    matched_patterns = [pattern for pattern in (fail_patterns or []) if pattern in combined_output]
    if proc.returncode == 0 and not matched_patterns:
        print(f"PASS: {label}")
        return True, ""
    if matched_patterns:
        print(f"FAIL: {label} output contained failure marker(s): {', '.join(matched_patterns)}")
        return False, f"{label} emitted failure marker(s): {', '.join(matched_patterns)}"
    print(f"FAIL: {label} exited {proc.returncode}")
    return False, f"{label} failed with exit code {proc.returncode}"


def discover_godot(root: Path) -> tuple[str | None, str]:
    env_bin = os.environ.get("GODOT_BIN", "").strip()
    if env_bin:
        candidate = Path(env_bin)
        if candidate.exists():
            return str(candidate), "GODOT_BIN"
        resolved = shutil.which(env_bin)
        if resolved:
            return resolved, "GODOT_BIN"
        return None, f"GODOT_BIN is set to '{env_bin}', but it was not found"

    local_candidates = sorted((root / ".godot" / "bin").glob("Godot*.exe")) + sorted((root / ".godot" / "bin").glob("godot*.exe"))
    if os.name != "nt":
        local_candidates.extend(sorted((root / ".godot" / "bin").glob("Godot*")))
        local_candidates.extend(sorted((root / ".godot" / "bin").glob("godot*")))
    for candidate in local_candidates:
        if candidate.is_file():
            return str(candidate), f"local:{candidate.relative_to(root)}"

    candidates = [
        "godot",
        "godot4",
        "godot.exe",
        "godot4.exe",
        "Godot_v4.3-stable_win64.exe",
        "Godot_v4.2-stable_win64.exe",
    ]
    for name in candidates:
        resolved = shutil.which(name)
        if resolved:
            return resolved, f"PATH:{name}"
    return None, "No Godot executable found on PATH. Set GODOT_BIN to the editor/CLI executable."


def main() -> int:
    root = project_root()
    print(f"Project root: {root}")
    failures: list[str] = []
    skipped: list[str] = []

    validators = [
        "tools/validate_factions.py",
        "tools/validate_world.py",
        "tools/validate_contracts.py",
        "tools/validate_company.py",
        "tools/validate_combat.py",
        "tools/validate_data.py",
    ]
    for validator in validators:
        ok, reason = run_command(f"validator {validator}", [sys.executable, validator], root)
        if not ok:
            failures.append(reason)

    ok, reason = run_command(
        "pure gameplay simulation tests",
        [sys.executable, "-m", "unittest", "discover", "-s", "tools/tests", "-p", "test_*.py"],
        root,
    )
    if not ok:
        failures.append(reason)

    godot_bin, godot_reason = discover_godot(root)
    if godot_bin:
        ok, reason = run_command(
            "Godot headless tests",
            [godot_bin, "--headless", "--path", str(root), "-s", "res://tools/godot/run_godot_tests.gd"],
            root,
            fail_patterns=["SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR: Failed to load script"],
        )
        if not ok:
            failures.append(reason)
    else:
        skipped.append(f"Godot headless tests skipped: {godot_reason}")
        print(f"\nSKIP: {skipped[-1]}")

    print("\n== Summary ==")
    if skipped:
        for item in skipped:
            print(f"SKIP: {item}")
    if failures:
        for item in failures:
            print(f"FAIL: {item}")
        print("Result: FAIL")
        return 1
    print("Result: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
