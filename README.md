# NInfer Server for NVIDIA Blackwell (RTX 5090) on SaladCloud

Containerized, high-performance runtime for serving `.ninfer` models (e.g. `Qwen3.8-27B-Uncensored-NInfer`) on NVIDIA RTX 5090 (Blackwell `sm_120a`) instances on [SaladCloud](https://salad.com).

## 🚀 Architecture Highlights

- **Lean Docker Image**: Runtime & CUDA dependencies only (~2.5 GB).
- **Dynamic Weight Pulling**: Weights (`qwen3_8_27b_uncensored.ninfer`, ~18.2 GB) are pulled directly at container boot from Hugging Face into memory/disk via accelerated `aria2c` multi-threaded downloading.
- **OpenAI Compatible API**: Exposes standard `/v1/chat/completions` and `/v1/models` on port `8000`.
- **SaladCloud Container Gateway Ready**: Built-in `/health` healthchecks and reverse proxy routing with 600s proxy timeout for ultra-long context inference.

## 📦 Container Registry

The image is automatically built and published via GitHub Actions to:
```
ghcr.io/nika-asatiani/ninfer-blackwell:latest
```

## 🛠️ SaladCloud Deployment Specifications

- **GPU**: NVIDIA GeForce RTX 5090 (32 GB VRAM)
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
| `MAX_CONTEXT` | `262144` | Maximum context length (262K tokens) |
| `KV_DTYPE` | `int8` | KV cache precision (`int8` for bandwidth efficiency) |
| `DRAFT_TOKENS` | `4` | Speculative decoding MTP draft tokens |
| `PREFILL_CHUNK` | `8192` | Chunked prefill token size |
| `HF_TOKEN` | *(optional)* | Access token for private/gated HF repos |

## 🧠 Reasoning & Thinking Control (Preventing Overthinking)

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

## 🧪 Testing the Endpoint

```bash
set NINFER_API_URL=https://your-salad-gateway-url.salad.cloud
set SALAD_API_KEY=your_api_key

python test_endpoint.py
```
