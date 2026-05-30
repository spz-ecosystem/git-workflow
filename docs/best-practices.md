# 最佳实践指南

## 推送最佳实践

### 1. 始终使用预检

```bash
# ✅ 推荐：使用预检
git-workflow push --precheck

# ❌ 不推荐：直接推送
git-workflow push
```

**原因**：预检可以检测到潜在问题，避免推送失败。

### 2. 使用标准推送流程

```bash
# ✅ 推荐：标准流程
git add .
git commit -m "feat: 添加新功能"
git-workflow push --precheck

# ❌ 不推荐：跳过步骤
git push origin main
```

### 3. 处理推送失败

```bash
# 如果推送失败，使用 PR 回退
git-workflow push --pr-fallback

# 或者手动创建 PR
git checkout -b feature/my-feature
git push origin feature/my-feature
gh pr create --base main --head feature/my-feature --fill
```

## 分支管理最佳实践

### 1. 遵循命名规范

```bash
# ✅ 推荐：使用规范命名
git-workflow branch create feature/user-authentication
git-workflow branch create bugfix/login-error
git-workflow branch create hotfix/security-fix
git-workflow branch create release/v1.2.0

# ❌ 不推荐：使用不规范命名
git-workflow branch create my-branch
git-workflow branch create test123
```

### 2. 使用隔离 Worktree

```bash
# ✅ 推荐：使用隔离 worktree
git-workflow branch create feature/new-feature
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/feature/new-feature

# ❌ 不推荐：在主 worktree 中工作
git checkout -b feature/new-feature
```

**原因**：隔离 worktree 可以避免污染主分支，提高开发效率。

### 3. 定期清理分支

```bash
# ✅ 推荐：定期清理
git-workflow branch cleanup

# ❌ 不推荐：积累大量分支
git branch -a  # 显示很多分支
```

### 4. 删除分支前检查

```bash
# ✅ 推荐：使用安全检查
git-workflow branch delete feature/old-feature

# ❌ 不推荐：直接删除
git branch -D feature/old-feature
```

### 5. 定期查看分支状态

```bash
# ✅ 推荐：定期查看分支状态
git-workflow branch status --all

# ❌ 不推荐：忽略分支状态
# 直接操作
```

**原因**：定期查看分支状态可以了解分支健康状况，及时发现过期分支。

### 6. 备份重要分支

```bash
# ✅ 推荐：备份重要分支
# 删除分支前，确保备份目录存在
ls -la ~/.codebuddy/backups/git-workflow/branch-deletes/

# ❌ 不推荐：不备份直接删除
git branch -D feature/important-feature
```

**原因**：备份分支引用可以在误删后恢复，避免数据丢失。

### 7. 配置定时清理任务

```bash
# ✅ 推荐：配置定时清理任务
git-workflow branch schedule --weekly --time 02:00

# ❌ 不推荐：手动定期清理
# 容易忘记，导致分支积累
```

**原因**：定时清理任务可以自动清理过期分支，保持仓库整洁。

### 8. 使用dry-run模式预览清理

```bash
# ✅ 推荐：使用dry-run模式预览
git-workflow branch cleanup --dry-run

# ❌ 不推荐：直接执行清理
git-workflow branch cleanup
```

**原因**：dry-run模式可以预览清理计划，避免误删重要分支。

### 9. 恢复误删分支

```bash
# ✅ 推荐：恢复误删分支
git-workflow branch restore feature/old-feature

# ❌ 不推荐：放弃恢复
# 重新创建分支，丢失历史记录
```

**原因**：恢复功能可以快速恢复误删分支，避免重新创建。

### 10. 监控分支过期状态

```bash
# ✅ 推荐：监控分支过期状态
git-workflow branch status --expire-days 30

# ❌ 不推荐：忽略过期分支
# 过期分支可能包含过时代码
```

**原因**：监控过期状态可以及时清理过期分支，避免代码过时。

## Worktree 最佳实践

### 1. 保护主 Worktree

```bash
# ✅ 推荐：保护主 worktree
git worktree lock --reason '主分支保护' .

# ❌ 不推荐：在主 worktree 中创建分支
git checkout -b feature/new-feature
```

### 2. 使用统一路径

```bash
# ✅ 推荐：使用统一路径
git worktree add ~/.config/superpowers/worktrees/$(basename $(pwd))/feature/new-feature feature/new-feature

# ❌ 不推荐：使用随机路径
git worktree add /tmp/my-worktree feature/new-feature
```

### 3. 清理孤立 Worktree

```bash
# ✅ 推荐：定期清理
git-workflow worktree cleanup

# ❌ 不推荐：忽略孤立 worktree
git worktree list  # 显示很多孤立 worktree
```

