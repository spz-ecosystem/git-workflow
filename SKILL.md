---
name: git-workflow
description: Git工作流统一管理skill，整合推送、分支、worktree、发版预检、安全审查、清理和历史管理工具。v2.0.0
---

# Git Workflow Umbrella Skill

统一管理所有git工作流操作，提供标准化、自动化、可追溯的git操作规范。

## 核心原则

1. **统一入口**：所有git工作流操作通过`git-workflow`命令执行
2. **标准化操作**：遵循统一的git操作规范
3. **自动化流程**：减少人工操作，提高效率
4. **可追溯性**：记录所有操作历史，便于审计

## 模块架构

```
git-workflow
├── push          # 推送管理
├── branch        # 分支管理
├── worktree      # Worktree管理
├── release       # 发版预检
├── security      # 安全审查
├── cleanup       # 清理工具
└── history       # 历史管理 (撤销/拆分/备份/批量提交)
```

## 使用场景

### 1. 推送代码
```bash
# 标准推送
git-workflow push

# 推送前预检
git-workflow push --precheck

# PR回退（分支保护时）
git-workflow push --pr-fallback
```

### 2. 分支管理
```bash
# 创建新分支（自动创建隔离worktree）
git-workflow branch create feature-new-feature

# 删除分支（安全审查后）
git-workflow branch delete feature-old-feature

# 清理已合并分支
git-workflow branch cleanup

# 显示分支状态报告
git-workflow branch status

# 恢复已删除的分支
git-workflow branch restore feature-old-feature

# 配置分支清理定时任务
git-workflow branch schedule --weekly --time 02:00
```

### 3. Worktree管理
```bash
# 创建隔离worktree
git-workflow worktree create feature-new-feature

# 删除worktree
git-workflow worktree delete feature-old-feature

# 清理孤立worktree
git-workflow worktree cleanup
```

