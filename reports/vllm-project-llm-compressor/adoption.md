# Real-World Adoption

> **Written to**: adoption.md

## Download Statistics

PyPI package name: `llmcompressor` (note: no hyphen)

| Period | Downloads |
|--------|-----------|
| Last day | ~4,750 |
| Last week | ~32,400 |
| Last month | ~115,000 |

Monthly downloads in the ~115K range is solid for a specialized ML infrastructure library. For comparison, this is comparable to niche-but-widely-deployed tools in the MLOps space. It reflects real production use rather than just experimentation.

## GitHub Signals

| Metric | Value |
|--------|-------|
| Stars | 2,754 |
| Forks | 396 |
| Open issues | 116 |
| Last push | Feb 17, 2026 (yesterday) |
| Repo age | ~20 months (created June 2024) |

2,754 stars for a 20-month-old infrastructure library is above average. Stars for compression tooling tend to undercount real usage because many teams adopt tools silently in production pipelines.

## Named Adopters & Ecosystem

No explicit `ADOPTERS.md` exists. However, adoption can be inferred from:

### Hugging Face Hub
Hundreds of quantized model checkpoints on Hugging Face Hub were produced using llm-compressor. The output format (`compressed-tensors` + `safetensors`) is the de-facto standard for vLLM-compatible quantized models. Popular quantized Llama, Qwen, Mixtral, and Mistral checkpoints use this pipeline.

### Production Models Generated
The README explicitly mentions llm-compressor was used to quantize:
- **Mistral Large 3 (675B)** — via the `model_free_ptq` pathway
- **Kimi K2** — via the same pathway
- **Qwen3-30B-A3B** — featured in the Quick Tour

These are frontier-scale models, confirming production-grade use by major labs.

### Cloud Provider Support

| Provider / Platform | Support |
|--------------------|---------|
| **Red Hat OpenShift AI** | Native — primary sponsor |
| **vLLM** | Direct integration — llm-compressor is the recommended compression tool |
| Hugging Face Hub | Output format compatible; many models hosted |
| AWS / GCP / Azure | Via vLLM on any cloud |

### Ecosystem Dependencies

- **`compressed-tensors`** (sibling library, also vLLM-project): the storage and format layer. Co-developed with llm-compressor.
- **HuggingFace Transformers**: required for loading models
- **HuggingFace Accelerate**: used for large-model sequential offloading
- **vLLM**: the runtime that loads and serves the compressed outputs

## Adoption Risk Note

The primary adoption path is via vLLM. Teams not using vLLM will find fewer reasons to adopt llm-compressor specifically, as alternatives like `bitsandbytes` or AutoGPTQ integrate with other runtimes. If your serving stack is vLLM, llm-compressor is effectively the official tool.