## 发版最佳实践

### 1. 执行发版预检

```bash
# ✅ 推荐：执行预检
git-workflow release check

# ❌ 不推荐：跳过预检
git-workflow release prepare v1.2.0
```

### 2. 使用语义化版本

```bash
# ✅ 推荐：语义化版本
git-workflow release prepare v1.2.0
git-workflow release prepare v1.2.1
git-workflow release prepare v2.0.0

# ❌ 不推荐：非语义化版本
git-workflow release prepare release-1
git-workflow release prepare latest
```

### 3. 完整发版流程

```bash
# 1. 执行预检
git-workflow release check

# 2. 准备发版
git-workflow release prepare v1.2.0

# 3. 切换到 release 分支
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/release/v1.2.0

# 4. 最终测试和修复
# ...

# 5. 提交更改
git add .
git commit -m "release: v1.2.0"

# 6. 推送
git-workflow push

# 7. 创建 PR
gh pr create --base main --head release/v1.2.0 --fill

# 8. 合并后打标签
git tag v1.2.0
git push origin v1.2.0

# 9. 清理
git-workflow branch delete release/v1.2.0
```

## 安全审查最佳实践

### 1. 定期安全审查

```bash
# ✅ 推荐：定期审查
git-workflow security review

# ❌ 不推荐：忽略安全审查
# 直接操作
```

### 2. 执行安全审计

```bash
# ✅ 推荐：执行审计
git-workflow security audit

# ❌ 不推荐：忽略审计
# 直接操作
```

### 3. 监控异常操作

```bash
# ✅ 推荐：监控异常
# 查看日志
cat ~/.codebuddy/logs/git-workflow/operations.log

# ❌ 不推荐：忽略异常
# 直接操作
```

## 清理最佳实践

### 1. 定期清理远程引用

```bash
# ✅ 推荐：定期清理
git-workflow cleanup remote

# ❌ 不推荐：忽略清理
# 直接操作
```

### 2. 清理孤立 Worktree

```bash
# ✅ 推荐：定期清理
git-workflow cleanup worktree

# ❌ 不推荐：忽略孤立 worktree
# 直接操作
```

### 3. 清理临时分支

```bash
# ✅ 推荐：定期清理
git-workflow cleanup branches

# ❌ 不推荐：积累临时分支
# 直接操作
```

### 4. 使用配置文件管理清理规则

```bash
# ✅ 推荐：使用配置文件管理清理规则
# 在 git-workflow.yaml 中配置清理选项
branch:
  cleanup:
    expire_days: 30
    clean_merged: true
    clean_remote: true
    exclude:
      - main
      - master
      - develop

# ❌ 不推荐：硬编码清理规则
# 直接在命令中指定参数
```

**原因**：配置文件可以统一管理清理规则，便于团队协作。

### 5. 备份后再清理

```bash
# ✅ 推荐：备份后再清理
# 清理前查看备份目录
ls -la ~/.codebuddy/backups/git-workflow/branch-deletes/

# ❌ 不推荐：直接清理不备份
# 可能导致无法恢复
```

**原因**：备份可以在清理后恢复重要分支，避免数据丢失。

### 6. 监控清理结果

```bash
# ✅ 推荐：监控清理结果
# 查看清理日志
cat ~/.codebuddy/logs/git-workflow/operations.log | grep cleanup

# ❌ 不推荐：忽略清理结果
# 可能遗漏重要信息
```

**原因**：监控清理结果可以了解清理效果，及时发现异常。

### 7. 分阶段清理

```bash
# ✅ 推荐：分阶段清理
# 第一阶段：dry-run预览
git-workflow branch cleanup --dry-run

# 第二阶段：非交互式清理
git-workflow branch cleanup --non-interactive

# ❌ 不推荐：一次性清理所有
# 可能误删重要分支
```

**原因**：分阶段清理可以降低风险，确保清理安全。

### 8. 清理后验证

```bash
# ✅ 推荐：清理后验证
# 检查分支状态
git-workflow branch status

# 检查worktree状态
git worktree list

# ❌ 不推荐：清理后不验证
# 可能遗漏问题
```

**原因**：清理后验证可以确保清理效果，及时发现异常。

### 9. 记录清理历史

```bash
# ✅ 推荐：记录清理历史
# 查看清理操作日志
cat ~/.codebuddy/logs/git-workflow/operations.log

# ❌ 不推荐：不记录清理历史
# 无法追溯清理操作
```

**原因**：记录清理历史可以追溯操作，便于审计和故障排查。

### 10. 团队统一清理策略

