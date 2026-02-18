# LLM Compressor — Analysis Report

> **Source**: https://github.com/vllm-project/llm-compressor | **Analyzed**: 2026-02-18

---

## Decision Brief

### Verdict: **ADOPT** (if using vLLM)

**One sentence**: llm-compressor is the official, Red Hat AI–backed post-training compression library for the vLLM ecosystem, offering six production-grade algorithms (GPTQ, AWQ, SmoothQuant, SparseGPT, AutoRound, SimplePTQ) with a simple one-function API — if your serving stack is vLLM, this is the clear default choice.

### Why Adopt
- **vLLM native**: Produces `compressed-tensors` format that vLLM reads directly — no conversion, no shims
- **Corporate backing**: Red Hat AI (IBM subsidiary) employs the core team; not a side project
- **Production proven**: Used to compress Mistral Large 3 (675B), Kimi K2, and hundreds of Hugging Face Hub model checkpoints
- **Active**: Last push yesterday (Feb 17, 2026); new algorithms shipped every 1–2 months
- **Comprehensive**: Six algorithms cover the full matrix from data-free FP8 to calibrated GPTQ/AWQ
- **Permissive license**: Apache 2.0, no lock-in

### Caveats
- **vLLM dependency**: If your runtime is NOT vLLM (e.g., llama.cpp, TRT-LLM, ONNX Runtime), alternatives fit better
- **Pre-1.0 API**: Still 0.9.x — minor breaking changes may occur; no formal CHANGELOG
- **Small core team**: Top-3 contributors hold ~48% of commits (all Red Hat employees)
- **No SECURITY.md**: No formal vulnerability disclosure process documented

### Recommended Use Cases
1. Compressing any Transformer model for production serving via vLLM (FP8, INT8, W4A16)
2. Reducing GPU count / memory footprint for large models in Red Hat / OpenShift AI environments
3. Experimenting with multiple quantization algorithms without switching libraries
4. Quantizing frontier models (MoE, multimodal, 600B+ parameter) via the model-free pathway

---

## Key Metrics

| Metric | Value |
|--------|-------|
| Stars | 2,754 |
| Forks | 396 |
| PyPI weekly downloads | ~32,400 |
| PyPI monthly downloads | ~115,000 |
| License | Apache 2.0 |
| Backed by | Red Hat AI (IBM) + vLLM Project |
| Latest release | v0.9.0.2 (Feb 13, 2026) |
| Last push | Feb 17, 2026 |
| Open PRs / Issues | 44 PRs / 116 issues |
| Repo age | ~20 months (created Jun 2024) |
| Top contributor share | Top-1: 17%, Top-3: 48% |
| Python requirement | ≥ 3.10 |

---

## Contents

| Section | Summary | File |
|---------|---------|------|
| Organizational Background | Red Hat AI (IBM) backs this via the vLLM umbrella; originated at Neural Magic (acquired 2024). Apache 2.0, no foundation governance but strong corporate stability. | [background.md](./background.md) |
| Real-World Adoption | ~115K monthly PyPI downloads; vLLM's de-facto compression tool; used to produce hundreds of HF Hub checkpoints including Mistral Large 3 (675B) and Kimi K2. | [adoption.md](./adoption.md) |
| Competitive Landscape | Supersedes AutoGPTQ and AutoAWQ in the vLLM ecosystem; bitsandbytes and TRT-LLM serve different runtime targets; llama.cpp/GGUF is for CPU/edge deployment. | [competitive.md](./competitive.md) |
| Momentum & Trajectory | Active growth: 2 minor releases + patches in 5 months, frontier algorithm additions (MXFP4, AutoRound, attention quantization), last push yesterday. | [momentum.md](./momentum.md) |
| Risk Assessment | Low abandonment risk (Red Hat-backed), medium bus factor (small team), medium API stability (pre-1.0), no SECURITY.md. Overall: manageable risk profile. | [risk.md](./risk.md) |
| Technical Details | Six algorithms (GPTQ, AWQ, SmoothQuant, SparseGPT, AutoRound, SimplePTQ); modifier + recipe architecture; 21 example categories; comprehensive FP8/INT8/W4A16 support including MoE, multimodal, and 600B+ models. | [technical.md](./technical.md) |
