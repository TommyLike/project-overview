# Technical Deep-Dive — LLM Compressor

> **Source**: https://github.com/vllm-project/llm-compressor | **Analyzed**: 2026-02-18

## 1. Core Concepts & Mental Model

### Primary Abstraction

LLM Compressor treats model compression as a **declarative pipeline**: you describe *what*
to compress and *how* using a **Recipe**, and the library orchestrates the **Modifiers**
that implement each algorithm. The compressed model is serialized in the
**compressed-tensors** safetensors format, which vLLM reads natively.

**One-sentence workflow**:
Load a Hugging Face model → define a Recipe → call `oneshot()` → save compressed model
→ load in vLLM.

### Key Terminology

| Term | Definition |
|------|-----------|
| **Recipe** | Declarative YAML or Python object specifying which compression algorithms to apply, to which layers, with which hyperparameters |
| **Modifier** | A pluggable algorithm module (e.g., `QuantizationModifier`, `GPTQModifier`, `SmoothQuantModifier`) that implements one compression step |
| **Oneshot** | The primary API entry point (`llmcompressor.oneshot()`) — applies a recipe to a model in a single forward-pass calibration (no training) |
| **Model-free PTQ** | A newer pathway (`model_free_ptq()`) that quantizes without requiring the Hugging Face model class definition — useful for unsupported architectures |
| **Observer** | A component that collects activation statistics during calibration (min/max, MSE) used to determine quantization scales |
| **Calibration dataset** | A small dataset (~512 samples) passed through the model during `oneshot` to compute activation statistics |
| **compressed-tensors** | The output serialization format and companion library — extends safetensors with compression metadata understood by vLLM |
| **Scheme** | A named quantization configuration preset (e.g., `FP8_BLOCK`, `W8A8`, `W4A16`) |

### Mental Model

Think of LLM Compressor as a **compiler for neural network weights**. Just as a compiler
takes source code and optimization flags to produce an efficient binary, LLM Compressor
takes a model and a Recipe to produce an efficient, compressed checkpoint. The Recipe is
the "optimization flag" — it specifies which layers to compress, which algorithm to use,
and what precision to target. The Modifiers are the "compiler passes" — each one
implements a specific transformation. The output is not the model itself running faster,
but a saved checkpoint that a runtime (vLLM) executes efficiently on hardware.

---

## 2. Architecture Overview

### Layered Architecture

```
User API Layer
├── oneshot(model, recipe, dataset)           ← Primary entry point
└── model_free_ptq(model_path, recipe)        ← No HF class required

Pipeline Layer
└── CalibrationPipeline / SequentialPipeline  ← Orchestrates modifier execution
    └── Handles batching, memory management, sequential layer onloading

Modifier Layer (one per algorithm)
├── QuantizationModifier  ← Simple PTQ / RTN
├── GPTQModifier          ← GPTQ (Hessian-based weight rounding)
├── AWQModifier           ← AWQ (activation-aware weight quantization)
├── SmoothQuantModifier   ← SmoothQuant (scale migration from activation to weight)
├── SparseGPTModifier     ← SparseGPT (unstructured/2:4 sparsity)
└── AutoRoundModifier     ← AutoRound (sign gradient descent rounding)

Observer Layer
├── MinMaxObserver        ← Simple min/max scale computation
├── MSEObserver           ← Mean-squared-error optimal clipping
└── PercentileObserver    ← Percentile-based clipping

Output Layer
└── compressed-tensors format (safetensors + quantization metadata JSON)
    └── → vLLM loads and executes natively
```

### Data Flow

1. User loads a Hugging Face model with `AutoModelForCausalLM.from_pretrained()`
2. User defines a Recipe (Python object or YAML file)
3. `oneshot()` creates a calibration pipeline and attaches modifier hooks to model layers
4. Calibration dataset is passed through in forward-pass batches
5. Observers collect statistics; Modifiers compute and apply quantization/sparsity
6. Modified weights and quantization scales are saved via `model.save_pretrained()`
7. Output directory contains safetensors files + `quantization_config.json` metadata

