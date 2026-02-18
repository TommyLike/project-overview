# Technical Deep-Dive

> **Written to**: technical.md

## 1. Core Concepts & Mental Model

llm-compressor is a **post-training compression library**: you take a pre-trained model, apply compression once (offline), save the result, and deploy the compressed model with vLLM. Nothing runs at training time.

The three core abstractions:

### Recipe
A YAML file (or Python object) that declares which compression algorithms to apply, to which layers, with which parameters. Decouples "what to compress" from "how to compress".

```yaml
# Example recipe: W4A16 GPTQ
gptq_stage:
  run_type: oneshot
  modifiers:
    GPTQModifier:
      targets: Linear
      scheme: W4A16
      num_calibration_samples: 512
      group_size: 128
      ignore: ["lm_head"]
```

### Modifier
A Python class implementing a specific compression algorithm. Each modifier knows how to:
1. Hook into the model's forward pass to collect calibration statistics
2. Apply weight transformations (quantization, pruning, rotation)
3. Store metadata in the output checkpoint

Current modifiers: `QuantizationModifier` (PTQ), `GPTQModifier`, `AWQModifier`, `SmoothQuantModifier`, `SparseGPTModifier`, `AutoRoundModifier`

### Oneshot
The single entrypoint for applying compression:
```python
from llmcompressor import oneshot
oneshot(model=model, recipe=recipe, dataset=calibration_data)
```
Handles the full pipeline: calibration data loading → modifier lifecycle → saving compressed checkpoint.

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  User / Recipe YAML                  │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│              oneshot() entrypoint                    │
│   (src/llmcompressor/entrypoints/oneshot.py)         │
└───────┬────────────────────────┬────────────────────┘
        │                        │
        ▼                        ▼
