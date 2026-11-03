#!/usr/bin/env python3
"""git-workflow 的**解绑**与**可选委托**臂（2026-11-03）。

定位：git-workflow 是开源插件 —— 不得因为「同级目录里恰好有个别的技能」就改变推送行为。
用户可能有自己的专属工具。故外部增强一律**默认关闭**、显式开启：

  · `push` 默认走原生 `git push`；委托需 `GIT_WORKFLOW_DELEGATE` / `push.delegate`；
  · `push precheck` 不再自动调用 `../github-push`；需 `GIT_WORKFLOW_PRECHECK_CLI` /
    `push.precheck_cli`；
  · 启用委托后：透传 `--allow-main`、被拒时给可操作指引、失败回落原生 push。

覆盖（离线、无网络）：
  · `test_default_push_is_native`        —— 默认**不**调用同级 gatekeeper；
  · `test_config_value_enables_delegation` —— 配置 `push.delegate: gatekeeper` 生效；
  · `test_allow_main_flag_is_forwarded`  —— 授权位透传；
  · `test_flag_absent_by_default`        —— 不带 flag 时不得透传；
  · `test_blocked_delegation_gives_hint` —— 被拒 ⟹ 可操作指引 + 降级成功；
  · `test_precheck_is_opt_in`            —— 默认不调 `../github-push`，仅显式配置才调。
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

SKILL = Path(__file__).resolve().parent.parent
GW_SRC = SKILL / "scripts" / "git-workflow.sh"
CRED_SRC = SKILL / "scripts" / "gw_credentials.sh"

STUB = """#!/usr/bin/env bash
printf '%s\\n' "$@" > "${GW_RECORD:?record path required}"
if [ "${GW_STUB_EXIT:-0}" != "0" ]; then
  echo '{"ok":false,"phase":"confirm","error":"Direct push to '"'"'main'"'"' blocked by policy","hint":"x"}'
  exit "${GW_STUB_EXIT}"
