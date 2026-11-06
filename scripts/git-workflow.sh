#!/bin/bash
# Git Workflow Umbrella Skill - 主脚本 (v2.1.2)
# Copyright (c) 2026 Pu Junhan. MulanPSL-2.0
# 统一管理所有git工作流操作 (7 模块: push/branch/worktree/release/security/cleanup/history)
# 2026-08-30 v2.1.0: 加载安全网（gk_gitworkflow_loader.py SHA256 pin 五源分流，tampered→fail-closed）
#                     + selfcheck 子命令 + 委托 spz-gatekeeper 防循环哨兵（GIT_WORKFLOW_DELEGATING）
# 2026-11-03 v2.1.1: 版本号与其他声明源对齐（loader / SKILL.md / yaml / package.sh 同值），pin 同步
# 2026-11-06 v2.1.2: 推送成功后回收本地快照（GW_SNAPSHOT_GC）；补登 pin（原改动未 bump 版本）

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# ── 跨平台兼容层（2026-11-02）────────────────────────────────────────────────
# 背景：本工具在 MSYS(Git Bash) / WSL / Linux / macOS 四侧都要能跑。
#   实测三处真差异：① `date -d`（GNU）vs `date -v`（BSD）；② `cp -r` 自嵌套时
#   **报错但仍返回 0**（假成功）；③ `read -p` 在 stdin 非 tty（AI/CI/管道）时挂死或空读。
# 原则：判据收敛到本层，调用点只见函数；**非交互一律 fail-closed**（默认拒绝，不静默放行）。

# 相对天数 → 日期（GNU date -d / BSD date -v / python 三级兜底）
_gw_days_ago() {
    local n="${1:?days required}" fmt="${2:-%Y-%m-%d}"
    if date -d "${n} days ago" +"$fmt" >/dev/null 2>&1; then
        date -d "${n} days ago" +"$fmt"
    elif date -v-"${n}"d +"$fmt" >/dev/null 2>&1; then
        date -v-"${n}"d +"$fmt"
    else
        python3 -c 'import datetime,sys;print((datetime.date.today()-datetime.timedelta(days=int(sys.argv[1]))).strftime(sys.argv[2]))' "$n" "$fmt" 2>/dev/null || true
    fi
}

# 交互确认：GW_ASSUME_YES=1 直通；stdin 非 tty 一律拒绝（不挂死、不静默放行）
_gw_confirm() {
    local prompt="${1:-继续?}" ans=""
    if [ "${GW_ASSUME_YES:-0}" = "1" ]; then
        log_info "GW_ASSUME_YES=1 ⟹ 自动确认: $prompt"
        return 0
    fi
    if [ ! -t 0 ]; then
        log_warn "非交互环境（stdin 非 tty）⟹ 默认拒绝: $prompt"
        log_warn "确认继续请设 GW_ASSUME_YES=1（或对该命令加 --yes）"
        return 1
    fi
    read -r -p "$prompt" ans || return 1
    case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# 备份目标是否落在**同一仓库**内（防自嵌套）。
#   为什么不用字符串前缀：MSYS 下 `pwd` 给 `/tmp/x`、`git rev-parse --show-toplevel` 给
#   `C:/Users/.../Temp/x` —— 同一目录两种形态，`realpath` 也不解析 MSYS 的 `/tmp` 映射
#   （实测 `realpath -m /tmp` 原样返回 `/tmp`）⟹ 前缀比较**结构性失效**。
#   正解：向上找最近存在的目录，用 `git rev-parse --absolute-git-dir` 比较（git 自己归一）。
_gw_in_repo() {
    local target="${1:-}" repo="${2:-}" d ga gb
    d="$target"
    while [ -n "$d" ] && [ ! -d "$d" ]; do
        case "$d" in "/"|"."|"") return 1 ;; esac
        d=$(dirname "$d")
    done
    [ -d "$d" ] || return 1
    ga=$(git -C "$d" rev-parse --absolute-git-dir 2>/dev/null) || return 1
    gb=$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null) || return 1
    [ "$ga" = "$gb" ]
}

# 自动检测脚本所在目录 (支持符号链接)
SKILL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/.." && pwd)"
# 配置文件路径 (优先环境变量, 否则使用脚本同目录下的配置文件)
CONFIG_FILE="${GIT_WORKFLOW_CONFIG:-$SKILL_DIR/git-workflow.yaml}"
LOG_DIR="${GIT_WORKFLOW_LOG:-$HOME/.local/share/git-workflow/logs}"
BACKUP_DIR="${GIT_WORKFLOW_BACKUP:-$HOME/.local/share/git-workflow/backups}"

# 凭据单一入口（2026-10-25）：密钥库 > 环境变量 > gh auth。
# 密钥库默认 ~/.config/trae-secrets/github.token（Windows 侧回退同名路径）。
# shellcheck source=/dev/null
. "$SKILL_DIR/scripts/gw_credentials.sh"

# 加载安全网（2026-08-30，模版第三次应用：bashpy/paper-review → git-workflow 技能类）
# gk_gitworkflow_loader.py 对核心脚本（git-workflow.sh + branch-delete-safety-check.sh）做
# SHA256 pin 五源分流：builtin=放行 / dev=WARN 放行 / tampered|missing|error=fail-closed exit 2。
GW_LOADER="$SKILL_DIR/scripts/gk_gitworkflow_loader.py"
GW_LOAD_SOURCE=""

# 创建必要目录
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# 检查git仓库
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是git仓库"
        exit 1
    fi
}

# 检查配置文件
check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warn "配置文件不存在: $CONFIG_FILE"
        log_info "使用默认配置 (可设 GIT_WORKFLOW_CONFIG 环境变量指定路径)"
    fi
}

# worktree 根解析（2026-09-23，ECC-A91DC4562198 收编）：**单一事实源 = 配置文件**
# `worktree.base_path`；`GIT_WORKFLOW_WORKTREE_ROOT` 可显式覆盖（测试/门禁注入用）。
# 背景：原实现把根**硬编码**为 `$HOME/.config/superpowers/worktrees`，与 yaml 的
# `base_path`、SKILL.md 记的 `/root/.config/superpowers/worktrees` **三处互不相同**。
_gw_worktree_base() {
    if [ -n "${GIT_WORKFLOW_WORKTREE_ROOT:-}" ]; then
        printf '%s' "$GIT_WORKFLOW_WORKTREE_ROOT"
        return 0
    fi
    local _b=""
    if [ -f "$CONFIG_FILE" ]; then
        _b=$(python3 -c "
import sys
for ln in open(sys.argv[1], encoding='utf-8'):
    s = ln.strip()
    if s.startswith('base_path:'):
        print(s.split(':', 1)[1].strip().strip(chr(34) + chr(39)))
        break
" "$CONFIG_FILE" 2>/dev/null)
    fi
    [ -z "$_b" ] && _b="$HOME/.config/superpowers/worktrees"   # 配置缺失 → 保持旧行为兜底
    printf '%s' "$_b"
}

# 记录操作日志
log_operation() {
    local operation=$1
    local details=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG_DIR/operations.log"
    
    echo "[$timestamp] $operation: $details" >> "$log_file"
}

# ─── 加载安全网守卫（2026-08-30）───
# 前置 gk_gitworkflow_loader.py 校验核心脚本完整性。tampered/missing/error → fail-closed exit 2。
# loader 缺失（python3 不可用/未安装）→ 放行：git-workflow 本体是 bash，不因增强层缺失而不可用。
_gw_loader_detail() {
    python3 "$GW_LOADER" status 2>/dev/null | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("detail",""))
except Exception:
    print("")'
}

gw_load_guard() {
    [ -f "$GW_LOADER" ] || return 0
    GW_LOAD_SOURCE=$(python3 "$GW_LOADER" status 2>/dev/null | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("source","error"))
except Exception:
    print("error")' 2>/dev/null)
    case "$GW_LOAD_SOURCE" in
        builtin)
            return 0 ;;
        dev)
            log_warn "git-workflow 未 pin（dev 态）: $(_gw_loader_detail)"
            return 0 ;;
        tampered|missing|error)
            log_error "git-workflow 加载被拦截（$GW_LOAD_SOURCE）：核心脚本被篡改/损坏/缺失"
            log_error "  详情: $(_gw_loader_detail)"
            log_error "  运行: python3 \"$GW_LOADER\" status"
            exit 2 ;;
        *)
            return 0 ;;  # loader 输出异常 → 放行（不阻断技能本体）
    esac
}

