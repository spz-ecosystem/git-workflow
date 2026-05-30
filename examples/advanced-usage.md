# 高级使用示例

## 自定义工作流

### 1. 自定义推送流程

```bash
# 创建自定义推送脚本
cat > ~/custom-push.sh << 'EOF'
#!/bin/bash
# 自定义推送脚本

set -e

echo "开始自定义推送流程..."

# 1. 代码质量检查
echo "1. 执行代码质量检查..."
# 这里可以添加你的代码质量检查工具
# eslint . --ext .js,.jsx,.ts,.tsx
# pylint *.py

# 2. 单元测试
echo "2. 执行单元测试..."
# npm test
# pytest

# 3. 构建检查
echo "3. 执行构建检查..."
# npm run build
# python setup.py build

# 4. 推送前预检
echo "4. 执行推送前预检..."
git-workflow push --precheck

# 5. 推送代码
echo "5. 推送代码..."
git-workflow push

echo "自定义推送流程完成"
EOF

chmod +x ~/custom-push.sh
```

### 2. 自定义分支管理

```bash
# 创建自定义分支管理脚本
cat > ~/custom-branch.sh << 'EOF'
#!/bin/bash
# 自定义分支管理脚本

set -e

ACTION=$1
BRANCH_NAME=$2

case $ACTION in
    "create-feature")
        echo "创建功能分支: $BRANCH_NAME"
        git-workflow branch create "feature/$BRANCH_NAME"
        
        # 切换到新分支的worktree
        cd ~/.config/superpowers/worktrees/$(basename $(pwd))/feature/$BRANCH_NAME
        
        # 初始化开发环境
        echo "初始化开发环境..."
        # npm install
        # pip install -r requirements.txt
        
        echo "功能分支创建完成"
        ;;
    "create-bugfix")
        echo "创建bugfix分支: $BRANCH_NAME"
        git-workflow branch create "bugfix/$BRANCH_NAME"
        
        # 切换到新分支的worktree
        cd ~/.config/superpowers/worktrees/$(basename $(pwd))/bugfix/$BRANCH_NAME
        
        echo "bugfix分支创建完成"
        ;;
    "create-hotfix")
        echo "创建hotfix分支: $BRANCH_NAME"
        git-workflow branch create "hotfix/$BRANCH_NAME"
        
        # 切换到新分支的worktree
        cd ~/.config/superpowers/worktrees/$(basename $(pwd))/hotfix/$BRANCH_NAME
        
        echo "hotfix分支创建完成"
        ;;
    "cleanup")
        echo "清理所有已合并分支..."
        git-workflow branch cleanup
        ;;
    "status")
        echo "查看分支状态..."
        git-workflow branch status --all
        ;;
    "restore")
        echo "恢复已删除分支: $BRANCH_NAME"
        git-workflow branch restore "$BRANCH_NAME"
        ;;
    "schedule")
        echo "配置分支清理定时任务..."
        git-workflow branch schedule --weekly --time 02:00
        ;;
    *)
        echo "用法: $0 <create-feature|create-bugfix|create-hotfix|cleanup|status|restore|schedule> [branch-name]"
        exit 1
        ;;
esac
EOF

chmod +x ~/custom-branch.sh
```

### 3. 自定义发版流程

```bash
# 创建自定义发版脚本
cat > ~/custom-release.sh << 'EOF'
#!/bin/bash
# 自定义发版脚本

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "用法: $0 <version>"
    exit 1
fi

echo "开始发版流程: $VERSION"

# 1. 执行发版预检
echo "1. 执行发版预检..."
git-workflow release check

# 2. 准备发版
echo "2. 准备发版..."
git-workflow release prepare "$VERSION"

# 3. 切换到release分支
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/release/$VERSION

# 4. 更新版本号
echo "3. 更新版本号..."
# 这里可以添加你的版本号更新逻辑
# sed -i "s/version=.*/version=$VERSION/" package.json
# sed -i "s/__version__=.*/__version__=\"$VERSION\"/" setup.py

# 5. 生成变更日志
echo "4. 生成变更日志..."
# 这里可以添加你的变更日志生成逻辑
# conventional-changelog -p angular -i CHANGELOG.md -s

# 6. 提交更改
echo "5. 提交更改..."
git add .
git commit -m "release: $VERSION"

# 7. 推送release分支
echo "6. 推送release分支..."
git-workflow push

# 8. 创建PR
echo "7. 创建PR..."
gh pr create --base main --head "release/$VERSION" --fill

echo "发版流程完成: $VERSION"
echo "请合并PR后执行以下命令:"
echo "  git tag $VERSION"
echo "  git push origin $VERSION"
echo "  git-workflow branch delete release/$VERSION"
EOF

chmod +x ~/custom-release.sh
```

