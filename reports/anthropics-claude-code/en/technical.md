# Technical Deep-Dive — Claude Code

> **Source**: https://github.com/anthropics/claude-code | **Analyzed**: 2026-02-18

## 1. Core Concepts & Mental Model

### What Claude Code Is

Claude Code is an **agentic AI coding assistant** that runs in your terminal and integrates
with your IDE. Unlike autocomplete tools (Copilot, Tabnine), it is a **reasoning agent**:
given a natural language instruction, it plans and executes a multi-step workflow —
reading files, writing code, running commands, committing to git — until the task is done.

**One-sentence workflow**: You describe what you want in natural language → Claude Code
reads your codebase, plans a solution, executes tools (file reads/writes, bash commands,
git operations), and reports the result.

### Key Terminology

| Term | Definition |
|------|-----------|
| **Session** | A conversation with Claude Code, persisted to disk; can be resumed with `/resume` |
| **CLAUDE.md** | A markdown file at project or home directory level; injected into Claude's context as persistent instructions about your project |
| **Recipe / Plugin** | A package of commands, hooks, agents, and skills that extends Claude Code's behavior |
| **Command** | A slash command (e.g., `/commit`, `/review`) defined in a plugin or CLAUDE.md; triggers a specific workflow |
| **Hook** | A shell script or Python script invoked before or after tool calls (file writes, bash commands); used to enforce policies or modify behavior |
| **Agent** | A named sub-workflow that can be invoked as a tool by Claude Code; enables multi-agent compositions |
| **Skill** | A reusable knowledge/workflow module similar to a prompt template; part of the plugin system |
| **MCP** | Model Context Protocol — a standard for connecting external data sources and tools to Claude Code |
| **Compact / Compaction** | Automatic summarization of long sessions to fit within model context limits |
| **Plan Mode** | A mode where Claude describes its plan before executing — useful for reviewing risky changes |

### Mental Model

Think of Claude Code as **a senior developer who reads your terminal and your code**.
You give it instructions in natural language; it has full access to your filesystem and
shell. It can read any file, write any file, run any command you authorize, and chain
multiple tool calls to complete complex tasks. The `CLAUDE.md` file is your way of
briefing it about your project — the equivalent of onboarding documentation for a new hire.
The plugin system lets you codify team conventions (commit style, code review checklists)
as structured workflows that Claude follows consistently.

---

## 2. Architecture Overview

Claude Code's source code is not public. Based on the CHANGELOG, README, and public
documentation, the architectural layers are:

```
User Interface Layer
├── Terminal (interactive REPL)
├── IDE integration (VS Code, JetBrains — via extension/plugin)
└── CLI flags (--print, --headless, non-interactive modes)

Agent Orchestration Layer
├── Session management (persist/resume conversations)
├── Plan mode (show plan before execution)
├── Agent Teams (multi-agent parallel execution)
└── Compact / context management (auto-summarize long sessions)

Tool Layer (what Claude can invoke)
├── File tools: Read, Write, Edit, Glob, Grep
├── Bash tool: Shell command execution
├── Task tool: Spawn background agents
├── MCP tools: External integrations (databases, APIs, services)
└── Web tools: Fetch, Search (when enabled)

Hook Layer (user-defined policies)
├── PreToolCall hooks: Validate/block before tool execution
├── PostToolCall hooks: React after tool execution
└── Notification hooks: Custom output/logging

Plugin System
├── Commands: Custom slash commands
├── Agents: Named sub-workflows
├── Skills: Reusable prompt templates
└── Hooks: Custom behavior policies

Model Layer
└── Claude API (Sonnet / Opus / Haiku) via:
    ├── Direct Anthropic API
    ├── AWS Bedrock
    ├── Google Vertex AI
    └── Azure Foundry

Configuration Layer
├── CLAUDE.md (project context, instructions)
├── settings.json (user/project/enterprise settings)
├── Managed settings (enterprise policy enforcement)
└── MCP server configuration
```

### Key Design Decision: Tool-First Agent

Claude Code is not a chat interface with code features bolted on. It is a **tool-using
agent** — Claude's primary mode of operation is calling tools (Read, Write, Bash, Task)
and reasoning about their outputs. Natural language is the control plane; tool execution
is the data plane. This is why it feels qualitatively different from IDE autocomplete.

---

## 3. Key Components

| Component | Location in Repo | Responsibility |
|-----------|-----------------|---------------|
| **Plugins** | `plugins/` | Official plugin examples: code-review, commit-commands, feature-dev, pr-review-toolkit, hookify, etc. |
| **Examples** | `examples/hooks/`, `examples/settings/` | Hook implementation examples; settings templates (lax, strict, sandbox) |
| **Scripts** | `scripts/` | GitHub Issues automation (TypeScript): auto-close duplicates, lifecycle management, triage |
| **DevContainer** | `.devcontainer/` | Docker-based development environment with firewall isolation script |
| **GitHub workflows** | `.github/workflows/` | CI for issue management; notably uses Claude itself for triage |
| **Claude commands** | `.claude/commands/` | Internal Anthropic team commands used for development |
| **CHANGELOG** | `CHANGELOG.md` | 94KB, hundreds of entries — the primary source of truth for what changed |

