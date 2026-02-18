# GPTQ: Accurate Post-Training Quantization for Generative Pre-trained Transformers

**Paper**: arxiv 2210.17323
**Authors**: Elias Frantar, Saleh Ashkboos, Torsten Hoefler, Dan Alistarh (IST Austria / ETH Zurich)
**Venue**: ICLR 2023
**Code**: https://github.com/IST-DASLab/gptq

---

## What it is

GPTQ is a **one-shot post-training weight quantization** method for large language models. It
compresses model weights to 3–4 bits per parameter in a few GPU hours, with negligible accuracy
loss, by exploiting approximate second-order (Hessian) information — without any retraining.

Prior art either:
- Used simple round-to-nearest (RTN), which fails badly below 8 bits, or
- Used accurate but slow second-order methods (OBQ) that couldn't scale beyond ~100M parameters.

GPTQ bridges this gap: it's as accurate as OBQ but **3 orders of magnitude faster**, enabling
quantization of 175B-parameter models on a single A100 GPU in ~4 hours.

---

## Core Algorithm (3 key ideas)

### 1. Arbitrary-order insight
OBQ quantizes weights in greedy order (lowest-error-first per row). GPTQ shows that **all rows
can be quantized in the same column order** with minimal accuracy loss on large models — because
the Hessian `H_F` depends only on layer inputs X (same for all rows), not on weights. This
reduces the Hessian inverse update from O(d_row · d_col³) to O(max{d_row · d_col², d_col³}),
saving several orders of magnitude for large layers.

### 2. Lazy batch updates (block size B=128)
Updating H⁻¹ column-by-column has a low compute-to-memory ratio and bottlenecks GPU bandwidth.
GPTQ processes **128 columns at a time**:
- Inside the block: quantize column-by-column, tracking errors in a B×B sub-block of H⁻¹
- After the block: apply a single global update to all remaining weights using the accumulated errors

This achieves an order-of-magnitude practical speedup with no change in theoretical complexity.

### 3. Cholesky reformulation
Repeated application of the Schur complement update accumulates floating point errors, causing
H⁻¹ to become indefinite on large models (guaranteed to happen for models >~few B params). Fix:
precompute the **Cholesky decomposition** of H⁻¹ upfront, reading off rows as needed. Combined
with mild dampening (λ = 1% of mean diagonal), this is numerically stable at any scale.

### Full algorithm (pseudocode)
```
Q = 0 (quantized output)
E = 0 (block errors)
H⁻¹ = Cholesky(H⁻¹)ᵀ  # precompute once

for i in 0, B, 2B, ...:
    for j in i, ..., i+B-1:
        Q[:,j] = quant(W[:,j])                           # quantize column
        E[:,j-i] = (W[:,j] - Q[:,j]) / [H⁻¹]_{jj}      # error
        W[:,j:i+B] -= E[:,j-i] · H⁻¹_{j, j:i+B}        # update block
    W[:,i+B:] -= E · H⁻¹_{i:i+B, i+B:}                 # global update
```

---

## Setup & Calibration

- **Calibration data**: 128 random 2048-token segments from C4 (generic web crawl text)
- **Quantization grid**: uniform per-row asymmetric min-max (same as LLM.int8())
- **Memory trick**: load one Transformer block at a time; pass inputs through the already-
  quantized prefix to get the correct layer inputs for subsequent blocks
- **Hardware**: all experiments run on a single NVIDIA A100 80GB

---

## Results

### Perplexity (WikiText2) — lower is better

| Model | FP16 | RTN 4-bit | GPTQ 4-bit | RTN 3-bit | GPTQ 3-bit |
|-------|------|-----------|-----------|-----------|-----------|
| OPT-175B | 8.34 | 10.54 | **8.37** | 7300 | **8.68** |
| BLOOM-176B | 8.11 | 8.37 | **8.21** | 571 | **8.64** |

At 3-bit, RTN completely collapses while GPTQ stays near baseline. At 4-bit, GPTQ essentially
matches FP16 on large models.

### Runtime (single A100)