### Architecture Diagram

`docs/assets/llmcompressor-user-flows.png` in the repository shows the user flow diagram.
See: https://docs.vllm.ai/projects/llm-compressor/en/latest/

---

## 3. Key Components

| Component | Location | Responsibility |
|-----------|----------|---------------|
| **Entrypoints** | `src/llmcompressor/entrypoints/` | Public API — `oneshot()`, `model_free_ptq()` |
| **Core** | `src/llmcompressor/core/` | Session management, modifier lifecycle |
| **Modifiers** | `src/llmcompressor/modifiers/` | Algorithm implementations (one subdirectory per algorithm) |
| **Pipelines** | `src/llmcompressor/pipelines/` | Calibration pipeline — sequential onloading for large models |
| **Recipe** | `src/llmcompressor/recipe/` | YAML ↔ Python object parsing and validation |
| **Observers** | `src/llmcompressor/observers/` | Activation statistics collection (min/max, MSE, percentile) |
| **Transformers** | `src/llmcompressor/transformers/` | HF Transformers integration — patching, tracing, saving |
| **Modeling** | `src/llmcompressor/modeling/` | Custom model definitions for tracing/calibration |
| **Datasets** | `src/llmcompressor/datasets/` | Calibration dataset loading and preprocessing |
| **Args** | `src/llmcompressor/args/` | Configuration dataclasses (model args, dataset args, recipe args) |
| **Metrics** | `src/llmcompressor/metrics/` | Calibration quality metrics |
| **Utils** | `src/llmcompressor/utils/` | Shared utilities |

**Non-obvious design decision**: The `modifiers/` directory is intentionally flat —
each algorithm (GPTQ, AWQ, etc.) is a self-contained `Modifier` class implementing a
common interface. This means adding a new algorithm requires only adding a new
`Modifier` subclass and registering it, without touching the pipeline or core.

---

## 4. Research & Academic References

### Algorithms and Their Papers

| Algorithm | Paper | Venue | Notes |
|-----------|-------|-------|-------|
| GPTQ | "GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers" (Frantar et al.) | ICLR 2023 | Hessian-based weight rounding; the most widely used PTQ method for W4A16 |
| SmoothQuant | "SmoothQuant: Accurate and Efficient Post-Training Quantization for Large Language Models" (Xiao et al.) | ICML 2023 | Migrates quantization difficulty from activations to weights via scaling |
| AWQ | "AWQ: Activation-aware Weight Quantization for LLM Compression and Acceleration" (Lin et al.) | MLSys 2024 | Protects salient weights based on activation magnitude |
| SparseGPT | "SparseGPT: Massive Language Models Can be Pruned in One Shot" (Frantar & Alistarh) | ICML 2023 | One-shot pruning to unstructured or 2:4 structured sparsity |
| AutoRound | "Optimize Weight Rounding via Signed Gradient Descent for the Quantization of LLMs" (Cheng et al.) | EMNLP Findings 2024 | Sign-gradient descent for weight rounding optimization |

> The AutoRound paper is from ACL Anthology (not arXiv), URL:
> https://aclanthology.org/2024.findings-emnlp.662.pdf

### Software Citation

```bibtex
@software{llmcompressor2024,
    title={{LLM Compressor}},
    author={Red Hat AI and vLLM Project},
    year={2024},
    month={8},
    url={https://github.com/vllm-project/llm-compressor},
}
```

### Blog Posts

| Title | Source | URL |
|-------|--------|-----|
| LLM Compressor is here — faster inference with vLLM | Neural Magic Blog | https://neuralmagic.com/blog/llm-compressor-is-here-faster-inference-with-vllm/ |

---

## 5. Documentation & Learning Resources