### 4. 发版预检
```bash
# 执行发版可行性检查
git-workflow release check

# 准备发版
git-workflow release prepare
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

## 详细功能

### 推送管理（Push Management）

#### Phase 0: 预检
1. **Hook完整性检查**
   - 检查CRLF换行符
   - 检查语法错误
   - 验证hook配置

2. **Token类型与权限验证**
   - 检测token类型（classic vs fine-grained）
   - 验证仓库权限
   - 检查token有效期

3. **分支保护检测**
   - 检查目标分支保护规则
   - 检测推送限制
   - 建议PR工作流

#### Phase 1: 标准推送
1. 核对分支和状态
2. 执行git push
3. 处理超时/TLS错误
4. 记录推送历史

#### Phase 2: PR回退
1. 创建feature分支
2. 推送feature分支
3. 创建Pull Request
4. 输出PR链接

### 分支管理（Branch Management）

#### 分支创建规范
1. **命名规范**
   - feature/功能描述
   - bugfix/问题描述
   - hotfix/紧急修复
   - release/版本号

2. **隔离要求**
   - 所有新分支必须在隔离worktree中
   - 主worktree仅用于main分支
   - 禁止在主worktree中创建新分支

#### 分支删除安全审查
1. **安全检查项目**
   - 保护分支检查
   - 当前分支检查
   - 合并状态检查
   - 未提交更改检查
   - 最后提交时间检查
   - PR关联检查
   - Worktree关联检查
   - 主Worktree检查

2. **删除流程**
   - 执行安全检查
   - 确认删除操作
   - 清理关联worktree
   - 记录删除历史

#### 分支状态报告
1. **报告内容**
   - 当前分支信息
   - 本地分支统计
   - 远程分支统计
   - 分支合并状态
   - 分支过期状态
   - 分支保护状态

2. **报告选项**
   - `--all`：显示所有分支信息
   - `--remote`：显示远程分支详情
   - `--no-merged`：不显示已合并分支
   - `--no-expired`：不显示过期分支
   - `--expire-days <天数>`：设置过期分支天数（默认30天）

#### 分支恢复
1. **恢复流程**
   - 查找备份目录
   - 检查备份文件
   - 恢复分支引用
   - 验证恢复结果

2. **备份机制**
   - 自动备份到 `~/.codebuddy/backups/git-workflow/branch-deletes/`
   - 按时间戳创建备份目录
   - 保留分支引用备份文件

#### 分支清理定时任务
1. **定时任务类型**
   - `--daily`：每日执行
   - `--weekly`：每周执行（默认）
   - `--monthly`：每月执行

2. **定时任务选项**
   - `--day <星期>`：设置执行星期（0=周日）
   - `--time <时间>`：设置执行时间（默认02:00）
   - `--disable`：禁用定时任务

### Worktree管理（Worktree Management）

#### 主Worktree保护
1. **锁定机制**
   - 使用`git worktree lock`保护
   - 配置`worktree.mainWorktree=true`
   - 禁止删除或修改

2. **隔离要求**
   - 仅用于main分支
   - 禁止在此创建其他分支
   - 禁止直接修改工作文件

#### 隔离Worktree创建
1. **创建规范**
   - 路径：`/root/.config/superpowers/worktrees/<repo>/<branch>`
   - 命名：与分支名一致
   - 权限：与主worktree一致

2. **生命周期管理**
   - 创建：检查分支是否存在
   - 使用：在隔离环境中工作
   - 清理：删除分支时自动清理

### 发版预检（Release Feasibility）

#### 构建验证
1. **编译检查**
   - 目标模块构建成功
   - 依赖库完整性
   - 配置文件正确性

2. **测试验证**
   - 关键测试最小集通过
   - 单元测试覆盖率
   - 集成测试通过

#### 质量检查
1. **代码质量**
   - 代码规范检查
   - 静态分析通过
   - 复杂度检查

2. **文档完整性**
   - API文档更新
   - 使用文档更新
   - 变更日志更新

### 安全审查（Security Review）

#### 操作安全
1. **权限验证**
   - 用户权限检查
   - 操作权限验证
   - 敏感操作确认

2. **操作审计**
   - 操作记录完整
   - 操作可追溯
   - 异常操作告警

#### 数据安全
1. **分支保护**
   - 保护分支规则
   - 强制推送限制
   - 删除保护分支限制

2. **Worktree安全**
   - 主worktree保护
   - 隔离worktree安全
   - 并发访问控制

### 清理工具（Cleanup Tools）

#### 远程清理
1. **远程跟踪引用清理**
   - `git fetch --prune`
   - 清理过期引用
   - 同步远程状态

2. **远程分支清理**
   - 删除已合并远程分支
   - 清理过期远程分支
   - 同步分支状态

#### 本地清理
1. **Worktree清理**
   - 清理孤立worktree
   - 清理未使用worktree
   - 优化worktree存储

2. **分支清理**
   - 清理已合并分支
   - 清理过期分支
   - 清理临时分支

## 配置管理

### 配置文件
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

### 环境变量
```bash
# Git Workflow配置
GIT_WORKFLOW_CONFIG=/path/to/git-workflow.yaml
GIT_WORKFLOW_LOG=/path/to/logs
GIT_WORKFLOW_BACKUP=/path/to/backups
```

### Windows/WSL路径处理

#### 自动检测机制
脚本会自动检测Windows路径并创建符号链接：
1. 检查WSL路径下的配置文件是否存在
2. 如果不存在，检测Windows路径 `/mnt/c/Users/HP/.codebuddy/skills/git-workflow/`
3. 自动创建符号链接到WSL路径
4. 使用默认配置作为后备方案

#### 路径映射
| 组件 | WSL路径 | Windows路径 |
|------|---------|-------------|
| 配置文件 | `/root/.codebuddy/skills/git-workflow/git-workflow.yaml` | `/mnt/c/Users/HP/.codebuddy/skills/git-workflow/git-workflow.yaml` |
| 日志目录 | `/root/.codebuddy/logs/git-workflow/` | `/mnt/c/Users/HP/.codebuddy/logs/git-workflow/` |
| 备份目录 | `/root/.codebuddy/backups/git-workflow/` | `/mnt/c/Users/HP/.codebuddy/backups/git-workflow/` |
| Worktrees | `/root/.config/superpowers/worktrees/` | `/mnt/c/Users/HP/.config/superpowers/worktrees/` |

#### 手动创建符号链接
如果自动检测失败，可以手动创建符号链接：
```bash
# 在WSL中执行
ln -s /mnt/c/Users/HP/.codebuddy/skills/git-workflow /root/.codebuddy/skills/git-workflow
```

## 最佳实践

### 1. 推送最佳实践
- **必须**执行预检
- **必须**使用标准推送流程
- **必须**记录推送历史
- **必须**处理推送失败

### 2. 分支管理最佳实践
- **必须**遵循命名规范
- **必须**使用隔离worktree
- **必须**执行安全审查
- **必须**记录分支操作

### 3. Worktree管理最佳实践
- **必须**保护主worktree
- **必须**使用隔离worktree
- **必须**清理孤立worktree
- **必须**记录worktree操作

### 4. 发版预检最佳实践
- **必须**执行构建验证
- **必须**执行测试验证
- **必须**检查文档完整性
- **必须**记录发版历史

### 5. 安全审查最佳实践
- **必须**验证操作权限
- **必须**记录操作历史
- **必须**监控异常操作
- **必须**定期安全审计

### 6. 清理工具最佳实践
- **必须**定期清理远程引用
- **必须**定期清理孤立worktree
- **必须**定期清理已合并分支
- **必须**记录清理历史

## 故障处理

### 1. 推送失败
- **网络超时**：使用重试机制
- **TLS错误**：检查网络配置
- **权限错误**：检查token权限
- **分支保护**：使用PR工作流

### 2. 分支操作失败
- **分支不存在**：检查分支名
- **分支被保护**：使用强制删除
- **分支有未提交更改**：先提交或暂存
- **分支有关联worktree**：先清理worktree

### 3. Worktree操作失败
- **Worktree被占用**：检查进程占用
- **Worktree有未提交更改**：先提交或暂存
- **Worktree路径错误**：检查路径配置
- **Worktree权限错误**：检查权限设置

### 4. 发版预检失败
- **构建失败**：检查代码和依赖
- **测试失败**：修复测试用例
- **文档不完整**：补充文档
- **依赖问题**：更新依赖版本

## 监控和告警

### 1. 操作监控
- **推送监控**：监控推送成功率
- **分支监控**：监控分支状态
- **Worktree监控**：监控worktree使用情况
- **发版监控**：监控发版质量

### 2. 异常告警
- **推送失败告警**：推送失败时告警
- **分支异常告警**：分支状态异常时告警
- **Worktree异常告警**：worktree状态异常时告警
- **安全事件告警**：安全事件发生时告警

### 3. 性能监控
- **操作耗时监控**：监控各操作耗时
- **资源使用监控**：监控资源使用情况
- **并发操作监控**：监控并发操作情况
- **存储空间监控**：监控存储空间使用

## 维护和支持

### 1. 日常维护
- **定期检查**：定期检查系统状态
- **定期清理**：定期清理过期数据
- **定期备份**：定期备份重要数据
- **定期更新**：定期更新系统版本

### 2. 问题处理
- **问题报告**：建立问题报告机制
- **问题分析**：分析问题根本原因
- **问题解决**：制定问题解决方案
- **问题预防**：建立问题预防机制

### 3. 持续改进
- **功能优化**：持续优化功能
- **性能优化**：持续优化性能
- **用户体验优化**：持续优化用户体验
- **文档完善**：持续完善文档

## 相关文件

- **设计文档**：`DESIGN.md`
- **配置文件**：`git-workflow.yaml`
- **脚本文件**：`scripts/`
- **测试文件**：`tests/`
- **文档文件**：`docs/`

## 更新记录

- **2026-05-09**：更新文档，添加新功能说明
- 添加分支状态报告功能
- 添加分支恢复功能
- 添加分支清理定时任务功能
- 更新配置管理部分，添加完整配置选项
- 更新最佳实践部分

- **2026-05-10**：v1.1 新增 history 模块
- 添加 undo-last (撤销最近提交, 保留工作区)
- 添加 split-root (巨型初始提交检查 + 拆分建议)
- 添加 stage-pick (文件列表 + 7 步推荐拆分顺序)
- 添加 backup (工作区完整备份)
- 添加 commit-batch (批量模块提交)

- **2026-05-05**：正式发布v1.0.0版本
- 整合github-push skill功能
- 整合推送规则功能
- 整合分支删除安全审查功能
- 整合Worktree隔离管理功能
- 添加发版预检模块
- 添加安全审查模块
- 添加清理工具模块

- **2026-05-04**：初始版本，创建git-workflow umbrella skill