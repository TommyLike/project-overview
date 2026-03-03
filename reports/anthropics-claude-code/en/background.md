# Organizational Background — Claude Code

> **Source**: https://github.com/anthropics/claude-code | **Analyzed**: 2026-02-18

## Backing Entity

Claude Code is a first-party product built and maintained entirely by **Anthropic PBC** —
the AI safety company founded in 2021 by Dario Amodei, Daniela Amodei, and other former
OpenAI leaders. This is not a community project; it is a core commercial offering from one
of the world's leading AI companies.

**About Anthropic**:

| Fact | Detail |
|------|--------|
| Founded | 2021 (San Francisco, CA) |
| Founders | Dario Amodei (CEO), Daniela Amodei (President), former OpenAI leadership team |
| Primary mission | AI safety research + commercial Claude model deployment |
| Total funding | ~$7.7B+ (as of 2025) |
| Key investors | Amazon ($4B+), Google ($300M+), Spark Capital, others |
| Revenue | Subscription (Claude.ai) + API (pay-per-token) + Enterprise |
| GitHub org | anthropics — 68 public repos, 27K followers |

**Amazon's $4B investment** (2023-2024) and Google's strategic investment make Anthropic's
financial runway one of the most secure in the AI industry. Anthropic is not at risk of
shutting down or pivoting away from Claude Code.

## Product Relationship

Claude Code is Anthropic's **primary developer-facing product** in the coding agent category.
It is both a commercial product (driving Claude API usage and subscriptions) and a proof
of Claude's agentic capabilities. This dual role ensures strong internal investment:

- Claude Code drives significant API token consumption — every coding session is
  billable API usage for Anthropic.
- Claude Code serves as Anthropic's flagship demonstration of "agentic AI" in practice.
- Used internally by Anthropic engineers themselves (dogfooding).

## Governance Model

Claude Code is **proprietary software** — there is no open-source governance, no foundation,
no community voting on direction. All product decisions are made by Anthropic's internal
Claude Code team.

| Mechanism | Detail |
|-----------|--------|
| Decision making | Anthropic internal product team |
| Issue tracking | GitHub Issues (public) — 6,247 open, actively used by community |
| Issue triage | Partially automated via Claude itself (GitHub Actions using Claude API) |
| Community | Claude Developers Discord (`anthropic.com/discord`) |
| Security disclosure | HackerOne VDP (`hackerone.com/anthropic-vdp`) |
| Plugin ecosystem | Official marketplace + community-contributed plugins |

## License: PROPRIETARY ⚠️

**This is not open source.** The entire `LICENSE.md` reads:

> © Anthropic PBC. All rights reserved. Use is subject to Anthropic's Commercial Terms of Service.

What this means practically:
- You **can** use Claude Code as a tool under Anthropic's Terms of Service.
- You **cannot** fork, modify, or redistribute the source code (the source is not published).
- You **cannot** audit the binary for security (though Anthropic's Privacy Policy applies).
- Your use is governed by Anthropic's **Commercial Terms of Service** — read them.

The GitHub repository is primarily a **community hub** (issue tracking, plugin examples,
CHANGELOG, documentation links) — the actual compiled binary is distributed separately via
install scripts and package managers.

## Commercial Relationship

Claude Code is **free to install but requires API credits** to use:
- **Claude.ai Pro/Team/Enterprise subscribers**: Included usage via max plan
- **API users**: Billed per token (input + output + cache reads/writes)
- No "open-core" model — all features require an active Anthropic account

This means adoption implies an ongoing financial relationship with Anthropic.
