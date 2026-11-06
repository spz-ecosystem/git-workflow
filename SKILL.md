---
name: git-workflow
description: Git工作流统一管理skill，整合推送、分支、worktree、发版预检、安全审查、清理和历史管理工具。v2.1.2
---

# Git Workflow Umbrella Skill

七模块统一入口（`scripts/git-workflow.sh`，安装后为 `git-workflow`）。所有写操作都带前置检查，
破坏性操作默认要确认；**非交互环境一律 fail-closed**（见「非交互与确认」）。

## 快速开始

```bash
git-workflow                      # 总览（模块与常用操作）
git-workflow <模块> --help         # 模块级帮助
git-workflow selfcheck            # 加载安全网自检
git-workflow version              # 2.1.2
```

仓库内未安装时用 `bash scripts/git-workflow.sh <模块> <操作>`。

## 模块一览

| 模块 | 作用 | 主要操作 |
|---|---|---|
| `push` | 推送与 PR 回退 | `precheck` / `push` / `pr-fallback` |
| `branch` | 分支生命周期 | `create` / `delete` / `cleanup` / `status` / `restore` / `schedule` |
| `worktree` | 隔离工作树 | `create` / `delete` / `cleanup` |
| `release` | 发版 | `check` / `prepare` |
| `security` | 安全审查 | `review` / `audit` |
| `cleanup` | 清理 | `remote` / `worktree` / `branches` |
| `history` | 提交历史 | `undo-last` / `split` / `split-root` / `stage-pick` / `backup` / `commit-batch` |

## push

```bash
git-workflow push precheck                      # 预检（依赖同级 github-push 模块；缺失则跳过并提示）
git-workflow push push [--remote origin] [--branch <name>] [--timeout 60] [--push-url <url>] [--allow-main]
git-workflow push pr-fallback                   # 建 feature/<时间戳> 分支 + 推送 + gh pr create
```

- 默认**不依赖任何外部技能**：`push` 直接走原生 `git push`（`timeout` 默认 60s，最多 3 次，
  间隔 5s），凭据由你自己的 credential helper / 环境提供。
- 需要外部门禁（白名单、分支策略等）时**显式开启**委托：
  ```bash
  GIT_WORKFLOW_DELEGATE=gatekeeper          # 同级 spz-gatekeeper-r-sequence
  GIT_WORKFLOW_DELEGATE=/path/to/cli.sh     # 或你自己的工具（需支持 push confirm 契约）
  # 或写进 git-workflow.yaml：push.delegate: gatekeeper
  ```
  委托启用后置 `GIT_WORKFLOW_DELEGATING=1` 防「委托→提醒→委托」环路；委托失败会回落原生
  `git push` 并打印原因。
- 直推 `main/master` 是否被拒**由外部工具决定**；若对方要求显式授权，可用
  `--allow-main` 透传（仅本次调用有效）。
- 成功后若配置 `auto_cleanup: true`，自动执行 `branch cleanup --non-interactive --no-remote`。
- `pr-fallback` 的 origin 必须命中远端白名单：默认放行常见托管站
  （`github.com/` `gitlab.com/` `atomgit.com/` `gitee.com/` `codeberg.org/`），
  可用 `GW_PUSH_REMOTE_ALLOW`（逗号/冒号分隔）收紧或放开；未命中直接拒绝。

## branch

```bash
git-workflow branch create <name>               # 建分支 + 隔离 worktree
git-workflow branch delete <name>               # 先跑安全检查，确认后清 worktree + git branch -d
git-workflow branch cleanup [--dry-run] [--non-interactive] [--no-merged] [--no-remote] [--expire-days 30]
git-workflow branch status [--all] [--remote] [--no-merged] [--no-expired] [--expire-days 30]
git-workflow branch restore <name> [备份目录]
git-workflow branch schedule [--daily|--weekly|--monthly] [--day 0-6] [--time HH:MM] [--disable]
```

- `delete` 的安全检查 = `scripts/branch-delete-safety-check.sh --dry-run`：保护分支、当前分支、
  合并状态、未提交更改、最后提交时间、worktree 关联；任一不过则拒删。保护名单为硬编码的
  `main/master/develop/release/production`（配置 `branch.protection[]` 当前**未生效**）。
- `cleanup` 删前把分支引用备份到 `$BACKUP_DIR/branch-deletes/<时间戳>/`，失败可用 `restore` 还原。
- `cleanup` 默认排除 `main/master/develop/release/production/gh-pages`，可用配置
  `branch.cleanup.exclude[]` 追加。
