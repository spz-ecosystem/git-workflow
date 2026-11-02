#!/usr/bin/env python3
"""gw_history_split.py — 把**已提交的混合提交**按主题拆成多个提交。

由 `git-workflow history split` 转发调用（入口在 scripts/git-workflow.sh）。

## 为什么需要
`history` 原设计（2026-05）只覆盖「巨型**初始**提交」：`split-root` 仅检查空仓库、
`stage-pick` 只打印建议、`commit-batch` 只按整文件分组。一旦提交已经落库且混了多个主题，
唯一的出路是手工 `reset --soft` + 逐个 `add`，遇到同一文件里混多个主题（hunk 级）就卡死。

## 不变量（硬约束）
1. **只重排，不改内容**：终态树必须与原 HEAD 逐字等价 —— 收尾强制校验
   `git diff --name-only <orig> HEAD` 为空，否则回滚并报错。
2. **零遗漏**：`<base>..HEAD` 的每个改动都必须被某个 group 覆盖，否则拒绝执行
   （宁可不动，也不能悄悄丢一块）。
3. **失败回滚**：任何异常 → `git reset --hard <orig>`（仅在入口已确认工作区干净时执行）。

## groups.json
```json
{
  "groups": [
    {"name": "fix(x): 主题一", "body": "多行说明", "paths": ["a.sh", "b.py"]},
    {"name": "test(x): 主题二", "hunks": {"gatekeeper-cli.sh": [1, 2, 6]}}
  ]
}
```
  · `paths`  = 整文件归属（新增/删除/二进制只能走这里）
  · `hunks`  = 文件内第 N 个 hunk（`git diff -U3` 的顺序，从 1 起）
  · 同一文件可分批（不同 group 给不同 hunk），执行时按序累加重建。

## 跨平台
只用 git 子进程 + 标准库；文件内容全程按 **bytes** 读写（不碰 CRLF），
路径用 `-z` 传输（非 ASCII 安全）。不依赖 bash 工具链。
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import subprocess
import sys

HUNK_RE = re.compile(rb"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


class SplitError(Exception):
    pass


def git(repo: str, *args: str, check: bool = True, stdin: bytes | None = None) -> bytes:
    r = subprocess.run(["git", *args], cwd=repo, input=stdin,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check and r.returncode != 0:
        raise SplitError("git %s 失败 (rc=%d): %s" % (
            " ".join(args), r.returncode,
            r.stderr.decode("utf-8", "replace").strip()[:400]))
    return r.stdout


def rev(repo: str, name: str) -> str:
    return git(repo, "rev-parse", "--verify", name).decode().strip()


# ── 改动清单 ────────────────────────────────────────────────────────────────

def changed_files(repo: str, base: str, head: str) -> list[str]:
    """`base..head` 的改动路径（-z，逐条）。"""
    raw = git(repo, "diff", "--name-only", "-z", base, head)
    return [p.decode("utf-8", "surrogateescape") for p in raw.split(b"\x00") if p]


def file_hunks(repo: str, base: str, head: str, path: str) -> list[list[bytes]]:
    """返回该文件的 hunk 列表（每个元素 = 含 header 的行数组，bytes）。"""
    patch = git(repo, "diff", "-U3", base, head, "--", path, check=False)
    if not patch:
        return []
    parts = re.split(rb"(?m)^(?=@@ )", patch)
    return [p.splitlines(keepends=True) for p in parts[1:] if p.startswith(b"@@ ")]


def blob(repo: str, rev_name: str, path: str) -> bytes | None:
    """取某版本的文件内容（bytes）；不存在返回 None。"""
    r = subprocess.run(["git", "show", "%s:%s" % (rev_name, path)], cwd=repo,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return r.stdout if r.returncode == 0 else None


def is_binary(data: bytes) -> bool:
    return b"\x00" in data[:8000]


def apply_hunks(base_bytes: bytes, hunks: list[list[bytes]], want: set[int]) -> bytes:
    """从 base 出发，按 base 坐标套用指定 hunk（一次性重建，与顺序无关）。"""
    lines = base_bytes.splitlines(keepends=True)
    out: list[bytes] = []
    cur = 0                                     # 0-based，base 坐标
    for idx in sorted(want):
        h = hunks[idx - 1]
        m = HUNK_RE.match(h[0])
        if not m:
            raise SplitError("hunk %d 头解析失败" % idx)
        old_start = int(m.group(1))
        while cur < old_start - 1:
            out.append(lines[cur]); cur += 1
        for ln in h[1:]:
            tag, body = ln[:1], ln[1:]
            if tag in (b" ", b"-"):
                if cur >= len(lines) or lines[cur] != body:
                    raise SplitError(
                        "hunk %d 在 base 第 %d 行对不上（文件已变更？）\n  base=%r\n  patch=%r"
                        % (idx, cur + 1, lines[cur] if cur < len(lines) else None, body))
                if tag == b" ":
                    out.append(body)
                cur += 1
            elif tag == b"+":
                out.append(body)
            elif tag == b"\\":
                pass                            # "\ No newline at end of file"
    out.extend(lines[cur:])
    return b"".join(out)


# ── 分组校验 ────────────────────────────────────────────────────────────────

def load_groups(path: str) -> list[dict]:
    try:
        with io.open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        raise SplitError("groups 文件读取失败: %s" % e)
    groups = data.get("groups") if isinstance(data, dict) else data
    if not isinstance(groups, list) or not groups:
        raise SplitError("groups 必须是非空数组（或 {\"groups\": [...]}）")
    for i, g in enumerate(groups, 1):
        if not isinstance(g, dict) or not str(g.get("name") or "").strip():
            raise SplitError("第 %d 组缺 name（用作 commit subject）" % i)
        if not g.get("paths") and not g.get("hunks"):
            raise SplitError("第 %d 组（%s）既无 paths 也无 hunks" % (i, g["name"]))
    return groups


def plan(repo: str, base: str, head: str, groups: list[dict]) -> list[dict]:
    """把 groups 解析成可执行计划，并做**覆盖完整性**校验。"""
    files = changed_files(repo, base, head)
    if not files:
        raise SplitError("`%s..%s` 没有任何改动" % (base[:8], head[:8]))

    whole: dict[str, int] = {}                  # path -> group 序号（整文件归属）
    hunked: dict[str, dict[int, int]] = {}      # path -> {hunk 序号: group 序号}
    steps = []

    for gi, g in enumerate(groups, 1):
        step = {"group": gi, "name": g["name"], "body": g.get("body") or "",
                "whole": [], "hunks": {}}
        for p in (g.get("paths") or []):
            p = str(p)
            if p not in files:
                raise SplitError("第 %d 组声明的路径不在改动集内: %s" % (gi, p))
            if p in whole:
                raise SplitError("路径被重复声明: %s（第 %d 组与第 %d 组）" % (p, whole[p], gi))
            whole[p] = gi
            step["whole"].append(p)

        for p, ids in (g.get("hunks") or {}).items():
            p = str(p)
            if p not in files:
                raise SplitError("第 %d 组声明的路径不在改动集内: %s" % (gi, p))
            if p in whole:
                raise SplitError("路径 %s 已整文件归属第 %d 组，不能再按 hunk 拆" % (p, whole[p]))
            hs = file_hunks(repo, base, head, p)
            if is_binary(blob(repo, head, p) or b"") or not hs:
                raise SplitError("文件 %s 无法按 hunk 拆（二进制或无 hunk）⟹ 用 paths" % p)
            for hid in ids:
                hid = int(hid)
                if hid < 1 or hid > len(hs):
                    raise SplitError("第 %d 组给 %s 的 hunk %d 越界（该文件共 %d 个）"
                                     % (gi, p, hid, len(hs)))
                if p in hunked and hid in hunked[p]:
                    raise SplitError("hunk 被重复声明: %s#%d（第 %d 组与第 %d 组）"
                                     % (p, hid, hunked[p][hid], gi))
                hunked.setdefault(p, {})[hid] = gi
            step["hunks"][p] = [int(x) for x in ids]
        steps.append(step)

    # 覆盖完整性
    missing = []
    for p in files:
        if p in whole:
            continue
        total = len(file_hunks(repo, base, head, p))
        covered = set((hunked.get(p) or {}).keys())
        if not covered:
            missing.append("%s（整文件未声明，hunk 0/%d）" % (p, total))
        elif len(covered) < total:
            missing.append("%s（hunk %d/%d，缺 %s）"
                           % (p, len(covered), total, sorted(set(range(1, total + 1)) - covered)))
    if missing:
        raise SplitError("有改动未被任何 group 覆盖（拒绝执行，避免静默丢改动）:\n  - "
                         + "\n  - ".join(missing))

    return steps


# ── 执行 ────────────────────────────────────────────────────────────────────

def write_file(repo: str, path: str, data: bytes | None) -> None:
    full = os.path.join(repo, path)
    if data is None:                            # 该版本不存在 ⟹ 删除
        if os.path.exists(full):
            os.remove(full)
        return
    d = os.path.dirname(full)
    if d and not os.path.isdir(d):
        os.makedirs(d, exist_ok=True)
    with io.open(full, "wb") as f:              # bytes 直写，**不碰 CRLF**
        f.write(data)


def execute(repo: str, base: str, head: str, steps: list[dict]) -> list[dict]:
    orig = head
    done = []
    applied: dict[str, object] = {}             # path -> "WHOLE" | set(hunk ids)

    try:
        git(repo, "reset", "--soft", base)
        git(repo, "reset")                      # 全 unstage，工作区保持 HEAD 内容

        for step in steps:
            affected: list[str] = []
            for p in step["whole"]:
                applied[p] = "WHOLE"
                affected.append(p)
            for p, ids in step["hunks"].items():
                cur = applied.setdefault(p, set())
                if cur == "WHOLE":
                    continue
                cur.update(ids)                 # type: ignore[union-attr]
                affected.append(p)

            for p in affected:
                state = applied[p]
                if state == "WHOLE":
                    content = blob(repo, head, p)          # 可能 None（删除）
                else:
                    base_b = blob(repo, base, p) or b""
                    content = apply_hunks(base_b, file_hunks(repo, base, head, p), state)  # type: ignore[arg-type]
                write_file(repo, p, content)

            if affected:
                git(repo, "add", "-A", "--", *affected)

            msg = step["name"]
            if step["body"]:
                msg += "\n\n" + step["body"]
            git(repo, "commit", "-F", "-", stdin=msg.encode("utf-8"))
            done.append({"group": step["group"], "name": step["name"],
                         "files": len(affected), "sha": rev(repo, "HEAD")[:8]})

        # 不变量：终态树必须与原 HEAD 等价
        drift = git(repo, "diff", "--name-only", orig, "HEAD").decode().strip()
        if drift:
            raise SplitError("终态树与原 HEAD 不一致（拆分丢了内容）:\n" + drift)
    except BaseException:
        try:
            git(repo, "reset", "--hard", orig)
        finally:
            raise
    return done


# ── 入口 ────────────────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser(description="按主题拆分已提交的混合提交")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--base", required=True, help="拆分起点（不含），如 HEAD~1 或某个 sha")
    ap.add_argument("--groups", required=True, help="groups.json 路径")
    ap.add_argument("--apply", action="store_true", help="真执行（默认 dry-run）")
    ap.add_argument("--allow-dirty", action="store_true", help="允许工作区有改动（不推荐）")
    ap.add_argument("--json", action="store_true", help="机器可读输出")
    a = ap.parse_args()

    repo = os.path.abspath(a.repo)
    try:
        git(repo, "rev-parse", "--git-dir")
        head = rev(repo, "HEAD")
        base = rev(repo, a.base)
        try:
            git(repo, "merge-base", "--is-ancestor", base, head)
        except SplitError:
            raise SplitError("base(%s) 不是 HEAD(%s) 的祖先" % (base[:8], head[:8]))

        # 只拦**已跟踪文件的未提交改动**（reset --hard 回滚会覆盖它们）。
        # 未跟踪文件（含 groups.json 本身）不受 reset 影响 ⟹ 不该拦。
        dirty = git(repo, "status", "--porcelain", "--untracked-files=no").decode().strip()
        if dirty and not a.allow_dirty:
            raise SplitError("已跟踪文件有未提交改动（回滚时会被覆盖）:\n" + dirty[:600]
                             + "\n先 commit/stash，或显式 --allow-dirty（不推荐）")

        groups = load_groups(a.groups)
        steps = plan(repo, base, head, groups)

        if not a.apply:
            out = {"ok": True, "dry_run": True, "base": base[:8], "head": head[:8],
                   "groups": [{"group": s["group"], "name": s["name"],
                               "whole": s["whole"], "hunks": s["hunks"]} for s in steps]}
            if a.json:
                print(json.dumps(out, ensure_ascii=False, indent=1))
            else:
                print("[dry-run] base=%s head=%s  共 %d 组（未改动任何东西）"
                      % (base[:8], head[:8], len(steps)))
                for s in steps:
                    parts = list(s["whole"]) + ["%s#%s" % (p, ids) for p, ids in s["hunks"].items()]
                    print("  %d) %s" % (s["group"], s["name"]))
                    print("     %s" % ", ".join(parts))
                print("\n确认无误后加 --apply 执行")
            return 0

        done = execute(repo, base, head, steps)
        out = {"ok": True, "dry_run": False, "base": base[:8], "orig": head[:8],
               "commits": done, "count": len(done)}
        if a.json:
            print(json.dumps(out, ensure_ascii=False, indent=1))
        else:
            print("[split] 完成：%d 个提交（原 HEAD %s → 新 HEAD %s）"
                  % (len(done), head[:8], rev(repo, "HEAD")[:8]))
            for d in done:
                print("  %s  %s  (%d 文件)" % (d["sha"], d["name"], d["files"]))
            print("[split] 树等价校验：通过（`git diff %s HEAD` 为空）" % head[:8])
        return 0
    except SplitError as e:
        if a.json:
            print(json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
        else:
            sys.stderr.write("[split][ERROR] %s\n" % e)
        return 2


if __name__ == "__main__":
    sys.exit(main())
