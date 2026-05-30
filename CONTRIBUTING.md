# 贡献指南

感谢您对 Git Workflow Umbrella Skill 的关注！我们欢迎各种形式的贡献。

## 如何贡献

### 1. 报告问题

如果您发现了 bug 或有功能建议，请提交 Issue：

1. **搜索现有 Issue**：确保问题没有被报告过
2. **创建新 Issue**：详细描述问题或建议
3. **提供信息**：
   - 操作系统版本
   - Git 版本
   - 错误信息
   - 复现步骤

### 2. 提交代码

#### Fork 仓库

```bash
# 1. Fork 仓库到您的 GitHub 账户
# 2. 克隆您的 Fork
git clone https://github.com/spz-ecosystem/git-workflow.git

# 3. 添加上游仓库
git remote add upstream https://github.com/spz-ecosystem/git-workflow.git
```

#### 创建分支

```bash
# 1. 同步上游代码
git fetch upstream
git checkout main
git merge upstream/main

# 2. 创建功能分支
git checkout -b feature/your-feature

# 3. 或者创建 bugfix 分支
git checkout -b bugfix/your-bugfix
```

#### 提交更改

```bash
# 1. 提交更改
git add .
git commit -m "feat: 添加新功能"

# 2. 推送到您的 Fork
git push origin feature/your-feature

# 3. 创建 Pull Request
gh pr create --base main --head feature/your-feature --fill
```

### 3. 改进文档

#### 修复文档

```bash
# 1. 编辑文档文件
# 2. 提交更改
git add docs/
git commit -m "docs: 修复文档错误"

# 3. 推送并创建 PR
```

#### 添加示例

```bash
# 1. 在 examples/ 目录添加示例
# 2. 提交更改
git add examples/
git commit -m "docs: 添加使用示例"

# 3. 推送并创建 PR
```

## 开发规范

### 1. 代码规范

#### Shell 脚本

```bash
# 使用 bash
#!/bin/bash

# 使用 set -e
set -e

# 使用函数
function_name() {
    local param1=$1
    local param2=$2
    
    # 函数体
}

# 使用日志函数
log_info "信息"
log_warn "警告"
log_error "错误"
log_success "成功"
```

#### YAML 配置

```yaml
# 使用 2 空格缩进
key: value
nested:
  key: value

# 使用注释
# 这是注释
key: value  # 行内注释
```

#### Markdown 文档

```markdown
# 标题

## 二级标题

正文内容。

```bash
# 代码示例
command
```

- 列表项 1
- 列表项 2
```

### 2. 提交规范

#### 提交消息格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

#### 类型

- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试
- `chore`: 构建过程或辅助工具的变动

#### 示例

```bash
# 新功能
git commit -m "feat(push): 添加推送前预检功能"

# 修复 bug
git commit -m "fix(branch): 修复分支删除安全检查问题"

# 文档更新
git commit -m "docs(readme): 更新安装说明"

# 重构
git commit -m "refactor(scripts): 重构配置加载逻辑"
```

### 3. 分支规范

#### 分支命名

```
feature/功能描述
bugfix/问题描述
hotfix/紧急修复
release/版本号
```

#### 示例

```bash
# 功能分支
feature/user-authentication
feature/push-precheck

# Bug 修复分支
bugfix/login-error
bugfix/config-loading

# 紧急修复分支
hotfix/security-fix
hotfix/crash-fix

# 发布分支
release/v1.0.0
release/v1.1.0
```

#### 分支管理命令

```bash
# 创建分支（自动创建隔离worktree）
git-workflow branch create feature/new-feature

# 删除分支（安全审查后）
git-workflow branch delete feature/old-feature

# 清理分支
git-workflow branch cleanup

# 查看分支状态
git-workflow branch status --all

# 恢复已删除分支
git-workflow branch restore feature/old-feature

# 配置定时清理任务
git-workflow branch schedule --weekly --time 02:00
```

## 测试

### 1. 运行测试

```bash
# 运行所有测试
./tests/test-git-workflow.sh

# 运行特定测试
./tests/test-git-workflow.sh test_help
./tests/test-git-workflow.sh test_config
```

