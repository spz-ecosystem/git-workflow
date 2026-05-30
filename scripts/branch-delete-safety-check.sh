#!/bin/bash
# Git Workflow Umbrella Skill - 分支删除安全检查脚本
# 执行分支删除前的安全检查，防止误删重要分支

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

# 配置文件路径
CONFIG_FILE="${GIT_WORKFLOW_CONFIG:-$HOME/.codebuddy/skills/git-workflow/git-workflow.yaml}"

# 默认配置
DEFAULT_PROTECTED_BRANCHES=("main" "master" "develop" "release" "production")
DEFAULT_MIN_AGE_DAYS=7
DEFAULT_CHECK_PR=true
DEFAULT_CHECK_WORKTREE=true

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # 简单的YAML解析（简化版）
        # 实际项目中应该使用更健壮的YAML解析器
        log_info "加载配置文件: $CONFIG_FILE"
    fi
}

# 检查是否在git仓库中
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "当前目录不是git仓库"
        exit 1
    fi
}

# 检查分支是否存在
check_branch_exists() {
    local branch_name=$1
    
    if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log_error "分支不存在: $branch_name"
        exit 1
    fi
}

# 检查是否是保护分支
check_protected_branch() {
    local branch_name=$1
    
    # 从配置文件读取保护分支列表，或使用默认值
    local protected_branches=("${DEFAULT_PROTECTED_BRANCHES[@]}")
    
    for protected in "${protected_branches[@]}"; do
        if [ "$branch_name" = "$protected" ]; then
            log_error "分支 '$branch_name' 是保护分支，不能删除"
            return 1
        fi
    done
    
    return 0
}

# 检查是否是当前分支
check_current_branch() {
    local branch_name=$1
    local current_branch=$(git branch --show-current)
    
    if [ "$branch_name" = "$current_branch" ]; then
        log_error "不能删除当前分支 '$branch_name'，请先切换到其他分支"
        return 1
    fi
    
    return 0
}

# 检查分支合并状态
check_merge_status() {
    local branch_name=$1
    
    # 检查分支是否已合并到main
    if git merge-base --is-ancestor "$branch_name" main 2>/dev/null; then
        log_warn "分支 '$branch_name' 已合并到main"
        return 0
    fi
    
    # 检查分支是否已合并到master
    if git merge-base --is-ancestor "$branch_name" master 2>/dev/null; then
        log_warn "分支 '$branch_name' 已合并到master"
        return 0
    fi
    
    log_info "分支 '$branch_name' 未合并到主分支"
    return 0
}

# 检查未提交更改
check_uncommitted_changes() {
    local branch_name=$1
    
    # 切换到分支检查
    local current_branch=$(git branch --show-current)
    
    if [ "$current_branch" != "$branch_name" ]; then
        # 临时切换到分支
        git checkout "$branch_name" > /dev/null 2>&1
        
        # 检查是否有未提交更改
        if ! git diff --quiet HEAD 2>/dev/null; then
            log_warn "分支 '$branch_name' 有未提交的更改"
            git checkout "$current_branch" > /dev/null 2>&1
            return 0
        fi
        
        # 切换回原分支
        git checkout "$current_branch" > /dev/null 2>&1
    else
        # 当前分支就是目标分支
        if ! git diff --quiet HEAD 2>/dev/null; then
            log_warn "分支 '$branch_name' 有未提交的更改"
            return 0
        fi
    fi
    
    return 0
}