- `create` 的 worktree 根固定为 `$HOME/.config/superpowers/worktrees/<repo>/<branch>`
  （**不读** `worktree.base_path`）；要自定义根或要 `--json` 机读，请用 `worktree create`。

## worktree

```bash
git-workflow worktree create <branch> [--from <ref>] [--json]
git-workflow worktree delete <branch> | --path <dir> [--force]
git-workflow worktree cleanup                   # 仅 git worktree prune（清元数据，不动目录）
```

- 根解析顺序：`GIT_WORKFLOW_WORKTREE_ROOT` → 配置 `worktree.base_path` →
  `$HOME/.config/superpowers/worktrees`。
- `create` 幂等：目标路径已是该分支的 worktree ⟹ 复用（`created=false`）；目录存在但分支不符
  ⟹ **拒绝覆盖**（exit 1）。分支不存在时必须给 `--from <ref>`。
- `delete --path` 用于**无分支的孤儿**（`worktree list | grep` 找不到的形态）；`--force` 跳过占用检查
  并强删（调用方应先完成归档）。
- `cleanup` 只清注册元数据；目录残留需由门禁回收链（`apply-worktree --reclaim`）处理。

## release

```bash
git-workflow release check
git-workflow release prepare <version>          # check + git checkout -b release/<version>
```

**如实口径**：`check` 目前只打印构建/测试/文档三个阶段，**不执行**真实构建或测试；需要真实门禁请
调用项目自身的 CI / `spz-gatekeeper-r-sequence` 的验收链。

## security

```bash
git-workflow security review                    # 骨架：输出分支保护/权限/操作历史检查项
git-workflow security audit                     # 落审计报告到 $LOG_DIR/audit_<时间戳>.txt
```

`audit` 报告内容 = 分支列表 + `git worktree list` + `git remote -v`；`review` 暂不做判定。

## cleanup

```bash
git-workflow cleanup remote                     # git fetch --prune
git-workflow cleanup worktree                   # git worktree prune
git-workflow cleanup branches                   # 删 temp/、tmp/、当日 feature/ 分支（需确认）
```

## history

```bash
git-workflow history undo-last                  # 撤销最近一次提交（保留工作区）
git-workflow history split --onto <base> --groups <groups.json> [--apply] [--allow-dirty] [--json]
git-workflow history split-root                 # 巨型初始提交检查 + 拆分建议
git-workflow history stage-pick                 # 文件列表 + 推荐拆分顺序
git-workflow history backup [路径]               # git bundle + uncommitted.patch + untracked.tar.gz
git-workflow history commit-batch <模块> <文件...> [--message <msg>]
```

- `split` 默认 **dry-run**；支持整文件（`paths`）与文件内第 N 个 hunk（`hunks`）。三条不变量：
  零遗漏 / 只重排不改内容 / 失败回滚；收尾强制树等价校验（`git diff <orig> HEAD` 必须为空）。
- `commit-batch` 不再交互：消息优先级 `--message` > `GW_COMMIT_MESSAGE` > 自动生成（会告警）。

## 配置（`git-workflow.yaml`）

路径：`GIT_WORKFLOW_CONFIG` → `<skill>/git-workflow.yaml`。

**当前被代码消费**的键：

| 键 | 作用 |
|---|---|
| `push.delegate` | 外部推送委托（`none` 默认 / `gatekeeper` / 可执行路径） |
| `push.precheck_cli` | 预检脚本路径（留空 = 跳过） |
| `worktree.base_path` | `worktree create` 的根 |
| `auto_cleanup: true` | 分支操作/推送成功后自动清理已合并分支 |
| `branch.cleanup.exclude[]` | 分支清理的排除名单 |

其余键（`push.timeout` / `push.retry_count` / `push.pr_fallback` / `branch.protection[]` /
`release.*` / `security.*` / `logging.*` / `notification.*` 等）为预留，当前不参与判定 ——
保护分支名单是硬编码的 `main/master/develop/release/production`。

## 环境变量

