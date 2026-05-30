# 故障排除指南

## 常见问题

### 1. 安装问题

#### 问题：安装脚本无法执行

**症状**：
```bash
$ ./scripts/install.sh
bash: ./scripts/install.sh: Permission denied
```

**解决方案**：
```bash
# 设置执行权限
chmod +x ./scripts/install.sh

# 或者使用 bash 直接执行
bash ./scripts/install.sh
```

#### 问题：依赖缺失

**症状**：
```bash
$ ./scripts/install.sh
[ERROR] git 未安装，请先安装 git
```

**解决方案**：
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install git

# CentOS/RHEL
sudo yum install git

# macOS
brew install git
```

#### 问题：目录权限问题

**症状**：
```bash
$ ./scripts/install.sh
mkdir: cannot create directory '/root/.codebuddy': Permission denied
```

**解决方案**：
```bash
# 检查目录权限
ls -la ~/.codebuddy

# 修改权限
chmod 755 ~/.codebuddy

# 或者使用 sudo（不推荐）
sudo ./scripts/install.sh
```

### 2. 配置问题

#### 问题：配置文件不存在

**症状**：
```bash
$ git-workflow --help
[WARN] 配置文件不存在: /root/.codebuddy/skills/git-workflow/git-workflow.yaml
[INFO] 使用默认配置
```

**解决方案**：
```bash
# 方案1：自动检测会创建符号链接
git-workflow --help

# 方案2：手动创建符号链接
ln -s /mnt/c/Users/HP/.codebuddy/skills/git-workflow ~/.codebuddy/skills/git-workflow

# 方案3：复制配置文件
cp ~/.codebuddy/skills/git-workflow/templates/git-workflow.yaml ~/.codebuddy/skills/git-workflow/git-workflow.yaml
```

#### 问题：配置文件格式错误

**症状**：
```bash
$ git-workflow --help
[ERROR] 配置文件格式错误
```

**解决方案**：
```bash
# 检查 YAML 语法
python3 -c "import yaml; yaml.safe_load(open('$HOME/.codebuddy/skills/git-workflow/git-workflow.yaml'))"

# 如果语法错误，恢复默认配置
cp ~/.codebuddy/skills/git-workflow/templates/git-workflow.yaml ~/.codebuddy/skills/git-workflow/git-workflow.yaml
```

#### 问题：环境变量不生效

**症状**：
```bash
$ export GIT_WORKFLOW_CONFIG="/custom/path/config.yaml"
$ git-workflow --help
[WARN] 配置文件不存在: /root/.codebuddy/skills/git-workflow/git-workflow.yaml
```

**解决方案**：
```bash
# 检查环境变量
echo $GIT_WORKFLOW_CONFIG

# 确保环境变量在当前 shell 中生效
source ~/.bashrc

