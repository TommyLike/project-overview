# 实际采用情况 — Claude Code

> **来源**: https://github.com/anthropics/claude-code | **分析日期**: 2026-02-18

## 下载统计

| 指标 | 数值 | 解读 |
|------|------|------|
| npm 周下载量（`@anthropic-ai/claude-code`） | **6,515,721** | 行业标准级——顶级梯队（超过 500 万/周） |
| npm 月下载量 | **31,002,928** | 年化约 3.72 亿次——开发者用户基数庞大 |
| GitHub Star 数 | **67,537** | 对于一款仅 12 个月历史的工具而言极为罕见 |
| GitHub Fork 数 | 5,274 | 高 Fork 率；大量定制化和镜像需求 |
| 开放 Issue 数 | 6,247 | 反映庞大的活跃用户基数 |
| 创建时间 | 2025-02-22 | 约 12 个月前 |

> **注意**：npm 分发现已弃用，推荐使用直接安装脚本（`curl -fsSL https://claude.ai/install.sh | bash`）。npm 下载量仍然反映大量真实使用，但也可能包含历史自动化安装。无论如何，真实用户规模都非常可观。

**横向对比**：650 万/周的 npm 下载量使 Claude Code 跻身主流开发者工具之列。作为对比，`prettier`（代码格式化工具）周下载量约 2,500 万。Claude Code 这款复杂的 AI 智能体工具，仅用一年时间就达到了 prettier 下载量的 26%。

## Star 增速

| 指标 | 数值 |
|------|------|
| 12 个月内新增 Star | 67,537 |
| 平均每月 Star 增量 | 约 5,600 |
| 平均每日 Star 增量 | 约 185 |

这是 2025 年 GitHub 上增长最快的开发者工具仓库之一。每次重要版本发布和 Anthropic 博客文章后，增速均会显著加快。

## 社区与生态

| 渠道 | 信号 |
|------|------|
| Claude Developers Discord | 活跃社区（`anthropic.com/discord`） |
| GitHub Issues | 6,247 个开放 Issue——高度参与的用户群持续反馈 Bug 和功能请求 |
| 插件市场 | 13 款官方插件；社区插件持续增长 |
| GitHub Discussions | 未开启；Issues 跟踪器同时承担社区问答功能 |

## 平台与集成支持

Claude Code 在一年内实现了广泛的平台覆盖：

| 平台 | 分发方式 |
|------|----------|
| macOS / Linux | `curl -fsSL https://claude.ai/install.sh \| bash`（推荐） |
| macOS / Linux | `brew install --cask claude-code`（Homebrew） |
| Windows | `irm https://claude.ai/install.ps1 \| iex`（推荐） |
| Windows | `winget install Anthropic.ClaudeCode`（WinGet） |
| npm（已弃用） | `npm install -g @anthropic-ai/claude-code` |
| VS Code | 原生扩展集成 |
| JetBrains IDEs | 通过插件集成 |
| GitHub | 在 PR 和 Issue 中支持 `@claude` 标记 |
| Docker / DevContainers | 仓库内含 `.devcontainer/` 配置 |

**Windows ARM64 支持**在 v2.1.41 中新增——体现了平台广度的持续扩展。

## 具名采用者

目前无正式的 `ADOPTERS.md` 文件。但采用信号可从以下渠道获取：

- **个人开发者**：主要用户群——涵盖各行业的软件工程师
- **科技公司**：X/Twitter 和 Discord 上大量公开讨论团队将 Claude Code 作为首选 AI 编程助手
- **Anthropic 内部**：Anthropic 工程师自用（该 GitHub 仓库的 CI 工作流本身就通过 `@claude` GitHub Actions 集成使用 Claude Code）
- **企业用户**：Anthropic 的商业条款和企业计划表明已有大量组织级采用

## 云端与企业支持

- **AWS Bedrock**：Claude Code 可以将 Bedrock 作为模型提供商（无需直接使用 Anthropic API）——对于有 AWS 数据协议的企业用户至关重要
- **Google Vertex AI**：内置 Vertex 提供商支持
- **Azure Foundry**：同样支持
- **企业设置管理**：支持通过 `C:\Program Files\ClaudeCode`（Windows）进行托管设置，并提供企业部署文档

多云支持意味着企业可以在首选云提供商的数据协议框架内采用 Claude Code。

## 采用情况综合评估

| 维度 | 信号 |
|------|------|
| 下载量 | 🟢 行业标准级（650 万/周） |
| Star 增速 | 🟢 极为罕见（12 个月内 6.7 万） |
| 社区参与度 | 🟢 非常活跃（6,247 个开放 Issue、Discord 社区） |
| 平台覆盖 | 🟢 Mac、Linux、Windows、VS Code、JetBrains、GitHub |
| 企业就绪度 | 🟢 支持 Bedrock/Vertex/Foundry；支持托管设置 |
| 采用阶段 | **主流** |