## 集成其他工具

### 1. 集成 ESLint

```bash
# 在推送前执行 ESLint
cat > ~/.codebuddy/skills/git-workflow/scripts/pre-push-eslint.sh << 'EOF'
#!/bin/bash
# 推送前执行 ESLint

echo "执行 ESLint 检查..."

# 检查是否有 ESLint 配置
if [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ]; then
    npx eslint . --ext .js,.jsx,.ts,.tsx
    if [ $? -ne 0 ]; then
        echo "ESLint 检查失败"
        exit 1
    fi
    echo "ESLint 检查通过"
else
    echo "未找到 ESLint 配置，跳过检查"
fi
EOF

chmod +x ~/.codebuddy/skills/git-workflow/scripts/pre-push-eslint.sh
```

### 2. 集成 pytest

```bash
# 在推送前执行 pytest
cat > ~/.codebuddy/skills/git-workflow/scripts/pre-push-pytest.sh << 'EOF'
#!/bin/bash
# 推送前执行 pytest

echo "执行 pytest 测试..."

# 检查是否有 pytest 配置
if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "setup.cfg" ]; then
    pytest
    if [ $? -ne 0 ]; then
        echo "pytest 测试失败"
        exit 1
    fi
    echo "pytest 测试通过"
else
    echo "未找到 pytest 配置，跳过测试"
fi
EOF

chmod +x ~/.codebuddy/skills/git-workflow/scripts/pre-push-pytest.sh
```

### 3. 集成 Docker 构建

```bash
# 在发版前执行 Docker 构建
cat > ~/.codebuddy/skills/git-workflow/scripts/pre-release-docker.sh << 'EOF'
#!/bin/bash
# 发版前执行 Docker 构建

echo "执行 Docker 构建..."

# 检查是否有 Dockerfile
if [ -f "Dockerfile" ]; then
    # 构建 Docker 镜像
    docker build -t myapp:$(git describe --tags) .
    if [ $? -ne 0 ]; then
        echo "Docker 构建失败"
        exit 1
    fi
    echo "Docker 构建成功"
else
    echo "未找到 Dockerfile，跳过构建"
fi
EOF

chmod +x ~/.codebuddy/skills/git-workflow/scripts/pre-release-docker.sh
```

## 自动化脚本

### 1. 每日清理脚本

```bash
# 创建每日清理脚本
cat > ~/daily-cleanup.sh << 'EOF'
#!/bin/bash
# 每日清理脚本

echo "开始每日清理..."

# 清理远程跟踪引用
echo "1. 清理远程跟踪引用..."
git-workflow cleanup remote

# 清理孤立worktree
echo "2. 清理孤立worktree..."
git-workflow cleanup worktree

# 清理临时分支
echo "3. 清理临时分支..."
git-workflow cleanup branches

# 查看分支状态
echo "4. 查看分支状态..."
git-workflow branch status

# 清理旧日志
echo "5. 清理旧日志..."
find ~/.codebuddy/logs/git-workflow -name "*.log" -mtime +30 -delete

# 清理旧备份
echo "6. 清理旧备份..."
find ~/.codebuddy/backups/git-workflow -mtime +30 -delete

echo "每日清理完成"
EOF

chmod +x ~/daily-cleanup.sh

# 添加到 crontab
(crontab -l 2>/dev/null; echo "0 2 * * * ~/daily-cleanup.sh") | crontab -
```