### 2. 添加测试

```bash
# 在 tests/test-git-workflow.sh 中添加测试函数
test_your_feature() {
    # 测试逻辑
    if [ condition ]; then
        return 0
    else
        return 1
    fi
}

# 在 main 函数中添加测试
run_test "你的测试" test_your_feature
```

### 3. 测试覆盖率

```bash
# 确保所有功能都有测试
# 确保测试覆盖正常流程和异常流程
# 确保测试在不同环境下都能运行
```

## 文档

### 1. 更新文档

```bash
# 更新 README.md
# 更新 DESIGN.md
# 更新 SKILL.md
# 更新 docs/ 目录下的文档
```

### 2. 添加示例

```bash
# 在 examples/ 目录添加示例
# 确保示例清晰易懂
# 确保示例可以运行
```

### 3. 文档规范

```bash
# 使用清晰的标题
# 使用代码示例
# 使用表格
# 使用列表
```

## 代码审查

### 1. 审查清单

- [ ] 代码符合规范
- [ ] 测试通过
- [ ] 文档更新
- [ ] 没有安全问题
- [ ] 性能良好
- [ ] 兼容性良好

### 2. 审查流程

1. **提交 PR**：详细描述更改
2. **自动测试**：CI/CD 自动运行测试
3. **人工审查**：团队成员审查代码
4. **修改反馈**：根据反馈修改代码
5. **合并代码**：审查通过后合并

### 3. 审查标准

- **功能正确**：代码实现符合需求
- **代码质量**：代码清晰、可读、可维护
- **测试覆盖**：有足够的测试覆盖
- **文档完整**：文档更新完整
- **性能良好**：没有性能问题
- **安全可靠**：没有安全问题

## 发布

### 1. 版本号

```
主版本号.次版本号.修订号
```

- **主版本号**：不兼容的 API 修改
- **次版本号**：向下兼容的功能性新增
- **修订号**：向下兼容的问题修正

### 2. 发布流程

```bash
# 1. 更新版本号
# 更新 git-workflow.yaml 中的版本号
# 更新 CHANGELOG.md

# 2. 创建发布分支
git checkout -b release/v1.2.0

# 3. 提交更改
git add .
git commit -m "release: v1.2.0"

# 4. 推送并创建 PR
git push origin release/v1.2.0
gh pr create --base main --head release/v1.2.0 --fill

# 5. 合并后打标签
git tag v1.2.0
git push origin v1.2.0

# 6. 创建 GitHub Release
gh release create v1.2.0 --title "v1.2.0" --notes "版本 1.2.0 发布"
```

### 3. 发布检查

- [ ] 所有测试通过
- [ ] 文档更新完整
- [ ] 版本号正确
- [ ] CHANGELOG 更新
- [ ] 没有已知问题

## 社区

### 1. 行为准则

- **尊重他人**：尊重所有贡献者
- ** constructive feedback**：提供建设性的反馈
- **包容性**：欢迎不同背景的贡献者
- **专业性**：保持专业态度

### 2. 沟通渠道

- **GitHub Issues**：问题报告和功能建议
- **GitHub Discussions**：讨论和问答
- **Pull Requests**：代码贡献
- **Email**：私人沟通

### 3. 获取帮助

- **查看文档**：首先查看文档
- **搜索 Issues**：搜索现有问题
- **提问**：在 Discussions 中提问
- **联系维护者**：紧急问题联系维护者

## 奖励

### 1. 贡献者列表

所有贡献者都会被列入贡献者列表。

### 2. 特别贡献

对于特别贡献的贡献者，我们会：

- 在 README 中特别感谢
- 在 CHANGELOG 中记录贡献
- 在发布说明中提及

### 3. 成为维护者

持续贡献的贡献者有机会成为项目维护者。

## 许可证

本项目采用 MIT 许可证。贡献代码即表示您同意您的代码在 MIT 许可证下发布。

## 感谢

感谢所有贡献者的支持！您的贡献使这个项目变得更好。