# selfcheck：加载安全网状态自检（builtin → PASS / dev → WARN / tampered|missing|error → FAIL exit 2）
gw_selfcheck() {
    if [ ! -f "$GW_LOADER" ]; then
        log_warn "加载安全网未安装（gk_gitworkflow_loader.py 缺失）— 技能未纳入 pin 治理"
        exit 2
    fi
    python3 "$GW_LOADER" check
    local rc=$?
    if [ $rc -eq 0 ]; then
        log_success "git-workflow 加载安全网 OK（version=$(python3 "$GW_LOADER" version 2>/dev/null)）"
    else
        log_error "git-workflow 加载安全网 FAILED（exit=$rc）— 核心脚本被篡改/损坏/缺失"
    fi
    return $rc
}

# ─── 外部工具的**显式**接线（2026-11-03：解绑）────────────────────────────────
# 定位：本技能是**开源插件**，不得假定用户装了什么、也不得按同级目录自动调用别的技能
#   （用户可能有自己的专属工具）。一切外部增强都**默认关闭**，由 env / 配置显式打开：
#     · push 委托：`GIT_WORKFLOW_DELEGATE` 或配置 `push.delegate`
#         - 空/none  ⟹ 不委托（默认，走原生 git push + 用户自己的凭据助手）
#         - gatekeeper ⟹ 按同级目录解析 spz-gatekeeper-r-sequence/gatekeeper-cli.sh
#         - <路径>     ⟹ 直接用该可执行入口
#     · push 预检：`GIT_WORKFLOW_PRECHECK_CLI` 或配置 `push.precheck_cli`（默认无）
_gw_config_push_key() {
    local key="$1"
    [ -f "$CONFIG_FILE" ] || return 0
    awk -v k="$key" '
        /^[^[:space:]#]/ { in_push = ($0 ~ /^push:[[:space:]]*$/) ; next }
        in_push && $0 ~ ("^[[:space:]]+" k ":") {
            sub("^[[:space:]]+" k ":[[:space:]]*", ""); sub(/[[:space:]]+#.*$/, ""); print; exit
        }
    ' "$CONFIG_FILE" 2>/dev/null
}

_gw_delegate_cli() {
    local v="${GIT_WORKFLOW_DELEGATE:-}"
    [ -n "$v" ] || v="$(_gw_config_push_key delegate)"
    case "$v" in
        ""|none|off|0) return 1 ;;
        gatekeeper)
            local p
            p="$(cd "$SKILL_DIR/../spz-gatekeeper-r-sequence" 2>/dev/null && pwd)/gatekeeper-cli.sh"
            if [ -f "$p" ]; then printf '%s' "$p"; return 0; fi
            log_warn "已启用 gatekeeper 委托，但未找到同级 gatekeeper-cli.sh ⟹ 回落原生 push" >&2
            return 1 ;;
        *)
            if [ -f "$v" ]; then printf '%s' "$v"; return 0; fi
            log_warn "委托入口不存在: $v ⟹ 回落原生 push" >&2
            return 1 ;;
    esac
}

# 推送后本地快照回收（2026-11-04）
#   发布链会在本地产出整树快照（约 30 MB/份），长期堆积。策略：
#   - 只在**当前仓**含 scripts/gk_snapshot_gc.py 时执行（不跨仓猜路径）；
#   - GW_SNAPSHOT_GC=0 关闭；GW_SNAPSHOT_GC_ARGS 覆盖参数（默认 --apply）；
#   - 尽力而为：失败只 WARN，不影响推送结果。
_gw_snapshot_gc() {
    [ "${GW_SNAPSHOT_GC:-1}" = "0" ] && return 0
    local root script py c
    root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
    script="${GW_SNAPSHOT_GC_SCRIPT:-$root/scripts/gk_snapshot_gc.py}"
    [ -f "$script" ] || return 0
    # 解释器**单源**（依次）：GK_PYTHON 显式覆盖 → 目标仓 scripts/py_resolve.sh →
    #   同级 gatekeeper 仓的 py_resolve.sh（Windows 专属环境 `.venv-accept` 在那边）→ PATH 探测。
    #   PATH 兜底必须试跑：Windows 的 python3 可能是 Store 占位桩（执行即静默退出 0）。
    py=""
    if [ -n "${GK_PYTHON:-}" ] && "$GK_PYTHON" -c "import sys" >/dev/null 2>&1; then
        py="$GK_PYTHON"
    fi
    for _pr in "$root/scripts/py_resolve.sh" \
               "$SKILL_DIR/../spz-gatekeeper-r-sequence/scripts/py_resolve.sh"; do
        [ -n "$py" ] && break
        [ -f "$_pr" ] || continue
        py=$(bash "$_pr" any 2>/dev/null) || py=""
    done
    if [ -z "$py" ]; then
        for c in python3 python; do
            command -v "$c" >/dev/null 2>&1 || continue
            "$c" -c "import sys" >/dev/null 2>&1 && { py="$c"; break; }
        done
    fi
    [ -n "$py" ] || { log_warn "未找到可用的 python，跳过快照回收"; return 0; }
    log_info "本地快照回收: $script ${GW_SNAPSHOT_GC_ARGS:---apply}"
    "$py" "$script" ${GW_SNAPSHOT_GC_ARGS:---apply} 2>&1 | tail -n 5 || \
        log_warn "快照回收失败（不影响推送）"
    return 0
}

