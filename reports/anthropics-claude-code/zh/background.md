# 组织背景 — Claude Code

> **来源**: https://github.com/anthropics/claude-code | **分析日期**: 2026-02-18

## 背书实体

Claude Code 是由 **Anthropic PBC** 全权构建和维护的第一方产品。Anthropic 是一家 AI 安全公司，由 Dario Amodei、Daniela Amodei 及其他前 OpenAI 核心成员于 2021 年创立。这不是社区项目，而是全球顶尖 AI 公司的核心商业产品。

**关于 Anthropic**：

| 事项 | 详情 |
|------|------|
| 成立时间 | 2021 年（加利福尼亚州旧金山） |
| 创始人 | Dario Amodei（CEO）、Daniela Amodei（总裁）及前 OpenAI 核心团队 |
| 核心使命 | AI 安全研究 + Claude 商业模型部署 |
| 融资总额 | 约 77 亿美元以上（截至 2025 年） |
| 主要投资方 | Amazon（超 40 亿美元）、Google（约 3 亿美元）、Spark Capital 等 |
| 营收来源 | Claude.ai 订阅 + API 按量付费 + 企业版 |
| GitHub 组织 | anthropics — 68 个公开仓库，2.7 万粉丝 |

**Amazon 的 40 亿美元投资**（2023-2024 年）和 Google 的战略投资，使 Anthropic 成为 AI 行业资金储备最雄厚的公司之一，Claude Code 不存在因公司倒闭或战略转型而停服的风险。

## 产品定位

Claude Code 是 Anthropic **面向开发者的核心产品**，专注于 AI 编程智能体赛道。它既是商业产品（驱动 Claude API 的使用和订阅），也是 Anthropic 展示 Claude 智能体能力的旗舰产品。双重定位确保了持续的内部投入：

- Claude Code 产生大量 API Token 消耗——每次编程对话都是对 Anthropic 的计费。
- Claude Code 是 Anthropic "智能体 AI" 的标志性实践展示。
- Anthropic 内部工程师也在使用（dogfooding）。

## 治理模式

Claude Code 是**专有软件**——没有开源治理，没有基金会，也没有社区投票决策产品方向。所有产品决策均由 Anthropic 内部 Claude Code 团队做出。

| 机制 | 详情 |
|------|------|
| 决策机制 | Anthropic 内部产品团队 |
| Issue 跟踪 | GitHub Issues（公开）——6,247 个开放 Issue，被社区活跃使用 |
| Issue 分类 | 部分通过 Claude 本身自动化处理（GitHub Actions 调用 Claude API） |
| 社区 | Claude Developers Discord（`anthropic.com/discord`） |
| 安全漏洞披露 | HackerOne VDP（`hackerone.com/anthropic-vdp`） |
| 插件生态 | 官方市场 + 社区贡献插件 |

## 许可证：专有 ⚠️

**这不是开源软件。** `LICENSE.md` 全文如下：

> © Anthropic PBC. All rights reserved. Use is subject to Anthropic's Commercial Terms of Service.

实际含义：
- 在 Anthropic 服务条款下，您**可以**将 Claude Code 作为工具使用。
- 您**不能**分叉、修改或再分发源代码（源代码未公开）。
- 您**不能**审计二进制文件（尽管 Anthropic 的隐私政策有所规范）。
- 您的使用受 Anthropic 的**商业服务条款**约束——请仔细阅读。

GitHub 代码仓库主要是**社区枢纽**（Issue 跟踪、插件示例、CHANGELOG、文档链接）——实际的编译二进制文件通过独立的安装脚本和包管理器分发。

## 商业关系

Claude Code **免费安装，但使用需要 API 额度**：
- **Claude.ai Pro/Team/Enterprise 订阅用户**：通过 Max 套餐包含使用额度
- **API 用户**：按 Token 付费（输入 + 输出 + 缓存读写）
- 无"开放核心"模式——所有功能均需有效的 Anthropic 账号

这意味着采用 Claude Code 即意味着与 Anthropic 建立持续的商业关系。