```bash
# ✅ 推荐：团队统一清理策略
# 使用统一的配置文件
git add ~/.codebuddy/skills/git-workflow/git-workflow.yaml
git commit -m "config: 更新清理策略"

# ❌ 不推荐：各自为政
# 每个成员使用不同的清理策略
```

**原因**：统一清理策略可以保持仓库一致性，避免冲突。

## 配置最佳实践

### 1. 使用版本控制

```bash
# ✅ 推荐：将配置纳入版本控制
git add ~/.codebuddy/skills/git-workflow/git-workflow.yaml
git commit -m "config: 更新 git-workflow 配置"

# ❌ 不推荐：配置不在版本控制中
# 直接修改配置文件
```

### 2. 备份配置

```bash
# ✅ 推荐：备份配置
cp ~/.codebuddy/skills/git-workflow/git-workflow.yaml ~/.codebuddy/skills/git-workflow/git-workflow.yaml.bak

# ❌ 不推荐：不备份配置
# 直接修改配置文件
```

### 3. 使用环境变量

```bash
# ✅ 推荐：使用环境变量
export GIT_WORKFLOW_CONFIG="/path/to/config.yaml"
export GIT_WORKFLOW_LOG="/path/to/logs"
export GIT_WORKFLOW_BACKUP="/path/to/backups"

# ❌ 不推荐：硬编码路径
# 直接修改配置文件
```

## 团队协作最佳实践

### 1. 统一工作流

```bash
# ✅ 推荐：统一工作流
# 所有团队成员使用相同的 git-workflow 配置
# 所有团队成员遵循相同的分支命名规范
# 所有团队成员使用相同的推送流程

# ❌ 不推荐：各自为政
# 每个团队成员使用不同的配置
# 每个团队成员使用不同的分支命名
# 每个团队成员使用不同的推送流程
```

### 2. 文档记录

```bash
# ✅ 推荐：文档记录
# 记录工作流
# 记录配置说明
# 记录故障排除

# ❌ 不推荐：没有文档
# 直接操作
```

### 3. 培训新成员

```bash
# ✅ 推荐：培训新成员
# 提供文档
# 提供示例
# 提供支持

# ❌ 不推荐：不培训
# 直接让新成员操作
```

## 监控和告警最佳实践

### 1. 监控操作

```bash
# ✅ 推荐：监控操作
# 查看日志
cat ~/.codebuddy/logs/git-workflow/operations.log

# 监控异常
grep -i error ~/.codebuddy/logs/git-workflow/*.log

# ❌ 不推荐：不监控
# 直接操作
```

### 2. 设置告警

```bash
# ✅ 推荐：设置告警
# 配置通知
# 配置邮件告警
# 配置 Slack 通知

# ❌ 不推荐：不设置告警
# 直接操作
```

### 3. 定期审查

```bash
# ✅ 推荐：定期审查
# 审查日志
# 审查配置
# 审查权限

# ❌ 不推荐：不审查
# 直接操作
```

## 性能优化最佳实践

### 1. 优化 Git 配置

```bash
# ✅ 推荐：优化配置
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256

# ❌ 不推荐：使用默认配置
# 直接操作
```

### 2. 使用缓存

```bash
# ✅ 推荐：使用缓存
# 使用 git 缓存
# 使用构建缓存
# 使用依赖缓存

# ❌ 不推荐：不使用缓存
# 直接操作
```

### 3. 减少网络请求

```bash
# ✅ 推荐：减少网络请求
# 使用本地缓存
# 使用批量操作
# 使用压缩

# ❌ 不推荐：频繁网络请求
# 直接操作
```

## 安全最佳实践

### 1. 使用 SSH 密钥

```bash
# ✅ 推荐：使用 SSH 密钥
ssh-keygen -t ed25519 -C "your_email@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# ❌ 不推荐：使用密码
# 直接操作
```

### 2. 使用访问令牌

```bash
# ✅ 推荐：使用访问令牌
# 使用 fine-grained token
# 使用 classic token
# 使用 OAuth

# ❌ 不推荐：使用密码
# 直接操作
```

### 3. 定期轮换密钥

```bash
# ✅ 推荐：定期轮换
# 定期更换 SSH 密钥
# 定期更换访问令牌
# 定期更换密码

# ❌ 不推荐：不轮换
# 直接操作
```

## 总结

1. **始终使用预检**：避免推送失败
2. **遵循命名规范**：提高可读性
3. **使用隔离 Worktree**：避免污染主分支
4. **定期清理**：保持仓库整洁
5. **备份配置**：避免配置丢失
6. **监控操作**：及时发现问题
7. **团队协作**：统一工作流
8. **安全第一**：使用密钥和令牌