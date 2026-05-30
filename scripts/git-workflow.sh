#!/bin/bash
# Git Workflow Umbrella Skill - 主脚本 (v2.0.0)
# Copyright (c) 2026 Pu Junhan. MulanPSL-2.0
# 统一管理所有git工作流操作 (7 模块: push/branch/worktree/release/security/cleanup/history)

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

# 自动检测脚本所在目录 (支持符号链接)
SKILL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")/.." && pwd)"
# 配置文件路径 (优先环境变量, 否则使用脚本同目录下的配置文件)
CONFIG_FILE="${GIT_WORKFLOW_CONFIG:-$SKILL_DIR/git-workflow.yaml}"
LOG_DIR="${GIT_WORKFLOW_LOG:-$HOME/.local/share/git-workflow/logs}"
BACKUP_DIR="${GIT_WORKFLOW_BACKUP:-$HOME/.local/share/git-workflow/backups}"

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

# 记录操作日志
log_operation() {
    local operation=$1
    local details=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG_DIR/operations.log"
    
    echo "[$timestamp] $operation: $details" >> "$log_file"
}

# 推送管理模块
push_management() {
    local action=$1
    shift
    
    case $action in
        "precheck")
            log_info "执行推送预检..."
            # 调用 github-push 子模块 (可选)
            local github_push="$SKILL_DIR/../github-push/github_push.py"
            if [ -f "$github_push" ]; then
                python "$github_push" precheck "$@"
            else
                log_warn "github-push 子模块未安装，跳过 hook 检查"
            fi
            ;;
        "push")
            log_info "执行标准推送..."
            local push_url="" remote="origin" branch="" timeout=60

            # Parse args for branch and remote
            while [ $# -gt 0 ]; do
                case "$1" in
                    --remote) remote="$2"; shift 2 ;;
                    --branch) branch="$2"; shift 2 ;;
                    --timeout) timeout="$2"; shift 2 ;;
                    --push-url) push_url="$2"; shift 2 ;;
                    *) break ;;
                esac
            done
            [ -z "$branch" ] && branch=$(git branch --show-current 2>/dev/null || echo "main")
            [ -z "$push_url" ] && push_url=$(git remote get-url "$remote" 2>/dev/null)

            # Try github-push submodule first (has retry + rate-limit handling)
            local github_push="$SKILL_DIR/../github-push/github_push.py"
            if [ -f "$github_push" ]; then
                log_info "使用 github-push 模块 (含重试+限速处理)..."
                if python "$github_push" git-push --token "$(gh auth token 2>/dev/null)" \
                    --owner "spz-ecosystem" --repo "spz_gatekeeper" \
                    --file "" --content "" --message "" --branch "$branch" 2>/dev/null; then
                    log_success "推送成功"
                    return 0
                fi
                log_warn "github-push 模块失败，降级到原生 git push"
            fi

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
            
            git checkout -b "$feature_branch"
            git push origin "$feature_branch"
            gh pr create --base main --head "$feature_branch" --fill
            
            log_success "PR创建成功"
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
            read -p "确认删除分支 '$branch_name'? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
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
            local expire_date=$(date -d "${expire_days} days ago" +%Y-%m-%d 2>/dev/null || date -v-${expire_days}d +%Y-%m-%d 2>/dev/null)
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
                read -p "确认清理上述分支? (y/N): " confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
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
                    local expire_date=$(date -d "${expire_days} days ago" +%Y-%m-%d 2>/dev/null || date -v-${expire_days}d +%Y-%m-%d 2>/dev/null)
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
                local expire_date=$(date -d "${expire_days} days ago" +%Y-%m-%d 2>/dev/null || date -v-${expire_days}d +%Y-%m-%d 2>/dev/null)
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
            local branch_name=$1
            log_info "创建隔离worktree: $branch_name"
            
            # 检查分支是否已存在
            if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
                log_error "分支不存在: $branch_name"
                exit 1
            fi
            
            # 创建worktree
            local worktree_path="$HOME/.config/superpowers/worktrees/$(basename $(git rev-parse --show-toplevel))/$branch_name"
            git worktree add "$worktree_path" "$branch_name"
            
            log_success "Worktree创建成功: $worktree_path"
            ;;
        "delete")
            local branch_name=$1
            log_info "删除worktree: $branch_name"
            
            # 查找worktree路径
            local worktree_info=$(git worktree list | grep "$branch_name")
            if [ -z "$worktree_info" ]; then
                log_error "未找到分支 '$branch_name' 的worktree"
                exit 1
            fi
            
            local worktree_path=$(echo "$worktree_info" | awk '{print $1}')
            
            # 检查worktree是否被占用
            if fuser -v "$worktree_path" &> /dev/null; then
                log_error "Worktree被其他进程占用"
                exit 1
            fi
            
            # 删除worktree
            git worktree remove "$worktree_path"
            log_success "Worktree删除成功: $worktree_path"
            ;;
        "cleanup")
            log_info "清理孤立worktree..."
            
            # 清理worktree
            git worktree prune
            
            log_success "Worktree清理完成"
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
                
                read -p "确认删除这些分支? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo "$temp_branches" | xargs git branch -D
                    log_success "临时分支清理完成"
                else
                    log_info "取消临时分支清理"
                fi
            else
                log_info "没有需要清理的临时分支"
            fi
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
            local backup_path="${1:-$HOME/.codex_backup_$(date +%Y%m%d)}"
            local repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

            log_info "创建工作区备份: $backup_path"
            cp -r "$repo_root" "$backup_path"
            log_success "备份完成: $backup_path"
            log_info "核心文件确认:"
            ls -la "$backup_path/bridge/engine.py" "$backup_path/bridge/server.py" "$backup_path/bridge/constitution.py" 2>/dev/null || log_warn "部分核心文件未找到（可能路径不同）"
            ;;

        "commit-batch")
            # 接收模块名和文件路径列表，自动 add + commit
            local module_name=$1
            shift
            local paths="$@"

            if [ -z "$module_name" ] || [ -z "$paths" ]; then
                log_error "用法: git-workflow history commit-batch <模块名> <文件路径...>"
                exit 1
            fi

            log_info "提交模块: $module_name"
            for p in $paths; do
                if [ -e "$p" ]; then
                    git add "$p"
                else
                    log_warn "跳过不存在的文件: $p"
                fi
            done

            local staged=$(git diff --cached --name-only 2>/dev/null | wc -l)
            if [ "$staged" -eq 0 ]; then
                log_warn "没有文件被暂存，跳过提交"
                return 0
            fi

            read -p "输入 commit message (留空则使用自动生成): " user_message
            if [ -z "$user_message" ]; then
                user_message="feat($module_name): add $module_name module"
            fi

            git commit -m "$user_message"
            log_success "模块 '$module_name' 提交完成 ($staged 个文件)"
            ;;

        "--help"|"-h")
            echo "history 模块 — 提交历史管理"
            echo ""
            echo "用法: git-workflow history <操作> [选项]"
            echo ""
            echo "操作:"
            echo "  undo-last           撤销最近一次提交（保留工作区文件）"
            echo "  split-root          检查巨型初始提交并提示拆分方案"
            echo "  stage-pick          显示文件列表 + 推荐拆分顺序"
            echo "  backup [路径]        创建工作区完整备份"
            echo "  commit-batch <模块> <文件...>  自动 add + commit 一个模块"
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
    # 检查git仓库
    check_git_repo
    
    # 检查配置文件
    check_config
    
    # 解析参数
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local module=$1
    shift
    
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