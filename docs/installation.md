# 安装指南

## 系统要求

### 操作系统
- Linux (推荐 Ubuntu 20.04+)
- macOS (推荐 macOS 11+)
- Windows (WSL2 环境)

### 依赖软件
- Git 2.20+
- Bash 4.0+
- curl (可选，用于下载)
- wget (可选，用于下载)

## 安装方法

### 方法 1: 从源码安装

```bash
# 1. 克隆仓库
git clone <repository-url> ~/.codebuddy/skills/git-workflow

# 2. 进入目录
cd ~/.codebuddy/skills/git-workflow

# 3. 运行安装脚本
./scripts/install.sh
```

### 方法 2: 从归档文件安装

```bash
# 1. 下载归档文件
wget <archive-url>

# 2. 解压归档
tar -xzf git-workflow-1.0.0.tar.gz

# 3. 进入目录
cd git-workflow-1.0.0

# 4. 运行安装脚本
./install.sh
```

### 方法 3: 手动安装

```bash
# 1. 创建目录
mkdir -p ~/.codebuddy/skills/git-workflow

# 2. 复制文件
cp -r * ~/.codebuddy/skills/git-workflow/

# 3. 设置权限
chmod +x ~/.codebuddy/skills/git-workflow/scripts/*.sh

# 4. 创建命令链接
mkdir -p ~/.local/bin
cat > ~/.local/bin/git-workflow << 'EOF'
#!/bin/bash
exec ~/.codebuddy/skills/git-workflow/scripts/git-workflow.sh "$@"
EOF
chmod +x ~/.local/bin/git-workflow

# 5. 添加到 PATH (如果需要)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Windows/WSL 安装

### 在 WSL 中安装

```bash
# 1. 确保在 WSL 环境中
grep -qi microsoft /proc/version && echo "WSL 环境"

# 2. 克隆或下载到 WSL
git clone <repository-url> ~/.codebuddy/skills/git-workflow

# 3. 运行安装脚本
cd ~/.codebuddy/skills/git-workflow
./scripts/install.sh

# 4. 脚本会自动检测 Windows 路径并创建符号链接
```

### 在 Windows 中使用

```bash
# 1. 在 WSL 中安装（如上）

# 2. 在 Windows 命令提示符或 PowerShell 中使用
wsl git-workflow --help
```

## 配置

### 配置文件位置

- **WSL 路径**: `/root/.codebuddy/skills/git-workflow/git-workflow.yaml`
- **Windows 路径**: `/mnt/c/Users/HP/.codebuddy/skills/git-workflow/git-workflow.yaml`

### 环境变量

```bash
# 配置文件路径
export GIT_WORKFLOW_CONFIG="/path/to/git-workflow.yaml"

# 日志目录
export GIT_WORKFLOW_LOG="/path/to/logs"

# 备份目录
export GIT_WORKFLOW_BACKUP="/path/to/backups"
```

### 自动检测

脚本会自动检测 Windows 路径并创建符号链接：
1. 检查 WSL 路径下的配置文件是否存在
2. 如果不存在，检测 Windows 路径
3. 自动创建符号链接到 WSL 路径
4. 使用默认配置作为后备方案

## 验证安装

### 检查安装

```bash
# 检查命令是否可用
git-workflow --help

# 检查配置文件
ls -la ~/.codebuddy/skills/git-workflow/

# 检查脚本权限
ls -la ~/.codebuddy/skills/git-workflow/scripts/
```

### 验证新功能

```bash
# 验证分支状态报告功能
git-workflow branch status --all

# 验证分支恢复功能
git-workflow branch restore --help

# 验证定时任务功能
git-workflow branch schedule --help

# 验证分支清理dry-run模式
git-workflow branch cleanup --dry-run
```

### 运行测试

```bash
# 运行测试脚本
~/.codebuddy/skills/git-workflow/tests/test-git-workflow.sh
```

## 卸载

### 使用卸载脚本

```bash
# 运行卸载脚本
~/.codebuddy/skills/git-workflow/scripts/uninstall.sh
```

### 手动卸载

```bash
# 1. 删除主目录
rm -rf ~/.codebuddy/skills/git-workflow

# 2. 删除日志目录
rm -rf ~/.codebuddy/logs/git-workflow

# 3. 删除备份目录
rm -rf ~/.codebuddy/backups/git-workflow

# 4. 删除命令链接
rm -f ~/.local/bin/git-workflow
```

## 故障排除

### 常见问题

#### 1. 权限问题

```bash
# 确保脚本有执行权限
chmod +x ~/.codebuddy/skills/git-workflow/scripts/*.sh
```

#### 2. PATH 问题

```bash
# 检查 PATH 是否包含 ~/.local/bin
echo $PATH | grep -q "$HOME/.local/bin" && echo "PATH 正确" || echo "需要添加 PATH"

# 添加到 PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 3. 配置文件问题

```bash
# 检查配置文件是否存在
ls -la ~/.codebuddy/skills/git-workflow/git-workflow.yaml

# 如果不存在，创建符号链接
ln -s /mnt/c/Users/HP/.codebuddy/skills/git-workflow ~/.codebuddy/skills/git-workflow
```

#### 4. 网络问题

```bash
# 使用代理
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port

# 或者配置 git 代理
git config --global http.proxy http://proxy:port
git config --global https.proxy http://proxy:port
```

## 更新

### 更新到新版本

```bash
# 1. 备份当前配置
cp ~/.codebuddy/skills/git-workflow/git-workflow.yaml ~/.codebuddy/skills/git-workflow/git-workflow.yaml.bak

# 2. 下载新版本
git pull origin main

# 3. 运行安装脚本
./scripts/install.sh

# 4. 恢复配置（如果需要）
cp ~/.codebuddy/skills/git-workflow/git-workflow.yaml.bak ~/.codebuddy/skills/git-workflow/git-workflow.yaml
```

## 支持

- **问题反馈**: 提交 Issue
- **功能建议**: 提交 PR
- **文档改进**: 提交 PR

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](../LICENSE) 文件