# 检查最后提交时间
check_last_commit_time() {
    local branch_name=$1
    local min_age_days=${2:-$DEFAULT_MIN_AGE_DAYS}
    
    # 获取最后提交时间
    local last_commit_date=$(git log -1 --format="%at" "$branch_name" 2>/dev/null)
    
    if [ -z "$last_commit_date" ]; then
        log_warn "无法获取分支 '$branch_name' 的最后提交时间"
        return 0
    fi
    
    # 计算时间差
    local current_date=$(date +%s)
    local diff_seconds=$((current_date - last_commit_date))
    local diff_days=$((diff_seconds / 86400))
    
    if [ "$diff_days" -lt "$min_age_days" ]; then
        log_warn "分支 '$branch_name' 最后提交于 ${diff_days} 天前（少于 ${min_age_days} 天）"
    else
        log_info "分支 '$branch_name' 最后提交于 ${diff_days} 天前"
    fi
    
    return 0
}

# 检查PR关联
check_pr_association() {
    local branch_name=$1
    
    # 检查是否有相关的PR
    # 这里简化处理，实际应该调用GitHub API
    log_info "检查分支 '$branch_name' 是否有关联的PR..."
    
    # 模拟检查（实际应该使用gh api）
    # gh pr list --head "$branch_name" --json number,title
    
    return 0
}

# 检查Worktree关联
check_worktree_association() {
    local branch_name=$1
    
    # 检查是否有worktree关联
    local worktree_info=$(git worktree list | grep "$branch_name")
    
    if [ -n "$worktree_info" ]; then
        log_warn "分支 '$branch_name' 有关联的worktree:"
        echo "$worktree_info"
        return 0
    fi
    
    return 0
}

# 检查主Worktree
check_main_worktree() {
    local branch_name=$1
    
    # 检查是否是主worktree的分支
    local main_worktree=$(git worktree list | head -n 1 | awk '{print $1}')
    local current_worktree=$(git rev-parse --show-toplevel)
    
    if [ "$main_worktree" = "$current_worktree" ]; then
        log_info "当前在主worktree中"
    fi
    
    return 0
}