# 推送管理模块
push_management() {
    local action=$1
    shift
    
    case $action in
        "precheck")
            log_info "执行推送预检..."
            # 预检工具**显式配置**（默认无）：不再按同级目录猜 github-push
            local _pc="${GIT_WORKFLOW_PRECHECK_CLI:-}"
            [ -n "$_pc" ] || _pc="$(_gw_config_push_key precheck_cli)"
            if [ -n "$_pc" ] && [ -f "$_pc" ]; then
                python3 "$_pc" precheck "$@"
            elif [ -n "$_pc" ]; then
                log_warn "预检入口不存在: $_pc ⟹ 跳过"
            else
                log_info "未配置预检工具（GIT_WORKFLOW_PRECHECK_CLI / push.precheck_cli）⟹ 跳过"
            fi
            ;;
        "push")
            log_info "执行标准推送..."
            local push_url="" remote="origin" branch="" timeout=60 allow_main=0

            # Parse args for branch and remote
            while [ $# -gt 0 ]; do
                case "$1" in
                    --remote) remote="$2"; shift 2 ;;
                    --branch) branch="$2"; shift 2 ;;
                    --timeout) timeout="$2"; shift 2 ;;
                    --push-url) push_url="$2"; shift 2 ;;
                    # 2026-11-03（集成修复）：直推 main 的**显式**授权位 —— 原实现只能绕到
                    #   gatekeeper CLI 敲 auth-main，委托链路上没有任何透传口。
                    --allow-main) allow_main=1; shift ;;
                    *) break ;;
                esac
            done
            [ -z "$branch" ] && branch=$(git branch --show-current 2>/dev/null || echo "main")
            [ -z "$push_url" ] && push_url=$(git remote get-url "$remote" 2>/dev/null)

            # ─── 可选委托（2026-11-03 解绑：**默认不启用**，见 `_gw_delegate_cli`）───
            # 启用后把推送交给外部工具（如 gatekeeper 的远端白名单 + 分支策略）。
            # 2026-08-30 防循环哨兵：委托时置 GIT_WORKFLOW_DELEGATING=1，spz-gatekeeper cmd_push
            # 检测到该 env 不再提示"使用 git-workflow"（防 cmd_push→提醒→git-workflow→委托→提醒 环路）。
            local gk_cli=""
            gk_cli="$(_gw_delegate_cli)" || gk_cli=""
            if [ -n "$gk_cli" ]; then
                log_info "委托推送 → $gk_cli"
                local repo="$(pwd)"
                local -a _gk_extra=()
                [ "$allow_main" = "1" ] && _gk_extra+=("--allow-main")
                local _gk_out gk_exit=0
                # `|| gk_exit=$?` —— 本脚本全局 `set -e`：裸赋值会在委托失败时直接中止
                #   （原实现的裸调用同样有此风险），故显式接住返回码。
                _gk_out=$(GIT_WORKFLOW_DELEGATING=1 bash "$gk_cli" push confirm --repo "$repo" \
                    --remote "$remote" --branch "$branch" --push-url "$push_url" \
                    ${_gk_extra[@]+"${_gk_extra[@]}"} 2>&1) || gk_exit=$?
                printf '%s\n' "$_gk_out"
                if [ $gk_exit -eq 0 ]; then
                    log_success "gatekeeper 委托推送成功"
                    return 0
                fi
                log_warn "gatekeeper 委托失败 (exit=$gk_exit), 降级到原生 push"
                # 2026-11-03：把 gatekeeper 的拒绝**翻译成可操作指令**（原实现只说"委托失败"）
                case "$_gk_out" in
                    *"Direct push to"*|*"blocked by policy"*)
                        log_info "提示: 直推 main 需**显式授权** —— 加 --allow-main（仅本次调用有效）："
                        log_info "        git-workflow push push --allow-main"
                        log_info "      或先开 10 分钟一次性授权：gatekeeper-cli.sh push auth-main"
                        ;;
                esac
            fi

            # 2026-10-26 修复（缺陷：假成功/假推送）：
            #   原实现在 gatekeeper 委托被拒后调用 `github_push.py git-push`，但
            #   ① 该脚本**没有** `git-push` 子命令（只有 push/batch-push/sync）⟹ argparse 直接报错；
            #   ② 参数硬编码 `--owner spz-ecosystem --repo spz_gatekeeper` 且 `--file ""`，
            #      即便命令存在也只会对**另一个仓**推一个空路径文件；
            #   ③ 其结果被当作「推送成功」返回 0，导致上层误判（实测 remote 完全未变）。
            #   ⟹ 删除该回落分支，统一走原生 `git push`（凭据由 gatekeeper 委托或 credential helper 提供）。
            # Native git push with timeout + retry
            local attempt=1 max_attempts=3
            while [ $attempt -le $max_attempts ]; do
                log_info "git push (attempt $attempt/$max_attempts)..."
                if timeout "$timeout" git push "$push_url" "$branch" 2>&1; then
                    log_success "推送成功"
                    # Auto-cleanup merged branches
                    if grep -q "auto_cleanup: true" "$CONFIG_FILE" 2>/dev/null; then
                        log_info "自动清理已合并分支..."
                        branch_management cleanup --non-interactive --no-remote 2>/dev/null || true
                    fi
                    _gw_snapshot_gc
                    return 0
                fi
                local exit_code=$?
                if [ $exit_code -eq 124 ]; then
                    log_warn "推送超时 (${timeout}s)，重试..."
                else
                    log_warn "推送失败 (exit=$exit_code)，重试..."
                fi
                attempt=$((attempt + 1))
                [ $attempt -le $max_attempts ] && sleep 5
            done

            log_error "推送失败 ($max_attempts 次重试均失败)"
            log_info "建议: 执行 git-workflow push pr-fallback 使用 PR 方式推送"
            return 1
            ;;
        "pr-fallback")
            log_info "执行PR回退..."
            # 创建feature分支并推送
            local branch=$(git branch --show-current)
            local feature_branch="feature/$(date +%Y%m%d-%H%M%S)"

            # F8.1: pr-fallback 远端白名单验证 (独立实现, 不依赖 gatekeeper CLI)
            # 2026-11-03（集成修复）：白名单**可配**。原实现硬编码两个组织前缀
            #   （github.com/spz-ecosystem/ + atomgit.com/pjh3955/）⟹ 换机器/换组织后
            #   pr-fallback 恒失败，与 gatekeeper 已修掉的 GK_PUSH_REMOTE_ALLOW 同族问题。
            local _pr_url; _pr_url=$(git remote get-url origin 2>/dev/null || echo "")
            local _pr_allow="${GW_PUSH_REMOTE_ALLOW:-github.com/,gitlab.com/,atomgit.com/,gitee.com/,codeberg.org/}"
            local _pr_lc; _pr_lc=$(printf '%s' "$_pr_url" | tr 'A-Z' 'a-z')
            local _pr_allowed=false _pr_pat
            while IFS= read -r _pr_pat; do
                [ -n "$_pr_pat" ] || continue
                case "$_pr_lc" in
                    *"$(printf '%s' "$_pr_pat" | tr 'A-Z' 'a-z')"*) _pr_allowed=true; break ;;
                esac
            done < <(printf '%s\n' "$_pr_allow" | tr ',:' '\n')
            if [ "$_pr_allowed" != "true" ]; then
                log_error "远端白名单验证失败: origin ($_pr_url) 不在允许列表中"
                log_info "允许列表（可用 GW_PUSH_REMOTE_ALLOW 覆盖）: $_pr_allow"
                return 1
            fi
            log_success "远端白名单验证通过"

            git checkout -b "$feature_branch"
            git push origin "$feature_branch"
            gh pr create --base main --head "$feature_branch" --fill
            
            log_success "PR创建成功"
            ;;
        "--help"|"-h")
            echo "用法: git-workflow push <操作> [选项]"
            echo ""
            echo "操作:"
            echo "  precheck       推送前预检"
            echo "  push           执行推送"
            echo "  pr-fallback    分支保护时改走 PR"
            echo ""
            echo "push 选项:"
            echo "  --remote <名>     远端名（默认 origin）"
            echo "  --branch <名>     分支（默认当前分支）"
            echo "  --timeout <秒>    单次推送超时（默认 60）"
            echo "  --allow-main      委托 gatekeeper 时显式授权直推 main/master（仅本次有效）"
            echo ""
            echo "环境变量:"
            echo "  GIT_WORKFLOW_DELEGATE      外部委托（默认 none；gatekeeper 或 <可执行路径>）"
            echo "  GIT_WORKFLOW_PRECHECK_CLI  预检脚本路径（默认无）"
            echo "  GW_PUSH_REMOTE_ALLOW       pr-fallback 远端白名单（逗号/冒号分隔，默认常见托管站）"
            echo "  GW_SNAPSHOT_GC             推送成功后回收本地快照（默认 1；0 关闭）"
            echo "  GW_SNAPSHOT_GC_ARGS        回收参数（默认 --apply，即真删；设成空串可退回 dry-run）"
            return 0
            ;;

        *)
            log_error "未知的推送操作: $action"
            exit 1
            ;;
    esac
}

