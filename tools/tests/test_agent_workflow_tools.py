from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class AgentWorkflowToolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.agent_status = load_module("agent_status_under_test", ROOT / "tools" / "agent_status.py")
        cls.agent_finish = load_module("agent_finish_under_test", ROOT / "tools" / "agent_finish.py")

    def test_project_root_finds_godot_project(self) -> None:
        self.assertEqual(self.agent_status.project_root(), ROOT)
        self.assertEqual(self.agent_finish.project_root(), ROOT)

    def test_visual_recommendation_detects_ui_paths(self) -> None:
        self.assertTrue(self.agent_status.should_run_visual(["game/scripts/ui/ContractBoard.gd"]))
        self.assertTrue(self.agent_status.should_run_visual(["tests/visual/baselines/main_menu.png"]))
        self.assertFalse(self.agent_status.should_run_visual(["tools/agent_status.py"]))

    def test_write_report_creates_markdown(self) -> None:
        result = self.agent_finish.CommandResult(
            label="All Tests",
            command=["python", "tools/run_all_tests.py"],
            returncode=0,
            stdout="Result: PASS",
            stderr="",
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "latest.md"
            self.agent_finish.write_report(path, "feature/test", "abc123 message", ["A\ttools/example.py"], [result])
            text = path.read_text(encoding="utf-8")
        self.assertIn("# Agent Finish Report", text)
        self.assertIn("feature/test", text)
        self.assertIn("A\ttools/example.py", text)
        self.assertIn("Status: PASS", text)


if __name__ == "__main__":
    unittest.main()
