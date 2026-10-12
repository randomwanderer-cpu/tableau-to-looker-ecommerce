#!/usr/bin/env python3
"""Proves tools/check_lookml.py actually catches errors.

Run with: python tests/test_checker.py
(needs `lkml` installed — see README for the venv setup)

1. Runs the checker against this project's real views/models -> expect pass.
2. Runs the checker against tests/broken/ -> expect failure, and checks the
   failure messages mention the specific bugs planted there.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CHECKER = REPO_ROOT / "tools" / "check_lookml.py"
BROKEN_DIR = REPO_ROOT / "tests" / "broken"


def run_checker(root: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(CHECKER), "--root", str(root)],
        capture_output=True,
        text=True,
    )


def test_real_project_passes() -> None:
    result = run_checker(REPO_ROOT)
    assert result.returncode == 0, (
        f"expected the real project to pass, got exit {result.returncode}:\n"
        f"{result.stdout}\n{result.stderr}"
    )
    print("PASS: real project passes the checker")


def test_broken_fixture_fails() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_root = Path(tmp)
        (tmp_root / "views").mkdir()
        (tmp_root / "models").mkdir()
        shutil.copy(
            BROKEN_DIR / "broken_order_items.view.lkml",
            tmp_root / "views" / "broken_order_items.view.lkml",
        )
        shutil.copy(
            BROKEN_DIR / "broken_model.model.lkml",
            tmp_root / "models" / "broken_model.model.lkml",
        )

        result = run_checker(tmp_root)

        assert result.returncode != 0, (
            "expected the broken fixture to fail, but the checker passed:\n"
            f"{result.stdout}"
        )

        stderr = result.stderr
        expected_substrings = [
            "no dimension with primary_key",  # rule 4
            "more than once",  # rule 3 (duplicate field name)
            "sale_price_that_does_not_exist",  # rule 1 (unknown field)
            "ghost_view",  # rule 2 (unknown view in a join)
        ]
        missing = [s for s in expected_substrings if s not in stderr]
        assert not missing, (
            f"checker failed as expected, but didn't report: {missing}\n"
            f"--- actual stderr ---\n{stderr}"
        )
        print("PASS: broken fixture fails, and for all the right reasons")


if __name__ == "__main__":
    test_real_project_passes()
    test_broken_fixture_fails()
    print("\nAll checker tests passed.")
