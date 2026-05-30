# 工作流示例

## Git Flow 工作流

### 1. 功能开发流程

```bash
# 1. 从 develop 分支创建功能分支
git checkout develop
git pull origin develop
git-workflow branch create feature/user-authentication

# 2. 切换到功能分支的 worktree
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/feature/user-authentication

# 3. 开发功能
# ... 编写代码 ...

# 4. 提交更改
git add .
git commit -m "feat: 添加用户认证功能"

# 5. 推送前预检
git-workflow push --precheck

# 6. 推送功能分支
git-workflow push

# 7. 创建 PR 到 develop 分支
gh pr create --base develop --head feature/user-authentication --fill

# 8. 代码审查和合并后清理
git-workflow branch delete feature/user-authentication
```

### 2. 发布流程

```bash
# 1. 从 develop 分支创建 release 分支
git checkout develop
git pull origin develop
git-workflow release prepare v1.2.0

# 2. 切换到 release 分支的 worktree
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/release/v1.2.0

# 3. 最终测试和修复
# ... 测试和修复 ...

# 4. 更新版本号
# 更新 package.json, setup.py 等文件中的版本号

# 5. 提交更改
git add .
git commit -m "release: v1.2.0"

# 6. 推送 release 分支
git-workflow push

# 7. 创建 PR 到 main 分支
gh pr create --base main --head release/v1.2.0 --fill

# 8. 合并后打标签
git checkout main
git pull origin main
git tag v1.2.0
git push origin v1.2.0

# 9. 合并回 develop 分支
git checkout develop
git pull origin develop
git merge main
git push origin develop

# 10. 清理
git-workflow branch delete release/v1.2.0
```

### 3. 热修复流程

```bash
# 1. 从 main 分支创建 hotfix 分支
git checkout main
git pull origin main
git-workflow branch create hotfix/security-fix

# 2. 切换到 hotfix 分支的 worktree
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/hotfix/security-fix

# 3. 修复问题
# ... 修复代码 ...

# 4. 提交更改
git add .
git commit -m "fix: 修复安全漏洞"

# 5. 推送前预检
git-workflow push --precheck

# 6. 推送 hotfix 分支
git-workflow push

# 7. 创建 PR 到 main 分支
gh pr create --base main --head hotfix/security-fix --fill

# 8. 合并后打标签
git checkout main
git pull origin main
git tag v1.2.1
git push origin v1.2.1

# 9. 合并回 develop 分支
git checkout develop
git pull origin develop
git merge main
git push origin develop

# 10. 清理
git-workflow branch delete hotfix/security-fix
```

## GitHub Flow 工作流

### 1. 功能开发流程

```bash
# 1. 从 main 分支创建功能分支
git checkout main
git pull origin main
git-workflow branch create feature/new-feature

# 2. 切换到功能分支的 worktree
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/feature/new-feature

# 3. 开发功能
# ... 编写代码 ...

# 4. 提交更改
git add .
git commit -m "feat: 添加新功能"

# 5. 推送前预检
git-workflow push --precheck

# 6. 推送功能分支
git-workflow push

# 7. 创建 PR 到 main 分支
gh pr create --base main --head feature/new-feature --fill

# 8. 代码审查和合并后清理
git-workflow branch delete feature/new-feature
```

### 2. 持续部署流程

```bash
# 1. 从 main 分支创建功能分支
git checkout main
git pull origin main
git-workflow branch create feature/ci-cd

# 2. 切换到功能分支的 worktree
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/feature/ci-cd

# 3. 开发功能
# ... 编写代码 ...

# 4. 提交更改
git add .
git commit -m "feat: 添加 CI/CD 配置"

# 5. 推送前预检
git-workflow push --precheck

# 6. 推送功能分支
git-workflow push

# 7. 创建 PR 到 main 分支
gh pr create --base main --head feature/ci-cd --fill

# 8. 合并后自动部署
# GitHub Actions 会自动部署到生产环境

# 9. 清理
git-workflow branch delete feature/ci-cd
```

## Trunk-Based Development 工作流

### 1. 短期功能分支

```bash
# 1. 从 main 分支创建短期功能分支
git checkout main
git pull origin main
git-workflow branch create feature/short-feature

# 2. 切换到功能分支的 worktree
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/feature/short-feature

# 3. 快速开发（1-2天）
# ... 编写代码 ...

# 4. 频繁提交
git add .
git commit -m "feat: 部分功能实现"

# 5. 推送前预检
git-workflow push --precheck

# 6. 推送功能分支
git-workflow push

# 7. 创建 PR 到 main 分支
gh pr create --base main --head feature/short-feature --fill

# 8. 快速合并后清理
git-workflow branch delete feature/short-feature
```

### 2. 功能开关工作流

```bash
# 1. 从 main 分支创建功能分支
git checkout main
git pull origin main
git-workflow branch create feature/feature-toggle

# 2. 切换到功能分支的 worktree
cd ~/.config/superpowers/worktrees/$(basename $(pwd))/feature/feature-toggle

# 3. 开发功能（使用功能开关）
# ... 编写代码，使用功能开关 ...

# 4. 提交更改
git add .
git commit -m "feat: 添加功能开关"

# 5. 推送前预检
git-workflow push --precheck

# 6. 推送功能分支
git-workflow push

# 7. 创建 PR 到 main 分支
gh pr create --base main --head feature/feature-toggle --fill

# 8. 合并后逐步启用功能
# 通过配置逐步启用功能

# 9. 清理
git-workflow branch delete feature/feature-toggle
```

## 自动化工作流

### 1. 自动化测试工作流

