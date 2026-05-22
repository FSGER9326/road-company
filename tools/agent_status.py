from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path


def project_root() -> Path:
    here = Path(__file__).resolve()
    for parent in [here.parent, *here.parents]:
        if (parent / "project.godot").exists():
            return parent
    return Path.cwd()


def run_command(command: list[str], cwd: Path) -> tuple[int, str, str]:
    try:
        proc = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    except OSError as exc:
        return 127, "", str(exc)
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()


def git_output(root: Path, args: list[str]) -> tuple[bool, str]:
    code, stdout, stderr = run_command(["git", *args], root)
    return code == 0, stdout if code == 0 else stderr


def diff_base(root: Path) -> str | None:
    for ref in ["origin/main", "main"]:
        ok, _ = git_output(root, ["rev-parse", "--verify", ref])
        if ok:
            return ref
    return None


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

    for name in ["godot", "godot4", "godot.exe", "godot4.exe", "Godot_v4.6.2-stable_win64.exe"]:
        resolved = shutil.which(name)
        if resolved:
            return resolved, f"PATH:{name}"
    return None, "No Godot executable found"


def latest_visual_summary(root: Path) -> str:
    report_path = root / "tests" / "visual" / "runs" / "latest" / "report.json"
    if not report_path.exists():
        return f"not found ({report_path.relative_to(root)})"
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
        summary = report.get("summary", {})
    except (OSError, json.JSONDecodeError) as exc:
        return f"unreadable ({exc})"
    total = int(summary.get("total", 0))
    passed = int(summary.get("passed", 0))
    failed = int(summary.get("failed", 0))
    accepted = int(summary.get("accepted", 0))
    return f"{passed}/{total} passed, {failed} failed, {accepted} accepted ({report_path.relative_to(root)})"


def changed_paths(root: Path, base: str | None, status_lines: list[str]) -> list[str]:
    paths: list[str] = []
    if base is not None:
        ok, diff = git_output(root, ["diff", "--name-only", f"{base}..HEAD"])
        if ok:
            paths.extend(line.strip() for line in diff.splitlines() if line.strip())
    for line in status_lines:
        if len(line) > 3:
            paths.append(line[3:].strip())
    return sorted(set(paths))


def should_run_visual(paths: list[str]) -> bool:
    visual_prefixes = (
        "assets/",
        "game/scenes/",
        "game/scripts/combat/",
        "game/scripts/road/",
        "game/scripts/ui/",
        "tests/visual/",
    )
    visual_files = {"project.godot"}
    return any(path.startswith(visual_prefixes) or path in visual_files for path in paths)


def main() -> int:
    root = project_root()
    print("=== ROAD COMPANY Agent Status ===")
    print(f"Project root: {root}")

    ok, branch = git_output(root, ["branch", "--show-current"])
    print(f"Branch: {branch if ok and branch else 'unknown'}")

    ok, commit = git_output(root, ["log", "-1", "--oneline"])
    print(f"Latest commit: {commit if ok else 'unknown'}")

    ok, status = git_output(root, ["status", "--short"])
    status_lines = status.splitlines() if ok and status else []
    print(f"Dirty status: {'dirty' if status_lines else 'clean'}")
    if status_lines:
        for line in status_lines:
            print(f"  {line}")

    base = diff_base(root)
    print(f"\nDiff against {base or 'main'}:")
    if base is None:
        print("  SKIP: neither origin/main nor main could be resolved")
    else:
        ok, diff = git_output(root, ["diff", "--name-status", f"{base}..HEAD"])
        if ok and diff:
            for line in diff.splitlines():
                print(f"  {line}")
        elif ok:
            print("  none")
        else:
            print(f"  SKIP: {diff}")

    godot_bin, godot_reason = discover_godot(root)
    print("\nTools:")
    print(f"  GODOT_BIN set: {'yes' if os.environ.get('GODOT_BIN') else 'no'}")
    print(f"  Godot executable: {'FOUND at ' + godot_bin if godot_bin else 'NOT FOUND - ' + godot_reason}")
    for rel in ["tools/run_all_tests.py", "tools/run_visual_smoke.py"]:
        print(f"  {rel}: {'FOUND' if (root / rel).exists() else 'MISSING'}")

    print(f"\nLatest visual report: {latest_visual_summary(root)}")

    paths = changed_paths(root, base, status_lines)
    print("\nRecommended validation:")
    print("  python tools/run_all_tests.py")
    if should_run_visual(paths):
        print("  python tools/run_visual_smoke.py")
    print("  python tools/agent_finish.py --skip-visual")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
