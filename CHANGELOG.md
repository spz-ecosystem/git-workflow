# 更新日志

所有重要的更改都会记录在这个文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
并且本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [2.1.2] - 2026-11-06

### 变更
- **推送后快照回收**：新增 `_gw_snapshot_gc()` —— 推送成功后回收本地产出的整树快照。
  仅在当前仓存在 `scripts/gk_snapshot_gc.py` 时执行；`GW_SNAPSHOT_GC=0` 关闭，
  `GW_SNAPSHOT_GC_ARGS` 覆盖参数（默认 `--apply`），失败只 WARN、不影响推送结果。
- 🔐 **loader pin 同步**：`gk_gitworkflow_loader.py` 版本与 pin 表更新到 `2.1.2`
  （补登 `1d78924` 改动漏掉的 pin —— 该提交只改了核心脚本未 bump/重钉，loader 判 tampered）。

## [2.1.1] - 2026-11-03

### 变更
- 🔓 **解绑外部技能（开源可移植）**：`push` 的委托与预检不再按**同级目录自动调用**
  `spz-gatekeeper-r-sequence` / `github-push`。默认 `push` = 原生 `git push`（凭据交给用户
  自己的 credential helper），外部工具一律**显式开启**：
  - `GIT_WORKFLOW_DELEGATE=none|gatekeeper|<可执行路径>` 或配置 `push.delegate`
  - `GIT_WORKFLOW_PRECHECK_CLI=<路径>` 或配置 `push.precheck_cli`
  背景：本技能是开源插件，强制依赖另一个技能既不可移植，也会覆盖用户已有的专属工具
- 📘 **SKILL.md 重写**：按**实际 CLI 口径**重写，删除与实现不符的描述（原文档把
  `release check` / `security review` 写成完整检查、把 `.codebuddy` 旧路径与预留配置项当作生效）。
  新文档逐模块列出真实可用命令与选项，并显式标注骨架实现、硬编码保护名单、配置项真实生效面
- 🔧 **版本声明对齐**：`git-workflow.sh --version` / `SKILL.md` / `git-workflow.yaml` /
  `templates/git-workflow.yaml` / `package.sh` 统一到 `2.1.1`。此前五处分散为
  `2.1.0` / `2.0.0` / `1.0.0` ⟹ 装的到底是哪一版无法判断，`package.sh` 打出的包名也停留在
  `1.0.0`
- 🔐 **loader pin 同步**：`gk_gitworkflow_loader.py` 版本与 pin 表更新到 `2.1.1`。
  核心脚本与 pin 的耦合是**即时**的：未同步 ⟹ `gw_load_guard` 判 `tampered` 并 `exit 2`
  （见 2026-09-23 起的历次记录，均在改脚本当次即触发）

### 修复
- 🐞 **push ↔ gatekeeper 委托链三处集成缺陷**（2026-11-03 实测：`push push` 被
  `Direct push to 'main' blocked` 拦下，但该仓历史全是直推 main）：
  - `push push` 新增 `--allow-main`，透传给 `gatekeeper push confirm`（仅本次调用有效）；
  - 委托被拒时输出可操作指引（`--allow-main` 或 `gatekeeper-cli.sh push auth-main`），
    不再只回一句「委托失败」；并修正 `set -e` 下裸调用的中止风险；
  - `pr-fallback` 远端白名单改为 `GW_PUSH_REMOTE_ALLOW` 可配（默认常见托管站），
    原实现硬编码两个组织前缀 ⟹ 换机器/换组织恒失败。
  对应门禁侧修复：main 门禁按目标仓显式授权判定（`--allow-main` / `GK_PUSH_ALLOW_MAIN` /
  auth-main），stage 闸只对本门禁仓生效，错误文案不再断言 “This repo uses PR workflow”。
- 🧹 **行尾归一**：`scripts/gk_gitworkflow_loader.py` 工作树为 CRLF、索引为 LF ⟹
  `core.autocrlf=false` 下呈现整文件 184 行假差异，掩盖真实的 pin 单行变更

## [2.1.0] - 2026-08-30

### 新增
- 🛡️ **技能加载安全网**（加载安全网模版第三次应用，对齐 spz-gatekeeper-r-sequence 的
  bashpy/paper-review 同款协议）：`scripts/gk_gitworkflow_loader.py` 对核心脚本
  （git-workflow.sh + branch-delete-safety-check.sh）做 **SHA256 pin 五源分流**
  （builtin/dev/tampered/missing/error）；入口 `gw_load_guard` 前置校验，
  **tampered/missing/error → fail-closed exit 2**（被篡改/损坏/缺失的技能永不执行）
- ✨ **`selfcheck` 子命令**：加载安全网状态自检（builtin → PASS / dev → WARN /
  tampered|missing|error → FAIL exit 2）
- ✨ **`version` 子命令**：输出当前版本
- 🔗 **manifest 登记**：spz-gatekeeper-r-sequence `gk_plugin_manifest` 登记
  `git-workflow`（intercept = 七模块能力白名单 + selfcheck/version），双向委托纳入治理闭环

### 变更
- 🔧 **防循环委托哨兵**：push 委托 spz-gatekeeper `cmd_push`（F8.1 远端白名单门禁）时置
  `GIT_WORKFLOW_DELEGATING=1`，cmd_push 检测到该 env 跳过"使用 git-workflow"提醒——
  消除 `cmd_push→提醒→git-workflow→委托→提醒` 环路风险

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