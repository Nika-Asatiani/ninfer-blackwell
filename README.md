# NInfer Server for NVIDIA Blackwell (RTX 5090) on SaladCloud

Containerized, ultra-high-performance runtime for serving `.ninfer` models (e.g. `Qwen3.8-27B-Uncensored-NInfer`) on NVIDIA GeForce RTX 5090 (Blackwell `sm_120a`) instances on [SaladCloud](https://salad.com).

---

## ⚡ Performance Benchmarks (RTX 5090 Blackwell)

| Metric | Measured Value | Notes |
| :--- | :--- | :--- |
| **Decode / Generation Speed** | **140 – 165+ tok/s** | Single-user MTP speculative decoding (`--max-concurrency 1 --draft-tokens 3`) |
| **Speculative Acceptance Rate** | **2.5 – 3.4 tok/step** | High draft hit-rate with LM head drafting (`--lm-head-draft`) |
| **Prefill Speed (Chunked)** | **6,500 – 8,800+ tok/s** | Accelerated via 4k chunked prefill (`--prefill-chunk 4096`) |
| **Host KV RAM Offloading** | **16 GB RAM Pool** | Multi-turn prefix cache hits directly from system RAM (`--kv-host-cache-mib 16384`) |
| **Context Window Capacity** | **235,520 tokens (~230K)** | ~10% headroom below full 256K, zero-OOM INT8 KV Cache |
| **Thinking / Reasoning Mode** | **Preserved** | Output traces preserved cleanly (`--preserve-thinking`) |
| **VRAM Footprint** | **~28.5 GB / 32.0 GB** | Safe 3.5+ GB headroom on RTX 5090 (32GB GDDR7) |

---

## 🚀 Architecture Highlights

- **Lean Docker Image**: Runtime & CUDA dependencies only (~2.5 GB).
- **Dynamic Weight Pulling**: Weights (`qwen3_8_27b_uncensored.ninfer`, ~18.2 GB) are pulled directly at container boot from Hugging Face into memory/disk via accelerated `aria2c` multi-threaded downloading.
- **OpenAI Compatible API**: Exposes standard `/v1/chat/completions` and `/v1/models` on port `8000`.
- **SaladCloud Container Gateway Ready**: Built-in `/health` healthchecks and reverse proxy routing with 600s proxy timeout for ultra-long context inference.
- **Single-User MTP Speculative Decoding**: Native Multi-Token Prediction with LM head drafting (`--spec mtp --draft-tokens 3 --lm-head-draft --max-concurrency 1`).
- **Host KV Cache Offload**: 16 GB host RAM cache (`--kv-host-cache-mib 16384`) for instant session resumes without re-prefilling.

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
| `MAX_CONTEXT` | `235520` | Maximum context length (~230K tokens, ~10% under full 256K) tuned for 32GB VRAM |
| `MAX_CONCURRENCY` | `1` | Max concurrent streams (`1` for maximum single-user decode speed) |
| `KV_DTYPE` | `int8` | KV cache precision (`int8` for bandwidth efficiency) |
| `KV_HOST_CACHE_MIB`| `16384` | Host RAM KV cache pool size in MiB (16 GB for multi-session caching) |
| `DRAFT_TOKENS` | `3` | Speculative decoding MTP draft tokens (sweet spot for Qwen 27B) |
| `PREFILL_CHUNK` | `4096` | 4K chunked prefill token size for accelerated TTFT & low activation jitter |
| `DEFAULT_MAX_TOKENS` | `24576` | Default max generation token budget (24K tokens) |
| `TEMPERATURE` | `0.5` | Sampling temperature for focused reasoning and reduced loop drift |
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
          maxTokens: 24576
      apiKeyEnv: SALAD_API_KEY
agent-default-model:
  provider: salad
  model: qwen3.8-27b
```

---

## 🧠 Reasoning & Thinking Control

Qwen reasoning models generate internal `<think>...</think>` traces dynamically based on problem complexity. To steer the model towards concise reasoning or instant output:

### Option A: Concise Thinking System Prompt (Recommended)
Add this instruction constraint to your chat client or system prompt:
```text
System: "Be concise. Keep internal reasoning brief (under 100 words) and output the solution/tool calls directly."
```

### Option B: Focused Sampling Parameters
Setting a lower temperature (`0.5`) and top-p (`0.95`) prevents the model from wandering into repetitive verification loops during reasoning:
```json
{
  "model": "qwen3.8-27b",
  "messages": [
    {"role": "system", "content": "Be concise. Keep internal thinking brief."},
    {"role": "user", "content": "Write an optimized C++ ring buffer."}
  ],
  "temperature": 0.5,
  "top_p": 0.95
}
```

---

## 🧪 Testing the Endpoint

```bash
set NINFER_API_URL=https://your-salad-gateway-url.salad.cloud
set SALAD_API_KEY=your_api_key

python test_endpoint.py
```