| 变量 | 作用 |
|---|---|
| `GIT_WORKFLOW_CONFIG` | 配置文件路径 |
| `GIT_WORKFLOW_LOG` | 日志目录（默认 `$HOME/.local/share/git-workflow/logs`） |
| `GIT_WORKFLOW_BACKUP` | 备份根（默认 `$HOME/.local/share/git-workflow/backups`） |
| `GIT_WORKFLOW_WORKTREE_ROOT` | 覆盖 worktree 根（优先于配置） |
| `GIT_WORKFLOW_AUTO_CLEANUP` | `true` 时等效于配置 `auto_cleanup: true` |
| `GIT_WORKFLOW_DELEGATE` | 外部推送委托：`none`（默认）/ `gatekeeper` / 可执行路径 |
| `GIT_WORKFLOW_PRECHECK_CLI` | 预检脚本路径（默认无） |
| `GW_ASSUME_YES` | `1` = 非交互确认直通（CI 用） |
| `GW_COMMIT_MESSAGE` | `commit-batch` 默认提交信息 |
| `GW_PUSH_REMOTE_ALLOW` | `pr-fallback` 远端白名单（逗号/冒号分隔；默认常见托管站） |

## 非交互与确认

`_gw_confirm` 的判据是**双条件**：`GW_ASSUME_YES=1` 直通；否则 stdin 必须是 tty，
**非 tty 一律拒绝**（不挂死、不静默放行）。CI 里请显式设 `GW_ASSUME_YES=1`。

## 加载安全网（改动核心脚本必读）

入口前置 `scripts/gk_gitworkflow_loader.py`，对三个核心脚本做 SHA256 pin：

```
git-workflow.sh · gw_history_split.py · branch-delete-safety-check.sh
```

状态四态：`builtin`（全命中）/ `dev`（未登记）/ `tampered`（哈希不符）/ `missing` / `error`。
**改任一核心脚本后必须同步 pin**，否则任何子命令被判 `tampered` 并 `exit 2`（即时生效，非约定）：

```bash
python3 scripts/gk_gitworkflow_loader.py status   # 期望 {"source":"builtin"}
```

## 凭据

- 唯一密钥库：`C:\Users\HP\.config\trae-secrets\github.token`（WSL `/mnt/c/.../github.token`）；
  只存 PAT，不入库、不进日志。
- 解析入口：`source scripts/gw_credentials.sh; t=$(gw_token)`；
  顺序：**密钥库 → `GITHUB_TOKEN` → `GH_TOKEN` → `gh auth token`**。
- `gw_export_env` 同时导出 `GH_TOKEN` / `GITHUB_TOKEN`（`gh` 因 PAT 缺 `read:org` 无法 `auth login` 时使用）。

## 典型流程

```bash
# 1) 隔离开发
git-workflow worktree create feature/x --from main --json

# 2) 提交与推送
git-workflow history commit-batch feature/x src/a.py src/b.py --message "feat: ..."
git-workflow push push

# 3) 收尾清理（先 dry-run 看计划）
git-workflow branch cleanup --dry-run
git-workflow branch delete feature/x

# 4) 发版
git-workflow release prepare 2.1.2
```

## 故障排查

| 现象 | 原因与处置 |
|---|---|
| 任意子命令 `exit 2` + `tampered` | 改了核心脚本未同步 loader pin ⟹ 重算 SHA256 写入 `_GITWORKFLOW_PINS` |
| `push` 报远端不在白名单 | `pr-fallback` 只放行两个组织前缀；改用 `push push` 或调整远端 |
| `push` 连续 3 次失败 | 看是否网络/TLS/凭据；`git push` 手工验证一次；凭据走 `gw_token` |
| `branch delete` 被拒 | 看 `branch-delete-safety-check.sh` 输出：保护分支/未合并/未提交/worktree 关联 |
| `worktree create` 报「目录已存在但不是该分支」 | 不覆盖；先确认目录归属，或换分支名/根 |
| 非交互脚本卡住/被拒 | 显式 `GW_ASSUME_YES=1`（脚本不会在非 tty 下静默放行） |
| `history split` 树不等价 | 按设计拒绝落盘；检查 `--groups` 是否遗漏 hunk |

## 相关文件

- 设计：`DESIGN.md` · 变更：`CHANGELOG.md` · 配置：`git-workflow.yaml`
- 脚本：`scripts/`（入口 `git-workflow.sh`、安全检查 `branch-delete-safety-check.sh`、
  拆分 `gw_history_split.py`、凭据 `gw_credentials.sh`、加载器 `gk_gitworkflow_loader.py`）
- 测试：`tests/`（`test_gk_gitworkflow_loader.py`、`test-git-workflow.sh`）
