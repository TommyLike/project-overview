# 竞争格局 — LLM Compressor

> **来源**: https://github.com/vllm-project/llm-compressor | **分析日期**: 2026-02-18

## 市场定位：**挑战者 → 主导者（vLLM 生态内）**

LLM Compressor 正迅速成为在 vLLM 部署场景下量化工作的事实标准。在 vLLM 生态之外，它是 AutoGPTQ 和 BitsAndBytes 的强力竞争者，但尚未成为通用领域的主导者。

## 对比一览

| 维度 | **LLM Compressor** | AutoGPTQ | BitsAndBytes | llama.cpp 量化 | Intel neural-compressor |
|------|-------------------|----------|-------------|--------------|------------------------|
| Star 数（约） | 2.8K | 5.0K | 3.5K | 80K（llama.cpp） | 2.8K |
| 周下载量 | 3.2 万 | 约 8K（下滑中） | 约 50 万 | 不适用（C++） | 约 2 万 |
| 协议 | Apache-2.0 | MIT | MIT | MIT | Apache-2.0 |
| 背后支持 | Red Hat AI / vLLM | 社区 | Hugging Face（Tim Dettmers） | Georgi Gerganov | Intel |
| 主要语言 | Python | Python | Python/CUDA | C++ | Python |
| 最新版本 | v0.9.0.2（2026 年 2 月） | v0.9.4（2024） | v0.45.x（2025） | 持续更新 | v3.x（2025） |
| vLLM 集成 | **原生/一等公民** | 需转换 | 部分支持 | 不支持 | 不支持 |
| GPTQ 支持 | 是 | 是（主要焦点） | 否 | 是（通过 GGUF） | 是 |
| AWQ 支持 | 是 | 部分 | 否 | 是（通过 GGUF） | 否 |
| SmoothQuant | 是 | 否 | 否 | 否 | 是 |
| FP8 支持 | 是（W8A8、块量化） | 否 | 有限 | 否 | 是 |
| NVFP4 / MXFP4 | 是（实验性） | 否 | 否 | 否 | 否 |
| KV 缓存量化 | 是 | 否 | 否 | 否 | 否 |
| 2:4 稀疏性 | 是 | 否 | 否 | 否 | 部分 |
| AutoRound | 是（已集成） | 否 | 否 | 否 | 部分 |
| 多模态支持 | 是（视觉、音频） | 部分 | 否 | 部分 | 否 |
| 大模型支持 | 是（通过 accelerate） | 是 | 是 | 是（GGUF 分片） | 部分 |
| 核心优势 | vLLM 集成、算法广度 | 成熟的 GPTQ 实现 | 安装最简单 | CPU/边缘/移动端 | 企业级 Intel 技术栈 |
| 核心劣势 | 输出格式以 vLLM 为中心 | 维护趋于停滞 | 算法较少 | 非 Python 原生 | API 复杂 |

## 何时选择 LLM Compressor

**以下情况推荐选用 LLM Compressor：**

1. **推理运行时是 vLLM** — 输出的 `compressed-tensors` 格式是 vLLM 的原生格式，部署零摩擦，无需转换。
2. **需要 FP8、W8A8 或现代量化方案** — LLM Compressor 覆盖当前主流硬件目标的完整量化方案（NVIDIA Hopper FP8、NVFP4、块量化）。
3. **需要在一个工作流中组合多种压缩算法** — 可在单个 recipe 文件中组合 GPTQ、SmoothQuant 和 2:4 稀疏性。
4. **使用前沿规模的 MoE 模型**（DeepSeek、Qwen MoE、Kimi K2）— 内置 MoE 专项支持，附带专属示例。
5. **需要多模态压缩** — 视觉语言和音频语言模型支持是内建能力，而非后期拼凑。
6. **技术栈中包含 Red Hat OpenShift AI** — 商业方向高度一致，更深度的官方支持即将到来。

**以下情况不推荐选用 LLM Compressor：**

1. **部署目标是 llama.cpp / GGUF** — LLM Compressor 输出 safetensors，而非 GGUF，需使用 llama.cpp 自带的量化工具或 GGUF 转换脚本。
2. **需要纯 CPU 推理** — 该库以 GPU 量化为目标，CPU 推理优化不在其范围内。
3. **只需最简单的 4-bit 加载，无需校准** — BitsAndBytes 的 `load_in_4bit=True` 一行代码原型验证更快。LLM Compressor 的大多数算法需要校准流程。
4. **模型不是 Transformer 架构**（如 CNN、RNN 用于非 LLM 任务）— 该库明确以 Transformers 为中心。

## 竞争趋势

- **AutoGPTQ 走向衰退**：自 2024 年中期以来维护明显放缓，其核心贡献者中已有多人转而贡献 LLM Compressor。
- **BitsAndBytes 在微调领域依然主导**（QLoRA 工作流），但在生产推理量化领域并无竞争。
- **llama.cpp 继续主导边缘/CPU/移动端** — 属于完全不同的市场细分。
- **LLM Compressor 正在整合 vLLM 生态的量化工作流**，吸收 AutoRound 并持续扩大算法覆盖范围。
