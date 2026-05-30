#!/bin/bash
# Git Workflow Umbrella Skill - 卸载脚本
# 卸载 git-workflow skill

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

# 确认卸载
confirm_uninstall() {
    echo "=========================================="
    echo "Git Workflow Umbrella Skill 卸载程序"
    echo "=========================================="
    echo ""
    echo "此操作将删除以下内容:"
    echo "  - ~/.codebuddy/skills/git-workflow/"
    echo "  - ~/.codebuddy/logs/git-workflow/"
    echo "  - ~/.codebuddy/backups/git-workflow/"
    echo "  - ~/.local/bin/git-workflow"
    echo ""
    echo "配置文件和日志将被备份到 ~/.codebuddy/backups/"
    echo ""
    
    read -p "确认卸载? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        exit 0
    fi
}

# 备份配置和日志
backup_data() {
    log_info "备份配置和日志..."
    
    local backup_dir="$HOME/.codebuddy/backups/git-workflow-uninstall-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份配置文件
    if [ -f "$HOME/.codebuddy/skills/git-workflow/git-workflow.yaml" ]; then
        cp "$HOME/.codebuddy/skills/git-workflow/git-workflow.yaml" "$backup_dir/"
        log_success "配置文件已备份"
    fi
    
    # 备份日志
    if [ -d "$HOME/.codebuddy/logs/git-workflow" ]; then
        cp -r "$HOME/.codebuddy/logs/git-workflow" "$backup_dir/"
        log_success "日志已备份"
    fi
    
    # 备份自定义脚本
    if [ -d "$HOME/.codebuddy/skills/git-workflow/scripts" ]; then
        cp -r "$HOME/.codebuddy/skills/git-workflow/scripts" "$backup_dir/"
        log_success "脚本已备份"
    fi
    
    log_info "备份位置: $backup_dir"
}

# 删除文件
remove_files() {
    log_info "删除文件..."
    
    # 删除主目录
    if [ -d "$HOME/.codebuddy/skills/git-workflow" ]; then
        rm -rf "$HOME/.codebuddy/skills/git-workflow"
        log_success "删除 skills/git-workflow"
    fi
    
    # 删除日志目录
    if [ -d "$HOME/.codebuddy/logs/git-workflow" ]; then
        rm -rf "$HOME/.codebuddy/logs/git-workflow"
        log_success "删除 logs/git-workflow"
    fi
    
    # 删除备份目录
    if [ -d "$HOME/.codebuddy/backups/git-workflow" ]; then
        rm -rf "$HOME/.codebuddy/backups/git-workflow"
        log_success "删除 backups/git-workflow"
    fi
    
    # 删除命令符号链接
    if [ -f "$HOME/.local/bin/git-workflow" ]; then
        rm -f "$HOME/.local/bin/git-workflow"
        log_success "删除 git-workflow 命令"
    fi
}

# 清理符号链接
cleanup_symlinks() {
    log_info "清理符号链接..."
    
    # 检查并删除符号链接
    local symlink="$HOME/.codebuddy/skills/git-workflow"
    if [ -L "$symlink" ]; then
        rm -f "$symlink"
        log_success "删除符号链接"
    fi
}

# 验证卸载
verify_uninstall() {
    log_info "验证卸载..."
    
    local success=true
    
    # 检查目录是否删除
    if [ -d "$HOME/.codebuddy/skills/git-workflow" ]; then
        log_warn "skills/git-workflow 目录仍然存在"
        success=false
    fi
    
    # 检查命令是否删除
    if [ -f "$HOME/.local/bin/git-workflow" ]; then
        log_warn "git-workflow 命令仍然存在"
        success=false
    fi
    
    if [ "$success" = true ]; then
        log_success "卸载验证完成"
    else
        log_warn "部分文件可能未完全删除"
    fi
}

# 显示卸载信息
show_uninstall_info() {
    echo ""
    echo "=========================================="
    echo "Git Workflow Umbrella Skill 卸载完成"
    echo "=========================================="
    echo ""
    echo "已删除:"
    echo "  - ~/.codebuddy/skills/git-workflow/"
    echo "  - ~/.codebuddy/logs/git-workflow/"
    echo "  - ~/.codebuddy/backups/git-workflow/"
    echo "  - ~/.local/bin/git-workflow"
    echo ""
    echo "备份位置: ~/.codebuddy/backups/git-workflow-uninstall-*"
    echo ""
    echo "已删除的功能:"
    echo "  - 分支状态报告"
    echo "  - 分支恢复功能"
    echo "  - 分支清理定时任务"
    echo "  - 分支清理dry-run模式"
    echo ""
    echo "如需重新安装，请运行:"
    echo "  ./scripts/install.sh"
    echo ""
    echo "=========================================="
}

# 主函数
main() {
    # 确认卸载
    confirm_uninstall
    
    # 备份数据
    backup_data
    
    # 删除文件
    remove_files
    
    # 清理符号链接
    cleanup_symlinks
    
    # 验证卸载
    verify_uninstall
    
    # 显示卸载信息
    show_uninstall_info
}

# 执行主函数
main "$@"