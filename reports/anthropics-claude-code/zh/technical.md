# 技术深度解析 — Claude Code

> **来源**: https://github.com/anthropics/claude-code | **分析日期**: 2026-02-18

## 1. 核心概念与心智模型

### Claude Code 是什么

Claude Code 是一款**智能体 AI 编程助手**，运行于终端并与 IDE 集成。与代码补全工具（Copilot、Tabnine）不同，它是一个**推理智能体**：接受自然语言指令后，它规划并执行多步骤工作流——读取文件、编写代码、运行命令、提交到 git——直到任务完成。

**一句话工作流**：用自然语言描述需求 → Claude Code 读取代码库、规划解决方案、调用工具（文件读写、bash 命令、git 操作），并汇报结果。

### 核心术语

| 术语 | 定义 |
|------|------|
| **Session（会话）** | 与 Claude Code 的一次对话，持久化到磁盘；可通过 `/resume` 恢复 |
| **CLAUDE.md** | 项目根目录或主目录下的 Markdown 文件；作为项目持久说明注入 Claude 的上下文 |
| **Recipe / Plugin（插件）** | 包含命令、Hook、智能体和技能的扩展包，用于定制 Claude Code 的行为 |
| **Command（命令）** | 斜杠命令（如 `/commit`、`/review`），在插件或 CLAUDE.md 中定义，触发特定工作流 |
| **Hook（钩子）** | 在工具调用（文件写入、bash 命令）前后触发的 shell 脚本或 Python 脚本；用于策略执行或行为修改 |
| **Agent（智能体）** | 可被 Claude Code 作为工具调用的命名子工作流；支持多智能体组合 |
| **Skill（技能）** | 类似提示词模板的可复用知识/工作流模块；插件系统的组成部分 |
| **MCP** | Model Context Protocol——将外部数据源和工具接入 Claude Code 的标准协议 |
| **Compact / Compaction（压缩）** | 对长会话自动摘要，以适应模型上下文长度限制 |
| **Plan Mode（计划模式）** | Claude 在执行前描述其计划的模式——适用于审查高风险变更 |

### 心智模型

将 Claude Code 理解为**一位能读懂你终端和代码的资深开发者**。你用自然语言下达指令；它可以完全访问你的文件系统和 shell，在你授权的范围内读写任意文件、运行任意命令，并将多次工具调用串联完成复杂任务。`CLAUDE.md` 是你向它简要介绍项目的方式——相当于给新员工的入职文档。插件系统让你将团队规范（提交风格、代码审查检查清单）固化为结构化工作流，Claude 可一致地遵循执行。

---

## 2. 架构概览

Claude Code 的源代码不公开。基于 CHANGELOG、README 和公开文档，可推断其架构分层如下：

```
用户界面层
├── 终端（交互式 REPL）
├── IDE 集成（VS Code、JetBrains——通过扩展/插件）
└── CLI 标志（--print、--headless、非交互模式）

智能体编排层
├── 会话管理（持久化/恢复对话）
├── 计划模式（执行前展示计划）
├── Agent Teams（多智能体并行执行）
└── Compact / 上下文管理（长会话自动摘要）

工具层（Claude 可调用的能力）
├── 文件工具：Read、Write、Edit、Glob、Grep
├── Bash 工具：shell 命令执行
├── Task 工具：生成后台智能体
├── MCP 工具：外部集成（数据库、API、服务）
└── Web 工具：Fetch、Search（启用后可用）

Hook 层（用户定义的策略）
├── PreToolCall Hook：工具执行前验证/拦截
├── PostToolCall Hook：工具执行后响应
└── Notification Hook：自定义输出/日志

插件系统
├── 命令：自定义斜杠命令
├── 智能体：命名子工作流
├── 技能：可复用提示词模板
└── Hook：自定义行为策略

模型层
└── Claude API（Sonnet / Opus / Haiku），通过以下提供商：
    ├── Anthropic 直接 API
    ├── AWS Bedrock
    ├── Google Vertex AI
    └── Azure Foundry

配置层
├── CLAUDE.md（项目上下文、指令）
├── settings.json（用户/项目/企业设置）
├── 托管设置（企业策略强制执行）
└── MCP 服务器配置
```

### 关键设计决策：工具优先智能体

Claude Code 不是带有代码功能附加组件的聊天界面。它是一个**工具调用智能体**——Claude 的主要工作模式是调用工具（Read、Write、Bash、Task）并对输出进行推理。自然语言是控制平面；工具执行是数据平面。这正是它感觉与 IDE 代码补全在质上截然不同的原因。

---

## 3. 核心组件

| 组件 | 仓库位置 | 职责 |
|------|----------|------|
| **Plugins（插件）** | `plugins/` | 官方插件示例：code-review、commit-commands、feature-dev、pr-review-toolkit、hookify 等 |
| **Examples（示例）** | `examples/hooks/`、`examples/settings/` | Hook 实现示例；设置模板（宽松、严格、沙箱） |
| **Scripts（脚本）** | `scripts/` | GitHub Issues 自动化（TypeScript）：自动关闭重复 Issue、生命周期管理、分类 |
| **DevContainer** | `.devcontainer/` | 带防火墙隔离脚本的 Docker 开发环境 |
| **GitHub 工作流** | `.github/workflows/` | Issue 管理 CI；值得注意的是使用 Claude 本身进行分类 |
| **Claude 命令** | `.claude/commands/` | Anthropic 团队内部开发使用的命令 |
| **CHANGELOG** | `CHANGELOG.md` | 94KB，数百条记录——变更的首要信息来源 |

