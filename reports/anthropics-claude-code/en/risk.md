# Risk Assessment — Claude Code

> **Source**: https://github.com/anthropics/claude-code | **Analyzed**: 2026-02-18

## Overall Risk: 🟡 Medium (for developer tooling adoption)

Claude Code is backed by one of the world's best-funded AI companies, ships constantly,
and has achieved mainstream adoption. The risks are real but are the expected trade-offs
of any proprietary SaaS developer tool — not unusual blockers. The critical risks to
evaluate are license terms, data collection, API cost unpredictability, and vendor lock-in.

---

## License Risk ⚠️ — The Most Important Finding

**License**: © Anthropic PBC. All rights reserved.

This is **not open source**. The GitHub repository does not contain the source code of
Claude Code — it contains plugins, examples, documentation links, and issue tracking.
The compiled binary is distributed via install scripts.

| Scenario | Risk |
|----------|------|
| Using Claude Code as a developer tool | 🟢 Permitted under Anthropic ToS |
| Embedding Claude Code in your product | 🔴 Not permitted — all rights reserved |
| Auditing the source code for security | 🔴 Not possible — source not published |
| Running Claude Code on-premises | 🔴 Not available |
| Forking or customizing the binary | 🔴 Not permitted |
| Redistribution | 🔴 Not permitted |

**Practical impact for developer teams**: As a *tool* (not a library you embed), the
"all rights reserved" license is comparable to using any other proprietary developer tool
(VS Code is MIT, but Cursor, GitHub Copilot, and many others are also proprietary). The
key question is your organization's comfort level with proprietary tooling and Anthropic's
Terms of Service.

---

## Data Collection & Privacy Risk 🟡

Claude Code sends your code and conversation to Anthropic's servers for model inference.

| Data aspect | Policy |
|-------------|--------|
| Code sent to servers | Yes — required for model inference |
| Retention | Limited retention periods for sensitive data (per privacy policy) |
| Training use | Policy states feedback data is NOT used for model training |
| Enterprise controls | AWS Bedrock / Vertex AI providers can keep data in your cloud |
| GDPR/compliance | Governed by Anthropic's Privacy Policy and Commercial ToS |

**Mitigation options**:
- Use **AWS Bedrock** or **Google Vertex AI** as the model provider — this routes inference
  through your cloud agreement, potentially satisfying data residency requirements.
- Use **managed network policies** to restrict outbound traffic to approved endpoints.
- Review Anthropic's full [data usage documentation](https://code.claude.com/docs/en/data-usage).

**Enterprise caution**: For teams working with highly sensitive IP, regulated data (HIPAA,
PCI, classified), or under strict data sovereignty laws, assess Anthropic's compliance
posture carefully. "Use Bedrock" is the primary enterprise mitigation.

---

## Vendor Lock-In Risk 🟡

| Aspect | Risk |
|--------|------|
| Model lock-in | Locked to Claude models only (no multi-model support) |
| Workflow customization | Plugins, hooks, and CLAUDE.md can be migrated, but skills are proprietary to Claude Code |
| API cost | Per-token pricing — agentic sessions can be expensive and hard to budget |
| Pricing changes | Anthropic can change Claude API pricing unilaterally |
| Service continuity | Depends entirely on Anthropic continuing to operate the service |

**Cost unpredictability is the most common complaint**: An agentic session on a large
codebase can consume millions of tokens. Teams report monthly API bills varying widely
based on usage patterns. Budget controls should be established before team-wide rollout.

---

## Bus Factor / Organizational Risk 🟢

Unlike open-source projects, the bus factor question here is about Anthropic as a company:

| Signal | Assessment |
|--------|------------|
| Total Anthropic funding | ~$7.7B+ |
| Key investors | Amazon ($4B+), Google ($300M+) |
| Revenue | Growing subscription + API revenue |
| Team size | ~3,000+ employees (2025 estimate) |
| Acquisition risk | High-profile target; acquisition would likely continue the product |
| Shutdown risk | Very low given investment level and revenue |

The individual contributor concentration (`bcherny` leads with 70 commits) is irrelevant
at the organizational level — Anthropic has a full product team behind Claude Code.

---

## Security Posture 🟢

| Check | Status |
|-------|--------|
| `SECURITY.md` | ✅ Present — HackerOne VDP program |
| Vulnerability disclosure | ✅ Formal process via HackerOne |
| Security audit | Not public, but Anthropic maintains a security team |
| Binary audit | ❌ Not possible (closed source) |
| Dependency audit | Not visible to users |
| MCP sandboxing | Claude Code includes permission prompts and sandboxing controls |

**Notable**: The install script (`curl ... | bash`) carries inherent supply-chain risk
common to this installation pattern. Review Anthropic's install script before running
in sensitive environments.

---

## Breaking Change Risk 🟡

The CHANGELOG shows frequent deprecations and removals:

- Legacy SDK entrypoint removed → must migrate to `@anthropic-ai/claude-agent-sdk`
- `DEBUG=true` removed → replaced by `ANTHROPIC_LOG=debug`
- `--print` JSON output changed format (breaking change explicitly labeled)
- Config options deprecated with 1-2 version notice before removal
- Windows managed settings path migrated

**Pattern**: Breaking changes occur roughly every 10-20 releases, with 1-2 releases of
deprecation notice. Compared to most proprietary SaaS tools, the notice period is
reasonable. However, teams scripting around Claude Code's output/behavior must monitor
the CHANGELOG actively.

---

## Risk Summary

| Risk Category | Level | Notes |
|---------------|-------|-------|
| License (for tool use) | 🟢 Acceptable | Normal proprietary SaaS tool terms |
| License (for embedding/redistribution) | 🔴 Blocked | All rights reserved |
| Data collection | 🟡 Medium | Code sent to Anthropic servers; use Bedrock/Vertex to mitigate |
| Vendor lock-in | 🟡 Medium | Claude-model-only; API cost variability |
| Org/bus factor | 🟢 Low | Anthropic is well-funded and growing |
| Security disclosure | 🟢 Good | HackerOne VDP; formal process |
| Binary auditability | 🟡 Medium | Closed source; trust required |
| Breaking changes | 🟡 Medium | Frequent deprecations; monitor CHANGELOG |