fi
echo '{"ok":true,"phase":"confirm"}'
exit 0
"""

PC_STUB = """import os, sys, pathlib
pathlib.Path(os.environ["GW_PC_MARK"]).write_text(" ".join(sys.argv[1:]))
"""


def _git(repo, *a):
    return subprocess.run(["git", "-C", str(repo), *a], capture_output=True, text=True)


@pytest.fixture()
def sandbox(tmp_path):
    skill = tmp_path / "skill"
    (skill / "scripts").mkdir(parents=True)
    shutil.copy2(GW_SRC, skill / "scripts" / "git-workflow.sh")
    shutil.copy2(CRED_SRC, skill / "scripts" / "gw_credentials.sh")
    (skill / "git-workflow.yaml").write_text(
        "worktree:\n  base_path: %s\n" % (tmp_path / "wts"), encoding="utf-8")

    # 同级 gatekeeper（桩）
    gk = tmp_path / "spz-gatekeeper-r-sequence"
    gk.mkdir()
    stub = gk / "gatekeeper-cli.sh"
    stub.write_text(STUB, encoding="utf-8")
    stub.chmod(0o755)
    # 同级 github-push（桩）—— 用来证明**默认不再自动调用**
    hp = tmp_path / "github-push"
    hp.mkdir()
    (hp / "github_push.py").write_text(PC_STUB, encoding="utf-8")

    bare = tmp_path / "bare.git"
    subprocess.run(["git", "init", "-q", "--bare", str(bare)], check=True)
    repo = tmp_path / "work"
    repo.mkdir()
    _git(repo, "init", "-q", "-b", "main")
    (repo / "a.txt").write_text("x", encoding="utf-8")
    _git(repo, "add", "a.txt")
    _git(repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "init")
    _git(repo, "remote", "add", "origin", str(bare))

    env = dict(os.environ)
    env.pop("GIT_WORKFLOW_DELEGATE", None)
    env.pop("GIT_WORKFLOW_PRECHECK_CLI", None)
    env.update({
        "GW_RECORD": str(tmp_path / "argv.txt"),
        "GW_PC_MARK": str(tmp_path / "pc_mark.txt"),
        "GIT_WORKFLOW_LOG": str(tmp_path / "logs"),
        "GIT_WORKFLOW_BACKUP": str(tmp_path / "backups"),
        "GIT_WORKFLOW_WORKTREE_ROOT": str(tmp_path / "wts"),
        "GW_ASSUME_YES": "1",
    })
    return {"skill": skill, "repo": repo, "record": tmp_path / "argv.txt",
            "pc_mark": tmp_path / "pc_mark.txt", "env": env}


def _run(box, *args, extra_env=None):
    env = dict(box["env"])
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        ["bash", str(box["skill"] / "scripts" / "git-workflow.sh"), *args],
        cwd=str(box["repo"]), capture_output=True, text=True, env=env, timeout=120)


def test_default_push_is_native(sandbox):
    """默认**不**调用同级 gatekeeper（开源包不得强制外部工具）。"""
    r = _run(sandbox, "push", "push")
    assert r.returncode == 0, (r.stdout, r.stderr)
    assert not sandbox["record"].exists(), "默认竟然调用了同级 gatekeeper（耦合未解）"
    bare = sandbox["repo"].parent / "bare.git"
    assert _git(bare, "rev-parse", "refs/heads/main").returncode == 0


def test_config_value_enables_delegation(sandbox):
    """配置 `push.delegate: gatekeeper` 是**显式**开启方式之一。"""
    (sandbox["skill"] / "git-workflow.yaml").write_text(
        "push:\n  delegate: gatekeeper\nworktree:\n  base_path: %s\n"
        % (sandbox["repo"].parent / "wts"), encoding="utf-8")
    r = _run(sandbox, "push", "push")
    assert r.returncode == 0, (r.stdout, r.stderr)
    assert sandbox["record"].exists(), "配置未生效（委托未被调用）"


def test_allow_main_flag_is_forwarded(sandbox):
    r = _run(sandbox, "push", "push", "--allow-main",
             extra_env={"GIT_WORKFLOW_DELEGATE": "gatekeeper"})
    assert r.returncode == 0, (r.stdout, r.stderr)
    argv = sandbox["record"].read_text(encoding="utf-8").splitlines()
    assert "--allow-main" in argv, f"未透传到委托：{argv}"


def test_flag_absent_by_default(sandbox):
    r = _run(sandbox, "push", "push", extra_env={"GIT_WORKFLOW_DELEGATE": "gatekeeper"})
    assert r.returncode == 0, (r.stdout, r.stderr)
    argv = sandbox["record"].read_text(encoding="utf-8").splitlines()
    assert "--allow-main" not in argv, f"默认不该放宽：{argv}"


def test_blocked_delegation_gives_hint(sandbox):
    r = _run(sandbox, "push", "push",
             extra_env={"GIT_WORKFLOW_DELEGATE": "gatekeeper", "GW_STUB_EXIT": "1"})
    out = r.stdout + r.stderr
    assert "--allow-main" in out, f"缺可操作指引：{out}"
    assert "auth-main" in out, f"缺一次性授权指引：{out}"
    assert r.returncode == 0, (r.stdout, r.stderr)
    bare = sandbox["repo"].parent / "bare.git"
    assert _git(bare, "rev-parse", "refs/heads/main").returncode == 0


def test_precheck_is_opt_in(sandbox):
    """默认不调 `../github-push`（旧实现按同级目录自动调用）；显式配置才调。"""
    r = _run(sandbox, "push", "precheck")
    assert r.returncode == 0, (r.stdout, r.stderr)
    assert "未配置预检工具" in (r.stdout + r.stderr), r.stdout
    assert not sandbox["pc_mark"].exists(), "默认仍自动调用了同级 github-push（耦合未解）"

    stub = sandbox["skill"] / "precheck.py"
    stub.write_text(PC_STUB, encoding="utf-8")
    r2 = _run(sandbox, "push", "precheck",
              extra_env={"GIT_WORKFLOW_PRECHECK_CLI": str(stub)})
    assert r2.returncode == 0, (r2.stdout, r2.stderr)
    assert sandbox["pc_mark"].exists(), "显式配置的预检未被执行"