┌───────────────┐     ┌──────────────────────────────┐
│  Session/     │     │  Modifier Pipeline           │
│  Lifecycle    │     │  (modifiers/*)               │
│  Management   │◄────│  GPTQModifier                │
│               │     │  AWQModifier                 │
│               │     │  SmoothQuantModifier         │
│               │     │  SparseGPTModifier           │
│               │     │  AutoRoundModifier           │
└───────┬───────┘     └──────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────┐
│             HuggingFace Transformers                 │
│    AutoModelForCausalLM + accelerate offloading      │
└───────────────────────────────────────────────────────┘
        │ saves
        ▼
┌─────────────────────────────────────────────────────┐
│         compressed-tensors checkpoint               │
│   (safetensors + quantization_config.json)          │
└───────────────────────────────────────────────────────┘
        │ loaded by
        ▼
┌─────────────────────────────────────────────────────┐
│                    vLLM Runtime                     │
└─────────────────────────────────────────────────────┘
```

**Large model handling**: Uses HuggingFace `accelerate`'s sequential CPU offloading. Transformer blocks are processed one at a time, with compressed blocks remaining on CPU while subsequent blocks are loaded to GPU. This allows quantizing models larger than available VRAM (e.g., Mistral 675B on limited GPU resources).

---

## 3. Key Components

### `src/llmcompressor/modifiers/`
Core algorithms directory:

| Module | Algorithm | What it does |
|--------|-----------|--------------|
| `modifiers/quantization/` | SimplePTQ (RTN) | Round-to-nearest, no calibration needed |
| `modifiers/obcq/` | GPTQ | Second-order weight quantization with Hessian compensation |
| `modifiers/awq/` | AWQ | Activation-aware weight quantization (scales activations before quantizing weights) |
| `modifiers/smoothquant/` | SmoothQuant | Migrates quantization difficulty from activations to weights via per-channel scaling |
| `modifiers/obcq/sgpt_sparsification.py` | SparseGPT | Unstructured/2:4 sparsity using same Hessian approach as GPTQ |
| `modifiers/quantization/autoround/` | AutoRound | Intel's sign-gradient rounding optimization |

### `src/llmcompressor/entrypoints/`
- `oneshot.py` — main API
- `model_free/` — new pathway for models without HF class definitions

### `src/llmcompressor/recipe/`
Recipe parsing, YAML loading, and modifier registration

### `src/llmcompressor/pipelines/`
Calibration data pipeline management (batching, sequential loading)

### `compressed-tensors` (sibling repo)
The storage format library. Defines quantization metadata schema, weight packing, and the reader used by vLLM. Not part of this repo but tightly coupled.

---

## 4. Research & Academic References

The algorithms implemented in llm-compressor are drawn directly from peer-reviewed research:

| Algorithm | Paper | Venue | Key Idea |
|-----------|-------|-------|----------|
| **GPTQ** | [GPTQ: Accurate PTQ for GPT](https://arxiv.org/abs/2210.17323) | ICLR 2023 | Hessian-based column-wise weight quantization; 3–4 bit with negligible loss |
| **SparseGPT** | [SparseGPT: Massive LLMs Can be Pruned in One Shot](https://arxiv.org/abs/2301.00774) | ICML 2023 | Same OBQ framework applied to pruning; 50-60% sparsity at minimal perplexity cost |
| **AWQ** | [AWQ: Activation-aware Weight Quantization](https://arxiv.org/abs/2306.00978) | MLSys 2024 | Protect salient weights via per-channel activation scales; hardware-efficient |
| **SmoothQuant** | [SmoothQuant: Accurate and Efficient PTQ for LLMs](https://arxiv.org/abs/2211.10438) | ICML 2023 | Migrate quantization difficulty from activations to weights via scaling |
| **AutoRound** | [Optimize Weight Rounding via Signed Gradient Descent](https://aclanthology.org/2024.findings-emnlp.662.pdf) | EMNLP Findings 2024 | Sign-gradient descent to jointly optimize rounding and clipping |
| **SpinQuant / R3** | [SpinQuant: LLM Quantization with Learned Rotations](https://arxiv.org/abs/2405.16406) | — | Random rotation matrices to improve quantizability |

> For a deeper understanding of GPTQ, see the local summary at `knowledge/summary_gptq.md`.

---

## 5. Documentation & Learning Resources

| Resource | URL |
|----------|-----|
| **Official Docs** | https://docs.vllm.ai/projects/llm-compressor/en/latest/ |
| **GitHub Repo** | https://github.com/vllm-project/llm-compressor |
| **Compression Schemes Guide** | [docs/guides/compression_schemes.md](https://github.com/vllm-project/llm-compressor/blob/main/docs/guides/compression_schemes.md) |
| **Announcement Blog** | https://neuralmagic.com/blog/llm-compressor-is-here-faster-inference-with-vllm/ |
| **Architecture Overview (slides)** | https://docs.google.com/presentation/d/1WNkYBKv_CsrYs69lb7bJKjh2dWt8U1HXUw7Gr4Wn3gE/edit |
| **Community Slack** | #llm-compressor and #sig-quantization in [vLLM Slack](https://communityinviter.com/apps/vllm-dev/join-vllm-developers-slack) |
| **PyPI** | https://pypi.org/project/llmcompressor/ |

### Key Example Directories

| Directory | What it demonstrates |
|-----------|---------------------|
| `examples/quantization_w8a8_fp8/` | FP8 activation + weight quantization (most common enterprise path) |
| `examples/quantization_w4a16/` | W4A16 GPTQ (maximum memory savings) |
| `examples/awq/` | AWQ quantization |
| `examples/quantization_kv_cache/` | KV cache FP8 quantization |
| `examples/big_models_with_sequential_onloading/` | Large model (>1 GPU) quantization |
| `examples/quantizing_moe/` | Mixture-of-Experts models (DeepSeek, Mixtral) |
| `examples/multimodal_vision/` | Vision-language models |
| `examples/model_free_ptq/` | Kimi K2 / Mistral Large 3 pathway |

---

## 6. Hello World — Quantize a Model to FP8

The most common use case: compress a model to FP8 (2× smaller, minimal accuracy loss, loads natively in vLLM).

### Step 1: Install

```bash
pip install llmcompressor
```

### Step 2: Quantize

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import QuantizationModifier

MODEL_ID = "meta-llama/Llama-3.1-8B-Instruct"  # any HF model

model = AutoModelForCausalLM.from_pretrained(MODEL_ID, dtype="auto")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

# FP8 dynamic quantization — no calibration dataset needed
recipe = QuantizationModifier(
    targets="Linear",
    scheme="FP8_DYNAMIC",
    ignore=["lm_head"],
)

oneshot(model=model, recipe=recipe)

# Save compressed checkpoint
model.save_pretrained("Llama-3.1-8B-FP8")
tokenizer.save_pretrained("Llama-3.1-8B-FP8")
```

### Step 3: Serve with vLLM

```python
from vllm import LLM
model = LLM("Llama-3.1-8B-FP8")
output = model.generate("Hello, my name is")
print(output[0].outputs[0].text)
```

**Time estimate**: FP8 RTN takes ~5–15 minutes on a single A100 for a 7–8B model. GPTQ (which needs calibration data) takes ~30–60 minutes.

---

## 7. Code Quality Signals

| Signal | Value | Assessment |
|--------|-------|------------|
| Language | Python 3.10+ | Modern, well-supported |
| Linting | `ruff` (fast, modern) | Good — consistent style |
| Type checking | `mypy ~1.10` | Present — reduces runtime surprises |
| Testing | `pytest` + `pytest-rerunfailures` | Flaky GPU tests handled gracefully |
| Test eval | `lm_eval==0.4.9.2` | Integrated accuracy validation |
| CI | 8 GitHub Actions workflows | quality-check, test-check, test-check-transformers, and more |
| Pre-commit hooks | Yes | Enforced on contributions |
| Docs | MkDocs + mkdocs-material | Professional, versioned docs |

The codebase is well-structured for a research-to-production library. The modifier pattern is clean and extensible — adding a new algorithm means subclassing the right modifier base class. The main complexity is managing GPU memory and calibration data pipelines, which is inherent to the domain.
