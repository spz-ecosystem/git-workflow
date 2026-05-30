# 配置指南

## 配置文件

### 配置文件位置

- **WSL 路径**: `/root/.codebuddy/skills/git-workflow/git-workflow.yaml`
- **Windows 路径**: `/mnt/c/Users/HP/.codebuddy/skills/git-workflow/git-workflow.yaml`

### 配置文件格式

配置文件使用 YAML 格式，支持以下配置项：

```yaml
# 推送管理配置
push:
  precheck: true
  timeout: 300
  retry_count: 3
  pr_fallback: true

# 分支管理配置
branch:
  protection:
    - main
    - master
    - develop
  auto_cleanup: true
  naming:
    feature: "feature/"
    bugfix: "bugfix/"
    hotfix: "hotfix/"
    release: "release/"

# Worktree管理配置
worktree:
  isolation: true
  base_path: "/root/.config/superpowers/worktrees"
  auto_cleanup: true
  main_protection: true

# 发版预检配置
release:
  precheck: true
  required_tests: true
  required_docs: true
  required_build: true

# 安全审查配置
security:
  audit: true
  log_operations: true
  monitor_anomalies: true
  sensitive_operations_confirm: true

# 清理工具配置
cleanup:
  auto_cleanup: true
  cleanup_interval: 7
  temp_branch_retention: 30
  worktree_retention: 30

# 日志配置
logging:
  log_dir: "~/.codebuddy/logs/git-workflow"
  log_level: "INFO"
  verbose: false
  retention_days: 30

# 备份配置
backup:
  backup_dir: "~/.codebuddy/backups/git-workflow"
  auto_backup: true
  retention_days: 30

# 通知配置
notification:
  enabled: true
  methods:
    - console
    - log
  levels:
    - error
    - warning
    - success

# 跨平台配置
cross_platform:
  auto_detect_windows: true
  windows_path_mapping:
    codebuddy_dir: "/mnt/c/Users/HP/.codebuddy"
    username: "HP"
  symlink:
    auto_create: true
    backup_existing: true
```

## 配置项详解

### 推送管理配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `push.precheck` | boolean | `true` | 是否启用推送前预检 |
| `push.timeout` | integer | `300` | 推送超时时间（秒） |
| `push.retry_count` | integer | `3` | 推送重试次数 |
| `push.pr_fallback` | boolean | `true` | 是否启用PR回退机制 |

### 分支管理配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `branch.protection` | array | `["main", "master", "develop"]` | 保护分支列表 |
| `branch.auto_cleanup` | boolean | `true` | 是否自动清理已合并分支 |
| `branch.naming.feature` | string | `"feature/"` | 功能分支前缀 |
| `branch.naming.bugfix` | string | `"bugfix/"` | Bug修复分支前缀 |
| `branch.naming.hotfix` | string | `"hotfix/"` | 紧急修复分支前缀 |
| `branch.naming.release` | string | `"release/"` | 发布分支前缀 |
| `branch.cleanup.interactive` | boolean | `true` | 是否启用交互式清理 |
| `branch.cleanup.dry_run` | boolean | `false` | 是否启用dry-run模式 |
| `branch.cleanup.expire_days` | integer | `30` | 过期分支天数（默认30天） |
| `branch.cleanup.clean_remote` | boolean | `true` | 是否清理远程分支 |
| `branch.cleanup.clean_merged` | boolean | `true` | 是否清理已合并分支 |
| `branch.cleanup.exclude` | array | `["main", "master", "develop", "release", "production", "gh-pages"]` | 排除列表（不清理的分支） |

### Worktree管理配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `worktree.isolation` | boolean | `true` | 是否启用隔离worktree |
| `worktree.base_path` | string | `"/root/.config/superpowers/worktrees"` | Worktree基础路径 |
| `worktree.auto_cleanup` | boolean | `true` | 是否自动清理孤立worktree |
| `worktree.main_protection` | boolean | `true` | 是否保护主worktree |

### 发版预检配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `release.precheck` | boolean | `true` | 是否启用发版预检 |
| `release.required_tests` | boolean | `true` | 是否要求测试通过 |
| `release.required_docs` | boolean | `true` | 是否要求文档完整 |
| `release.required_build` | boolean | `true` | 是否要求构建成功 |

### 安全审查配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `security.audit` | boolean | `true` | 是否启用安全审计 |
| `security.log_operations` | boolean | `true` | 是否记录操作日志 |
| `security.monitor_anomalies` | boolean | `true` | 是否监控异常操作 |
| `security.sensitive_operations_confirm` | boolean | `true` | 敏感操作是否需要确认 |

### 清理工具配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `cleanup.auto_cleanup` | boolean | `true` | 是否自动清理 |
| `cleanup.cleanup_interval` | integer | `7` | 清理间隔（天） |
| `cleanup.temp_branch_retention` | integer | `30` | 临时分支保留天数 |
| `cleanup.worktree_retention` | integer | `30` | Worktree保留天数 |

### 日志配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `logging.log_dir` | string | `"~/.codebuddy/logs/git-workflow"` | 日志目录 |
| `logging.log_level` | string | `"INFO"` | 日志级别 |
| `logging.verbose` | boolean | `false` | 是否记录详细日志 |
| `logging.retention_days` | integer | `30` | 日志保留天数 |

### 备份配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `backup.backup_dir` | string | `"~/.codebuddy/backups/git-workflow"` | 备份目录 |
| `backup.auto_backup` | boolean | `true` | 是否自动备份 |
| `backup.retention_days` | integer | `30` | 备份保留天数 |

