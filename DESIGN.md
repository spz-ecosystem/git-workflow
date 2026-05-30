# Git Workflow Umbrella Skill 设计文档

## 1. 设计目标

### 1.1 核心目标
- **统一管理**：整合所有git工作流相关的规则和skills
- **标准化**：建立统一的git操作规范
- **自动化**：提供一键式git工作流操作
- **可追溯**：记录所有git操作历史

### 1.2 解决的问题
- **规则分散**：git相关规则分散在多个文件中
- **职责模糊**：github-push skill和推送规则有重叠
- **操作繁琐**：开发者需要遵循多个规则文件
- **维护困难**：规则更新需要修改多个文件

## 2. 架构设计

### 2.1 分层架构
```
┌─────────────────────────────────────┐
│         git-workflow skill          │  ← 统一入口
├─────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌──────┐│
│  │ 推送管理 │  │ 分支管理 │  │Worktree││
│  │         │  │         │  │管理   ││
│  └─────────┘  └─────────┘  └──────┘│
├─────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌──────┐│
│  │ 发版预检 │  │ 安全审查 │  │清理  ││
│  │         │  │         │  │工具  ││
│  └─────────┘  └─────────┘  └──────┘│
└─────────────────────────────────────┘
```

### 2.2 核心模块

#### 模块1：推送管理（Push Management）
- **功能**：处理git push相关操作
- **包含**：
  - Phase 0 预检（hook、token、保护规则）
  - 标准推送流程
  - PR回退机制
  - 超时/TLS处理

#### 模块2：分支管理（Branch Management）
- **功能**：处理分支生命周期管理
- **包含**：
  - 分支创建规范
  - 分支删除安全审查（9项安全检查）
  - 分支合并策略
  - 分支清理工具
  - 分支状态报告
  - 分支恢复功能
  - 分支清理定时任务

#### 模块3：Worktree管理（Worktree Management）
- **功能**：处理worktree隔离和管理
- **包含**：
  - 主worktree保护
  - 隔离worktree创建
  - Worktree清理流程
  - Worktree状态监控

#### 模块4：发版预检（Release Feasibility）
- **功能**：发版前的质量检查
- **包含**：
  - 构建验证
  - 测试通过检查
  - 依赖安全检查
  - 文档完整性检查

#### 模块5：安全审查（Security Review）
- **功能**：git操作的安全检查
- **包含**：
  - 分支删除安全审查
  - Worktree安全检查
  - 权限验证
  - 操作审计

#### 模块6：清理工具（Cleanup Tools）
- **功能**：git仓库清理和维护
- **包含**：
  - 远程跟踪引用清理
  - 孤立worktree清理
  - 临时分支清理
  - 历史记录清理

## 3. 接口设计

### 3.1 命令行接口
```bash
# 推送相关
git-workflow push [options]
git-workflow push --precheck
git-workflow push --pr-fallback

# 分支管理
git-workflow branch create <name>
git-workflow branch delete <name>
git-workflow branch cleanup [options]
git-workflow branch status [options]
git-workflow branch restore <name> [backup_dir]
git-workflow branch schedule [options]

# Worktree管理
git-workflow worktree create <branch>
git-workflow worktree delete <branch>
git-workflow worktree cleanup

# 发版预检
git-workflow release check
git-workflow release prepare

# 安全审查
git-workflow security review
git-workflow security audit

# 清理工具
git-workflow cleanup remote
git-workflow cleanup worktree
git-workflow cleanup branches
```

### 3.2 配置接口
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
  cleanup:
    interactive: true
    dry_run: false
    expire_days: 30
    clean_remote: true
    clean_merged: true
    exclude:
      - main
      - master
      - develop
      - release
      - production
      - gh-pages
  
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

## 4. 实施计划

### 4.1 第一阶段：基础架构（本周）
1. 创建git-workflow skill文件结构
2. 设计统一的命令行接口
3. 实现核心模块框架
4. 集成现有github-push功能

### 4.2 第二阶段：功能完善（下周）
1. 实现分支管理模块
2. 实现Worktree管理模块
3. 实现发版预检模块
4. 实现安全审查模块

### 4.3 第三阶段：优化和测试（第三周）
1. 实现清理工具模块
2. 优化性能和用户体验
3. 编写测试用例
4. 编写使用文档

### 4.4 第四阶段：部署和推广（第四周）
1. 部署到生产环境
2. 培训团队成员
3. 收集反馈和优化
4. 建立维护机制

