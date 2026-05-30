#!/bin/bash
# Git Workflow Umbrella Skill - 安装脚本
# 自动安装和配置 git-workflow skill

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

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    # 检查 git
    if ! command -v git &> /dev/null; then
        log_error "git 未安装，请先安装 git"
        exit 1
    fi
    
    # 检查 bash
    if ! command -v bash &> /dev/null; then
        log_error "bash 未安装，请先安装 bash"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 检查操作系统
check_os() {
    log_info "检查操作系统..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
    else
        log_warn "未知操作系统: $OSTYPE"
        OS="unknown"
    fi
    
    log_info "操作系统: $OS"
}

# 检查 WSL 环境
check_wsl() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        WSL=true
        log_info "检测到 WSL 环境"
    else
        WSL=false
    fi
}

# 设置安装路径
setup_paths() {
    log_info "设置安装路径..."
    
    # 主目录
    HOME_DIR="$HOME"
    
    # .codebuddy 目录
    CODEBUDDY_DIR="$HOME_DIR/.codebuddy"
    
    # skills 目录
    SKILLS_DIR="$CODEBUDDY_DIR/skills"
    
    # git-workflow 目录
    GIT_WORKFLOW_DIR="$SKILLS_DIR/git-workflow"
    
    # 日志目录
    LOG_DIR="$CODEBUDDY_DIR/logs/git-workflow"
    
    # 备份目录
    BACKUP_DIR="$CODEBUDDY_DIR/backups/git-workflow"
    
    # 配置文件
    CONFIG_FILE="$GIT_WORKFLOW_DIR/git-workflow.yaml"
    
    log_info "安装路径: $GIT_WORKFLOW_DIR"
}

# 创建目录
create_directories() {
    log_info "创建目录..."
    
    mkdir -p "$CODEBUDDY_DIR"
    mkdir -p "$SKILLS_DIR"
    mkdir -p "$GIT_WORKFLOW_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    
    log_success "目录创建完成"
}

# 复制文件
copy_files() {
    log_info "复制文件..."
    
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PARENT_DIR="$(dirname "$SCRIPT_DIR")"
    
    # 复制所有文件
    cp -r "$PARENT_DIR"/* "$GIT_WORKFLOW_DIR/"
    
    # 设置执行权限
    chmod +x "$GIT_WORKFLOW_DIR/scripts/"*.sh
    
    log_success "文件复制完成"
}

# 创建符号链接
create_symlinks() {
    log_info "创建符号链接..."
    
    # 创建主命令符号链接
    local bin_dir="$HOME_DIR/.local/bin"
    mkdir -p "$bin_dir"
    
    # 创建 git-workflow 命令
    cat > "$bin_dir/git-workflow" << 'EOF'
#!/bin/bash
# Git Workflow Umbrella Skill - 命令入口
exec ~/.codebuddy/skills/git-workflow/scripts/git-workflow.sh "$@"
EOF
    
    chmod +x "$bin_dir/git-workflow"
    
    # 检查 PATH
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        log_warn "$bin_dir 不在 PATH 中"
        log_info "请将以下行添加到 ~/.bashrc 或 ~/.zshrc:"
        log_info "export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    
    log_success "符号链接创建完成"
}

# 配置 Windows/WSL 路径
setup_windows_wsl() {
    if [[ "$WSL" == true ]]; then
        log_info "配置 Windows/WSL 路径..."
        
        # 检查 Windows .codebuddy 目录
        local windows_codebuddy="/mnt/c/Users/HP/.codebuddy"
        if [ -d "$windows_codebuddy" ]; then
            log_info "检测到 Windows .codebuddy 目录"
            
            # 创建符号链接（如果不存在）
            if [ ! -L "$GIT_WORKFLOW_DIR" ] && [ ! -d "$GIT_WORKFLOW_DIR" ]; then
                ln -s "$windows_codebuddy/skills/git-workflow" "$GIT_WORKFLOW_DIR"
                log_success "创建 Windows 路径符号链接"
            fi
        fi
    fi
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    # 检查主脚本
    if [ -f "$GIT_WORKFLOW_DIR/scripts/git-workflow.sh" ]; then
        log_success "主脚本存在"
    else
        log_error "主脚本不存在"
        exit 1
    fi
    
    # 检查配置文件
    if [ -f "$CONFIG_FILE" ]; then
        log_success "配置文件存在"
    else
        log_warn "配置文件不存在，将使用默认配置"
    fi
    
    # 检查执行权限
    if [ -x "$GIT_WORKFLOW_DIR/scripts/git-workflow.sh" ]; then
        log_success "脚本有执行权限"
    else
        log_warn "设置脚本执行权限"
        chmod +x "$GIT_WORKFLOW_DIR/scripts/git-workflow.sh"
    fi
    
    log_success "安装验证完成"
}

# 显示安装信息
show_installation_info() {
    echo ""
    echo "=========================================="
    echo "Git Workflow Umbrella Skill 安装完成"
    echo "=========================================="
    echo ""
    echo "安装路径: $GIT_WORKFLOW_DIR"
    echo "配置文件: $CONFIG_FILE"
    echo "日志目录: $LOG_DIR"
    echo "备份目录: $BACKUP_DIR"
    echo ""
    echo "使用方法:"
    echo "  git-workflow --help"
    echo ""
    echo "快速开始:"
    echo "  git-workflow push --precheck"
    echo "  git-workflow branch create feature-new"
    echo "  git-workflow branch status --all"
    echo "  git-workflow branch cleanup --dry-run"
    echo "  git-workflow branch schedule --weekly"
    echo "  git-workflow cleanup remote"
    echo ""
    echo "新功能:"
    echo "  分支状态报告: git-workflow branch status --all"
    echo "  分支恢复: git-workflow branch restore feature-old"
    echo "  定时清理: git-workflow branch schedule --weekly --time 02:00"
    echo ""
    echo "文档:"
    echo "  $GIT_WORKFLOW_DIR/README.md"
    echo "  $GIT_WORKFLOW_DIR/DESIGN.md"
    echo "  $GIT_WORKFLOW_DIR/SKILL.md"
    echo ""
    echo "=========================================="
}

# 主函数
main() {
    echo "=========================================="
    echo "Git Workflow Umbrella Skill 安装程序"
    echo "=========================================="
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 检查操作系统
    check_os
    
    # 检查 WSL
    check_wsl
    
    # 设置路径
    setup_paths
    
    # 创建目录
    create_directories
    
    # 复制文件
    copy_files
    
    # 创建符号链接
    create_symlinks
    
    # 配置 Windows/WSL 路径
    setup_windows_wsl
    
    # 验证安装
    verify_installation
    
    # 显示安装信息
    show_installation_info
}

# 执行主函数
main "$@"