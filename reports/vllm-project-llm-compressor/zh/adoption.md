# 实际采用情况 — LLM Compressor

> **来源**: https://github.com/vllm-project/llm-compressor | **分析日期**: 2026-02-18

## 下载统计

| 指标 | 数值 | 解读 |
|------|------|------|
| PyPI 周下载量 | **32,427** | 真实用户群持续增长（处于 10K–500K 区间） |
| PyPI 月下载量 | **115,282** | 年化折算约 140 万次 |
| PyPI 日下载量 | 4,750 | 稳定的日常使用，并非 CI/CD 噪声 |
| GitHub Star 数 | 2,756 | 偏低——但下载量与 Star 比值高（积极信号） |
| GitHub Fork 数 | 399 | Fork 率 14.5%——表明大量定制化和二次开发活动 |

**背景对比**：3.2 万的周下载量对于专业 ML 压缩库而言意义重大。作为参考，`peft`（参数高效微调）在周下载量超过 50 万之前，也经历了类似规模的增长阶段。LLM Compressor 的增长轨迹与成为 vLLM 生态 LLM 量化标准工具的路径高度吻合。

## 具名采用者

目前尚无正式的 `ADOPTERS.md` 或 `USERS.md` 文件。但采用信号可从其他渠道获取：

- **模型仓库**：`compressed-tensors` 格式已被 Hugging Face Hub 上数百个预量化模型检查点使用（由 Neural Magic / Red Hat AI 发布），这是生产使用的间接证明。
- **README 提及**：Kimi K2（Moonshot AI）和 Mistral Large 3（675B）在 README 中被明确引用为通过 LLM Compressor 新 `model_free_ptq` 路径量化的模型——这些是前沿规模模型（千亿参数级别）。
- **广泛的模型支持**：已有适用于 Llama、Qwen、Gemma、Mistral、DeepSeek、Phi、LLaVA、InternVL、Whisper、MedGemma 等模型的示例，这种广度表明社区在各模型系列中的采用已相当普遍。

## 生态系统集成

| 集成对象 | 状态 | 重要性 |
|----------|------|--------|
| **vLLM**（推理引擎） | 原生集成——compressed-tensors 格式是 vLLM 默认的量化格式 | 关键：压缩后的模型可直接在 vLLM 中加载，无需转换 |
| **Hugging Face Transformers** | 完全兼容——扩展 `AutoModelForCausalLM` | 任何 HF 兼容模型无需修改代码即可压缩 |
| **Hugging Face Hub** | 通过 `save_pretrained` / `from_pretrained` 推送/拉取 | 量化模型可无缝共享 |
| **accelerate** | 集成以支持大模型分片卸载 | 支持在多 GPU 环境下量化 70B+ 模型 |
| **compressed-tensors** | 强依赖（同属 vLLM Project 组织） | 格式规范与序列化层 |

## 社区渠道

| 渠道 | 详情 |
|------|------|
| vLLM 社区 Slack | 活跃的 `#llm-compressor` 和 `#sig-quantization` 频道 |
| GitHub Issues | 119 个开放 Issue；近期 Issue 数小时内即关闭 |
| GitHub Discussions | Issues 跟踪器同时用于社区问答 |

## 云端与平台支持

目前尚无原生托管服务（这是一个库，而非平台）。但是：

- LLM Compressor 生成的模型可通过 vLLM 部署在任何云上（AWS、GCP、Azure 及所有支持 vLLM 的主流云 ML 平台）
- 随着 Red Hat AI 商业产品的深化，Red Hat OpenShift AI 预计会加强集成力度

## 采用情况综合评估

| 维度 | 信号 |
|------|------|
| 下载量 | 增长中——在专业细分领域 3.2 万/周表现健康 |
| 生态契合度 | 紧密——在 vLLM 中是一等公民，而 vLLM 是增长最快的 LLM 推理引擎 |
| 具名企业用户 | 隐性（前沿模型量化实践）|
| 社区活跃度 | Slack 活跃，Issue 响应迅速 |
| 采用阶段 | **增长中**——已超越实验阶段，但尚未成为主流 |

**结论**：LLM Compressor 已跨越"玩具/实验"门槛。其与 vLLM 的深度集成意味着：任何使用 vLLM 进行规模化 LLM 部署的团队都是天然的目标用户。随着 vLLM 采用量的增长，两者的下载量将协同上升——两者的命运紧密相连。