## 5. 迁移策略

### 5.1 现有组件迁移
1. **github-push skill** → 推送管理模块
2. **推送规则** → 发版预检和安全审查模块
3. **branch-delete-safety-check.sh** → 分支管理模块
4. **Worktree隔离策略** → Worktree管理模块

### 5.2 兼容性保证
- 保持现有命令行接口兼容
- 保持现有配置文件兼容
- 保持现有工作流程兼容
- 提供迁移指南和工具

### 5.3 回滚机制
- 保留现有skills和规则作为备份
- 提供快速回滚脚本
- 建立监控和告警机制
- 制定应急响应计划

## 6. 成功标准

### 6.1 功能标准
- ✅ 所有git工作流操作通过统一入口
- ✅ 所有现有功能完整迁移
- ✅ 新功能按计划实现
- ✅ 性能不低于现有方案

### 6.2 质量标准
- ✅ 测试覆盖率 > 80%
- ✅ 文档完整性 100%
- ✅ 用户满意度 > 90%
- ✅ 维护成本降低 50%

### 6.3 业务标准
- ✅ 开发效率提升 30%
- ✅ 错误率降低 50%
- ✅ 合规性 100%
- ✅ 安全性 100%

## 7. 风险评估

### 7.1 技术风险
- **风险**：功能迁移不完整
- **缓解**：分阶段迁移，充分测试

### 7.2 用户风险
- **风险**：用户不适应新接口
- **缓解**：保持兼容性，提供培训

### 7.3 维护风险
- **风险**：维护成本增加
- **缓解**：自动化测试，文档完善

## 8. Windows/WSL路径处理

### 8.1 路径问题分析
在Windows环境下使用WSL时，存在以下路径问题：
- **WSL路径**：`/root/.codebuddy/skills/git-workflow/`
- **Windows路径**：`/mnt/c/Users/HP/.codebuddy/skills/git-workflow/`
- **配置文件位置**：Windows路径中存在，WSL路径中不存在

### 8.2 自动检测与符号链接
脚本实现了自动检测机制：
```bash
# 检查配置文件
check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warn "配置文件不存在: $CONFIG_FILE"
        
        # 尝试从Windows路径创建符号链接
        local windows_path="/mnt/c/Users/HP/.codebuddy/skills/git-workflow"
        if [ -d "$windows_path" ]; then
            log_info "检测到Windows路径，创建符号链接..."
            mkdir -p "$(dirname "$CONFIG_FILE")"
            ln -s "$windows_path" "$(dirname "$CONFIG_FILE")/git-workflow"
            if [ -f "$CONFIG_FILE" ]; then
                log_success "符号链接创建成功，配置文件已可用"
                return 0
            fi
        fi
        
        log_info "使用默认配置"
    fi
}
```

### 8.3 路径映射规则
| 组件 | WSL路径 | Windows路径 |
|------|---------|-------------|
| 配置文件 | `/root/.codebuddy/skills/git-workflow/git-workflow.yaml` | `/mnt/c/Users/HP/.codebuddy/skills/git-workflow/git-workflow.yaml` |
| 日志目录 | `/root/.codebuddy/logs/git-workflow/` | `/mnt/c/Users/HP/.codebuddy/logs/git-workflow/` |
| 备份目录 | `/root/.codebuddy/backups/git-workflow/` | `/mnt/c/Users/HP/.codebuddy/backups/git-workflow/` |
| Worktrees | `/root/.config/superpowers/worktrees/` | `/mnt/c/Users/HP/.config/superpowers/worktrees/` |

### 8.4 环境变量覆盖
可以通过环境变量覆盖默认路径：
```bash
export GIT_WORKFLOW_CONFIG="/custom/path/to/git-workflow.yaml"
export GIT_WORKFLOW_LOG="/custom/path/to/logs"
export GIT_WORKFLOW_BACKUP="/custom/path/to/backups"
```

## 9. 总结

git-workflow umbrella skill将提供：
1. **统一入口**：一个skill管理所有git工作流
2. **标准化操作**：建立统一的git操作规范
3. **自动化流程**：减少人工操作，提高效率
4. **可追溯性**：记录所有操作历史，便于审计
5. **跨平台支持**：自动处理Windows/WSL路径问题

通过这个umbrella skill，我们可以彻底规范化git工作流，提高开发效率，降低错误率，确保代码质量。