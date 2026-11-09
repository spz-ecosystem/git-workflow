#!/usr/bin/env python3
"""gk_gitworkflow_loader.py — git-workflow 技能加载安全网（2026-08-30，加载安全网模版第三次应用）。

定位：把 plugin-loading-test-framework.md §1 插件加载安全网协议（bashpy/paper-review 同款）
应用到 **bash 技能类** git-workflow（v2.1.0）——技能入口 git-workflow.sh 前置本 loader
校验，核心脚本被篡改/损坏/缺失 → fail-closed 拦截，杜绝"误加载被投毒技能"。

与 gk_paper_review_loader.py 差异（技能类适配）：
- 多入口 pin：技能由多个核心脚本组成（git-workflow.sh 主入口 + branch-delete-safety-check.sh），
  全部 SHA256 命中 = builtin；任一命中失败 = tampered（永不静默使用）。
- 消费方是 bash（git-workflow.sh 入口 + gatekeeper self-check），经 CLI 子命令消费：
    python3 gk_gitworkflow_loader.py status   # JSON 状态（入口安全网用）
    python3 gk_gitworkflow_loader.py check    # exit 0/2（fail-closed 判定，脚本侧用）
    python3 gk_gitworkflow_loader.py version  # 版本号

加载语义（对齐 §1.3）:
  builtin   → self-check PASS；入口放行
  dev       → self-check WARN（存在未 pin）；入口放行但提示
  tampered  → self-check FAIL（误加载拦截）；入口 fail-closed exit 2
  missing   → self-check WARN（脚本缺失）；入口 fail-closed exit 2
  error     → self-check FAIL（错误加载拦截）；入口 fail-closed exit 2
"""
import hashlib
import json
import os
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = SKILL_DIR / "scripts"
GITWORKFLOW_VERSION = "2.1.2"
# 核心脚本 pin 表（version → {filename: sha256}）。登记 = 跑过测试/验收的当前产物。
# 修改任一核心脚本后须更新本 pin（对齐 _RELEASE_PINS 纪律：未登记 = dev WARN）。
# 2026-09-23（ECC-A91DC4562198 收编）：`git-workflow.sh` 新增 `worktree create --from/--json`
#   + `_gw_worktree_base()`（根改为读配置 worktree.base_path）⟹ 同步更新其 pin。
#   实测：未更新前 `git-workflow.sh` 任何子命令被 `gw_load_guard` 判 tampered exit 2
#   （「改核心脚本 ⟹ 必须同步 pin」的耦合是**真实且即时的**，非文档约定）。
# 2026-09-24（用户裁定「按建议做」取 A：worktree 生命周期单源化）：`worktree delete` 新增
#   `--path <dir>`（按路径，应对**无 branch 的孤儿**）+ `--force`（脏 wt 强删 —— 门禁回收链
#   **先归档、归档不改 wt** ⟹ 落刀时 wt 仍 dirty，原实现必被 git 拒删）⟹ 同步更新其 pin。
#   实测：未更新前 `pytest tests/test_gk_gitworkflow_loader.py` **4 failed**
#   （`test_builtin_ok` / `test_dev_no_manifest` / `test_load_builtin_returns_entry` /
#   `test_cli_check_builtin_exit0`）⟹ 红先是**真的**，不是文档约定。
# 2026-10-25（凭据单一入口）：git-workflow.sh 改为 source scripts/gw_credentials.sh，
#   推送取 token 由 `gh auth token` 改为 `gw_token`（密钥库 → 环境变量 → gh）⟹ 同步更新其 pin。
#   实测：未更新前任何子命令被 gw_load_guard 判 tampered exit 2（同 09-23/09-24 的即时耦合）。
# 2026-11-02（跨平台层 + history split）：
#   · 新增 `_gw_days_ago` / `_gw_confirm` / `_gw_within`（GNU/BSD date 双分支、
#     非交互 fail-closed、cp 自嵌套判定）；`backup` 改 git bundle + patch + untracked tar；
#     `commit-batch` 去交互（`--message` / `GW_COMMIT_MESSAGE`）。
#   · `history` 新增 `split`（支持 **hunk 级**拆分已提交的混合提交），实现落
#     `scripts/gw_history_split.py` ⟹ **一并纳入 pin**（核心能力，被改后果严重）。
#   ⟹ 同步更新 git-workflow.sh 的 pin + 新增 gw_history_split.py。
# 2026-11-03（v2.1.1 收口）：git-workflow.sh 版本声明对齐（原 2.1.0 ⟹ 2.1.1，与本文
#   GITWORKFLOW_VERSION / SKILL.md / yaml / package.sh 同值）⟹ 同步更新其 pin。
# 2026-11-03（集成修复）：`push push` 新增 `--allow-main` 透传 + 拒绝时给出可操作指引；
#   `pr-fallback` 白名单改 `GW_PUSH_REMOTE_ALLOW` ⟹ 再改 git-workflow.sh ⟹ pin 同步。
# 2026-11-03（解绑）：push 委托/预检改为**显式启用**（GIT_WORKFLOW_DELEGATE /
#   GIT_WORKFLOW_PRECHECK_CLI，默认 none）—— 开源插件不再按同级目录自动调用别的技能。
_GITWORKFLOW_PINS = {
    "2.1.1": {
        "git-workflow.sh": "cea6f92e3504221f0086883e5d2ea17185d72ac57ca6f2031cbcbff058b9262d",
        "gw_history_split.py": "08c83f3c1b960333cf8c8adba0cc3495d9bdf4d26d08200f0b06e5b5d9ceae5a",
        "branch-delete-safety-check.sh": "0cf22c748aa218dbd672c83eaf10f684c6cb9d0084aeb54bae86ab316896e3f4",
    },
    # 2026-11-06 v2.1.2：推送成功后回收本地快照（`GW_SNAPSHOT_GC` / `GW_SNAPSHOT_GC_ARGS`）。
    #   现场：该改动（提交 1d78924）只改了 `git-workflow.sh`、**没 bump 版本也没重钉** ⟹
    #   loader 判 tampered（实测 sha256 变动后任何子命令 exit 2，apply-worktree 建树随之失败）。
    #   本版补齐版本三处声明（脚本 / yaml / templates / package / SKILL）并重登记三个核心脚本 pin。
    # 2026-11-09（检测命中修复）：`precheck_cli: ""` 空占位被当成路径 ⟹ 每次 push 误报
    #   `预检入口不存在: ""`。改为先剥引号再判空 ⟹ 同步重钉 git-workflow.sh。
    "2.1.2": {
        "git-workflow.sh": "ff640ff3d877c0b9cb4b16cbf4a2cbb68596080b299808a3e986f21204af0144",
        "gw_history_split.py": "08c83f3c1b960333cf8c8adba0cc3495d9bdf4d26d08200f0b06e5b5d9ceae5a",
        "branch-delete-safety-check.sh": "0cf22c748aa218dbd672c83eaf10f684c6cb9d0084aeb54bae86ab316896e3f4",
    },
}
# 技能能力白名单（对齐 manifest intercept：skill 的七模块即其对外能力）
SKILL_CAPS = ("push", "branch", "worktree", "release", "security", "cleanup", "history")
GK_DBG_LOG = SKILL_DIR / "gk_dbg.log"


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def _dbg(msg: str) -> None:
    """GK_DBG_LOG 追加（可调试插桩）: 加载决策可审计。"""
    try:
        with open(GK_DBG_LOG, "a", encoding="utf-8") as f:
            f.write(f"[{Path(__file__).name}] {msg}\n")
    except OSError:
        pass