### 2. 每周安全审计脚本

```bash
# 创建每周安全审计脚本
cat > ~/weekly-security-audit.sh << 'EOF'
#!/bin/bash
# 每周安全审计脚本

echo "开始每周安全审计..."

# 执行安全审查
echo "1. 执行安全审查..."
git-workflow security review

# 执行安全审计
echo "2. 执行安全审计..."
git-workflow security audit

# 检查分支保护
echo "3. 检查分支保护..."
git branch -a | grep -E "main|master|develop" | while read branch; do
    echo "检查分支: $branch"
    # 这里可以添加分支保护检查逻辑
done

# 检查worktree状态
echo "4. 检查worktree状态..."
git worktree list

echo "每周安全审计完成"
EOF

chmod +x ~/weekly-security-audit.sh

# 添加到 crontab
(crontab -l 2>/dev/null; echo "0 3 * * 1 ~/weekly-security-audit.sh") | crontab -
```

## 高级配置

### 1. 多环境配置

```bash
# 创建多环境配置
cat > ~/.codebuddy/skills/git-workflow/config-dev.yaml << 'EOF'
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
EOF

cat > ~/.codebuddy/skills/git-workflow/config-prod.yaml << 'EOF'
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
EOF

# 使用环境变量切换配置
export GIT_WORKFLOW_CONFIG="$HOME/.codebuddy/skills/git-workflow/config-dev.yaml"
```

### 2. 自定义钩子

```bash
# 创建自定义钩子目录
mkdir -p ~/.codebuddy/skills/git-workflow/hooks

# 创建 pre-push 钩子
cat > ~/.codebuddy/skills/git-workflow/hooks/pre-push << 'EOF'
#!/bin/bash
# 自定义 pre-push 钩子

echo "执行自定义 pre-push 钩子..."

# 这里可以添加你的自定义逻辑
# 例如：代码质量检查、测试、构建等

echo "自定义 pre-push 钩子完成"
EOF

chmod +x ~/.codebuddy/skills/git-workflow/hooks/pre-push

# 创建 post-merge 钩子
cat > ~/.codebuddy/skills/git-workflow/hooks/post-merge << 'EOF'
#!/bin/bash
# 自定义 post-merge 钩子

echo "执行自定义 post-merge 钩子..."

# 这里可以添加你的自定义逻辑
# 例如：更新依赖、重新构建等

echo "自定义 post-merge 钩子完成"
EOF

chmod +x ~/.codebuddy/skills/git-workflow/hooks/post-merge
```

## 故障排除

### 1. 调试模式

```bash
# 启用调试模式
export GIT_WORKFLOW_DEBUG=1

# 执行命令
git-workflow push --precheck

# 查看详细日志
cat ~/.codebuddy/logs/git-workflow/operations.log
```

### 2. 性能优化

```bash
# 优化 git 配置
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 256

# 优化 worktree 配置
git config --global worktree.guessRemote true
```

### 3. 网络优化

```bash
# 使用代理
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port

# 或者配置 git 代理
git config --global http.proxy http://proxy:port
git config --global https.proxy http://proxy:port
```

## 最佳实践

1. **使用环境变量**：通过环境变量管理不同环境的配置
2. **自定义钩子**：根据项目需求创建自定义钩子
3. **自动化脚本**：创建自动化脚本减少重复工作
4. **定期审计**：定期执行安全审计和清理
5. **监控日志**：定期查看操作日志，了解git操作历史
6. **备份配置**：重要配置更改前备份配置文件
7. **测试工作流**：在测试环境中测试自定义工作流
8. **文档记录**：记录自定义工作流和配置
9. **定期查看分支状态**：使用 `git-workflow branch status --all` 了解分支健康状况
10. **配置定时清理**：使用 `git-workflow branch schedule` 配置自动清理任务
11. **使用dry-run模式**：清理前使用 `--dry-run` 预览清理计划
12. **恢复误删分支**：使用 `git-workflow branch restore` 恢复误删分支