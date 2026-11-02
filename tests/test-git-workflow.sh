#!/bin/bash
# Git Workflow Umbrella Skill - 测试脚本
# 测试 git-workflow 的各项功能

set -e

# ── 测试目标推导（2026-11-02 修）─────────────────────────────────────────────
# 原实现有 12 处硬编码 `$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh`。
# 那个路径**至今仍存在**（5-31 的独立副本，非符号链）⟹ 本测试不会报"找不到"，
# 而是**静默测了另一份文件**：16 tests / 12 passed / 4 failed 全是旧副本的读数，
# 与当前仓代码零关系（典型假绿）。
# 修法：从脚本自身位置推导；并加两条守卫（硬编码残留 / 旧副本提示）。
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$TESTS_DIR/.." && pwd)"
SCRIPT_PATH="$SKILL_DIR/scripts/git-workflow.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "[ERROR] 测试目标不存在: $SCRIPT_PATH" >&2
    exit 1
fi

# 守卫①：禁止再写回硬编码（形如 script_path 指向 $HOME 下的某个 skills 目录）
#   ⚠ 只匹配**代码行**（行首可选的 local 前缀），注释行（#）不算 —— 否则守卫会命中自己的说明文字。
if grep -nE '^[[:space:]]*(local[[:space:]]+)?script_path="\$HOME/' "$0" 2>/dev/null | grep -q .; then
    echo "[ERROR] 测试脚本仍存在硬编码 \$HOME 路径；请统一用 \$SCRIPT_PATH" >&2
    exit 1
fi

# 守卫②：旧副本仍在时告警（不阻断；本测试不使用它）
for _legacy in "$HOME/.codebuddy/skills/git-workflow/scripts/git-workflow.sh"; do
    if [ -f "$_legacy" ]; then
        echo "[WARN] 检测到旧副本仍在: $_legacy" >&2
        echo "[WARN] 本测试**不使用**它；建议删除，以免别的脚本误指向" >&2
    fi
done
unset _legacy

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
    local script_path="$SCRIPT_PATH"
    
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
    local config_file="$SKILL_DIR/git-workflow.yaml"

    # 配置是仓内文件，必须存在（原实现"不存在也 return 0"⟹ 恒绿）
    if [ -f "$config_file" ]; then
        return 0
    fi
    log_error "配置文件缺失: $config_file"
    return 1
}

# 测试脚本执行权限
test_permissions() {
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    local script_path="$SCRIPT_PATH"
    
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
    # 真断言：**能写**日志文件（原实现只检查目录、不存在就 mkdir 再 return 0 ⟹ 恒绿）
    #   写入唯一文件名，不删（避安全删除钩子），文件 < 32 B。
    local tmp_log="${TEMP:-/tmp}/gw-test-log-$$.log"
    if echo "[test] $(date +%s)" > "$tmp_log" 2>/dev/null && [ -s "$tmp_log" ]; then
        return 0
    fi
    log_error "无法写入日志文件: $tmp_log"
    return 1
}

# 测试备份功能
test_backup() {
    # 真断言：`history backup` 能产出 repo.bundle（原实现只 mkdir 目录就 return 0 ⟹ 恒绿）
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_warn "不在 git 仓库中，跳过 backup 行为断言"
        return 0
    fi
    local dest="${TEMP:-/tmp}/gw-test-bak-$$"
    if bash "$SCRIPT_PATH" history backup "$dest" >/dev/null 2>&1 && [ -f "$dest/repo.bundle" ]; then
        return 0
    fi
    log_error "backup 未产出 repo.bundle（dest=$dest）"
    return 1
}

# 测试Windows/WSL路径检测
test_windows_wsl_detection() {
    # 跨平台能力断言。
    #   原实现在 WSL 分支里检查一个写死的 `.codebuddy` 路径，且**两条分支都 return 0** ⟹ 恒绿。
    #   真判据：`_gw_days_ago` 在本平台能算出日期（GNU date -d / BSD date -v / python 三级兜底任一成功）。
    local got
    got=$(bash -c 'eval "$(sed -n "/^_gw_days_ago()/,/^}/p" "$1")"; _gw_days_ago 1' _ "$SCRIPT_PATH" 2>/dev/null)
    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_info "检测到 WSL 环境"
    fi
    if [ -n "$got" ]; then
        log_info "跨平台日期换算可用: _gw_days_ago 1 = $got"
        return 0
    fi
    log_error "跨平台日期换算不可用（三级兜底全失败）"
    return 1
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