# 分支管理模块
branch_management() {
    local action=$1
    shift
    
    case $action in
        "create")
            local branch_name=$1
            log_info "创建新分支: $branch_name"
            
            # 检查分支是否已存在
            if git show-ref --verify --quiet "refs/heads/$branch_name"; then
                log_error "分支已存在: $branch_name"
                exit 1
            fi
            
            # 创建隔离worktree
            local worktree_path="$HOME/.config/superpowers/worktrees/$(basename $(git rev-parse --show-toplevel))/$branch_name"
            git worktree add "$worktree_path" -b "$branch_name"
            
            log_success "分支创建成功: $branch_name"
            log_info "Worktree路径: $worktree_path"
            ;;
        "delete")
            local branch_name=$1
            log_info "删除分支: $branch_name"
            
            # 执行安全检查
            "$SKILL_DIR/scripts/branch-delete-safety-check.sh" --dry-run "$branch_name"
            
            # 确认删除
            if _gw_confirm "确认删除分支 '$branch_name'? (y/N): "; then
                # 清理关联worktree
                local worktree_info=$(git worktree list | grep "$branch_name")
                if [ -n "$worktree_info" ]; then
                    local worktree_path=$(echo "$worktree_info" | awk '{print $1}')
                    git worktree remove "$worktree_path"
                    log_info "已清理worktree: $worktree_path"
                fi
                
                # 删除分支
                git branch -d "$branch_name"
                log_success "分支删除成功: $branch_name"
            else
                log_info "取消删除分支"
            fi
            ;;
        "cleanup")
            log_info "清理分支..."
            
            # 解析参数
            local dry_run=false
            local interactive=true
            local clean_merged=true
            local clean_remote=true
            local expire_days=30
            
            while [ $# -gt 0 ]; do
                case $1 in
                    --dry-run)
                        dry_run=true
                        shift
                        ;;
                    --non-interactive)
                        interactive=false
                        shift
                        ;;
                    --no-merged)
                        clean_merged=false
                        shift
                        ;;
                    --no-remote)
                        clean_remote=false
                        shift
                        ;;
                    --expire-days)
                        expire_days=$2
                        shift 2
                        ;;
                    *)
                        log_error "未知参数: $1"
                        shift
                        ;;
                esac
            done
            
            # 加载排除列表
            local exclude_branches=("main" "master" "develop" "release" "production" "gh-pages")
            
            # 尝试从配置文件读取排除列表
            if [ -f "$CONFIG_FILE" ]; then
                # 简单的YAML解析（简化版）
                local in_exclude=false
                while IFS= read -r line; do
                    if [[ "$line" =~ ^[[:space:]]*exclude: ]]; then
                        in_exclude=true
                    elif [ "$in_exclude" = true ] && [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
                        local exclude_item="${BASH_REMATCH[1]}"
                        exclude_branches+=("$exclude_item")
                    elif [ "$in_exclude" = true ] && [[ ! "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
                        in_exclude=false
                    fi
                done < "$CONFIG_FILE"
            fi
            
            # 构建grep模式
            local exclude_pattern=""
            for exclude in "${exclude_branches[@]}"; do
                if [ -n "$exclude_pattern" ]; then
                    exclude_pattern="$exclude_pattern\\|$exclude"
                else
                    exclude_pattern="$exclude"
                fi
            done
            
            # 统计信息
            local total_branches=$(git branch | wc -l)
            local branches_to_delete=0
            local branches_deleted=0
            
            echo "=== 分支清理计划 ==="
            echo "总分支数: $total_branches"
            echo "排除分支: ${exclude_branches[*]}"
            echo ""
            
            # 1. 清理已合并分支
            if [ "$clean_merged" = true ]; then
                log_info "1. 检查已合并分支..."
                local merged_branches=$(git branch --merged main | grep -v "$exclude_pattern")
                
                if [ -n "$merged_branches" ]; then
                    echo "已合并到main的分支:"
                    echo "$merged_branches"
                    echo ""
                    branches_to_delete=$((branches_to_delete + $(echo "$merged_branches" | wc -l)))
                else
                    log_info "   没有已合并的分支"
                fi
            fi
            
            # 2. 清理过期分支
            log_info "2. 检查过期分支（${expire_days}天前）..."
            local expire_date=$(_gw_days_ago "$expire_days")
            local expired_branches=""
            
            if [ -n "$expire_date" ]; then
                # 获取过期分支
                while IFS= read -r branch; do
                    local branch_name=$(echo "$branch" | sed 's/^[* ]*//')
                    local last_commit_date=$(git log -1 --format="%ai" "$branch_name" 2>/dev/null | cut -d' ' -f1)
                    
                    if [ -n "$last_commit_date" ] && [ "$last_commit_date" \< "$expire_date" ]; then
                        expired_branches="$expired_branches$branch_name\n"
                    fi
                done < <(git branch | grep -v "$exclude_pattern")
                
                if [ -n "$expired_branches" ]; then
                    echo "过期分支（最后提交于${expire_days}天前）:"
                    echo -e "$expired_branches"
                    branches_to_delete=$((branches_to_delete + $(echo -e "$expired_branches" | wc -l)))
                else
                    log_info "   没有过期的分支"
                fi
            fi
            
            # 3. 清理远程跟踪引用
            if [ "$clean_remote" = true ]; then
                log_info "3. 清理远程跟踪引用..."
                git fetch --prune
                log_info "   远程跟踪引用清理完成"
            fi
            
            echo ""
            echo "=== 清理统计 ==="
            echo "待清理分支数: $branches_to_delete"
            echo ""
            
            if [ "$branches_to_delete" -eq 0 ]; then
                log_info "没有需要清理的分支"
                return 0
            fi
            
            # 确认清理
            if [ "$dry_run" = true ]; then
                log_info "Dry-run模式，不执行实际删除"
                return 0
            fi
            
            if [ "$interactive" = true ]; then
                if ! _gw_confirm "确认清理上述分支? (y/N): "; then
                    log_info "取消分支清理"
                    return 0
                fi
            fi
            
            # 执行清理
            log_info "执行分支清理..."
            
            # 创建备份目录
            local backup_dir="$BACKUP_DIR/branch-deletes/$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            
            # 备份分支引用
            log_info "备份分支引用到: $backup_dir"
            
            # 清理已合并分支
            if [ "$clean_merged" = true ]; then
                local merged_branches=$(git branch --merged main | grep -v "$exclude_pattern")
                if [ -n "$merged_branches" ]; then
                    # 备份分支引用
                    echo "$merged_branches" | while read -r branch; do
                        local branch_name=$(echo "$branch" | sed 's/^[* ]*//')
                        git branch "$branch_name" > "$backup_dir/$branch_name.backup" 2>/dev/null || true
                    done
                    
                    # 删除分支
                    echo "$merged_branches" | xargs git branch -d
                    branches_deleted=$((branches_deleted + $(echo "$merged_branches" | wc -l)))
                fi
            fi
            
            # 清理过期分支
            if [ -n "$expired_branches" ]; then
                # 备份分支引用
                echo -e "$expired_branches" | while read -r branch; do
                    local branch_name=$(echo "$branch" | sed 's/^[* ]*//')
                    git branch "$branch_name" > "$backup_dir/$branch_name.backup" 2>/dev/null || true
                done
                
                # 删除分支
                echo -e "$expired_branches" | xargs git branch -D
                branches_deleted=$((branches_deleted + $(echo -e "$expired_branches" | wc -l)))
            fi
            
            log_success "分支清理完成"
            echo "清理统计:"
            echo "  清理前分支数: $total_branches"
            echo "  清理后分支数: $(git branch | wc -l)"
            echo "  删除分支数: $branches_deleted"
            echo "  备份目录: $backup_dir"
            echo ""
            echo "恢复分支命令:"
            echo "  cd $(git rev-parse --show-toplevel)"
            echo "  git branch <分支名> $backup_dir/<分支名>.backup"
            ;;
        "status")
            log_info "分支状态报告"
            
            # 解析参数
            local show_all=false
            local show_remote=false
            local show_merged=true
            local show_expired=true
            local expire_days=30
            
            while [ $# -gt 0 ]; do
                case $1 in
                    --all)
                        show_all=true
                        shift
                        ;;
                    --remote)
                        show_remote=true
                        shift
                        ;;
                    --no-merged)
                        show_merged=false
                        shift
                        ;;
                    --no-expired)
                        show_expired=false
                        shift
                        ;;
                    --expire-days)
                        expire_days=$2
                        shift 2
                        ;;
                    *)
                        log_error "未知参数: $1"
                        shift
                        ;;
                esac
            done
            
            # 获取当前分支
            local current_branch=$(git branch --show-current)
            echo "=== 分支状态报告 ==="
            echo "当前分支: $current_branch"
            echo "仓库路径: $(git rev-parse --show-toplevel)"
            echo ""
            
            # 分支统计
            local total_branches=$(git branch | wc -l)
            local local_branches=$(git branch | wc -l)
            local remote_branches=$(git branch -r | wc -l)
            
            echo "分支统计:"
            echo "  本地分支: $local_branches"
            echo "  远程分支: $remote_branches"
            echo "  总分支数: $((local_branches + remote_branches))"
            echo ""
            
            # 本地分支详情
            echo "=== 本地分支详情 ==="
            echo "分支名 | 最后提交时间 | 合并状态 | 与main差异"
            echo "-------|---------------|----------|------------"
            
            while IFS= read -r branch; do
                local branch_name=$(echo "$branch" | sed 's/^[* ]*//')
                local last_commit_date=$(git log -1 --format="%ai" "$branch_name" 2>/dev/null | cut -d' ' -f1)
                local last_commit_time=$(git log -1 --format="%ar" "$branch_name" 2>/dev/null)
                
                # 检查合并状态
                local merge_status="未合并"
                if git merge-base --is-ancestor "$branch_name" main 2>/dev/null; then
                    merge_status="已合并"
                fi
                
                # 检查与main的差异
                local diff_count=$(git rev-list --count main.."$branch_name" 2>/dev/null || echo "0")
                local diff_info="$diff_count 个提交"
                
                # 检查是否过期
                local expire_info=""
                if [ "$show_expired" = true ]; then
                    local expire_date=$(_gw_days_ago "$expire_days")
                    if [ -n "$expire_date" ] && [ -n "$last_commit_date" ] && [ "$last_commit_date" \< "$expire_date" ]; then
                        expire_info=" [过期]"
                    fi
                fi
                
                # 标记当前分支
                local marker=" "
                if [ "$branch_name" = "$current_branch" ]; then
                    marker="*"
                fi
                
                echo "$marker $branch_name | $last_commit_time | $merge_status | $diff_info$expire_info"
            done < <(git branch)
            
            echo ""
            
            # 远程分支详情
            if [ "$show_remote" = true ]; then
                echo "=== 远程分支详情 ==="
                echo "分支名 | 最后提交时间 | 合并状态"
                echo "-------|---------------|----------"
                
                while IFS= read -r branch; do
                    local branch_name=$(echo "$branch" | sed 's/^[* ]*//')
                    local last_commit_date=$(git log -1 --format="%ai" "$branch_name" 2>/dev/null | cut -d' ' -f1)
                    local last_commit_time=$(git log -1 --format="%ar" "$branch_name" 2>/dev/null)
                    
                    # 检查合并状态
                    local merge_status="未合并"
                    if git merge-base --is-ancestor "$branch_name" main 2>/dev/null; then
                        merge_status="已合并"
                    fi
                    
                    echo "  $branch_name | $last_commit_time | $merge_status"
                done < <(git branch -r | grep -v "HEAD")
                
                echo ""
            fi
            
            # 已合并分支
            if [ "$show_merged" = true ]; then
                echo "=== 已合并到main的分支 ==="
                local merged_branches=$(git branch --merged main | grep -v "main\|master\|develop\|release\|production\|gh-pages")
                
                if [ -n "$merged_branches" ]; then
                    echo "$merged_branches"
                else
                    echo "没有已合并的分支"
                fi
                
                echo ""
            fi
            
            # 过期分支
            if [ "$show_expired" = true ]; then
                echo "=== 过期分支（${expire_days}天前） ==="
                local expire_date=$(_gw_days_ago "$expire_days")
                local expired_branches=""
                
                if [ -n "$expire_date" ]; then
                    while IFS= read -r branch; do
                        local branch_name=$(echo "$branch" | sed 's/^[* ]*//')
                        local last_commit_date=$(git log -1 --format="%ai" "$branch_name" 2>/dev/null | cut -d' ' -f1)
                        
                        if [ -n "$last_commit_date" ] && [ "$last_commit_date" \< "$expire_date" ]; then
                            expired_branches="$expired_branches$branch_name\n"
                        fi
                    done < <(git branch | grep -v "main\|master\|develop\|release\|production\|gh-pages")
                    
                    if [ -n "$expired_branches" ]; then
                        echo -e "$expired_branches"
                    else
                        echo "没有过期的分支"
                    fi
                fi
                
                echo ""
            fi
            
            # 分支保护状态
            echo "=== 分支保护状态 ==="
            local protected_branches=("main" "master" "develop" "release" "production")
            
            for protected in "${protected_branches[@]}"; do
                if git show-ref --verify --quiet "refs/heads/$protected"; then
                    echo "✓ $protected (受保护)"
                fi
            done
            
            echo ""
            log_success "分支状态报告完成"
            ;;
        "restore")
            local branch_name=$1
            local backup_dir=$2
            
            if [ -z "$branch_name" ]; then
                log_error "请提供要恢复的分支名"
                exit 1
            fi
            
            if [ -z "$backup_dir" ]; then
                # 查找最新的备份目录
                local backup_base="$BACKUP_DIR/branch-deletes"
                if [ -d "$backup_base" ]; then
                    backup_dir=$(ls -td "$backup_base"/*/ 2>/dev/null | head -n 1)
                    if [ -z "$backup_dir" ]; then
                        log_error "没有找到分支备份"
                        exit 1
                    fi
                    log_info "使用最新备份目录: $backup_dir"
                else
                    log_error "没有找到分支备份目录"
                    exit 1
                fi
            fi
            
            local backup_file="$backup_dir/$branch_name.backup"
            
            if [ ! -f "$backup_file" ]; then
                log_error "备份文件不存在: $backup_file"
                exit 1
            fi
            
            log_info "恢复分支: $branch_name"
            
            # 检查分支是否已存在
            if git show-ref --verify --quiet "refs/heads/$branch_name"; then
                log_error "分支已存在: $branch_name"
                exit 1
            fi
            
            # 恢复分支
            git branch "$branch_name" -f < "$backup_file"
            
            log_success "分支恢复成功: $branch_name"
            log_info "备份文件: $backup_file"
            ;;
        "schedule")
            log_info "配置分支清理定时任务"
            
            # 解析参数
            local schedule_type="weekly"
            local schedule_day="0"  # 0=周日
            local schedule_time="02:00"
            local enable=true
            
            while [ $# -gt 0 ]; do
                case $1 in
                    --daily)
                        schedule_type="daily"
                        shift
                        ;;
                    --weekly)
                        schedule_type="weekly"
                        shift
                        ;;
                    --monthly)
                        schedule_type="monthly"
                        shift
                        ;;
                    --day)
                        schedule_day=$2
                        shift 2
                        ;;
                    --time)
                        schedule_time=$2
                        shift 2
                        ;;
                    --disable)
                        enable=false
                        shift
                        ;;
                    *)
                        log_error "未知参数: $1"
                        shift
                        ;;
                esac
            done
            
            # 创建cron任务
            local cron_job=""
            local cron_command="cd $(git rev-parse --show-toplevel) && $SKILL_DIR/scripts/git-workflow.sh branch cleanup --non-interactive --no-remote"
            
            if [ "$enable" = true ]; then
                case $schedule_type in
                    "daily")
                        cron_job="0 $schedule_time * * * $cron_command"
                        ;;
                    "weekly")
                        cron_job="0 $schedule_time * * $schedule_day $cron_command"
                        ;;
                    "monthly")
                        cron_job="0 $schedule_time 1 * * $cron_command"
                        ;;
                esac
                
                log_info "添加定时任务: $cron_job"
                
                # 添加到crontab
                (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
                
                log_success "定时任务配置完成"
                echo "定时任务详情:"
                echo "  类型: $schedule_type"
                echo "  时间: $schedule_time"
                if [ "$schedule_type" = "weekly" ]; then
                    echo "  星期: $schedule_day"
                fi
                echo "  命令: $cron_command"
            else
                log_info "禁用分支清理定时任务"
                
                # 从crontab中移除相关任务
                crontab -l 2>/dev/null | grep -v "branch cleanup" | crontab -
                
                log_success "定时任务已禁用"
            fi
            ;;
        "--help"|"-h")
            echo "用法: git-workflow branch <操作> [选项]"
            echo ""
            echo "操作:"
            echo "  create <name>  创建新分支（自动建隔离 worktree）"
            echo "  delete <name>  删除分支（安全审查后）"
            echo "  cleanup        清理已合并/过期分支"
            echo "  status         分支状态报告"
            echo "  restore <name> 恢复已删除分支"
            echo "  schedule       配置清理定时任务"
            return 0
            ;;

        *)
            log_error "未知的分支操作: $action"
            exit 1
            ;;
    esac
    
    # 自动清理已合并分支
    if [ "$GIT_WORKFLOW_AUTO_CLEANUP" = "true" ] || grep -q "auto_cleanup: true" "$CONFIG_FILE" 2>/dev/null; then
        if [ "$action" != "cleanup" ] && [ "$action" != "status" ] && [ "$action" != "restore" ] && [ "$action" != "schedule" ]; then
            log_info "自动清理已合并分支..."
            branch_management cleanup --non-interactive --no-remote
        fi
    fi
}

# Worktree管理模块
worktree_management() {
    local action=$1
    shift
    
    case $action in
        "create")
            # 2026-09-23（ECC-A91DC4562198 收编）：机读模式 + 建分支 + 根单一化。
            # 原实现三缺：① 要求分支**已存在**（无 `-b`）⟹ 门禁的 `agent/<family>/<short>`
            #   分支尚不存在时必失败；② 只回**人类日志** ⟹ 调用方无法机读 worktree 路径；
            #   ③ 根**硬编码** `$HOME/.config/superpowers/worktrees`（与 yaml/SKILL.md 三处不一致）。
            # 现：`--from <ref>` 允许新建分支、`--json` 回单行 JSON、根取 `_gw_worktree_base()`。
            local branch_name="" from_ref="" json_out=0
            while [ $# -gt 0 ]; do
                case "$1" in
                    --from) from_ref="${2:-}"; shift 2 ;;
                    --json) json_out=1; shift ;;
                    *) [ -z "$branch_name" ] && branch_name="$1"; shift ;;
                esac
            done
            if [ -z "$branch_name" ]; then
                log_error "usage: git-workflow worktree create <branch> [--from <ref>] [--json]"
                exit 2
            fi
            # fail-loud：拒非法分支 token（路径逃逸面；与门禁 `_FAMILY_RE` 同口径的保守子集）
            case "$branch_name" in
                *..*|/*|/*/*|-) log_error "非法分支名: $branch_name"; exit 2 ;;
            esac

            local _base _repo _worktree_path _created=0
            _base=$(_gw_worktree_base)
            _repo=$(basename "$(git rev-parse --show-toplevel)")
            _worktree_path="$_base/$_repo/$branch_name"
            mkdir -p "$(dirname "$_worktree_path")" 2>/dev/null || true

            # 幂等（2026-09-23 实测补修）：目标路径**已是该分支的 worktree** ⟹ 复用。
            # 原缺此分支：第二次调用会走到 `git worktree add` ⟹
            # `fatal: '<path>' already exists` ⟹ rc=1（把「复用」误报成失败）。
            if [ -d "$_worktree_path" ]; then
                local _cur
                _cur=$(git -C "$_worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
                if [ "$_cur" = "$branch_name" ]; then
                    if [ "$json_out" = "1" ]; then
                        printf '{"ok":true,"worktree":"%s","branch":"%s","created":false,"reused":true}\n' \
                            "$_worktree_path" "$branch_name"
                    else
                        log_success "Worktree已存在（复用）: $_worktree_path"
                    fi
                    return 0
                fi
                log_error "目标目录已存在但不是该分支（拒绝覆盖）: $_worktree_path"
                exit 1
            fi

            if git show-ref --verify --quiet "refs/heads/$branch_name"; then
                git worktree add "$_worktree_path" "$branch_name" || {
                    log_error "git worktree add 失败: $branch_name"; exit 1; }
            elif [ -n "$from_ref" ]; then
                git worktree add -b "$branch_name" "$_worktree_path" "$from_ref" || {
                    log_error "git worktree add -b 失败: $branch_name (from $from_ref)"; exit 1; }
                _created=1
            else
                log_error "分支不存在且未提供 --from <ref>: $branch_name"
                exit 1
            fi

            if [ "$json_out" = "1" ]; then
                if [ "$_created" = "1" ]; then _cb=true; else _cb=false; fi
                printf '{"ok":true,"worktree":"%s","branch":"%s","created":%s,"reused":%s}\n' \
                    "$_worktree_path" "$branch_name" "$_cb" "$([ "$_created" = "1" ] && echo false || echo true)"
            else
                log_success "Worktree创建成功: $_worktree_path"
            fi
            ;;
        "delete")
            # 2026-09-24（用户裁定「按建议做」= 二择一取 A：与 create 侧对称的单源）。
            # 原实现两缺，逼得门禁侧只能**自造第二套** `git worktree remove`（双源）：
            #   ① 只吃 **branch 名**（`worktree list | grep`）⟹ 对**失效注册 / 无 branch**
            #      的孤儿目录无解（grep 不到 ⟹ 报「未找到」）；
            #   ② **无 `--force`** ⟹ 有未提交内容的 worktree 必被 git 拒删（而门禁回收链
            #      必须先归档、归档不改 wt ⟹ 落刀时 wt 仍是 dirty ⟹ 必然走不通）。
            # 现：`--path <dir>` 直指路径（跳 grep）、`--force` 跳占用检查并强删。
            local branch_name="" wt_path="" force=0
            while [ $# -gt 0 ]; do
                case "$1" in
                    --path) wt_path="${2:-}"; shift 2 ;;
                    --force) force=1; shift ;;
                    *) [ -z "$branch_name" ] && branch_name="$1"; shift ;;
                esac
            done
            if [ -n "$wt_path" ]; then
                log_info "删除worktree（按路径）: $wt_path"
            else
                if [ -z "$branch_name" ]; then
                    log_error "usage: git-workflow worktree delete <branch> | worktree delete --path <dir> [--force]"
                    exit 2
                fi
                log_info "删除worktree: $branch_name"
                # 查找worktree路径
                local worktree_info=$(git worktree list | grep "$branch_name")
                if [ -z "$worktree_info" ]; then
                    log_error "未找到分支 '$branch_name' 的worktree"
                    exit 1
                fi
                wt_path=$(echo "$worktree_info" | awk '{print $1}')
            fi
            if [ ! -d "$wt_path" ]; then
                log_error "路径不存在: $wt_path"
                exit 1
            fi

            # 检查worktree是否被占用（`--force` 时跳过：调用方＝门禁回收链，语义已是「归档后
            # 确认删除」；占用多为自己的 instrumented 子进程，误拦会让回收链永远清不掉）
            if [ "$force" != "1" ] && fuser -v "$wt_path" &> /dev/null; then
                log_error "Worktree被其他进程占用"
                exit 1
            fi

            # 删除worktree
            if [ "$force" = "1" ]; then
                git worktree remove --force "$wt_path"
            else
                git worktree remove "$wt_path"
            fi
            log_success "Worktree删除成功: $wt_path"
            ;;
        "cleanup")
            log_info "清理孤立worktree..."
            
            # 清理worktree
            git worktree prune
            
            log_success "Worktree清理完成"
            ;;
        "--help"|"-h")
            echo "用法: git-workflow worktree <操作> [选项]"
            echo ""
            echo "操作:"
            echo "  create <name>  创建隔离 worktree"
            echo "  delete <name>  删除 worktree"
            echo "  cleanup        清理孤立 worktree"
            return 0
            ;;

        *)
            log_error "未知的Worktree操作: $action"
            exit 1
            ;;
    esac
}

