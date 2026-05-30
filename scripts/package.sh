#!/bin/bash
# Git Workflow Umbrella Skill - 打包脚本
# 创建可分发的安装包

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

# 配置
PACKAGE_NAME="git-workflow"
VERSION="1.0.0"
PACKAGE_DIR="$PACKAGE_NAME-$VERSION"
ARCHIVE_NAME="$PACKAGE_DIR.tar.gz"

# 清理旧的打包文件
cleanup_old_packages() {
    log_info "清理旧的打包文件..."
    
    if [ -d "$PACKAGE_DIR" ]; then
        rm -rf "$PACKAGE_DIR"
        log_success "删除旧目录: $PACKAGE_DIR"
    fi
    
    if [ -f "$ARCHIVE_NAME" ]; then
        rm -f "$ARCHIVE_NAME"
        log_success "删除旧归档: $ARCHIVE_NAME"
    fi
}

# 创建打包目录
create_package_directory() {
    log_info "创建打包目录..."
    
    mkdir -p "$PACKAGE_DIR"
    log_success "创建目录: $PACKAGE_DIR"
}

# 复制核心文件
copy_core_files() {
    log_info "复制核心文件..."
    
    # 复制主文件
    cp README.md "$PACKAGE_DIR/"
    cp DESIGN.md "$PACKAGE_DIR/"
    cp SKILL.md "$PACKAGE_DIR/"
    cp CHANGELOG.md "$PACKAGE_DIR/"
    cp LICENSE "$PACKAGE_DIR/"
    cp git-workflow.yaml "$PACKAGE_DIR/"
    
    # 复制脚本目录
    cp -r scripts "$PACKAGE_DIR/"
    
    # 复制示例目录
    cp -r examples "$PACKAGE_DIR/"
    
    # 复制模板目录
    cp -r templates "$PACKAGE_DIR/"
    
    # 复制测试目录
    cp -r tests "$PACKAGE_DIR/"
    
    # 复制文档目录
    if [ -d "docs" ]; then
        cp -r docs "$PACKAGE_DIR/"
    fi
    
    log_success "核心文件复制完成"
}

# 设置文件权限
set_file_permissions() {
    log_info "设置文件权限..."
    
    # 设置脚本执行权限
    chmod +x "$PACKAGE_DIR/scripts/"*.sh
    chmod +x "$PACKAGE_DIR/tests/"*.sh
    
    log_success "文件权限设置完成"
}

# 创建安装脚本
create_install_script() {
    log_info "创建安装脚本..."
    
    cat > "$PACKAGE_DIR/install.sh" << 'EOF'
#!/bin/bash
# Git Workflow Umbrella Skill - 快速安装脚本

set -e

echo "=========================================="
echo "Git Workflow Umbrella Skill 安装"
echo "=========================================="
echo ""

# 检查是否已安装
if [ -d "$HOME/.codebuddy/skills/git-workflow" ]; then
    echo "检测到已安装的版本"
    read -p "是否覆盖安装? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "取消安装"
        exit 0
    fi
fi

# 运行安装脚本
./scripts/install.sh

echo ""
echo "安装完成！"
echo "使用 'git-workflow --help' 查看帮助"
EOF
    
    chmod +x "$PACKAGE_DIR/install.sh"
    log_success "安装脚本创建完成"
}

# 创建卸载脚本
create_uninstall_script() {
    log_info "创建卸载脚本..."
    
    cat > "$PACKAGE_DIR/uninstall.sh" << 'EOF'
#!/bin/bash
# Git Workflow Umbrella Skill - 快速卸载脚本

set -e

echo "=========================================="
echo "Git Workflow Umbrella Skill 卸载"
echo "=========================================="
echo ""

# 运行卸载脚本
./scripts/uninstall.sh

echo ""
echo "卸载完成！"
EOF
    
    chmod +x "$PACKAGE_DIR/uninstall.sh"
    log_success "卸载脚本创建完成"
}

# 创建版本信息文件
create_version_info() {
    log_info "创建版本信息文件..."
    
    cat > "$PACKAGE_DIR/VERSION" << EOF
$PACKAGE_NAME
版本: $VERSION
构建时间: $(date '+%Y-%m-%d %H:%M:%S')
构建系统: $(uname -s) $(uname -m)
EOF
    
    log_success "版本信息文件创建完成"
}

# 创建校验和文件
create_checksums() {
    log_info "创建校验和文件..."
    
    cd "$PACKAGE_DIR"
    
    # 创建 MD5 校验和 (快速完整性检查)
    find . -type f \( -name "*.sh" -o -name "*.md" -o -name "*.yaml" -o -name "*.yml" \) | sort | xargs md5sum > checksums.md5

    # 创建 SHA256 校验和 (安全强度校验)
    find . -type f \( -name "*.sh" -o -name "*.md" -o -name "*.yaml" -o -name "*.yml" \) | sort | xargs sha256sum > checksums.sha256
    
    cd ..
    
    log_success "校验和文件创建完成"
}

# 创建归档文件
create_archive() {
    log_info "创建归档文件..."
    
    tar -czf "$ARCHIVE_NAME" "$PACKAGE_DIR"
    
    log_success "归档文件创建完成: $ARCHIVE_NAME"
}

# 显示打包信息
show_package_info() {
    echo ""
    echo "=========================================="
    echo "打包完成"
    echo "=========================================="
    echo ""
    echo "包名: $PACKAGE_NAME"
    echo "版本: $VERSION"
    echo "归档: $ARCHIVE_NAME"
    echo "大小: $(du -h "$ARCHIVE_NAME" | cut -f1)"
    echo ""
    echo "目录结构:"
    tree "$PACKAGE_DIR" -L 2
    echo ""
    echo "包含功能:"
    echo "  - 推送管理（预检、PR回退）"
    echo "  - 分支管理（创建、删除、清理、状态报告、恢复、定时任务）"
    echo "  - Worktree管理（创建、删除、清理）"
    echo "  - 发版预检（构建、测试、文档检查）"
    echo "  - 安全审查（9项安全检查）"
    echo "  - 清理工具（远程引用、worktree、分支清理）"
    echo ""
    echo "安装方法:"
    echo "  1. 解压: tar -xzf $ARCHIVE_NAME"
    echo "  2. 进入目录: cd $PACKAGE_DIR"
    echo "  3. 运行安装: ./install.sh"
    echo ""
    echo "或者直接运行:"
    echo "  tar -xzf $ARCHIVE_NAME && cd $PACKAGE_DIR && ./install.sh"
    echo ""
    echo "=========================================="
}

# 主函数
main() {
    echo "=========================================="
    echo "Git Workflow Umbrella Skill 打包程序"
    echo "=========================================="
    echo ""
    
    # 清理旧的打包文件
    cleanup_old_packages
    
    # 创建打包目录
    create_package_directory
    
    # 复制核心文件
    copy_core_files
    
    # 设置文件权限
    set_file_permissions
    
    # 创建安装脚本
    create_install_script
    
    # 创建卸载脚本
    create_uninstall_script
    
    # 创建版本信息文件
    create_version_info
    
    # 创建校验和文件
    create_checksums
    
    # 创建归档文件
    create_archive
    
    # 显示打包信息
    show_package_info
}

# 执行主函数
main "$@"