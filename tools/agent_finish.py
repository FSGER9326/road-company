from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


@dataclass
class CommandResult:
    label: str
    command: list[str]
    returncode: int
    stdout: str
    stderr: str
    skipped: bool = False
    skip_reason: str = ""

    @property
    def status(self) -> str:
        if self.skipped:
            return "SKIPPED"
        return "PASS" if self.returncode == 0 else "FAIL"


def project_root() -> Path:
    here = Path(__file__).resolve()
    for parent in [here.parent, *here.parents]:
        if (parent / "project.godot").exists():
            return parent
    return Path.cwd()


def run_command(label: str, command: list[str], cwd: Path) -> CommandResult:
    print(f"\n=== {label} ===")
    print(" ".join(command))
    try:
        proc = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
        stdout = proc.stdout.strip()
        stderr = proc.stderr.strip()
        if stdout:
            print(stdout)
        if stderr:
            print(stderr)
        print(f"{'PASS' if proc.returncode == 0 else 'FAIL'}: {label}")
        return CommandResult(label, command, proc.returncode, stdout, stderr)
    except OSError as exc:
        print(f"FAIL: {label}: {exc}")
        return CommandResult(label, command, 127, "", str(exc))


def skipped_result(label: str, command: list[str], reason: str) -> CommandResult:
    print(f"\n=== {label} ===")
    print(f"SKIP: {reason}")
    return CommandResult(label, command, 0, "", "", skipped=True, skip_reason=reason)


def git_text(root: Path, args: list[str], fallback: str = "unknown") -> str:
    try:
        proc = subprocess.run(["git", *args], cwd=root, text=True, capture_output=True)
    except OSError:
        return fallback
    if proc.returncode != 0:
        return fallback
    return proc.stdout.strip() or fallback


def diff_base(root: Path) -> str | None:
    for ref in ["origin/main", "main"]:
        if git_text(root, ["rev-parse", "--verify", ref], ""):
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


def changed_files(root: Path, base: str | None) -> list[str]:
    files: list[str] = []
    if base is not None:
        diff = git_text(root, ["diff", "--name-status", f"{base}..HEAD"], "")
        files.extend(line for line in diff.splitlines() if line.strip())
    status = git_text(root, ["status", "--short"], "")
    files.extend(line for line in status.splitlines() if line.strip())
    return sorted(set(files))


def write_report(path: Path, branch: str, commit: str, changed: list[str], results: list[CommandResult]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Agent Finish Report",
        "",
        f"- Date: {datetime.now().isoformat(timespec='seconds')}",
        f"- Branch: `{branch}`",
        f"- Latest commit: `{commit}`",
        "",
        "## Changed Files",
        "",
    ]
    if changed:
        lines.extend(f"- `{item}`" for item in changed)
    else:
        lines.append("- none")
    lines.extend(["", "## Commands Run", ""])
    for result in results:
        lines.append(f"### {result.label}")
        lines.append("")
        lines.append(f"- Command: `{' '.join(result.command) if result.command else 'none'}`")
        lines.append(f"- Status: {result.status}")
        if result.skipped:
            lines.append(f"- Skip reason: {result.skip_reason}")
        lines.append("")
        if result.stdout:
            lines.append("<details><summary>stdout</summary>")
            lines.append("")
            lines.append("```text")
            lines.append(result.stdout[-12000:])
            lines.append("```")
            lines.append("</details>")
            lines.append("")
        if result.stderr:
            lines.append("<details><summary>stderr</summary>")
            lines.append("")
            lines.append("```text")
            lines.append(result.stderr[-12000:])
            lines.append("```")
            lines.append("</details>")
            lines.append("")
    lines.extend(
        [
            "## Known Limitations",
            "",
            "- Visual smoke is skipped when Godot is unavailable unless `--force-visual` is used.",
            "- This report captures command output and git metadata; it does not inspect screenshots directly.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Road Company agent finish validation and write a report.")
    parser.add_argument("--skip-visual", action="store_true", help="Skip visual smoke even if Godot is available.")
    parser.add_argument("--force-visual", action="store_true", help="Run visual smoke even if Godot discovery fails.")
    parser.add_argument("--no-tests", action="store_true", help="Skip run_all_tests.py. Intended only for tooling dry-runs.")
    parser.add_argument("--report-path", default="artifacts/agent_reports/latest.md", help="Markdown report output path.")
    args = parser.parse_args()

    root = project_root()
    report_path = Path(args.report_path)
    if not report_path.is_absolute():
        report_path = root / report_path

    branch = git_text(root, ["branch", "--show-current"])
    commit = git_text(root, ["log", "-1", "--oneline"])
    base = diff_base(root)

    print("=== ROAD COMPANY Agent Finish ===")
    print(f"Project root: {root}")
    print(f"Branch: {branch}")
    print(f"Latest commit: {commit}")

    results: list[CommandResult] = []
    results.append(run_command("Git Status", ["git", "status", "--short"], root))
    if base is None:
        results.append(skipped_result("Diff Against Main", ["git", "diff", "--name-status", "origin/main..HEAD"], "origin/main and main are unavailable"))
    else:
        results.append(run_command("Diff Against Main", ["git", "diff", "--name-status", f"{base}..HEAD"], root))

    if args.no_tests:
        results.append(skipped_result("All Tests", [sys.executable, "tools/run_all_tests.py"], "--no-tests was provided"))
    else:
        results.append(run_command("All Tests", [sys.executable, "tools/run_all_tests.py"], root))

    visual_script = root / "tools" / "run_visual_smoke.py"
    godot_bin, godot_reason = discover_godot(root)
    if args.skip_visual:
        results.append(skipped_result("Visual Smoke", [sys.executable, "tools/run_visual_smoke.py"], "--skip-visual was provided"))
    elif not visual_script.exists():
        results.append(skipped_result("Visual Smoke", [sys.executable, "tools/run_visual_smoke.py"], "tools/run_visual_smoke.py is missing"))
    elif godot_bin or args.force_visual:
        if not godot_bin:
            print("WARNING: forcing visual smoke without discovered Godot executable")
        results.append(run_command("Visual Smoke", [sys.executable, "tools/run_visual_smoke.py"], root))
    else:
        results.append(skipped_result("Visual Smoke", [sys.executable, "tools/run_visual_smoke.py"], f"Godot not available - {godot_reason}"))

    changed = changed_files(root, base)
    print("\n=== Writing Report ===")
    write_report(report_path, branch, commit, changed, results)
    print(f"Report written: {report_path}")

    required_failures = [
        result for result in results
        if not result.skipped and result.returncode != 0 and result.label in {"All Tests", "Visual Smoke"}
    ]
    if required_failures:
        print("\nResult: FAIL")
        return 1
    print("\nResult: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
