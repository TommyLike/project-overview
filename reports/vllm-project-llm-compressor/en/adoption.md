# Real-World Adoption — LLM Compressor

> **Source**: https://github.com/vllm-project/llm-compressor | **Analyzed**: 2026-02-18

## Download Statistics

| Metric | Value | Interpretation |
|--------|-------|---------------|
| PyPI weekly downloads | **32,427** | Growing real user base (10K–500K range) |
| PyPI monthly downloads | **115,282** | ~1.4M annualized run rate |
| PyPI daily downloads | 4,750 | Consistent daily usage, not just CI/CD noise |
| GitHub stars | 2,756 | Modest — downloads-to-stars ratio is high (healthy signal) |
| GitHub forks | 399 | 14.5% fork rate — significant adaptation/extension activity |

**Context**: 32K weekly downloads for an ML compression library is meaningful. For
comparison, highly specialized ML tools like `peft` (parameter-efficient fine-tuning) grew
from similar numbers before crossing 500K/week. LLM Compressor is on a growth trajectory
consistent with becoming a category standard for LLM quantization in the vLLM ecosystem.

## Named Adopters

No formal `ADOPTERS.md` or `USERS.md` file exists. However, adoption signals are visible
in other ways:

- **Model hubs**: The `compressed-tensors` format is used by hundreds of pre-quantized
  model checkpoints on Hugging Face Hub (by Neural Magic / Red Hat AI). These serve as
  indirect proof of production use.
- **README mentions**: Kimi K2 (Moonshot AI), Mistral Large 3 (675B) are explicitly
  cited in the README as models quantized using LLM Compressor's new `model_free_ptq`
  pathway — these are frontier-scale models (100B+ parameter class).
- **Broad model support**: Examples exist for Llama, Qwen, Gemma, Mistral, DeepSeek,
  Phi, LLaVA, InternVL, Whisper, MedGemma — this breadth suggests wide community adoption
  across model families.

## Ecosystem Integration

| Integration | Status | Significance |
|-------------|--------|-------------|
| **vLLM** (inference engine) | Native — compressed-tensors format is vLLM's default quantization format | Critical: models compressed here load directly into vLLM without conversion |
| **Hugging Face Transformers** | Full compatibility — extends `AutoModelForCausalLM` | Any HF-compatible model can be compressed without code changes |
| **Hugging Face Hub** | Push/pull via `save_pretrained` / `from_pretrained` | Seamless sharing of quantized models |
| **accelerate** | Integrated for large model offloading | Enables quantization of 70B+ models on multi-GPU setups |
| **compressed-tensors** | Hard dependency (same vLLM Project org) | Format specification and serialization layer |

## Community Channels

| Channel | Detail |
|---------|--------|
| vLLM Community Slack | Active `#llm-compressor` and `#sig-quantization` channels |
| GitHub Issues | 119 open issues; recent issues closed within hours |
| GitHub Discussions | Issues tracker used for community Q&A |

## Cloud & Platform Support

No native managed service exists yet (this is a library, not a platform). However:

- Models produced by LLM Compressor are deployable on any cloud via vLLM (AWS, GCP, Azure,
  and all major cloud ML platforms that support vLLM)
- Red Hat OpenShift AI is expected to deepen integration as Red Hat AI's commercial offering

## Adoption Assessment

| Dimension | Signal |
|-----------|--------|
| Download volume | Growing — 32K/week in a specialized niche is healthy |
| Ecosystem fit | Tight — first-class in vLLM, the fastest-growing LLM inference engine |
| Named enterprise users | Implicit (frontier model quantization at scale) |
| Community activity | Active Slack, fast issue response |
| Adoption stage | **Growing** — not yet mainstream, but clearly beyond experimental |

**Bottom line**: LLM Compressor has crossed the "toy/experimental" threshold. Its tight
integration with vLLM means that any team deploying LLMs at scale with vLLM is the natural
adopter. Downloads will grow as vLLM adoption grows — the two are coupled.