| Model | Parameters | GPTQ time |
|-------|-----------|-----------|
| BLOOM-1.7B | 1.7B | 2.9 min |
| OPT-13B | 13B | 20.9 min |
| OPT-66B | 66B | 1.6 hours |
| OPT-175B | 175B | 4.2 hours |

### Practical speedups (batch size 1, generative inference)

| GPU | FP16 | 3-bit GPTQ | Speedup | GPU reduction |
|-----|------|-----------|---------|---------------|
| A100 80GB | 230ms/tok | 71ms/tok | **3.25×** | 5 → 1 GPU |
| A6000 48GB | 589ms/tok | 130ms/tok | **4.5×** | 8 → 2 GPUs |

Speedup comes from **memory bandwidth** reduction: quantized kernels dequantize weights on-the-fly
during matrix-vector products (generation is memory-bound, not compute-bound).

### Grouping and extreme quantization

- **Group quantization** (g=128, g=1024): adds 0.15–0.02 extra bits but recovers ~0.1–0.2 PPL
- **2-bit + g128**: <1.5 PPL increase on OPT-175B (~2.2 bits average with scale/zero overhead)
- **Ternary (-1,0,+1) + g8**: 9.20 PPL on OPT-175B (<1 point drop from FP16)

---

## Limitations

1. **No compute speedup for matrix-matrix products** — only memory bandwidth speedup for
   matrix-vector (batch size 1 generation). Large-batch inference is compute-bound; GPTQ
   reduces GPU count but not FLOP count.
2. **No activation quantization** — weights only. Activations remain FP16.
3. **Accuracy on small models is slightly below best PTQ methods** (AdaRound, BRECQ) at 3-bit,
   though it matches them at 4-bit and is much faster.

---

## Connections to the llm-compressor project

Since this codebase (vllm-project/llm-compressor) directly implements GPTQ as `GPTQModifier`
in `src/llmcompressor/modifiers/obcq/`, this paper is the theoretical foundation for one of
the library's core algorithms. Specific connections:

### What llm-compressor adds on top of the paper

1. **HuggingFace integration**: the paper's PyTorch prototype becomes a full ecosystem library
   with `AutoModelForCausalLM` loading, recipe YAML files, and `safetensors` output.

2. **Multiple algorithms**: GPTQ is one of six algorithms. Others (AWQ, SmoothQuant, AutoRound,
   SparseGPT) each address different accuracy/speed tradeoffs — see `docs/guides/compression_schemes.md`.

3. **Beyond W4A16**: the paper focuses on weight-only quantization. llm-compressor extends this
   to W8A8 FP8/INT8 (with activation quantization), KV cache quantization, and sparsity.

4. **Large model support**: the paper's block-loading trick is productionized via HuggingFace
   `accelerate`'s sequential CPU offloading pipeline.

### Key hyperparameters to know when using GPTQModifier

| Parameter | Paper value | Notes |
|-----------|-------------|-------|
| `num_calibration_samples` | 128 | More (512+) helps small models |
| `block_size` (B) | 128 columns | Hard-coded in paper; tune if OOM |
| Calibration data | C4 (generic text) | Match domain if possible |
| `dampening_frac` | 0.01 (1% of diag mean) | Increase for unstable layers |
| `group_size` | None (per-row) | Set to 128 for better 3-bit accuracy |

### Practical recipe for W4A16 GPTQ with llm-compressor

```python
from llmcompressor.modifiers.obcq import GPTQModifier

recipe = GPTQModifier(
    targets="Linear",
    scheme="W4A16",
    num_calibration_samples=512,
    group_size=128,       # adds ~0.15 bits but helps 3-4bit accuracy significantly
    ignore=["lm_head"],
)
oneshot(model=model, recipe=recipe, dataset="open_platypus")
```

---

## Key takeaways

- GPTQ makes 4-bit quantization **effectively lossless** for models ≥7B parameters
- At 3-bit, GPTQ is viable; RTN is not — second-order error compensation matters
- Larger models are **easier to quantize** (a counterintuitive but consistent finding)
- Speedup comes purely from memory bandwidth savings — critical insight for deployment
- 128 calibration samples of generic text is sufficient; domain-specific data gives marginal gains
- Grouping (g=128) is a free lunch at 3-bit: adds tiny bit overhead, recovers substantial accuracy
