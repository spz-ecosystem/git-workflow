# Git Workflow Umbrella Skill

统一管理所有git工作流操作，提供标准化、自动化、可追溯的git操作规范。

## 🚀 快速开始

### 安装

```bash
# 克隆或下载到 ~/.codebuddy/skills/git-workflow/
git clone <repository-url> ~/.codebuddy/skills/git-workflow

# 或者运行安装脚本
./scripts/install.sh
```

### 验证安装

```bash
git-workflow --help
```

## 📦 功能特性

### 六大核心模块

| 模块 | 功能 | 示例命令 |
|------|------|----------|
| **push** | 推送管理 | `git-workflow push --precheck` |
| **branch** | 分支管理 | `git-workflow branch create feature-new` |
| **worktree** | Worktree管理 | `git-workflow worktree create feature-new` |
| **release** | 发版预检 | `git-workflow release check` |
| **security** | 安全审查 | `git-workflow security review` |
| **cleanup** | 清理工具 | `git-workflow cleanup remote` |

### 分支管理增强功能

| 功能 | 描述 | 示例命令 |
|------|------|----------|
| **分支状态报告** | 显示详细的分支状态信息 | `git-workflow branch status --all` |
| **分支恢复** | 恢复已删除的分支 | `git-workflow branch restore feature-old` |
| **定时清理** | 配置分支清理定时任务 | `git-workflow branch schedule --weekly` |
| **安全删除** | 9项安全检查后删除分支 | `git-workflow branch delete feature-old` |
| **智能清理** | 自动清理已合并和过期分支 | `git-workflow branch cleanup --dry-run` |

### 核心优势

- ✅ **统一入口**：所有git工作流操作通过`git-workflow`命令执行
- ✅ **标准化操作**：遵循统一的git操作规范
- ✅ **自动化流程**：减少人工操作，提高效率
- ✅ **可追溯性**：记录所有操作历史，便于审计
- ✅ **跨平台支持**：自动处理Windows/WSL路径问题
- ✅ **模块化设计**：各模块独立，便于维护和扩展
- ✅ **安全第一**：9项分支删除安全检查
- ✅ **智能备份**：自动备份分支引用，支持恢复
- ✅ **定时任务**：支持配置分支清理定时任务

## 🛠️ 使用指南

### 1. 推送管理

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
git-workflow branch create feature-new-feature

# 删除分支（安全审查后）
git-workflow branch delete feature-old-feature

# 清理已合并分支
git-workflow branch cleanup

# 显示分支状态报告
git-workflow branch status --all

# 恢复已删除的分支
git-workflow branch restore feature-old-feature

# 配置分支清理定时任务
git-workflow branch schedule --weekly --time 02:00

# 分支清理dry-run模式
git-workflow branch cleanup --dry-run
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

## ⚙️ 配置管理

### 配置文件位置

- **WSL路径**：`/root/.codebuddy/skills/git-workflow/git-workflow.yaml`
- **Windows路径**：`/mnt/c/Users/HP/.codebuddy/skills/git-workflow/git-workflow.yaml`

### 环境变量覆盖

```bash
export GIT_WORKFLOW_CONFIG="/custom/path/to/git-workflow.yaml"
export GIT_WORKFLOW_LOG="/custom/path/to/logs"
export GIT_WORKFLOW_BACKUP="/custom/path/to/backups"
```

### 自动检测机制

脚本会自动检测Windows路径并创建符号链接：
1. 检查WSL路径下的配置文件是否存在
2. 如果不存在，检测Windows路径
3. 自动创建符号链接到WSL路径
4. 使用默认配置作为后备方案

## 📁 目录结构

```
git-workflow/
├── README.md                    # 本文件
├── DESIGN.md                    # 设计文档
├── SKILL.md                     # 主文档
├── CHANGELOG.md                 # 更新日志
├── CONTRIBUTING.md              # 贡献指南
├── LICENSE                      # 许可证
├── git-workflow.yaml            # 配置文件
├── scripts/
│   ├── git-workflow.sh          # 主脚本（994行）
│   ├── branch-delete-safety-check.sh  # 分支删除安全检查（444行）
│   ├── install.sh               # 安装脚本
│   ├── uninstall.sh             # 卸载脚本
│   └── package.sh               # 打包脚本
├── examples/
│   ├── basic-usage.md           # 基础使用示例
│   ├── advanced-usage.md        # 高级使用示例
│   └── workflows.md             # 工作流示例
├── templates/
│   ├── git-workflow.yaml        # 配置模板
│   └── hooks/                   # Git hooks模板
├── tests/
│   ├── test-git-workflow.sh     # 测试脚本（386行）
│   └── test-config.yaml         # 测试配置
└── docs/
    ├── installation.md          # 安装指南
    ├── configuration.md         # 配置指南
    ├── troubleshooting.md       # 故障排除
    └── best-practices.md        # 最佳实践（445行）
```

## 🔧 故障排除

### 常见问题

#### 1. 配置文件不存在
```bash
# 自动检测会创建符号链接
git-workflow --help

# 或手动创建符号链接
ln -s /mnt/c/Users/HP/.codebuddy/skills/git-workflow /root/.codebuddy/skills/git-workflow
```

#### 2. 权限问题
```bash
# 确保脚本有执行权限
chmod +x ~/.codebuddy/skills/git-workflow/scripts/*.sh
```

#### 3. 网络问题
```bash
# 使用代理
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port
```

#### 4. 分支删除失败
```bash
# 检查分支是否受保护
git-workflow branch status

# 使用安全检查脚本
~/.codebuddy/skills/git-workflow/scripts/branch-delete-safety-check.sh --dry-run <分支名>

# 检查分支是否有关联的worktree
git worktree list | grep <分支名>
```

#### 5. 分支恢复失败
```bash
# 检查备份目录是否存在
ls -la ~/.codebuddy/backups/git-workflow/branch-deletes/

# 手动恢复分支
git branch <分支名> <备份文件路径>
```

#### 6. 定时任务配置失败
```bash
# 检查crontab是否可用
crontab -l

# 手动添加定时任务
crontab -e
# 添加：0 2 * * 0 cd <仓库路径> && ~/.codebuddy/skills/git-workflow/scripts/git-workflow.sh branch cleanup --non-interactive --no-remote
```

## 📚 文档

- [设计文档](DESIGN.md) - 详细的设计说明
- [主文档](SKILL.md) - 完整的功能说明
- [安装指南](docs/installation.md) - 详细安装步骤
- [配置指南](docs/configuration.md) - 配置选项说明
- [故障排除](docs/troubleshooting.md) - 常见问题解决
- [最佳实践](docs/best-practices.md) - 使用建议

## 🤝 贡献

欢迎贡献代码！请查看 [贡献指南](CONTRIBUTING.md)。

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 📞 支持

- **问题反馈**：提交 Issue
- **功能建议**：提交 PR
- **文档改进**：提交 PR

## 🙏 致谢

感谢所有贡献者和用户的支持！

---

**Git Workflow Umbrella Skill** - 让git工作流更简单、更安全、更高效