# LLM Compressor — Analysis Report

> **Source**: https://github.com/vllm-project/llm-compressor | **Analyzed**: 2026-02-18

## Decision Brief

**Verdict**: Adopt ✅

**One-line summary**: LLM Compressor is the officially-endorsed, Red Hat AI–backed
quantization and sparsity library for compressing Hugging Face LLMs into a format
natively deployable with vLLM.

| Signal | Status |
|--------|--------|
| Organizational backing | FAANG-adjacent — Red Hat AI (IBM subsidiary), vLLM Project |
| Real-world adoption | Growing — 32K weekly PyPI downloads, native vLLM integration |
| Maintenance health | Active — pushed today (2026-02-18), monthly release cadence |
| License risk | 🟢 Low — Apache-2.0 |
| Bus factor | 🟢 Low-Medium — 6 active maintainers, top 3 hold 41% of commits |
| Breaking-change risk | 🟡 Medium — pre-v1 (v0.9.x), pin minor version in production |

**Best suited for**: Teams deploying quantized LLMs with vLLM; organizations needing
FP8, W8A8, W4A16, or multi-algorithm compression pipelines; production deployments at
7B–675B parameter scale; multimodal and MoE model compression.

**Not suited for**: GGUF/llama.cpp inference stacks; CPU-only or mobile deployment;
non-Transformer model architectures; teams needing plug-and-play BitsAndBytes-style loading.

**Key risk**: Pre-v1 status means API may change between minor versions; tight
`transformers` version pin can conflict with rapidly-updating Hugging Face ecosystem.

**Primary alternative**: BitsAndBytes for simplest one-line 4-bit loading;
AutoGPTQ for legacy GPTQ workflows (note: AutoGPTQ is in declining maintenance).

**Recommended next step**: Adopt now for vLLM-based production inference. Run a
proof-of-concept with your target model (start with `FP8_BLOCK` scheme — data-free,
fastest to validate). Pin `llmcompressor~=0.9.0` until v1.0 releases.

---

## Key Metrics

| Metric | Value |
|--------|-------|
| GitHub stars | 2,756 |
| GitHub forks | 399 |
| Weekly PyPI downloads | 32,427 |
| Monthly PyPI downloads | 115,282 |
| License | Apache-2.0 |
| Backed by | Red Hat AI (IBM) / vLLM Project |
| Current version | v0.9.0.2 |
| Last pushed | 2026-02-18 (today) |
| Created | 2024-06-20 |
| Open issues | 119 |
| Open PRs | 45 |
| Active maintainers | 6 |
| Python requirement | ≥ 3.10 (Linux only) |
| Primary language | Python |

---

## Contents

| Section | Summary | File |
|---------|---------|------|
| Organizational Background | Red Hat AI (IBM) via Neural Magic acquisition, co-governed with vLLM Project; 6-person core team; no FUNDING.yml — commercially funded. | [background.md](./background.md) |
| Real-World Adoption | 32K weekly PyPI downloads; native vLLM integration; used to compress frontier models including Kimi K2 and Mistral Large 3. | [adoption.md](./adoption.md) |
| Competitive Landscape | De-facto standard for vLLM quantization; strongest challenger to AutoGPTQ (declining) and BitsAndBytes (different use case) in the production inference space. | [competitive.md](./competitive.md) |
| Momentum & Trajectory | Rapid growth — 8 releases in 8 months, pushed today, 138 stars/month; high feature velocity with new algorithms per minor version. | [momentum.md](./momentum.md) |
| Risk Assessment | Overall medium risk: pre-v1 API instability and tight transformers version pins are the main concerns; bus factor and license risks are low. | [risk.md](./risk.md) |
| Technical Details | Recipe + Modifier declarative pipeline; supports GPTQ, AWQ, SmoothQuant, SparseGPT, AutoRound; outputs compressed-tensors format for vLLM. | [technical.md](./technical.md) |
