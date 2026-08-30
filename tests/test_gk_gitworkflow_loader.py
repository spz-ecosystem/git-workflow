"""
test_gk_gitworkflow_loader.py — git-workflow 技能加载安全网测试（2026-08-30，模版第三次应用）
=============================================================================================
覆盖：五源分流（builtin/dev/tampered/missing/error）/ 多入口 SHA256 pin 校验 /
manifest 对账 / 双函数契约（load_status + load_gitworkflow 二元组）/ CLI check fail-closed。
符合 plugin-loading-test-framework.md §2：R1（只 patch 模块边界）/ R3（可用/不可用分用例）。
"""
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import gk_gitworkflow_loader as gwl


class TestLoadStatus:
    def test_builtin_ok(self):
        """真实脚本 + 当前 pin 全部命中 + manifest 登记 → builtin（hash_verified=True）。"""
        st = gwl.load_status()
        assert st["source"] == "builtin"
        assert st["hash_verified"] is True
        assert st["manifest_ok"] is True

    def test_missing(self, monkeypatch, tmp_path):
        """核心脚本不存在 → missing（漏加载显式报告，不静默）。"""
        empty = tmp_path / "scripts"
        empty.mkdir()
        monkeypatch.setattr(gwl, "SCRIPTS_DIR", empty)
        st = gwl.load_status()
        assert st["source"] == "missing"
        assert "缺失" in st["detail"]

    def test_tampered(self, monkeypatch):
        """核心脚本哈希不匹配固定点 → tampered（误加载拦截，永不静默使用）。"""
        monkeypatch.setattr(gwl, "_GITWORKFLOW_PINS",
                            {gwl.GITWORKFLOW_VERSION:
                             {"git-workflow.sh": "0" * 64,
                              "branch-delete-safety-check.sh": "0" * 64}})
        st = gwl.load_status()
        assert st["source"] == "tampered"
        assert st["hash_verified"] is False
        assert "git-workflow.sh" in st["detail"]

    def test_dev_unpinned(self, monkeypatch):
        """版本无 pin 登记 → dev（WARN：未 pin，非 CI 验证）。"""
        monkeypatch.setattr(gwl, "_GITWORKFLOW_PINS", {})
        st = gwl.load_status()
        assert st["source"] == "dev"

    def test_dev_no_manifest(self, monkeypatch):
        """哈希全命中但 manifest 未登记 → dev（治理缺口 WARN，不误判 tampered）。"""
        monkeypatch.setattr(gwl, "_manifest_ok", lambda: False)
        st = gwl.load_status()
        assert st["source"] == "dev"
        assert st["hash_verified"] is True
        assert st["manifest_ok"] is False


class TestLoadGitworkflow:
    def test_load_builtin_returns_entry(self):
        """双函数契约：builtin 态 → (主入口路径, status)。"""
        entry, st = gwl.load_gitworkflow()
        assert entry is not None and entry.endswith("git-workflow.sh")
        assert st["source"] in ("builtin", "dev")

    def test_load_tampered_returns_none(self, monkeypatch):
        """tampered 态 → (None, status)——调用点必须检查双信号（R3 分用例）。"""
        monkeypatch.setattr(gwl, "load_status",
                            lambda: {"source": "tampered", "version": None,
                                     "hash_verified": False, "detail": "forced"})
        entry, st = gwl.load_gitworkflow()
        assert entry is None
        assert st["source"] == "tampered"


class TestCli:
    def test_cli_check_builtin_exit0(self):
        """CLI check：builtin → exit 0（入口放行判定）。"""
        assert gwl.main(["check"]) == 0

    def test_cli_check_tampered_exit2(self, monkeypatch):
        """CLI check：tampered → exit 2（fail-closed 判定）。"""
        monkeypatch.setattr(gwl, "load_status",
                            lambda: {"source": "tampered", "version": None,
                                     "hash_verified": False, "detail": "forced"})
        assert gwl.main(["check"]) == 2

    def test_cli_version(self):
        assert gwl.main(["version"]) == 0