| Resource | URL | What it covers |
|----------|-----|---------------|
| Official docs site | https://docs.vllm.ai/projects/llm-compressor | Full guides, API reference, getting started |
| Getting started guide | https://docs.vllm.ai/projects/llm-compressor/en/latest/getting-started/ | Installation, first compression run |
| Choosing an algorithm | `docs/getting-started/choosing-algo.md` | Which modifier to use for which goal |
| Choosing a scheme | `docs/getting-started/choosing-scheme.md` | W4A16 vs W8A8 vs FP8 — when to use each |
| Compression schemes guide | `docs/guides/compression_schemes.md` | Deep dive into all supported schemes |
| API reference | https://docs.vllm.ai/projects/llm-compressor/en/latest/api/ | All public classes and functions |
| Examples directory | `examples/` (local, 20 subdirectories) | Runnable end-to-end scripts per use case |
| vLLM Community Slack | https://communityinviter.com/apps/vllm-dev/join-vllm-developers-slack | Live help in #llm-compressor and #sig-quantization |

**Documentation quality**: Comprehensive for getting started and examples; API reference
is auto-generated from docstrings. Architecture/internals documentation is sparse — primarily
derived from source code structure.

---

## 6. Hello World

### Prerequisites

- **Python ≥ 3.10**
- **Linux** (macOS/Windows not officially supported)
- **CUDA GPU** (required for most quantization algorithms; RTN/FP8 can run on CPU with caveats)
- **CUDA-compatible PyTorch** (`torch >= 2.9.0`)
- Sufficient VRAM: 7B models need ~14 GB (bf16) + calibration overhead

### Install

```bash
pip install llmcompressor
```

### Minimal Working Example — FP8 Block Quantization (RTN, data-free)

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
from compressed_tensors.offload import dispatch_model
from llmcompressor import oneshot
from llmcompressor.modifiers.quantization import QuantizationModifier

MODEL_ID = "meta-llama/Llama-3.2-1B-Instruct"  # swap for any HF model

# Load model
model = AutoModelForCausalLM.from_pretrained(MODEL_ID, dtype="auto")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)

# Define recipe: FP8 block quantization (no calibration dataset needed)
recipe = QuantizationModifier(
    targets="Linear",
    scheme="FP8_BLOCK",
    ignore=["lm_head"],
)

# Apply quantization
oneshot(model=model, recipe=recipe)

# Save compressed model
model.save_pretrained("Llama-3.2-1B-FP8-BLOCK")
tokenizer.save_pretrained("Llama-3.2-1B-FP8-BLOCK")
```

### Load and Run in vLLM

```python
from vllm import LLM
llm = LLM("Llama-3.2-1B-FP8-BLOCK")
print(llm.generate("Hello, my name is"))
```

### Expected Output

- A directory `Llama-3.2-1B-FP8-BLOCK/` containing safetensors files and
  `quantization_config.json`
- vLLM loads the model and runs inference with FP8 hardware acceleration

### Common Pitfalls

1. **Transformers version mismatch**: The library pins `transformers>=4.56.1,<=4.57.6`.
   Installing a newer Transformers may cause compatibility errors (open issue as of Feb 2026).
   Pin: `pip install transformers==4.57.6`.
2. **Insufficient VRAM for calibration**: GPTQ, AWQ, and SmoothQuant require calibration,
   which loads the full model in bf16 plus activations. For 70B+ models, use the
   `sequential_onloading` example to process layer by layer.
3. **Linux only**: The library is classified as Linux-only. macOS MPS or Windows CUDA
   may partially work but are not supported and frequently cause issues.

---

## 7. Code Quality Signals

**Testing**: Comprehensive
→ pytest with 5 tiers (smoke, sanity, regression, integration, unit) plus dedicated
  `e2e/` tests against vLLM and `lmeval/` tests for accuracy benchmarking. CI-enforced
  on every PR via GitHub Actions with GPU runners.

**CI/CD**: Production-grade
→ GitHub Actions with quality checks (ruff lint + format), test-check workflows, stale
  issue management, Mergify for merge automation, and ready-label checks for PR gating.
  Separate `test-check-transformers.yaml` validates Transformers version compatibility.

**Maintenance discipline**: Active
→ ruff (lint + format) and mypy (type checking) configured and enforced in CI.
  Pre-commit hooks available. `Makefile` provides `make style`, `make quality`, `make test`
  shortcuts for contributors. setuptools_scm for version management.
