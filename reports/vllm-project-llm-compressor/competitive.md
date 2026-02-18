# Competitive Landscape

> **Written to**: competitive.md

## Alternatives at a Glance

| Tool | Backing | Algorithms | Runtime Integration | Best For |
|------|---------|-----------|---------------------|----------|
| **llm-compressor** | Red Hat AI / vLLM | GPTQ, AWQ, SmoothQuant, SparseGPT, AutoRound, SimplePTQ | vLLM (native), HF | vLLM deployments, Red Hat/enterprise |
| **AutoGPTQ** | Community (Qwen team active) | GPTQ only | transformers, vLLM (via compat) | GPTQ-only W4A16 use cases |
| **AutoAWQ** | Casper Hansen (community) | AWQ only | transformers, vLLM (via compat) | AWQ W4A16 use cases |
| **bitsandbytes** | Tim Dettmers → HuggingFace | NF4/INT8 (BnB-specific) | HF Transformers (bnb backend) | Quick 4/8-bit inference in HF pipelines |
| **TensorRT-LLM** | NVIDIA | FP8, INT4/8, W4A8 | TensorRT-LLM runtime only | NVIDIA-exclusive, maximum throughput |
| **ONNX Runtime / Olive** | Microsoft | INT4/8, QDQ quantization | ONNX Runtime | Edge, Windows, non-NVIDIA deployment |
| **llama.cpp / GGUF** | Community (georgi gerganov) | GGUF Q2-Q8 formats | llama.cpp, Ollama, LM Studio | CPU inference, local/edge deployment |

## Detailed Comparison

### vs. AutoGPTQ and AutoAWQ
AutoGPTQ and AutoAWQ are **single-algorithm** libraries. llm-compressor subsumes both — it implements GPTQ and AWQ, plus four additional algorithms, with a unified recipe API. If you're already using AutoGPTQ/AutoAWQ and are happy, there is no urgent reason to migrate. But for new projects or multi-algorithm experimentation, llm-compressor is the more complete choice.

*Key difference*: llm-compressor's `compressed-tensors` format is what vLLM natively reads. AutoGPTQ/AutoAWQ outputs require conversion or compatibility shims.

### vs. bitsandbytes
bitsandbytes is a **runtime quantization** library — it quantizes on the fly during inference. llm-compressor is a **PTQ pre-compression** library — you compress once, save the compressed checkpoint, and serve it repeatedly. For high-volume serving, pre-compression is far more efficient.

bitsandbytes is better for: quick QLoRA fine-tuning experiments, HF ecosystem scripts without a separate compression step.

### vs. TensorRT-LLM
TensorRT-LLM offers higher throughput but at the cost of NVIDIA lock-in and a significantly heavier integration burden. llm-compressor + vLLM is more portable and has a gentler adoption curve. For non-NVIDIA hardware (AMD ROCm, upcoming) or for teams that want to avoid NVIDIA's SDK ecosystem, llm-compressor is the better choice.

### vs. llama.cpp / GGUF
Entirely different deployment targets. GGUF is for CPU-first, local, or edge inference. llm-compressor targets GPU serving at scale via vLLM. They don't compete directly; many teams use both (GGUF for local dev, vLLM+llm-compressor for production).

## Market Positioning

llm-compressor occupies the **"vLLM-first, enterprise-ready PTQ compression"** niche. It is the recommended path for:
- Teams already using or planning to use vLLM as their inference server
- Organizations in the Red Hat / OpenShift AI ecosystem
- Teams needing multiple quantization algorithms without stitching together separate libraries

## When to Pick llm-compressor vs. Alternatives

| Situation | Recommended |
|-----------|-------------|
| You serve with vLLM | **llm-compressor** — native format |
| Quick HF pipeline, no serving infra | bitsandbytes |
| NVIDIA-only, max throughput matters | TensorRT-LLM |
| CPU / local inference (Ollama etc.) | llama.cpp / GGUF |
| Fine-tuning + quantization combined | bitsandbytes (QLoRA) |
| GPTQ-only, already invested in AutoGPTQ | AutoGPTQ (no urgent switch needed) |