# 或者直接在命令中指定
GIT_WORKFLOW_CONFIG="/custom/path/config.yaml" git-workflow --help
```

### 3. 权限问题

#### 问题：脚本无法执行

**症状**：
```bash
$ git-workflow --help
bash: /root/.codebuddy/skills/git-workflow/scripts/git-workflow.sh: Permission denied
```

**解决方案**：
```bash
# 设置执行权限
chmod +x ~/.codebuddy/skills/git-workflow/scripts/*.sh

# 检查权限
ls -la ~/.codebuddy/skills/git-workflow/scripts/
```

#### 问题：目录无法创建

**症状**：
```bash
$ git-workflow --help
mkdir: cannot create directory '/root/.codebuddy/logs/git-workflow': Permission denied
```

**解决方案**：
```bash
# 检查目录权限
ls -la ~/.codebuddy/

# 修改权限
chmod 755 ~/.codebuddy/
chmod 755 ~/.codebuddy/logs/
chmod 755 ~/.codebuddy/backups/
```

### 4. 网络问题

#### 问题：推送超时

**症状**：
```bash
$ git-workflow push
fatal: unable to access 'https://github.com/...': GnuTLS recv error (-110): The TLS connection was non-properly terminated.
```

**解决方案**：
```bash
# 方案1：使用代理
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port

# 方案2：配置 git 代理
git config --global http.proxy http://proxy:port
git config --global https.proxy http://proxy:port

# 方案3：增加超时时间
export GIT_WORKFLOW_TIMEOUT=600

# 方案4：使用 SSH 代替 HTTPS
git remote set-url origin git@github.com:user/repo.git
```

#### 问题：TLS 错误

**症状**：
```bash
$ git-workflow push
fatal: unable to access 'https://github.com/...': SSL: certificate verification failed
```

**解决方案**：
```bash
# 方案1：更新证书
sudo apt update
sudo apt install ca-certificates

# 方案2：临时禁用 SSL 验证（不推荐）
git config --global http.sslVerify false

# 方案3：使用 SSH 代替 HTTPS
git remote set-url origin git@github.com:user/repo.git
```

### 5. Git 问题

#### 问题：不在 git 仓库中

**症状**：
```bash
$ git-workflow push
[ERROR] 当前目录不是git仓库
```

**解决方案**：
```bash
# 检查当前目录
pwd

# 检查是否在 git 仓库中
git status

# 如果不在 git 仓库中，进入 git 仓库目录
cd /path/to/git/repo
```

#### 问题：分支保护

**症状**：
```bash
$ git-workflow push
remote: error: GH006: Protected branch update failed.
```

**解决方案**：
```bash
# 方案1：使用 PR 回退
git-workflow push --pr-fallback

# 方案2：手动创建 PR
git checkout -b feature/my-feature
git push origin feature/my-feature
gh pr create --base main --head feature/my-feature --fill
```

#### 问题：Worktree 问题

**症状**：
```bash
$ git-workflow worktree create feature-new
fatal: 'feature-new' already exists
```

**解决方案**：
```bash
# 检查 worktree 列表
git worktree list

# 删除现有的 worktree
git worktree remove /path/to/worktree

# 或者使用不同的分支名
git-workflow worktree create feature-new-v2
```

#### 问题：分支删除失败

**症状**：
```bash
$ git-workflow branch delete feature-old
[ERROR] 分支 'feature-old' 是保护分支，不能删除
```

**解决方案**：
```bash
# 检查分支是否受保护
git-workflow branch status

# 使用安全检查脚本
~/.codebuddy/skills/git-workflow/scripts/branch-delete-safety-check.sh --dry-run feature-old

# 检查分支是否有关联的worktree
git worktree list | grep feature-old
```

#### 问题：分支恢复失败

**症状**：
```bash
$ git-workflow branch restore feature-old
[ERROR] 没有找到分支备份
```

**解决方案**：
```bash
# 检查备份目录是否存在
ls -la ~/.codebuddy/backups/git-workflow/branch-deletes/

# 手动恢复分支
git branch feature-old <备份文件路径>

# 检查备份文件
ls -la ~/.codebuddy/backups/git-workflow/branch-deletes/*/
```

#### 问题：定时任务配置失败

**症状**：
```bash
$ git-workflow branch schedule --weekly
[ERROR] crontab 不可用
```

**解决方案**：
```bash
# 检查crontab是否可用
crontab -l

# 手动添加定时任务
crontab -e
# 添加：0 2 * * 0 cd <仓库路径> && ~/.codebuddy/skills/git-workflow/scripts/git-workflow.sh branch cleanup --non-interactive --no-remote

# 检查定时任务是否添加成功
crontab -l | grep git-workflow
```

### 6. Windows/WSL 问题

#### 问题：WSL 中无法访问 Windows 文件

**症状**：
```bash
$ ls /mnt/c/Users/HP/.codebuddy
ls: cannot access '/mnt/c/Users/HP/.codebuddy': No such file or directory
```

**解决方案**：
```bash
# 检查 WSL 版本
wsl --list --verbose

# 确保 WSL2 已安装
wsl --install

# 检查挂载点
mount | grep drvfs

