# Momentum & Trajectory

> **Written to**: momentum.md

## Release Cadence

| Version | Date | Notes |
|---------|------|-------|
| v0.9.0.2 | 2026-02-13 | Latest patch |
| v0.9.0.1 | 2026-01-21 | Patch |
| v0.9.0 | 2025-12-17 | Minor release |
| v0.8.1 | 2025-10-08 | Patch |
| v0.8.0 | 2025-10-03 | Minor release |

**Cadence**: Minor releases every ~2 months; patches as needed. This is a healthy cadence for an ML tooling library — frequent enough to show active development, stable enough that production users aren't chasing breaking changes.

**Versioning note**: No v1.0 yet (still 0.x), which signals the team considers the API not fully stable. Expect occasional interface changes. The library is described as "Production/Stable" in PyPI classifiers, a slight contradiction worth noting.

## Star Growth

The repo was created June 2024 and reached 2,754 stars by February 2026 — roughly **20 months**. That implies ~138 stars/month average. For an infrastructure library (which attracts fewer casual stargazers than application tools), this is solid traction.

## Activity Signals

| Signal | Value | Assessment |
|--------|-------|------------|
| Last push | Feb 17, 2026 | Active (yesterday) |
| Open PRs | 44 | High — team is busy |
| Oldest open PR | Mar 2025 | ~11 months backlog; some PRs may be stale |
| Open issues | 116 | Moderate backlog |
| Contributors (top 10 coverage) | 10 active | Small but consistent team |

## Feature Trajectory

The recent What's New section reveals strong forward momentum:

- **Batched calibration** (new) — performance improvement for quantization throughput
- **Model-Free PTQ pathway** — expanded to support massive models (Mistral Large 3 @ 675B, Kimi K2) without HF model definition
- **Extended KV cache + attention quantization** — frontier capability, few tools support this
- **MXFP4 (NVIDIA Blackwell)** — proactive support for next-gen GPU hardware (still experimental)
- **AutoRound algorithm** — added recently, from Microsoft Research
- **R3 Transform (SpinQuant)** — experimental, cutting-edge rotation-based quantization

This trajectory shows the team is tracking the state-of-the-art closely and shipping new algorithms within weeks of publication.

## Lifecycle Stage

**Assessment: Active Growth / Early Maturity**

- Not in early experimental (it handles 675B models)
- Not in maintenance mode (new algorithms every release)
- Transitioning from startup-heritage codebase to mature library
- The move from Neural Magic → Red Hat → vLLM umbrella has expanded contributor base but also created some organizational complexity visible in the 44 open PRs

## Risk of Stagnation

Low. Red Hat has a direct commercial incentive to maintain this tool (OpenShift AI). vLLM's rising adoption (it's now one of the most widely used LLM serving frameworks) creates a pull effect — as vLLM grows, tools that feed into vLLM's ecosystem naturally gain more use and more contribution.