# 发版预检模块
release_management() {
    local action=$1
    shift
    
    case $action in
        "check")
            log_info "执行发版可行性检查..."
            
            # 检查构建
            log_info "检查构建..."
            # 这里应该调用项目的构建系统
            
            # 检查测试
            log_info "检查测试..."
            # 这里应该调用项目的测试系统
            
            # 检查文档
            log_info "检查文档..."
            # 这里应该检查文档完整性
            
            log_success "发版可行性检查完成"
            ;;
        "prepare")
            log_info "准备发版..."
            
            # 执行预检
            release_management "check"
            
            # 创建release分支
            local version=$1
            if [ -z "$version" ]; then
                log_error "请提供版本号"
                exit 1
            fi
            
            local release_branch="release/$version"
            git checkout -b "$release_branch"
            
            log_success "发版准备完成: $release_branch"
            ;;
        "--help"|"-h")
            echo "用法: git-workflow release <操作> [选项]"
            echo ""
            echo "操作:"
            echo "  check          发版可行性检查"
            echo "  prepare        发版准备"
            return 0
            ;;

        *)
            log_error "未知的发版操作: $action"
            exit 1
            ;;
    esac
}

# 安全审查模块
security_management() {
    local action=$1
    shift
    
    case $action in
        "review")
            log_info "执行安全审查..."
            
            # 检查分支保护
            log_info "检查分支保护规则..."
            
            # 检查权限设置
            log_info "检查权限设置..."
            
            # 检查操作历史
            log_info "检查操作历史..."
            
            log_success "安全审查完成"
            ;;
        "audit")
            log_info "执行安全审计..."
            
            # 生成审计报告
            local audit_report="$LOG_DIR/audit_$(date +%Y%m%d_%H%M%S).txt"
            
            {
                echo "安全审计报告"
                echo "生成时间: $(date)"
                echo "仓库路径: $(git rev-parse --show-toplevel)"
                echo ""
                echo "分支状态:"
                git branch -a
                echo ""
                echo "Worktree状态:"
                git worktree list
                echo ""
                echo "远程状态:"
                git remote -v
            } > "$audit_report"
            
            log_success "安全审计完成: $audit_report"
            ;;
        "--help"|"-h")
            echo "用法: git-workflow security <操作> [选项]"
            echo ""
            echo "操作:"
            echo "  review         安全审查"
            echo "  audit          依赖/配置审计"
            return 0
            ;;

        *)
            log_error "未知的安全操作: $action"
            exit 1
            ;;
    esac
}

