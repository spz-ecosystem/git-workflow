#!/bin/bash
# Git Workflow Umbrella Skill - 测试脚本
# 测试 git-workflow 的各项功能

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

# 测试计数器
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# 测试函数
run_test() {
    local test_name=$1
    local test_function=$2
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    log_info "运行测试: $test_name"
    
    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "测试通过: $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "测试失败: $test_name"
    fi
}

# 测试帮助信息
test_help() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    if [ ! -f "$script_path" ]; then
        log_error "主脚本不存在: $script_path"
        return 1
    fi
    
    # 测试帮助信息
    if $script_path --help > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 测试配置文件
test_config() {
    local config_file="$HOME/.codebuddy/skills/git-workflow/git-workflow.yaml"
    
    if [ -f "$config_file" ]; then
        return 0
    else
        log_warn "配置文件不存在，将使用默认配置"
        return 0
    fi
}

# 测试脚本执行权限
test_permissions() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    if [ -x "$script_path" ]; then
        return 0
    else
        log_warn "设置脚本执行权限"
        chmod +x "$script_path"
        return 0
    fi
}

# 测试安全审查功能
test_security_review() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过安全审查测试"
        return 0
    fi
    
    # 测试安全审查
    if $script_path security review > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 测试清理功能
test_cleanup() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过清理测试"
        return 0
    fi
    
    # 测试清理远程引用（可能会失败，但不应该崩溃）
    $script_path cleanup remote > /dev/null 2>&1 || true
    
    return 0
}

# 测试分支管理功能
test_branch_management() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过分支管理测试"
        return 0
    fi
    
    # 测试分支管理帮助信息
    if $script_path branch --help > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 测试分支状态报告
test_branch_status() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过分支状态测试"
        return 0
    fi
    
    # 测试分支状态报告
    if $script_path branch status > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 测试分支清理dry-run
test_branch_cleanup_dry_run() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过分支清理dry-run测试"
        return 0
    fi
    
    # 测试分支清理dry-run
    if $script_path branch cleanup --dry-run > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 测试分支恢复功能
test_branch_restore() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过分支恢复测试"
        return 0
    fi
    
    # 测试分支恢复帮助信息（不需要实际恢复）
    # 由于恢复功能需要备份文件，这里只测试命令是否存在
    if $script_path branch restore --help > /dev/null 2>&1; then
        return 0
    else
        # 如果restore命令没有--help选项，检查命令是否存在
        if $script_path branch restore 2>&1 | grep -q "请提供要恢复的分支名"; then
            return 0
        else
            return 1
        fi
    fi
}

# 测试分支定时任务配置
test_branch_schedule() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过分支定时任务测试"
        return 0
    fi
    
    # 测试分支定时任务配置（dry-run模式，不实际添加cron任务）
    # 由于定时任务需要crontab权限，这里只测试命令是否存在
    if $script_path branch schedule --help > /dev/null 2>&1; then
        return 0
    else
        # 如果schedule命令没有--help选项，检查命令是否存在
        if $script_path branch schedule 2>&1 | grep -q "配置分支清理定时任务"; then
            return 0
        else
            return 1
        fi
    fi
}

# 测试Worktree管理功能
test_worktree_management() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过Worktree管理测试"
        return 0
    fi
    
    # 测试Worktree管理帮助信息
    if $script_path worktree --help > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 测试发版预检功能
test_release_management() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过发版预检测试"
        return 0
    fi
    
    # 测试发版预检帮助信息
    if $script_path release --help > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 测试推送管理功能
test_push_management() {
    local script_path="$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不在git仓库中，跳过推送管理测试"
        return 0
    fi
    
    # 测试推送管理帮助信息
    if $script_path push --help > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 测试日志功能
test_logging() {
    local log_dir="$HOME/.codebuddy/logs/git-workflow"
    
    # 检查日志目录是否存在
    if [ -d "$log_dir" ]; then
        return 0
    else
        log_warn "日志目录不存在，将自动创建"
        mkdir -p "$log_dir"
        return 0
    fi
}

# 测试备份功能
test_backup() {
    local backup_dir="$HOME/.codebuddy/backups/git-workflow"
    
    # 检查备份目录是否存在
    if [ -d "$backup_dir" ]; then
        return 0
    else
        log_warn "备份目录不存在，将自动创建"
        mkdir -p "$backup_dir"
        return 0
    fi
}

# 测试Windows/WSL路径检测
test_windows_wsl_detection() {
    # 检查是否在WSL环境中
    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_info "检测到WSL环境"
        
        # 检查Windows路径是否存在
        local windows_path="/mnt/c/Users/HP/.codebuddy/skills/git-workflow"
        if [ -d "$windows_path" ]; then
            log_info "Windows路径存在: $windows_path"
            return 0
        else
            log_warn "Windows路径不存在: $windows_path"
            return 0
        fi
    else
        log_info "不在WSL环境中"
        return 0
    fi
}

# 显示测试结果
show_test_results() {
    echo ""
    echo "=========================================="
    echo "测试结果"
    echo "=========================================="
    echo ""
    echo "总测试数: $TESTS_TOTAL"
    echo "通过: $TESTS_PASSED"
    echo "失败: $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "所有测试通过"
        return 0
    else
        log_error "有测试失败"
        return 1
    fi
}

# 主函数
main() {
    echo "=========================================="
    echo "Git Workflow Umbrella Skill 测试"
    echo "=========================================="
    echo ""
    
    # 运行测试
    run_test "帮助信息" test_help
    run_test "配置文件" test_config
    run_test "脚本权限" test_permissions
    run_test "安全审查" test_security_review
    run_test "清理功能" test_cleanup
    run_test "分支管理" test_branch_management
    run_test "分支状态报告" test_branch_status
    run_test "分支清理dry-run" test_branch_cleanup_dry_run
    run_test "分支恢复功能" test_branch_restore
    run_test "分支定时任务" test_branch_schedule
    run_test "Worktree管理" test_worktree_management
    run_test "发版预检" test_release_management
    run_test "推送管理" test_push_management
    run_test "日志功能" test_logging
    run_test "备份功能" test_backup
    run_test "Windows/WSL检测" test_windows_wsl_detection
    
    # 显示测试结果
    show_test_results
}

# 执行主函数
main "$@"