# 手动挂载（如果需要）
sudo mount -t drvfs C: /mnt/c
```

#### 问题：符号链接创建失败

**症状**：
```bash
$ git-workflow --help
[WARN] 配置文件不存在: /root/.codebuddy/skills/git-workflow/git-workflow.yaml
[INFO] 检测到Windows路径，创建符号链接...
[INFO] 使用默认配置
```

**解决方案**：
```bash
# 检查 Windows 路径是否存在
ls -la /mnt/c/Users/HP/.codebuddy/skills/git-workflow/

# 手动创建符号链接
ln -s /mnt/c/Users/HP/.codebuddy/skills/git-workflow ~/.codebuddy/skills/git-workflow

# 或者复制文件
cp -r /mnt/c/Users/HP/.codebuddy/skills/git-workflow ~/.codebuddy/skills/
```

### 7. 性能问题

#### 问题：命令执行缓慢

**症状**：
```bash
$ git-workflow --help
# 执行时间很长
```

**解决方案**：
```bash
# 检查网络连接
ping github.com

# 检查 git 配置
git config --list

# 优化 git 配置
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256

# 检查磁盘空间
df -h
```

#### 问题：内存不足

**症状**：
```bash
$ git-workflow push
fatal: Out of memory, malloc failed
```

**解决方案**：
```bash
# 检查内存使用
free -h

# 增加 swap 空间
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 或者减少 git 缓冲区
git config --global http.postBuffer 524288000
```

## 调试技巧

### 1. 启用调试模式

```bash
# 启用调试模式
export GIT_WORKFLOW_DEBUG=1

# 执行命令
git-workflow push --precheck

# 查看详细日志
cat ~/.codebuddy/logs/git-workflow/operations.log
```

### 2. 查看详细输出

```bash
# 使用 verbose 模式
git-workflow push --precheck --verbose

# 或者设置配置
export GIT_WORKFLOW_VERBOSE=1
```

### 3. 检查日志文件

```bash
# 查看操作日志
cat ~/.codebuddy/logs/git-workflow/operations.log

# 查看错误日志
grep -i error ~/.codebuddy/logs/git-workflow/*.log

# 查看最近日志
tail -100 ~/.codebuddy/logs/git-workflow/operations.log
```

### 4. 测试配置

```bash
# 运行测试脚本
~/.codebuddy/skills/git-workflow/tests/test-git-workflow.sh

# 测试特定功能
git-workflow security review
git-workflow cleanup remote
```

## 恢复操作

### 1. 恢复默认配置

```bash
# 备份当前配置
cp ~/.codebuddy/skills/git-workflow/git-workflow.yaml ~/.codebuddy/skills/git-workflow/git-workflow.yaml.bak

# 恢复默认配置
cp ~/.codebuddy/skills/git-workflow/templates/git-workflow.yaml ~/.codebuddy/skills/git-workflow/git-workflow.yaml
```

### 2. 恢复备份

```bash
# 查看备份列表
ls -la ~/.codebuddy/backups/git-workflow/

# 恢复备份
cp ~/.codebuddy/backups/git-workflow/git-workflow.yaml.bak ~/.codebuddy/skills/git-workflow/git-workflow.yaml
```

### 3. 重新安装

```bash
# 卸载
~/.codebuddy/skills/git-workflow/scripts/uninstall.sh

# 重新安装
./scripts/install.sh
```

## 获取帮助

### 1. 查看帮助信息

```bash
# 查看主帮助
git-workflow --help

# 查看模块帮助
git-workflow push --help
git-workflow branch --help
git-workflow worktree --help
git-workflow release --help
git-workflow security --help
git-workflow cleanup --help
```

### 2. 查看文档

```bash
# 查看 README
cat ~/.codebuddy/skills/git-workflow/README.md

# 查看设计文档
cat ~/.codebuddy/skills/git-workflow/DESIGN.md

# 查看主文档
cat ~/.codebuddy/skills/git-workflow/SKILL.md
```

### 3. 提交问题

如果以上方法都无法解决问题，请提交问题：

1. **收集信息**：
   - 操作系统版本
   - Git 版本
   - 错误信息
   - 日志文件

2. **提交 Issue**：
   - 详细描述问题
   - 提供复现步骤
   - 附上相关日志

3. **联系支持**：
   - 邮件支持
   - 社区论坛
   - 文档反馈