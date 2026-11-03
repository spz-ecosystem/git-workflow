#!/usr/bin/env python3
"""git-workflow → gatekeeper 委托链的集成臂（2026-11-03）。

**现场**：`git-workflow push push` 委托 `gatekeeper push confirm` 时，
① 调用方没有透传「直推 main」授权位（只能绕到 gatekeeper CLI 敲 auth-main）；
② 委托失败只回「委托失败」四个字，不给可操作指引；
③ `pr-fallback` 白名单硬编码两个组织前缀 ⟹ 换机器/换组织恒失败。

覆盖（离线、无网络）：
  · `test_allow_main_flag_is_forwarded`      —— `--allow-main` 必须出现在委托参数里；
  · `test_flag_absent_by_default`            —— 不带该 flag 时**不得**透传（防默认放宽）；
  · `test_blocked_delegation_gives_hint`     —— 委托被拒 ⟹ 输出含 `--allow-main` 与 `auth-main` 指引；
  · `test_pr_fallback_rejects_unlisted_remote` —— 非白名单远端 ⟹ 退出码 1 + 明确报错。

构造：把 `git-workflow.sh` + `gw_credentials.sh` 复制到临时「技能根」，同级放一个
**桩 gatekeeper**（记录 argv / 可令其失败）⟹ 不触碰真实门禁、不触网。
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

    gk = tmp_path / "spz-gatekeeper-r-sequence"
    gk.mkdir()
    stub = gk / "gatekeeper-cli.sh"
    stub.write_text(STUB, encoding="utf-8")
    stub.chmod(0o755)

    bare = tmp_path / "bare.git"
    subprocess.run(["git", "init", "-q", "--bare", str(bare)], check=True)
    repo = tmp_path / "work"
    repo.mkdir()
    _git(repo, "init", "-q", "-b", "main")
    (repo / "a.txt").write_text("x", encoding="utf-8")
    _git(repo, "add", "a.txt")
    _git(repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "init")
    _git(repo, "remote", "add", "origin", str(bare))

    record = tmp_path / "argv.txt"
    env = dict(os.environ)
    env.update({
        "GW_RECORD": str(record),
        "GIT_WORKFLOW_LOG": str(tmp_path / "logs"),
        "GIT_WORKFLOW_BACKUP": str(tmp_path / "backups"),
        "GIT_WORKFLOW_WORKTREE_ROOT": str(tmp_path / "wts"),
        "GW_ASSUME_YES": "1",
    })
    return {"skill": skill, "repo": repo, "record": record, "env": env}


def _run(box, *args, extra_env=None):
    env = dict(box["env"])
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        ["bash", str(box["skill"] / "scripts" / "git-workflow.sh"), *args],
        cwd=str(box["repo"]), capture_output=True, text=True, env=env, timeout=120)


def test_allow_main_flag_is_forwarded(sandbox):
    r = _run(sandbox, "push", "push", "--allow-main")
    assert r.returncode == 0, (r.stdout, r.stderr)
    argv = sandbox["record"].read_text(encoding="utf-8").splitlines()
    assert "--allow-main" in argv, f"未透传到委托：{argv}"


def test_flag_absent_by_default(sandbox):
    r = _run(sandbox, "push", "push")
    assert r.returncode == 0, (r.stdout, r.stderr)
    argv = sandbox["record"].read_text(encoding="utf-8").splitlines()
    assert "--allow-main" not in argv, f"默认不该放宽：{argv}"


def test_blocked_delegation_gives_hint(sandbox):
    r = _run(sandbox, "push", "push", extra_env={"GW_STUB_EXIT": "1"})
    out = r.stdout + r.stderr
    assert "--allow-main" in out, f"缺可操作指引：{out}"
    assert "auth-main" in out, f"缺一次性授权指引：{out}"
    # 委托失败后应降级原生 push（本案 origin 是本地裸仓 ⟹ 会成功）
    assert r.returncode == 0, (r.stdout, r.stderr)
    bare = sandbox["repo"].parent / "bare.git"
    assert _git(bare, "rev-parse", "refs/heads/main").returncode == 0


def test_pr_fallback_rejects_unlisted_remote(sandbox):
    r = _run(sandbox, "push", "pr-fallback")
    out = r.stdout + r.stderr
    assert r.returncode != 0, (r.stdout, r.stderr)
    assert "白名单验证失败" in out, out
    assert "GW_PUSH_REMOTE_ALLOW" in out, f"报错未给出覆盖位：{out}"
