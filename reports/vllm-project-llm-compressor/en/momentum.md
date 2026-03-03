# Momentum & Trajectory — LLM Compressor

> **Source**: https://github.com/vllm-project/llm-compressor | **Analyzed**: 2026-02-18

## Life-Cycle Stage: **Rapid Growth**

## Star & Fork Velocity

| Metric | Value | Rate |
|--------|-------|------|
| Total stars | 2,756 | ~138 stars / month since creation (Jun 2024) |
| Total forks | 399 | 14.5% fork-to-star ratio (high — indicates active customization) |
| Created | 2024-06-20 | ~20 months ago |
| Last pushed | **2026-02-18** | Today — extremely active |

**Star rate interpretation**: 138 stars/month is healthy for a specialized ML tooling
library. This is not viral consumer-app growth, but it is consistent forward movement
in a high-value niche. For context, the vLLM inference engine itself (the ecosystem
anchor) has 50K+ stars — as vLLM adoption grows, LLM Compressor grows with it.

## Release Cadence

| Release | Date | Time since previous |
|---------|------|-------------------|
| v0.9.0.2 | 2026-02-13 | 23 days |
| v0.9.0.1 | 2026-01-21 | 35 days |
| v0.9.0 | 2025-12-17 | ~70 days |
| v0.8.1 | 2025-10-08 | 5 days (patch) |
| v0.8.0 | 2025-10-03 | ~44 days |
| v0.7.1 | 2025-08-21 | 1 day (patch) |
| v0.7.0 | 2025-08-20 | ~23 days |
| v0.6.0.1 | 2025-07-28 | — |

**Pattern**: Minor versions every 1-2 months, with rapid patch follow-up when needed.
This is an **active development** cadence — not maintenance mode, not chaotic.

## Issue & PR Health

| Signal | Value | Assessment |
|--------|-------|------------|
| Open PRs | 45 | Moderate backlog — review bandwidth is a mild bottleneck |
| Oldest open PR | 2025-03-15 (~11 months) | Some PRs stall; core PRs merge fast |
| Issue response | Minutes to hours (same-day closes observed) | Excellent responsiveness |
| Open issues | 119 | Normal for a growing library; no sign of accumulation without response |

**Recent PR sample titles show active feature work:**
- `perf: make MSE observer compatible with torch.compile (39x speedup)` — performance optimization
- `feat: add Qwen3.5 MoE calibration module` — new model family support
- `[Docs] Reorganize` — documentation investment
- FP8 block quantization for non-divisible shapes — hardening existing features

## Feature Velocity (Recent Releases Highlights)

The v0.9.0 cycle (Dec 2025 – Feb 2026) introduced:
- Batched calibration support (batch size > 1)
- Model-free PTQ pathway (no HF model definition required) — used for Mistral Large 3 (675B)
- KV cache per-head quantization scheme
- Generalized AWQ (beyond W4A16)
- AutoRound integration
- Experimental MXFP4 support
- R3 transform support (SpinQuant-style)
- Extended Qwen3.5 MoE support

This is a high feature velocity — roughly 6-8 significant algorithm/format additions per
minor version cycle.

## Contributor Trends

| Metric | Value |
|--------|-------|
| Total contributors tracked (top 15) | 15 shown; actual count higher |
| Top contributor (markurtz) | 297 contributions |
| Second contributor (bfineran) | 293 contributions |
| Active maintainers | 6 (per .MAINTAINERS) |
| Total contributions (top 15) | 2,024 |

The top 3 contributors are roughly equal in output (297 / 293 / 249), which is a healthy
distribution — no single "wizard" gatekeeping all merges.

## Media & Community Signals

| Signal | Detail |
|--------|--------|
| Launch blog post | Neural Magic blog: "LLM Compressor is here — faster inference with vLLM" |
| vLLM ecosystem alignment | vLLM is one of the most-discussed inference engines in AI infrastructure circles |
| Frontier model adoption | Kimi K2 (Moonshot AI) and Mistral Large 3 quantized with LLM Compressor and cited in README |
| Community Slack | Active `#llm-compressor` and `#sig-quantization` channels |

## Trajectory Outlook

LLM Compressor's growth is structurally coupled to vLLM adoption:
- vLLM is the fastest-growing LLM inference engine (100K+ GitHub stars, massive enterprise uptake)
- Red Hat AI's commercial incentives align with continued investment
- The library is absorbing algorithms (AutoRound) that previously lived in separate projects

**Outlook: Accelerating.** The combination of corporate backing, ecosystem coupling, and
consistent feature delivery makes a plateau or decline in the near term unlikely.
