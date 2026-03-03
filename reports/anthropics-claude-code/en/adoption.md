# Real-World Adoption — Claude Code

> **Source**: https://github.com/anthropics/claude-code | **Analyzed**: 2026-02-18

## Download Statistics

| Metric | Value | Interpretation |
|--------|-------|---------------|
| npm weekly downloads (`@anthropic-ai/claude-code`) | **6,515,721** | Category standard — top tier (>5M/week) |
| npm monthly downloads | **31,002,928** | ~372M annualized — massive developer base |
| GitHub stars | **67,537** | Extraordinary for a 12-month-old tool |
| GitHub forks | 5,274 | High fork rate; many customizations and mirrors |
| Open issues | 6,247 | Indicator of massive active user base |
| Created | 2025-02-22 | ~12 months old |

> **Note**: npm distribution is now deprecated in favor of direct install scripts
> (`curl -fsSL https://claude.ai/install.sh | bash`). npm download counts still reflect
> significant real usage but may also include legacy automated installs. The true user
> base is very large regardless.

**Benchmark context**: 6.5M weekly npm downloads puts Claude Code alongside mainstream
developer tools. For comparison, `prettier` (the code formatter) downloads ~25M/week.
Claude Code, a complex AI agent tool, is already at 26% of that volume in year one.

## Star Velocity

| Metric | Value |
|--------|-------|
| Stars in 12 months | 67,537 |
| Average stars per month | ~5,600 |
| Stars per day (avg) | ~185 |

This is among the fastest-growing developer tool repositories on GitHub in 2025. Growth
consistently accelerates around major release announcements and Anthropic blog posts.

## Community & Ecosystem

| Channel | Signal |
|---------|--------|
| Claude Developers Discord | Active community (`anthropic.com/discord`) |
| GitHub Issues | 6,247 open — highly engaged user base reporting bugs and requesting features |
| Plugin marketplace | 13 official plugins; community plugins growing |
| GitHub Discussions | Not enabled; issues tracker serves as the community Q&A venue |

## Platform & Integration Support

Claude Code has achieved broad platform coverage within one year:

| Platform | Distribution method |
|----------|-------------------|
| macOS / Linux | `curl -fsSL https://claude.ai/install.sh \| bash` (recommended) |
| macOS / Linux | `brew install --cask claude-code` (Homebrew) |
| Windows | `irm https://claude.ai/install.ps1 \| iex` (recommended) |
| Windows | `winget install Anthropic.ClaudeCode` (WinGet) |
| npm (deprecated) | `npm install -g @anthropic-ai/claude-code` |
| VS Code | Native extension integration |
| JetBrains IDEs | Integration via plugin |
| GitHub | `@claude` tag support in PRs and Issues |
| Docker / DevContainers | `.devcontainer/` configuration included in repo |

**Windows ARM64 support** was added in v2.1.41 — showing platform breadth expansion.

## Named Adopters

No formal ADOPTERS.md exists. However, the tool's adoption profile is visible through:

- **Individual developers**: Primary user segment — software engineers across all sectors
- **Tech companies**: Many public discussions on X/Twitter and Discord of teams adopting
  Claude Code as the primary AI coding assistant
- **Anthropic internally**: Used by Anthropic engineers (the GitHub CI workflows
  themselves use Claude Code via `@claude` GitHub Actions integration)
- **Enterprise**: Anthropic's commercial terms and enterprise plan indicate significant
  organizational adoption

## Cloud & Enterprise Support

- **AWS Bedrock**: Claude Code can use Bedrock as the model provider (no direct Anthropic
  API needed) — critical for enterprise customers with AWS data agreements
- **Google Vertex AI**: Vertex provider support built in
- **Azure Foundry**: Also supported
- **Enterprise settings management**: Managed settings via `C:\Program Files\ClaudeCode`
  (Windows) and enterprise deployment documentation

This multi-cloud support means enterprises can adopt Claude Code without data leaving
their preferred cloud provider.

## Adoption Assessment

| Dimension | Signal |
|-----------|--------|
| Download volume | 🟢 Category standard (6.5M/week) |
| Star velocity | 🟢 Extraordinary (67K in 12 months) |
| Community engagement | 🟢 Very active (6.2K open issues, Discord) |
| Platform breadth | 🟢 Mac, Linux, Windows, VS Code, JetBrains, GitHub |
| Enterprise readiness | 🟢 Bedrock/Vertex/Foundry support; managed settings |
| Adoption stage | **Mainstream** |