**Plugin architecture details** (from `marketplace.json`):

13 official plugins ship with the repo, covering:
- `code-review` — multi-agent PR review with confidence scoring
- `commit-commands` — git commit/push/PR workflows
- `feature-dev` — full feature development lifecycle agents
- `pr-review-toolkit` — specialized agents per review dimension (comments, tests, types)
- `hookify` — define custom behavior policies via markdown rules
- `security-guidance` — hooks that warn on potential security issues
- `agent-sdk-dev` — development tools for the Agent SDK
- `plugin-dev` — toolkit for creating new plugins

---

## 4. Research & Academic References

Claude Code is a **commercial product**, not an academic project. No `CITATION.cff`,
no arXiv papers, no peer-reviewed publications about the tool itself.

The underlying Claude models are described in Anthropic's published model cards and
safety reports, which include technical details about training, alignment approaches,
and evaluation. These are not traditional academic papers but are publicly available
at `anthropic.com`.

### Technical Blog Posts

| Title | Source |
|-------|--------|
| Claude Code: Deep Dive | Anthropic documentation site (`code.claude.com/docs/en/overview`) |
| Agent SDK documentation | Anthropic platform docs |
| MCP specification | Model Context Protocol spec (open standard, separate from Claude Code) |

---

## 5. Documentation & Learning Resources

| Resource | URL | What it covers |
|----------|-----|---------------|
| Official docs | https://code.claude.com/docs/en/overview | Full product documentation |
| Setup guide | https://code.claude.com/docs/en/setup | Installation, configuration |
| Agent SDK docs | https://platform.claude.com/docs/en/agent-sdk | Building on top of Claude Code |
| Plugin examples | `plugins/` (this repo) | 13 complete plugin implementations |
| Hook examples | `examples/hooks/` | Python hook implementation example |
| Settings examples | `examples/settings/` | Lax, strict, and sandbox configuration templates |
| CHANGELOG | `CHANGELOG.md` | Every feature and fix — an invaluable reference |
| Discord | https://anthropic.com/discord | Live community help |
| GitHub Issues | This repo | Bug reports, feature requests, community Q&A |

**Documentation quality**: Official docs are thorough for getting started. The `CHANGELOG.md`
in the repo is an unusually rich source of practical information — every deprecation,
breaking change, and new feature is documented there.

---

## 6. Hello World

### Prerequisites

- **Node.js 18+** (for legacy npm install only — new installs via curl/brew/winget)
- **Anthropic API key** or Claude.ai Pro/Max subscription
- Any operating system: macOS, Linux, Windows (including ARM64)
- CUDA GPU not required — inference runs on Anthropic's servers

### Install

**macOS / Linux (recommended)**:
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**macOS via Homebrew**:
```bash
brew install --cask claude-code
```

**Windows (recommended)**:
```powershell
irm https://claude.ai/install.ps1 | iex
```

### First Run

```bash
# Navigate to your project
cd /path/to/your/project

# Start Claude Code
claude

# Or run a one-shot command (non-interactive)
claude --print "Explain this codebase in 3 bullet points"
```

### Minimal Working Example — One-Shot Code Generation

```bash
# Create a new Python utility
claude --print "Create a Python script that counts word frequencies in a text file.
Use argparse for the filename argument and print the top 10 words."
```

### Expected Output

Claude Code reads any relevant files, writes the requested code to disk, and summarizes
what it did. In interactive mode, it shows a real-time view of tool calls.

### Common Pitfalls

1. **API cost surprise**: Long agentic sessions consume many tokens rapidly. Set spend
   limits in Anthropic Console before team-wide rollout. Monitor the token counter shown
   at session end.
2. **CLAUDE.md not respected**: The `CLAUDE.md` file must be in the git root (or home
   directory for global settings). Subdirectory placement won't be found automatically.
3. **Bash tool permission prompts**: By default, Claude Code asks permission before
   running shell commands. The `settings.json` can be configured to pre-allow common
   safe commands and pre-deny dangerous ones — do this before automating workflows.
4. **Windows compatibility**: Some features (especially shell commands assuming Unix
   utilities) may behave differently. Test on Windows before assuming macOS/Linux parity.

---

## 7. Code Quality Signals

Note: The source code is not available for audit. These signals are derived from
the public repository (plugins, scripts, CI workflows, CHANGELOG).

**Testing**: Not assessable
→ Test infrastructure for the core product is not in this repo. The plugin examples
  and scripts (TypeScript in `scripts/`) appear to lack test files in the public repo.
  The CHANGELOG's consistent high-quality fix descriptions suggest internal testing
  exists, but it cannot be evaluated externally.

**CI/CD**: Operational (issue automation)
→ 12 GitHub Actions workflows, all focused on issue/PR lifecycle management and
  community automation. No build/test/release CI is visible in this public repo
  (the release pipeline is internal to Anthropic).

**Maintenance discipline**: Exceptional (by release output)
→ Multiple patch releases per week, issues closed same-day, detailed CHANGELOG,
  deprecation notices given 1-2 versions before removal. By behavioral output,
  this team is among the most disciplined shippers in the AI tooling space.