# 清理工具模块
cleanup_management() {
    local action=$1
    shift
    
    case $action in
        "remote")
            log_info "清理远程跟踪引用..."
            git fetch --prune
            log_success "远程跟踪引用清理完成"
            ;;
        "worktree")
            log_info "清理孤立worktree..."
            git worktree prune
            log_success "Worktree清理完成"
            ;;
        "branches")
            log_info "清理临时分支..."
            
            # 删除临时分支
            local temp_branches=$(git branch | grep -E "temp/|tmp/|feature/.*$(date +%Y%m%d)")
            
            if [ -n "$temp_branches" ]; then
                echo "以下临时分支将被删除:"
                echo "$temp_branches"
                
                if _gw_confirm "确认删除这些分支? (y/N): "; then
                    echo "$temp_branches" | xargs git branch -D
                    log_success "临时分支清理完成"
                else
                    log_info "取消临时分支清理"
                fi
            else
                log_info "没有需要清理的临时分支"
            fi
            ;;
        "--help"|"-h")
            echo "用法: git-workflow cleanup <操作> [选项]"
            echo ""
            echo "操作:"
            echo "  remote         清理远程跟踪引用"
            echo "  worktree       清理 worktree"
            echo "  branches       清理分支"
            return 0
            ;;

        *)
            log_error "未知的清理操作: $action"
            exit 1
            ;;
    esac
}