**插件架构详情**（来自 `marketplace.json`）：

13 款官方插件随仓库发布，涵盖：
- `code-review` — 多智能体 PR 审查，带置信度评分以过滤误报
- `commit-commands` — git 提交/推送/PR 工作流
- `feature-dev` — 完整功能开发生命周期智能体
- `pr-review-toolkit` — 按评审维度专项化的智能体（注释、测试、类型、代码质量等）
- `hookify` — 通过 Markdown 规则定义自定义行为策略
- `security-guidance` — 在编辑文件时提示潜在安全问题的 Hook
- `agent-sdk-dev` — Agent SDK 开发工具
- `plugin-dev` — 创建新插件的完整工具包

---

## 4. 学术参考文献

Claude Code 是**商业产品**，而非学术项目。没有 `CITATION.cff`，没有 arXiv 论文，也没有关于该工具本身的同行评审出版物。

底层 Claude 模型在 Anthropic 公布的模型卡和安全报告中有所描述，其中包含训练、对齐方法和评估的技术细节。这些不是传统的学术论文，但在 `anthropic.com` 公开可查。

### 技术博客文章

| 标题 | 来源 |
|------|------|
| Claude Code 深度解析 | Anthropic 文档站（`code.claude.com/docs/en/overview`） |
| Agent SDK 文档 | Anthropic 平台文档 |
| MCP 规范 | Model Context Protocol 规范（开放标准，独立于 Claude Code） |

---

## 5. 文档与学习资源

| 资源 | 链接 | 内容 |
|------|------|------|
| 官方文档 | https://code.claude.com/docs/en/overview | 完整产品文档 |
| 安装配置指南 | https://code.claude.com/docs/en/setup | 安装与配置 |
| Agent SDK 文档 | https://platform.claude.com/docs/en/agent-sdk | 基于 Claude Code 进行开发 |
| 插件示例 | `plugins/`（本仓库） | 13 个完整插件实现 |
| Hook 示例 | `examples/hooks/` | Python Hook 实现示例 |
| 设置示例 | `examples/settings/` | 宽松、严格和沙箱配置模板 |
| CHANGELOG | `CHANGELOG.md` | 每项功能和修复——极具价值的实践参考 |
| Discord | https://anthropic.com/discord | 实时社区帮助 |
| GitHub Issues | 本仓库 | Bug 报告、功能请求、社区问答 |

**文档质量**：官方文档在入门方面内容全面。仓库中的 `CHANGELOG.md` 是异常丰富的实践信息来源——每一次弃用、破坏性变更和新功能都有记录。

---

## 6. Hello World

### 环境要求

- **Node.js 18+**（仅旧版 npm 安装方式需要——新版通过 curl/brew/winget 安装）
- **Anthropic API Key** 或 Claude.ai Pro/Max 订阅
- 任意操作系统：macOS、Linux、Windows（含 ARM64）
- 无需 CUDA GPU——推理在 Anthropic 服务器上运行

### 安装

**macOS / Linux（推荐）**：
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**macOS（Homebrew）**：
```bash
brew install --cask claude-code
```

**Windows（推荐）**：
```powershell
irm https://claude.ai/install.ps1 | iex
```

### 首次运行

```bash
# 进入你的项目目录
cd /path/to/your/project

# 启动 Claude Code
claude

# 或运行单次命令（非交互模式）
claude --print "用 3 个要点解释这个代码库"
```

### 最小可运行示例 — 单次代码生成

```bash
# 创建一个新的 Python 工具
claude --print "创建一个 Python 脚本，统计文本文件中的词频。
使用 argparse 接收文件名参数，打印出现次数最多的前 10 个词。"
```

### 预期输出

Claude Code 读取相关文件，将所需代码写入磁盘，并汇报执行结果。在交互模式下，会实时显示工具调用过程。

### 常见问题

1. **API 成本意外**：长智能体会话会快速消耗大量 Token。在团队级别推广前，先在 Anthropic Console 中设置消费限额。关注会话结束时显示的 Token 计数。
2. **CLAUDE.md 未生效**：`CLAUDE.md` 必须放在 git 根目录（或主目录，用于全局设置）。放在子目录下不会被自动发现。
3. **Bash 工具权限提示**：默认情况下，Claude Code 在运行 shell 命令前会请求权限。可在 `settings.json` 中预先允许常见的安全命令并预先拒绝危险命令——自动化工作流前请完成此配置。
4. **Windows 兼容性**：部分功能（尤其是依赖 Unix 工具的 shell 命令）在 Windows 上行为可能有所不同。在假定与 macOS/Linux 完全一致之前，请先在 Windows 上进行测试。

---

## 7. 代码质量信号

注：源代码不可审计。以下信号基于公开仓库内容（插件、脚本、CI 工作流、CHANGELOG）得出。

**测试**：无法评估
→ 核心产品的测试基础设施不在本仓库。插件示例和脚本（`scripts/` 下的 TypeScript 代码）在公开仓库中没有可见的测试文件。CHANGELOG 中持续高质量的修复描述表明内部存在测试体系，但外部无法评估。

**CI/CD**：运转中（Issue 自动化）
→ 12 个 GitHub Actions 工作流，全部聚焦于 Issue/PR 生命周期管理和社区自动化。公开仓库中没有可见的构建/测试/发布 CI（发布流水线为 Anthropic 内部）。

**维护纪律**：卓越（以发布产出衡量）
→ 每周多次补丁发布，Issue 当日关闭，详细的 CHANGELOG，移除前提前 1-2 个版本给出弃用通知。从行为输出看，这是 AI 工具领域交付纪律最严格的团队之一。