def _core_scripts() -> list[str]:
    """当前版本登记的技能核心脚本清单（key = 文件名）。"""
    return list(_GITWORKFLOW_PINS.get(GITWORKFLOW_VERSION, {}))


def _manifest_ok() -> bool:
    """manifest 对账：git-workflow 必须已登记于 spz-gatekeeper gk_plugin_manifest
    （intercept = 七模块能力白名单），且本技能目录存在对应登记。"""
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent
                              / "spz-gatekeeper-r-sequence" / "scripts"))
        from gk_plugin_manifest import get_manifest
        m = get_manifest("git-workflow") or {}
        return "git-workflow" in (m.get("id") or "") and any(
            c in (m.get("intercept") or ()) for c in SKILL_CAPS)
    except Exception as e:
        _dbg(f"manifest check failed: {type(e).__name__}: {e}")
        return False


def load_status() -> dict:
    """加载状态（供 self-check / CLI 消费）。

    source ∈ {builtin, dev, tampered, missing, error}
    """
    scripts = _core_scripts()
    if not scripts:
        _dbg("dev: 版本无 pin 登记（未 pin，非 CI 验证）")
        return {"source": "dev", "version": GITWORKFLOW_VERSION, "hash_verified": None,
                "manifest_ok": _manifest_ok(),
                "detail": "当前版本未登记核心脚本 pin（dev 语义，WARN）",
                "module_file": str(SCRIPTS_DIR)}
    # 存在性 + 哈希逐文件核验
    pins = _GITWORKFLOW_PINS[GITWORKFLOW_VERSION]
    missing, tampered = [], []
    for name in scripts:
        p = SCRIPTS_DIR / name
        if not p.is_file():
            missing.append(name)
            continue
        try:
            if _sha256_file(p) != pins[name]:
                tampered.append(name)
        except OSError as e:
            _dbg(f"error reading {name}: {e}")
            tampered.append(name)
    if missing:
        _dbg(f"missing: {missing}")
        return {"source": "missing", "version": GITWORKFLOW_VERSION, "hash_verified": None,
                "manifest_ok": _manifest_ok(),
                "detail": f"核心脚本缺失（漏加载，显式报告不静默）: {missing}",
                "module_file": str(SCRIPTS_DIR)}
    if tampered:
        _dbg(f"tampered: {tampered}")
        return {"source": "tampered", "version": GITWORKFLOW_VERSION, "hash_verified": False,
                "manifest_ok": _manifest_ok(),
                "detail": f"核心脚本 SHA256 不匹配固定哈希（误加载拦截，永不静默使用）: {tampered}",
                "module_file": str(SCRIPTS_DIR)}
    mok = _manifest_ok()
    # 全部命中但 manifest 未登记 → dev（功能可用但未纳入治理）
    if not mok:
        _dbg("dev: 哈希全命中但 manifest 未登记")
        return {"source": "dev", "version": GITWORKFLOW_VERSION, "hash_verified": True,
                "manifest_ok": False,
                "detail": "脚本 SHA256 全部命中，但 gk_plugin_manifest 未登记 git-workflow（治理缺口，WARN）",
                "module_file": str(SCRIPTS_DIR)}
    return {"source": "builtin", "version": GITWORKFLOW_VERSION, "hash_verified": True,
            "manifest_ok": True,
            "detail": "技能核心脚本 SHA256 校验通过 + manifest 登记确认",
            "module_file": str(SCRIPTS_DIR)}


def load_gitworkflow():
    """返回 (主入口路径 | None, 加载状态 dict)。调用点必须检查双信号。"""
    status = load_status()
    if status["source"] not in ("builtin", "dev"):
        return None, status
    return str(SCRIPTS_DIR / "git-workflow.sh"), status


def main(argv: list[str]) -> int:
    """CLI 入口: status / check / version（供 git-workflow.sh 入口 + gatekeeper self-check）。"""
    cmd = argv[0] if argv else "status"
    if cmd == "version":
        print(GITWORKFLOW_VERSION)
        return 0
    st = load_status()
    if cmd == "status":
        print(json.dumps(st, ensure_ascii=False))
        return 0
    if cmd == "check":  # fail-closed 判定：builtin/dev → 0；tampered/missing/error → 2
        if st["source"] in ("builtin", "dev"):
            print(json.dumps(st, ensure_ascii=False))
            return 0
        print(json.dumps(st, ensure_ascii=False), file=sys.stderr)
        return 2
    print('{"ok":false,"error":"usage: status | check | version"}')
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