### 通知配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `notification.enabled` | boolean | `true` | 是否启用通知 |
| `notification.methods` | array | `["console", "log"]` | 通知方式 |
| `notification.levels` | array | `["error", "warning", "success"]` | 通知级别 |

### 跨平台配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `cross_platform.auto_detect_windows` | boolean | `true` | 是否启用Windows/WSL路径自动检测 |
| `cross_platform.windows_path_mapping.codebuddy_dir` | string | `"/mnt/c/Users/HP/.codebuddy"` | Windows .codebuddy目录路径 |
| `cross_platform.windows_path_mapping.username` | string | `"HP"` | Windows用户名 |
| `cross_platform.symlink.auto_create` | boolean | `true` | 是否自动创建符号链接 |
| `cross_platform.symlink.backup_existing` | boolean | `true` | 是否备份现有符号链接 |

## 环境变量

### 配置文件路径

```bash
# 指定配置文件路径
export GIT_WORKFLOW_CONFIG="/path/to/git-workflow.yaml"
```

### 日志目录

```bash
# 指定日志目录
export GIT_WORKFLOW_LOG="/path/to/logs"
```

### 备份目录

```bash
# 指定备份目录
export GIT_WORKFLOW_BACKUP="/path/to/backups"
```

### 调试模式

```bash
# 启用调试模式
export GIT_WORKFLOW_DEBUG=1
```

## 配置示例

### 开发环境配置

```yaml
# 开发环境配置
push:
  precheck: true
  timeout: 600
  retry_count: 5

branch:
  protection:
    - main
    - develop
  auto_cleanup: true

worktree:
  isolation: true
  base_path: /root/.config/superpowers/worktrees
  auto_cleanup: true

logging:
  log_level: "DEBUG"
  verbose: true
```

### 生产环境配置

```yaml
# 生产环境配置
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

worktree:
  isolation: true
  base_path: /root/.config/superpowers/worktrees
  auto_cleanup: true
  main_protection: true

security:
  audit: true
  log_operations: true
  monitor_anomalies: true
  sensitive_operations_confirm: true

logging:
  log_level: "INFO"
  verbose: false
```

### 测试环境配置

```yaml
# 测试环境配置
push:
  precheck: false
  timeout: 60
  retry_count: 1
  pr_fallback: false

branch:
  protection:
    - main
  auto_cleanup: false

worktree:
  isolation: true
  base_path: "/tmp/test-worktrees"
  auto_cleanup: false

release:
  precheck: false
  required_tests: false
  required_docs: false
  required_build: false

security:
  audit: false
  log_operations: false
  monitor_anomalies: false
  sensitive_operations_confirm: false

logging:
  log_dir: "/tmp/test-logs/git-workflow"
  log_level: "DEBUG"
  verbose: true
  retention_days: 1
```

## 配置管理

### 查看当前配置

```bash
# 查看配置文件
cat ~/.codebuddy/skills/git-workflow/git-workflow.yaml

# 查看环境变量
env | grep GIT_WORKFLOW
```

### 修改配置

```bash
# 编辑配置文件
nano ~/.codebuddy/skills/git-workflow/git-workflow.yaml

# 或使用环境变量覆盖
export GIT_WORKFLOW_CONFIG="/path/to/custom-config.yaml"
```

### 重置配置

```bash
# 恢复默认配置
cp ~/.codebuddy/skills/git-workflow/templates/git-workflow.yaml ~/.codebuddy/skills/git-workflow/git-workflow.yaml
```

### 备份配置

```bash
# 备份当前配置
cp ~/.codebuddy/skills/git-workflow/git-workflow.yaml ~/.codebuddy/skills/git-workflow/git-workflow.yaml.bak
```

## 配置验证

### 验证配置文件

```bash
# 检查 YAML 语法
python3 -c "import yaml; yaml.safe_load(open('$HOME/.codebuddy/skills/git-workflow/git-workflow.yaml'))"
```

### 测试配置

```bash
# 运行测试脚本
~/.codebuddy/skills/git-workflow/tests/test-git-workflow.sh
```

## 故障排除

### 配置文件不存在

```bash
# 自动检测会创建符号链接
git-workflow --help

# 或手动创建符号链接
ln -s /mnt/c/Users/HP/.codebuddy/skills/git-workflow ~/.codebuddy/skills/git-workflow
```

### 配置文件格式错误

```bash
# 检查 YAML 语法
python3 -c "import yaml; yaml.safe_load(open('$HOME/.codebuddy/skills/git-workflow/git-workflow.yaml'))"

# 如果语法错误，恢复默认配置
cp ~/.codebuddy/skills/git-workflow/templates/git-workflow.yaml ~/.codebuddy/skills/git-workflow/git-workflow.yaml
```

### 环境变量不生效

```bash
# 检查环境变量
echo $GIT_WORKFLOW_CONFIG
echo $GIT_WORKFLOW_LOG
echo $GIT_WORKFLOW_BACKUP

# 重新加载环境变量
source ~/.bashrc
```

## 最佳实践

1. **使用版本控制**：将配置文件纳入版本控制
2. **备份配置**：重要配置更改前备份配置文件
3. **使用环境变量**：通过环境变量管理不同环境的配置
4. **定期审查**：定期审查和优化配置
5. **文档记录**：记录配置更改和原因
6. **测试配置**：在测试环境中测试配置更改
7. **团队共享**：与团队共享配置最佳实践