```bash
# 创建自动化测试脚本
cat > ~/auto-test.sh << 'EOF'
#!/bin/bash
# 自动化测试脚本

set -e

echo "开始自动化测试..."

# 1. 执行单元测试
echo "1. 执行单元测试..."
# npm test
# pytest

# 2. 执行集成测试
echo "2. 执行集成测试..."
# npm run test:integration
# pytest tests/integration

# 3. 执行端到端测试
echo "3. 执行端到端测试..."
# npm run test:e2e
# pytest tests/e2e

# 4. 生成测试报告
echo "4. 生成测试报告..."
# npm run test:report
# pytest --html=report.html

echo "自动化测试完成"
EOF

chmod +x ~/auto-test.sh
```

### 2. 自动化部署工作流

```bash
# 创建自动化部署脚本
cat > ~/auto-deploy.sh << 'EOF'
#!/bin/bash
# 自动化部署脚本

set -e

ENVIRONMENT=$1

if [ -z "$ENVIRONMENT" ]; then
    echo "用法: $0 <staging|production>"
    exit 1
fi

echo "开始自动化部署到 $ENVIRONMENT..."

# 1. 执行发版预检
echo "1. 执行发版预检..."
git-workflow release check

# 2. 构建项目
echo "2. 构建项目..."
# npm run build
# python setup.py build

# 3. 运行测试
echo "3. 运行测试..."
# npm test
# pytest

# 4. 部署到环境
echo "4. 部署到 $ENVIRONMENT..."
if [ "$ENVIRONMENT" = "staging" ]; then
    # 部署到 staging
    # kubectl apply -f k8s/staging/
    echo "部署到 staging 完成"
elif [ "$ENVIRONMENT" = "production" ]; then
    # 部署到 production
    # kubectl apply -f k8s/production/
    echo "部署到 production 完成"
fi

# 5. 执行部署后测试
echo "5. 执行部署后测试..."
# curl -f https://staging.example.com/health
# curl -f https://production.example.com/health

echo "自动化部署完成"
EOF

chmod +x ~/auto-deploy.sh
```

### 3. 自动化监控工作流

```bash
# 创建自动化监控脚本
cat > ~/auto-monitor.sh << 'EOF'
#!/bin/bash
# 自动化监控脚本

set -e

echo "开始自动化监控..."

# 1. 检查 git 状态
echo "1. 检查 git 状态..."
git status

# 2. 检查分支状态
echo "2. 检查分支状态..."
git-workflow branch status --all

# 3. 检查 worktree 状态
echo "3. 检查 worktree 状态..."
git worktree list

# 4. 检查远程状态
echo "4. 检查远程状态..."
git remote -v

# 5. 检查最近提交
echo "5. 检查最近提交..."
git log --oneline -10

# 6. 检查未推送的提交
echo "6. 检查未推送的提交..."
git log origin/main..main --oneline

# 7. 检查未合并的分支
echo "7. 检查未合并的分支..."
git branch --no-merged main

# 8. 检查过期分支
echo "8. 检查过期分支..."
git-workflow branch status --expire-days 30

echo "自动化监控完成"
EOF

chmod +x ~/auto-monitor.sh
```

## 集成工作流

### 1. GitHub Actions 集成

```yaml
# .github/workflows/git-workflow.yml
name: Git Workflow

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  git-workflow:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Git Workflow
      run: |
        # 安装 git-workflow
        ./scripts/install.sh
        
    - name: Run Pre-check
      run: |
        git-workflow push --precheck
        
    - name: Run Tests
      run: |
        # 运行测试
        npm test
        
    - name: Build
      run: |
        # 构建项目
        npm run build
        
    - name: Deploy
      if: github.ref == 'refs/heads/main'
      run: |
        # 部署到生产环境
        ./scripts/deploy.sh
```

### 2. GitLab CI 集成

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

git-workflow:
  stage: test
  script:
    - ./scripts/install.sh
    - git-workflow push --precheck
    - npm test
  only:
    - main
    - develop
    - merge_requests

build:
  stage: build
  script:
    - npm run build
  only:
    - main
    - develop

deploy:
  stage: deploy
  script:
    - ./scripts/deploy.sh
  only:
    - main
  when: manual
```

### 3. Jenkins 集成

```groovy
// Jenkinsfile
pipeline {
    agent any
    
    stages {
        stage('Setup') {
            steps {
                sh './scripts/install.sh'
            }
        }
        
        stage('Pre-check') {
            steps {
                sh 'git-workflow push --precheck'
            }
        }
        
        stage('Test') {
            steps {
                sh 'npm test'
            }
        }
        
        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh './scripts/deploy.sh'
            }
        }
    }
    
    post {
        always {
            // 清理
            sh 'git-workflow cleanup remote'
            sh 'git-workflow cleanup worktree'
        }
    }
}
```

## 最佳实践

1. **选择合适的工作流**：根据团队规模和项目需求选择合适的工作流
2. **自动化测试**：在工作流中集成自动化测试
3. **自动化部署**：在工作流中集成自动化部署
4. **监控和告警**：在工作流中集成监控和告警
5. **文档记录**：记录工作流和配置
6. **定期审查**：定期审查和优化工作流
7. **团队培训**：培训团队成员使用工作流
8. **持续改进**：持续改进工作流
9. **定期查看分支状态**：使用 `git-workflow branch status --all` 了解分支健康状况
10. **配置定时清理**：使用 `git-workflow branch schedule` 配置自动清理任务
11. **使用dry-run模式**：清理前使用 `--dry-run` 预览清理计划
12. **恢复误删分支**：使用 `git-workflow branch restore` 恢复误删分支