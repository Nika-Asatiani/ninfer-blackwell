# NInfer Server for NVIDIA Blackwell (RTX 5090) on SaladCloud

Containerized, ultra-high-performance runtime for serving `.ninfer` models (e.g. `Qwen3.8-27B-Uncensored-NInfer`) on NVIDIA GeForce RTX 5090 (Blackwell `sm_120a`) instances on [SaladCloud](https://salad.com).

---

## ⚡ Performance Benchmarks (RTX 5090 Blackwell)

| Metric | Measured Value | Notes |
| :--- | :--- | :--- |
| **Decode / Generation Speed** | **130 – 165+ tok/s** | Multi-Token Prediction (MTP) Speculative Decoding on 27B model |
| **Speculative Acceptance Rate** | **3.40 – 3.80 tok/round** | ~60% – 70% draft acceptance rate (`--draft-tokens 4`) |
| **Prefill Speed (Chunked)** | **2,400 – 2,700 tok/s** | Accelerated via 16k chunked prefill (`--prefill-chunk 16384`) |
| **Context Window Capacity** | **194,560 tokens (~190K)** | Zero-OOM stable high context with INT8 KV Cache |
| **KV Prefix Cache Reuse** | **Sub-second TTFT** | Instant attention prefix reuse (`reuse=append_frontier`) |
| **VRAM Footprint** | **28.08 GB / 32.00 GB** | Clean 4.5+ GB headroom on RTX 5090 (32GB GDDR7) |

---

## 🚀 Architecture Highlights

- **Lean Docker Image**: Runtime & CUDA dependencies only (~2.5 GB).
- **Dynamic Weight Pulling**: Weights (`qwen3_8_27b_uncensored.ninfer`, ~18.2 GB) are pulled directly at container boot from Hugging Face into memory/disk via accelerated `aria2c` multi-threaded downloading.
- **OpenAI Compatible API**: Exposes standard `/v1/chat/completions` and `/v1/models` on port `8000`.
- **SaladCloud Container Gateway Ready**: Built-in `/health` healthchecks and reverse proxy routing with 600s proxy timeout for ultra-long context inference.
- **MTP Speculative Decoding**: Native Multi-Token Prediction with LM head drafting (`--spec mtp --draft-tokens 4 --lm-head-draft`).

---

## 📦 Container Registry

The image is automatically built and published via GitHub Actions to:
```bash
ghcr.io/nika-asatiani/ninfer-blackwell:latest
```

---

## 🛠️ SaladCloud Deployment Specifications

- **GPU**: NVIDIA GeForce RTX 5090 (32 GB VRAM, Blackwell Architecture)
- **RAM**: 30 GB
- **vCPUs**: 6–8 vCPUs
- **Storage**: 50 GB
- **Container Gateway**: Port `8000`, Protocol `http`, Health check `/v1/models` or `/health`.

### Environment Variables

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `HF_REPO_ID` | `fullmetaljackass/Qwen3.8-27B-Uncensored-NInfer` | Hugging Face repository ID |
| `HF_FILENAME` | `qwen3_8_27b_uncensored.ninfer` | Target `.ninfer` model file |
| `PORT` | `8000` | HTTP API port |
| `HOST` | `127.0.0.1` | Internal bind host |
| `MAX_CONTEXT` | `194560` | Maximum context length (~190K tokens) tuned for 32GB VRAM |
| `KV_DTYPE` | `int8` | KV cache precision (`int8` for bandwidth efficiency) |
| `DRAFT_TOKENS` | `4` | Speculative decoding MTP draft tokens |
| `PREFILL_CHUNK` | `16384` | 16K chunked prefill token size for accelerated TTFT |
| `HF_TOKEN` | *(optional)* | Access token for private/gated HF repos |

---

## 💻 Client Integration (DeepSeek Harness / OpenAI Compatible)

To configure in **DeepSeek Harness** (`.dsh/settings.yaml`):

```yaml
llm-pi-ai:
  providers:
    salad:
      api: openai-completions
      baseURL: https://your-salad-gateway-url.salad.cloud/v1
      models:
        - id: qwen3.8-27b
          name: qwen3.8-27b
          contextWindow: 194560
          maxTokens: 16384
      apiKeyEnv: SALAD_API_KEY
agent-default-model:
  provider: salad
  model: qwen3.8-27b
```

---

## 🧠 Reasoning & Thinking Control

By default, Qwen reasoning models run at maximum reasoning depth (`xhigh`), generating long internal `<think>...</think>` traces. To enforce **medium concise thinking** or instant direct answers, use the following patterns:

### Option A: Concise Thinking System Prompt (Recommended)
Add this system prompt to your chat client or requests:
```text
System: "Be concise. Keep internal thinking and reasoning brief (medium depth) and jump directly into the solution without repetitive verification loops."
```

### Option B: API Parameter
```json
{
  "model": "qwen3.8-27b",
  "messages": [
    {"role": "system", "content": "Be concise. Keep internal thinking brief."},
    {"role": "user", "content": "Write an optimized C++ ring buffer."}
  ],
  "reasoning_effort": "medium",
  "temperature": 0.6
}
```

### Option C: Disable Thinking (Instant Output)
```json
{
  "model": "qwen3.8-27b",
  "messages": [{"role": "user", "content": "Explain quantum decoherence."}],
  "chat_template_kwargs": {
    "enable_thinking": false
  }
}
```

---

## 🧪 Testing the Endpoint

```bash
set NINFER_API_URL=https://your-salad-gateway-url.salad.cloud
set SALAD_API_KEY=your_api_key

python test_endpoint.py
```