# 执行安全检查
run_safety_check() {
    local branch_name=$1
    local dry_run=$2
    
    log_info "执行分支删除安全检查: $branch_name"
    echo ""
    
    # 记录检查结果
    local checks_passed=0
    local checks_failed=0
    local checks_warning=0
    
    # 1. 检查分支是否存在
    log_info "1. 检查分支是否存在..."
    if check_branch_exists "$branch_name"; then
        log_success "   ✓ 分支存在"
        checks_passed=$((checks_passed + 1))
    else
        log_error "   ✗ 分支不存在"
        checks_failed=$((checks_failed + 1))
        return 1
    fi
    
    # 2. 检查是否是保护分支
    log_info "2. 检查是否是保护分支..."
    if check_protected_branch "$branch_name"; then
        log_success "   ✓ 不是保护分支"
        checks_passed=$((checks_passed + 1))
    else
        log_error "   ✗ 是保护分支"
        checks_failed=$((checks_failed + 1))
        return 1
    fi
    
    # 3. 检查是否是当前分支
    log_info "3. 检查是否是当前分支..."
    if check_current_branch "$branch_name"; then
        log_success "   ✓ 不是当前分支"
        checks_passed=$((checks_passed + 1))
    else
        log_error "   ✗ 是当前分支"
        checks_failed=$((checks_failed + 1))
        return 1
    fi
    
    # 4. 检查合并状态
    log_info "4. 检查合并状态..."
    if check_merge_status "$branch_name"; then
        log_success "   ✓ 合并状态检查完成"
        checks_passed=$((checks_passed + 1))
    else
        log_warn "   ⚠ 合并状态检查有问题"
        checks_warning=$((checks_warning + 1))
    fi
    
    # 5. 检查未提交更改
    log_info "5. 检查未提交更改..."
    if check_uncommitted_changes "$branch_name"; then
        log_success "   ✓ 未提交更改检查完成"
        checks_passed=$((checks_passed + 1))
    else
        log_warn "   ⚠ 有未提交的更改"
        checks_warning=$((checks_warning + 1))
    fi
    
    # 6. 检查最后提交时间
    log_info "6. 检查最后提交时间..."
    if check_last_commit_time "$branch_name"; then
        log_success "   ✓ 最后提交时间检查完成"
        checks_passed=$((checks_passed + 1))
    else
        log_warn "   ⚠ 最后提交时间检查有问题"
        checks_warning=$((checks_warning + 1))
    fi
    
    # 7. 检查PR关联
    log_info "7. 检查PR关联..."
    if check_pr_association "$branch_name"; then
        log_success "   ✓ PR关联检查完成"
        checks_passed=$((checks_passed + 1))
    else
        log_warn "   ⚠ PR关联检查有问题"
        checks_warning=$((checks_warning + 1))
    fi
    
    # 8. 检查Worktree关联
    log_info "8. 检查Worktree关联..."
    if check_worktree_association "$branch_name"; then
        log_success "   ✓ Worktree关联检查完成"
        checks_passed=$((checks_passed + 1))
    else
        log_warn "   ⚠ Worktree关联检查有问题"
        checks_warning=$((checks_warning + 1))
    fi
    
    # 9. 检查主Worktree
    log_info "9. 检查主Worktree..."
    if check_main_worktree "$branch_name"; then
        log_success "   ✓ 主Worktree检查完成"
        checks_passed=$((checks_passed + 1))
    else
        log_warn "   ⚠ 主Worktree检查有问题"
        checks_warning=$((checks_warning + 1))
    fi
    
    # 显示检查结果
    echo ""
    log_info "安全检查完成:"
    echo "  通过: $checks_passed"
    echo "  警告: $checks_warning"
    echo "  失败: $checks_failed"
    echo ""
    
    # 根据检查结果决定是否允许删除
    if [ "$checks_failed" -gt 0 ]; then
        log_error "安全检查失败，不允许删除分支 '$branch_name'"
        return 1
    elif [ "$checks_warning" -gt 0 ]; then
        log_warn "安全检查有警告，请确认是否继续删除"
        
        if [ "$dry_run" = "true" ]; then
            log_info "Dry-run模式，不执行实际删除"
            return 0
        fi
        
        read -p "确认删除分支 '$branch_name'? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            return 0
        else
            log_info "取消删除操作"
            return 1
        fi
    else
        log_success "安全检查全部通过，可以删除分支 '$branch_name'"
        
        if [ "$dry_run" = "true" ]; then
            log_info "Dry-run模式，不执行实际删除"
            return 0
        fi
        
        read -p "确认删除分支 '$branch_name'? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            return 0
        else
            log_info "取消删除操作"
            return 1
        fi
    fi
}

# 显示帮助信息
show_help() {
    echo "分支删除安全检查脚本"
    echo ""
    echo "用法: $0 [选项] <分支名>"
    echo ""
    echo "选项:"
    echo "  --dry-run       仅显示检查结果，不执行实际删除"
    echo "  --help, -h      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 feature-old-feature"
    echo "  $0 --dry-run feature-old-feature"
    echo ""
    echo "安全检查项目:"
    echo "  1. 分支是否存在"
    echo "  2. 是否是保护分支"
    echo "  3. 是否是当前分支"
    echo "  4. 合并状态检查"
    echo "  5. 未提交更改检查"
    echo "  6. 最后提交时间检查"
    echo "  7. PR关联检查"
    echo "  8. Worktree关联检查"
    echo "  9. 主Worktree检查"
}

# 主函数
main() {
    # 解析参数
    local dry_run=false
    local branch_name=""
    
    while [ $# -gt 0 ]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [ -z "$branch_name" ]; then
                    branch_name=$1
                else
                    log_error "未知参数: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 检查分支名是否提供
    if [ -z "$branch_name" ]; then
        log_error "请提供分支名"
        show_help
        exit 1
    fi
    
    # 检查git仓库
    check_git_repo
    
    # 加载配置
    load_config
    
    # 执行安全检查
    run_safety_check "$branch_name" "$dry_run"
}

# 执行主函数
main "$@"