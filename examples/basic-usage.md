# 基础使用示例

## 快速开始

### 1. 推送代码

```bash
# 标准推送
git-workflow push

# 推送前预检（推荐）
git-workflow push --precheck

# PR回退（分支保护时）
git-workflow push --pr-fallback
```

### 2. 分支管理

```bash
# 创建新分支（自动创建隔离worktree）
git-workflow branch create feature-user-auth

# 查看分支状态
git-workflow branch status --all

# 删除分支（安全审查后）
git-workflow branch delete feature-old-feature

# 清理已合并分支
git-workflow branch cleanup

# 恢复已删除分支
git-workflow branch restore feature-old-feature

# 配置定时清理任务
git-workflow branch schedule --weekly --time 02:00

# 分支清理dry-run模式
git-workflow branch cleanup --dry-run
```

### 3. Worktree管理

```bash
# 创建隔离worktree
git-workflow worktree create feature-user-auth

# 查看worktree列表
git worktree list

# 删除worktree
git-workflow worktree delete feature-user-auth

# 清理孤立worktree
git-workflow worktree cleanup
```

### 4. 发版预检

```bash
# 执行发版可行性检查
git-workflow release check

# 准备发版
git-workflow release prepare v1.0.0
```

### 5. 安全审查

```bash
# 执行安全审查
git-workflow security review

# 执行安全审计
git-workflow security audit
```

### 6. 清理工具

```bash
# 清理远程跟踪引用
git-workflow cleanup remote

# 清理孤立worktree
git-workflow cleanup worktree

# 清理临时分支
git-workflow cleanup branches
```

## 常见工作流

### 功能开发工作流

```bash
# 1. 创建功能分支
git-workflow branch create feature-user-auth

# 2. 切换到功能分支
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/feature-user-auth

# 3. 开发功能
# ... 编写代码 ...

# 4. 提交更改
git add .
git commit -m "feat: 添加用户认证功能"

# 5. 推送前预检
git-workflow push --precheck

# 6. 推送代码
git-workflow push

# 7. 创建PR（如果需要）
gh pr create --base main --head feature-user-auth --fill

# 8. 合并后清理
git-workflow branch delete feature-user-auth

# 9. 查看分支状态
git-workflow branch status
```

### 紧急修复工作流

```bash
# 1. 创建hotfix分支
git-workflow branch create hotfix-security-fix

# 2. 切换到hotfix分支
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/hotfix-security-fix

# 3. 修复问题
# ... 修复代码 ...

# 4. 提交更改
git add .
git commit -m "fix: 修复安全漏洞"

# 5. 推送前预检
git-workflow push --precheck

# 6. 推送代码
git-workflow push

# 7. 创建PR
gh pr create --base main --head hotfix-security-fix --fill

# 8. 合并后清理
git-workflow branch delete hotfix-security-fix
```

### 发版工作流

```bash
# 1. 执行发版预检
git-workflow release check

# 2. 准备发版
git-workflow release prepare v1.2.0

# 3. 切换到release分支
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/release/v1.2.0

# 4. 最终测试和修复
# ... 测试和修复 ...

# 5. 提交更改
git add .
git commit -m "release: v1.2.0"

# 6. 推送release分支
git-workflow push

# 7. 创建PR
gh pr create --base main --head release/v1.2.0 --fill

# 8. 合并后打标签
git tag v1.2.0
git push origin v1.2.0

# 9. 清理
git-workflow branch delete release/v1.2.0
```

## 配置示例

### 基础配置

```yaml
# git-workflow.yaml
push:
  precheck: true
  timeout: 300
  retry_count: 3

branch:
  protection:
    - main
    - master
    - develop
  auto_cleanup: true

worktree:
  isolation: true
  base_path: /root/.config/superpowers/worktrees
  auto_cleanup: true
```

### 高级配置

```yaml
# git-workflow.yaml
push:
  precheck: true
  timeout: 300
  retry_count: 3
  pr_fallback: true

branch:
  protection:
    - main
    - master
    - develop
    - release
    - production
  auto_cleanup: true
  naming:
    feature: "feature/"
    bugfix: "bugfix/"
    hotfix: "hotfix/"
    release: "release/"

worktree:
  isolation: true
  base_path: /root/.config/superpowers/worktrees
  auto_cleanup: true
  main_protection: true

release:
  precheck: true
  required_tests: true
  required_docs: true
  required_build: true

security:
  audit: true
  log_operations: true
  monitor_anomalies: true
  sensitive_operations_confirm: true

cleanup:
  auto_cleanup: true
  cleanup_interval: 7
  temp_branch_retention: 30
  worktree_retention: 30

logging:
  log_dir: "~/.codebuddy/logs/git-workflow"
  log_level: "INFO"
  verbose: false
  retention_days: 30

backup:
  backup_dir: "~/.codebuddy/backups/git-workflow"
  auto_backup: true
  retention_days: 30

notification:
  enabled: true
  methods:
    - console
    - log
  levels:
    - error
    - warning
    - success

cross_platform:
  auto_detect_windows: true
  windows_path_mapping:
    codebuddy_dir: "/mnt/c/Users/HP/.codebuddy"
    username: "HP"
  symlink:
    auto_create: true
    backup_existing: true
```

## 故障排除

### 配置文件不存在

```bash
# 自动检测会创建符号链接
git-workflow --help

# 或手动创建符号链接
ln -s /mnt/c/Users/HP/.codebuddy/skills/git-workflow /root/.codebuddy/skills/git-workflow
```

### 权限问题

```bash
# 确保脚本有执行权限
chmod +x ~/.codebuddy/skills/git-workflow/scripts/*.sh
```

### 网络问题

```bash
# 使用代理
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port
```

## 最佳实践

1. **始终使用预检**：推送前执行 `git-workflow push --precheck`
2. **使用隔离worktree**：所有新分支都在隔离worktree中工作
3. **定期清理**：定期执行 `git-workflow cleanup remote` 和 `git-workflow cleanup worktree`
4. **查看日志**：定期查看操作日志，了解git操作历史
5. **备份配置**：重要配置更改前备份配置文件
6. **定期查看分支状态**：使用 `git-workflow branch status --all` 了解分支健康状况
7. **备份重要分支**：删除分支前确保备份目录存在
8. **配置定时清理**：使用 `git-workflow branch schedule` 配置自动清理任务
9. **使用dry-run模式**：清理前使用 `--dry-run` 预览清理计划
10. **恢复误删分支**：使用 `git-workflow branch restore` 恢复误删分支