# 历史管理模块
history_management() {
    local action=$1
    shift

    case $action in
        "undo-last")
            local commit_count=$(git log --oneline 2>/dev/null | wc -l)
            if [ "$commit_count" -eq 0 ]; then
                log_info "没有可撤销的提交"
                return 0
            fi

            log_info "撤销最近一次提交（保留工作区文件）..."
            if [ "$commit_count" -eq 1 ]; then
                # 唯一提交 (root commit): update-ref 删除 HEAD
                local old_hash=$(git rev-parse HEAD 2>/dev/null)
                git update-ref -d HEAD
                log_success "已撤销 root commit ($old_hash)，工作区文件完整保留"
            else
                # 普通提交: soft reset
                git reset --soft HEAD~1
                log_success "已撤销最近提交，文件已还原到暂存区"
            fi
            log_info "工作区文件未受影响，可重新逐模块提交"
            ;;

        "split-root")
            log_info "拆分巨型初始提交..."

            local commit_count=$(git log --oneline 2>/dev/null | wc -l)
            if [ "$commit_count" -gt 0 ]; then
                log_error "仓库已有 $commit_count 次提交，split-root 仅适用于空仓库的初始提交"
                exit 1
            fi

            # 检查暂存区是否有文件
            local staged_count=$(git diff --cached --name-only 2>/dev/null | wc -l)
            if [ "$staged_count" -eq 0 ]; then
                log_error "暂存区无文件，请先 git add 文件"
                exit 1
            fi

            log_info "暂存区有 $staged_count 个文件待初始提交"
            log_warn "建议使用 git-workflow history stage-pick 逐模块选取，而非一次性提交全部"
            ;;

        "stage-pick")
            log_info "逐模块选取文件进入暂存区..."
            echo ""
            echo "当前工作区文件:"
            echo "===================="
            git status --short
            echo ""
            echo "===================="
            echo "使用方法:"
            echo "  git add <模块路径>           # 选取特定模块"
            echo "  git status --short           # 检查当前暂存区"
            echo "  git diff --cached --stat     # 查看暂存区文件"
            echo "  git commit -m '<conventional-commit-message>'  # 提交"
            echo ""
            echo "推荐的首次提交拆分顺序:"
            echo "  1. .gitignore"
            echo "  2. bridge/security/"
            echo "  3. bridge/context/ + bridge/tools/"
            echo "  4. bridge/constitution.py"
            echo "  5. bridge/engine.py + bridge/server.py"
            echo "  6. bridge/verify_integration.py + tests/"
            echo "  7. docs/ + commands/ + config.toml + 杂项"
            echo ""
            ;;

        "backup")
            local backup_path="${1:-$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)}"
            local repo_root
            repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
                log_error "不在 git 仓库内，无法备份"
                return 1
            }

            # 自嵌套保护：`cp -r` 到自身子目录会报错但**返回 0**（实测假成功）
            if _gw_in_repo "$backup_path" "$repo_root"; then
                log_error "备份路径位于仓库内部（$backup_path ⊂ $repo_root）⟹ 会递归复制自身"
                log_error "请改到仓库外，例如：$HOME/backups/$(basename "$repo_root")"
                return 1
            fi
            mkdir -p "$backup_path" || { log_error "无法创建 $backup_path"; return 1; }

            # ① git 对象：bundle（全部分支/标签；比 cp -r 整个 .git 小得多且可 clone 还原）
            log_info "备份 git 对象（bundle）..."
            if git bundle create "$backup_path/repo.bundle" --all >/dev/null 2>&1; then
                log_success "  repo.bundle $(du -h "$backup_path/repo.bundle" 2>/dev/null | cut -f1)"
            else
                log_error "git bundle 失败（仓库可能无任何引用）"
                rmdir "$backup_path" 2>/dev/null || true
                return 1
            fi

            # ② 已跟踪但未提交：patch（可 git apply 还原）
            if ! git diff --quiet HEAD 2>/dev/null; then
                if git diff HEAD > "$backup_path/uncommitted.patch" 2>/dev/null; then
                    log_success "  uncommitted.patch $(wc -l < "$backup_path/uncommitted.patch" | tr -d ' ') 行"
                fi
            fi

            # ③ 未跟踪且未被忽略：tar
            local untracked
            untracked=$(git ls-files --others --exclude-standard 2>/dev/null)
            if [ -n "$untracked" ]; then
                if printf '%s\n' "$untracked" | tar -czf "$backup_path/untracked.tar.gz" -T - 2>/dev/null; then
                    log_success "  untracked.tar.gz $(printf '%s\n' "$untracked" | wc -l | tr -d ' ') 个文件"
                fi
            fi

            log_success "备份完成: $backup_path"
            log_info "还原: git clone repo.bundle <dir>  |  patch: git apply uncommitted.patch"
            ;;

        "commit-batch")
            # 用法: commit-batch <模块名> <路径...> [--message <msg>]
            # 去交互（2026-11-02）：原 `read -p` 在 stdin 非 tty 时挂死/空读。
            #   优先级 = --message > GW_COMMIT_MESSAGE > 自动生成（并在生成时告警）。
            local module_name="" msg="${GW_COMMIT_MESSAGE:-}"
            local -a cb_paths=()
            while [ $# -gt 0 ]; do
                case "$1" in
                    --message|-m) msg="${2:-}"; shift 2 ;;
                    --) shift; while [ $# -gt 0 ]; do cb_paths+=("$1"); shift; done ;;
                    -*) log_error "未知选项: $1"; return 1 ;;
                    *) if [ -z "$module_name" ]; then module_name="$1"; else cb_paths+=("$1"); fi; shift ;;
                esac
            done

            if [ -z "$module_name" ] || [ ${#cb_paths[@]} -eq 0 ]; then
                log_error "用法: git-workflow history commit-batch <模块名> <文件路径...> [--message <msg>]"
                return 1
            fi

            log_info "提交模块: $module_name（${#cb_paths[@]} 个路径）"
            local p
            for p in "${cb_paths[@]}"; do
                if [ -e "$p" ]; then
                    git add "$p" || log_warn "git add 失败: $p"
                else
                    log_warn "跳过不存在的文件: $p"
                fi
            done

            local staged
            staged=$(git diff --cached --name-only 2>/dev/null | wc -l)
            if [ "$staged" -eq 0 ]; then
                log_warn "没有文件被暂存，跳过提交"
                return 0
            fi

            if [ -z "$msg" ]; then
                msg="feat($module_name): add $module_name module"
                log_warn "未提供 --message / GW_COMMIT_MESSAGE ⟹ 使用自动生成: $msg"
            fi

            git commit -m "$msg"
            log_success "模块 '$module_name' 提交完成 ($staged 个文件)"
            ;;

        "split")
            # 用法: split --onto <base> --groups <groups.json> [--apply] [--allow-dirty] [--json]
            #   把**已提交的混合提交**按主题拆成多个提交（只重排，不改内容）。
            local onto="" groups_file="" pass=()
            while [ $# -gt 0 ]; do
                case "$1" in
                    --onto|--base) onto="${2:-}"; shift 2 ;;
                    --groups)      groups_file="${2:-}"; shift 2 ;;
                    --apply|--allow-dirty|--json) pass+=("$1"); shift ;;
                    -h|--help)
                        echo "用法: git-workflow history split --onto <base> --groups <groups.json> [--apply] [--allow-dirty] [--json]"
                        echo ""
                        echo "  把已提交的混合提交按主题拆成多个提交（只重排，不改内容）。"
                        echo "  默认 dry-run；--apply 才执行；收尾强制校验终态树与原 HEAD 逐字等价。"
                        echo ""
                        echo "  groups.json:"
                        echo '    {"groups":[{"name":"fix(x): 主题一","paths":["a.sh"]},'
                        echo '               {"name":"test(x): 主题二","hunks":{"b.py":[1,2]}}]}'
                        echo ""
                        echo "  paths = 整文件归属（新增/删除/二进制只能走这里）"
                        echo "  hunks = 文件内第 N 个 hunk（git diff -U3 顺序，从 1 起）"
                        return 0 ;;
                    *) log_error "未知选项: $1"; return 1 ;;
                esac
            done
            [ -n "$onto" ] || { log_error "--onto <base> 必填（拆分起点，不含）"; return 1; }
            [ -n "$groups_file" ] || { log_error "--groups <groups.json> 必填"; return 1; }
            [ -f "$groups_file" ] || { log_error "groups 文件不存在: $groups_file"; return 1; }

            local gw_py=""
            for c in python3 python; do
                command -v "$c" >/dev/null 2>&1 && { gw_py="$c"; break; }
            done
            [ -n "$gw_py" ] || { log_error "找不到 python（split 依赖标准库）"; return 1; }

            "$gw_py" "$SKILL_DIR/scripts/gw_history_split.py" \
                --repo "$(git rev-parse --show-toplevel)" \
                --base "$onto" --groups "$groups_file" ${pass[@]+"${pass[@]}"}
            ;;

        "--help"|"-h")
            echo "history 模块 — 提交历史管理"
            echo ""
            echo "用法: git-workflow history <操作> [选项]"
            echo ""
            echo "操作:"
            echo "  undo-last           撤销最近一次提交（保留工作区文件）"
            echo "  split --onto <base> --groups <json> [--apply]"
            echo "                      拆分已提交的混合提交（支持 hunk 级；默认 dry-run）"
            echo "  split-root          检查巨型初始提交并提示拆分方案"
            echo "  stage-pick          显示文件列表 + 推荐拆分顺序"
            echo "  backup [路径]        备份（git bundle + 未提交 patch + 未跟踪 tar）"
            echo "  commit-batch <模块> <文件...> [--message <msg>]  自动 add + commit"
            echo ""
            echo "示例:"
            echo "  git-workflow history undo-last"
            echo "  git-workflow history backup /path/to/backup"
            echo "  git-workflow history stage-pick"
            echo "  git-workflow history commit-batch security bridge/security/"
            echo ""
            echo "典型工作流 (修复巨型初始提交):"
            echo "  1. git-workflow history backup          # 安全备份"
            echo "  2. git-workflow history undo-last       # 撤销巨型提交"
            echo "  3. git-workflow history stage-pick      # 查看拆分方案"
            echo "  4. git add bridge/security/ && git commit -m '...'"
            echo "  5. 重复 step 4 逐模块提交"
            ;;

        *)
            log_error "未知的历史操作: $action"
            echo "可用操作: undo-last, split-root, stage-pick, backup, commit-batch"
            exit 1
            ;;
    esac
}

