# 更新日志

所有重要的更改都会记录在这个文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [2.0.0] - 2026-05-10

### 新增
- ✨ **history 模块**：提交历史管理（undo-last / split-root / stage-pick / backup / commit-batch）
- ✨ **SKILL_DIR 自动检测**：脚本通过 `BASH_SOURCE` 自动定位安装目录，不再硬编码路径

### 变更
- 🔧 **路径去硬编码**：移除所有 `$HOME/.codebuddy` / `/mnt/c/Users/HP` / `/root/` 硬编码路径
- 🔧 **LICENSE 重写**：对齐 spz-ecosystem MIT 协议，新增 Cultural Note
- 🔧 **配置文件**：`~/.codebuddy/` → `~/.local/share/git-workflow/` (XDG 兼容)
- 🔧 **YAML 清理**：移除 `cross_platform.windows_path_mapping` 硬编码节
- 🔧 **package.sh**：MD5 + SHA256 双校验和并存

### 修复
- 🐛 `check_config()` 移除 Windows/WSL 符号链接自动创建 (不可移植)
- 🐛 `push` 模块 github-push 子模块路径改为 `$SKILL_DIR/../github-push/` 相对引用

### 开源准备
- 📦 独立仓库: `spz-ecosystem/git-workflow`
- 📦 MIT 协议 (Pu Junhan, 2026)
- 📦 README 中的硬编码路径全部替换为占位符

## [1.1.0] - 2026-05-09

### 新增
- ✨ **分支状态报告**：显示详细的分支状态信息，包括合并状态、过期状态、保护状态
- ✨ **分支恢复功能**：支持恢复已删除的分支，自动备份分支引用
- ✨ **分支清理定时任务**：支持配置每日、每周、每月的定时清理任务
- ✨ **分支清理增强**：添加 `--dry-run`、`--non-interactive`、`--no-merged`、`--no-remote`、`--expire-days` 选项
- ✨ **分支状态选项**：添加 `--all`、`--remote`、`--no-merged`、`--no-expired`、`--expire-days` 选项
- ✨ **安全检查增强**：分支删除安全检查脚本增加到9项检查
- ✨ **配置管理增强**：添加完整的配置选项，包括日志、备份、通知、跨平台配置

### 改进
- 🔧 更新文档，添加新功能说明
- 🔧 更新配置文件示例，添加完整配置选项
- 🔧 更新故障排除指南，添加新问题的解决方案
- 🔧 更新最佳实践，添加新功能的使用建议

### 文档
- 📚 更新 SKILL.md，添加分支状态报告、分支恢复、定时任务功能说明
- 📚 更新 README.md，添加新的目录结构和功能特性
- 📚 更新 CHANGELOG.md，添加新的更新记录
- 📚 更新 docs/best-practices.md，添加新功能的最佳实践

## [1.0.0] - 2026-05-05

### 新增
- 🎉 **Git Workflow Umbrella Skill 正式发布**
- ✨ **统一入口**：所有git工作流操作通过`git-workflow`命令执行
- ✨ **六大核心模块**：
  - 推送管理（Push Management）
  - 分支管理（Branch Management）
  - Worktree管理（Worktree Management）
  - 发版预检（Release Feasibility）
  - 安全审查（Security Review）
  - 清理工具（Cleanup Tools）
- ✨ **跨平台支持**：自动检测Windows/WSL路径并创建符号链接
- ✨ **配置管理**：支持YAML配置文件和环境变量覆盖
- ✨ **日志记录**：记录所有操作历史，便于审计
- ✨ **安全审查**：8项分支删除安全检查
- ✨ **Worktree隔离**：强制新分支使用隔离worktree
- ✨ **主分支保护**：主worktree锁定保护

### 集成
- 🔄 整合 github-push skill 功能
- 🔄 整合推送规则功能
- 🔄 整合分支删除安全审查功能
- 🔄 整合 Worktree 隔离管理功能

### 文档
- 📚 完整的设计文档（DESIGN.md）
- 📚 详细的使用说明（SKILL.md）
- 📚 快速开始指南（README.md）
- 📚 安装、配置、故障排除文档

### 脚本
- 🔧 主脚本（git-workflow.sh）
- 🔧 分支删除安全检查脚本
- 🔧 安装/卸载脚本
- 🔧 测试脚本

### 示例
- 📝 基础使用示例
- 📝 高级使用示例
- 📝 工作流示例

## [0.9.0] - 2026-05-04

### 新增
- ✨ 创建 git-workflow umbrella skill 架构
- ✨ 设计六大核心模块
- ✨ 实现推送管理模块
- ✨ 实现分支管理模块
- ✨ 实现 Worktree 管理模块

### 集成
- 🔄 集成 github-push skill
- 🔄 集成分支删除安全审查
- 🔄 集成 Worktree 隔离策略

## [0.8.0] - 2026-05-03

### 新增
- ✨ 分支删除安全审查脚本
- ✨ Worktree 隔离管理策略
- ✨ 主分支保护机制

### 改进
- 🔧 优化分支删除安全检查
- 🔧 完善 Worktree 清理流程
- 🔧 增强主分支保护

## [0.7.0] - 2026-05-02

### 新增
- ✨ GitHub 推送问题解决经验
- ✨ 推送前预检机制
- ✨ PR 回退策略

### 改进
- 🔧 优化网络超时处理
- 🔧 完善令牌权限验证
- 🔧 增强分支保护检测

## [0.6.0] - 2026-05-01

### 新增
- ✨ GitHub Push Skill 创建
- ✨ 推送规则文件
- ✨ 分支管理规范

### 改进
- 🔧 优化推送流程
- 🔧 完善错误处理
- 🔧 增强日志记录

---

## 版本说明

### 版本号规则
- **主版本号**：不兼容的 API 修改
- **次版本号**：向下兼容的功能性新增
- **修订号**：向下兼容的问题修正

### 更新类型
- **新增**：新功能
- **改进**：现有功能的改进
- **修复**：问题修复
- **移除**：功能移除
- **安全**：安全相关的更新
- **文档**：文档更新
- **集成**：组件集成

### 贡献指南
1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

### 许可证
本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件