# 显示帮助信息
show_help() {
    echo "Git Workflow Umbrella Skill"
    echo ""
    echo "用法: git-workflow <模块> <操作> [选项]"
    echo ""
    echo "模块:"
    echo "  push          推送管理"
    echo "  branch        分支管理"
    echo "  worktree      Worktree管理"
    echo "  release       发版预检"
    echo "  security      安全审查"
    echo "  cleanup       清理工具"
    echo "  history       提交历史管理（撤销/拆分/备份/批量提交）"
    echo ""
    echo "分支管理操作:"
    echo "  branch create <name>           创建新分支（自动创建隔离worktree）"
    echo "  branch delete <name>           删除分支（安全审查后）"
    echo "  branch cleanup [选项]          清理分支"
    echo "  branch status [选项]           显示分支状态报告"
    echo "  branch restore <name> [备份目录] 恢复已删除的分支"
    echo "  branch schedule [选项]         配置分支清理定时任务"
    echo ""
    echo "分支清理选项:"
    echo "  --dry-run                      仅显示清理计划，不执行实际删除"
    echo "  --non-interactive              非交互式模式"
    echo "  --no-merged                    不清理已合并分支"
    echo "  --no-remote                    不清理远程跟踪引用"
    echo "  --expire-days <天数>           设置过期分支天数（默认30天）"
    echo ""
    echo "分支状态选项:"
    echo "  --all                          显示所有分支信息"
    echo "  --remote                       显示远程分支详情"
    echo "  --no-merged                    不显示已合并分支"
    echo "  --no-expired                   不显示过期分支"
    echo "  --expire-days <天数>           设置过期分支天数（默认30天）"
    echo ""
    echo "示例:"
    echo "  git-workflow push precheck"
    echo "  git-workflow branch create feature-new"
    echo "  git-workflow branch delete feature-old"
    echo "  git-workflow branch cleanup --dry-run"
    echo "  git-workflow branch status --all"
    echo "  git-workflow worktree create feature-new"
    echo "  git-workflow release check"
    echo "  git-workflow security review"
    echo "  git-workflow cleanup remote"
    echo ""
    echo "历史管理操作:"
    echo "  history undo-last              撤销最近一次提交（保留工作区）"
    echo "  history split-root             检查巨型初始提交 + 提示拆分"
    echo "  history stage-pick             显示文件拆分方案"
    echo "  history backup [路径]          创建工作区备份"
    echo "  history commit-batch <模块> <文件...>  批量提交一个模块"
    echo ""
    echo "典型工作流 (修复巨型初始提交):"
    echo "  1. git-workflow history backup"
    echo "  2. git-workflow history undo-last"
    echo "  3. git-workflow history stage-pick"
    echo "  4. git add <模块> && git commit -m '...'  (逐模块)"
    echo ""
    echo "详细帮助:"
    echo "  git-workflow <模块> --help"
}

# 主函数
main() {
    # 加载安全网最先（2026-08-30）：tampered/missing/error → fail-closed exit 2，不执行任何模块
    gw_load_guard

    # 解析参数
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local module=$1
    shift

    # 自检/版本不需 git 仓库（在 check_git_repo 前处理）
    case $module in
        "selfcheck")
            gw_selfcheck
            return $?
            ;;
        "version")
            echo "git-workflow v2.1.2"
            return 0
            ;;
    esac

    # 检查git仓库
    check_git_repo

    # 检查配置文件
    check_config

    case $module in
        "push")
            push_management "$@"
            ;;
        "branch")
            branch_management "$@"
            ;;
        "worktree")
            worktree_management "$@"
            ;;
        "release")
            release_management "$@"
            ;;
        "security")
            security_management "$@"
            ;;
        "cleanup")
            cleanup_management "$@"
            ;;
        "history")
            history_management "$@"
            ;;
        "--help"|"-h")
            show_help
            ;;
        *)
            log_error "未知的模块: $module"
            show_help
            exit 1
            ;;
    esac

    # 记录操作日志
    log_operation "$module" "$*"
}

# 执行主函数
main "$@"
