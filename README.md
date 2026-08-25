# NInfer Server for NVIDIA Blackwell (RTX 5090) on SaladCloud

Containerized, ultra-high-performance runtime for serving `.ninfer` models (e.g. `Qwen3.8-27B-Uncensored-NInfer`) on NVIDIA GeForce RTX 5090 (Blackwell `sm_120a`) instances on [SaladCloud](https://salad.com).

---

## ⚡ Performance Benchmarks (RTX 5090 Blackwell)

Tested live on NVIDIA GeForce RTX 5090 32 GB (Blackwell `sm_120a`) on SaladCloud:

| Metric | Measured Value | Notes & Hardware Telemetry |
| :--- | :--- | :--- |
| **Peak Decode / Generation Speed** | **165 – 197+ tok/s** | Single-user MTP speculative decoding (`--max-concurrency 1 --draft-tokens 3 --lm-head-draft`) |
| **Sustained Real-World Agent Decode** | **142 – 188+ tok/s** | Measured across continuous 75-request live harness sessions up to 188K context |
| **Short Query Generation Latency** | **0.34 – 0.38 s (75 tokens)** | Sub-second response on live chat/tool queries with full reasoning traces |
| **Speculative Draft Acceptance** | **2.7 – 3.8 tok/round** | Optimal acceptance rate on Qwen 27B architecture with K=3 draft tokens |
| **Chunked Prefill Throughput** | **6,500 – 8,800+ tok/s** | 4K chunked prefill (`--prefill-chunk 4096`) preventing activation jitter |
| **Long Context Window Capacity** | **235,520 tokens (~230K)** | Tuned ~10% below 256K for guaranteed zero-OOM memory buffer |
| **Max Context Reached in Session** | **188,265 tokens (~188K)** | Flawless multi-turn agent tool execution at 188K depth |
| **Multi-Turn Prefix Cache Hit Rate** | **> 98% Cache Reuse** | Instant sub-second TTFT (~170–450 ms) on consecutive agent turns |
| **150K Needle-in-a-Haystack** | **100% Exact Retrieval** | Instant retrieval of hidden keys buried at deep context depths |
| **VRAM Footprint & Safety Headroom** | **27.1 – 27.7 GB / 32.6 GB** | Clean ~4.9+ GB unfragmented headroom on 32GB GDDR7 |
| **Sustained Power & Thermals** | **574 – 601 W TDP / 59°C** | Sustained full Blackwell tensor core compute without thermal throttling |

---

## 📊 Real-World Agent Workload Telemetry (DeepSeek Harness Session)

The following metrics were captured during a continuous 20-minute, 75-request live agent coding and tool-calling workload scaling from **44K context to 188K tokens**:

### Context Scaling vs. Generation Speed

| Context Window Range | Sample Requests | Avg TTFT (Cached Turns) | Avg Decode Speed | MTP Draft Acceptance | VRAM Allocated |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **40K – 75K Tokens** | Req #11 – #21 | **~200 – 700 ms** | **175.4 tok/s** | **3.15 tok/round** (70%) | 26.9 GB |
| **75K – 120K Tokens** | Req #22 – #35 | **~250 – 900 ms** | **164.2 tok/s** | **3.08 tok/round** (68%) | 27.0 GB |
| **120K – 150K Tokens** | Req #36 – #53 | **~300 – 600 ms** | **161.7 tok/s** | **3.22 tok/round** (72%) | 27.1 GB |
| **150K – 188K Tokens** | Req #54 – #81 | **~340 – 450 ms** | **160.1 tok/s** | **3.31 tok/round** (74%) | 27.1 GB |

### Key Workload Observations:
1. **Near-Flat Decode Curve Across 188K Context:**
   - Generation speed at **44K context** was **~170–180 tok/s**.
   - Even at **188K context (Req #81)**, decode speed stayed at **173.1 tok/s**, demonstrating virtually zero degradation as context grew 4×.
2. **Massive Generation Stress Tests:**
   - Single-request generation sustained up to **7,050 output tokens** in a single turn (Req #76) at **142.7 tok/s** without memory leaks or degradation.
3. **Sub-Second TTFT via Attention Reuse (`reuse=append_frontier`):**
   - At Req #80 (**187,843 tokens context**), TTFT was only **411 ms** because **187,787 tokens** were instantly reused from the prefix cache.
4. **Context Compaction Recovery:**
   - Following a full 146K context compaction reset (Req #82), the next turn (Req #83) instantly locked onto the new prefix cache, achieving a **307 ms TTFT** and generating 1,579 tokens in 11.8s.

---

## 🔬 Long Context Evaluation (150,000 Tokens)

A dedicated benchmark was conducted across a synthetic 150K-token C++ multi-module codebase:

1. **Cold Long-Context Codebase Ingestion:**
   - Evaluated 389 C++ architecture modules (~150,000 BPE tokens).
   - Accurately analyzed `LockFreeRingBuffer` template classes, lock-free ring buffer push/pop algorithms, and atomic memory order acquire/release constraints.
2. **Needle-in-a-Haystack Retrieval:**
   - Retrieved exact cryptographic migration keys (`[SECRET-KEY-ALPHA-5090-NVFP4-7789]`) and clustering ports buried at deep token positions with **100% precision**.
3. **Multi-Turn Follow-up & Prefix Cache Reuse:**
   - Follow-up turns executed on the cached 150K context without re-prefilling from scratch, providing coherent cache-line false sharing optimization suggestions.

---

## 🚀 Architecture Highlights

- **Lean Docker Image**: Runtime & CUDA dependencies only (~2.5 GB).
- **Dynamic Weight Pulling**: Weights (`qwen3_8_27b_uncensored.ninfer`, ~18.2 GB) are pulled directly at container boot from Hugging Face into memory/disk via accelerated `aria2c` multi-threaded downloading.
- **OpenAI Compatible API**: Exposes standard `/v1/chat/completions` and `/v1/models` on port `8000`.
- **SaladCloud Container Gateway Ready**: Built-in `/health` healthchecks and reverse proxy routing with 600s proxy timeout for ultra-long context inference.
- **Single-User MTP Speculative Decoding**: Native Multi-Token Prediction with LM head drafting (`--spec mtp --draft-tokens 3 --lm-head-draft --max-concurrency 1`).
- **Preserved Reasoning Traces**: Full thinking steps (`<think>...</think>`) cleanly surfaced (`--preserve-thinking`).

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
      baseURL: https://salmon-shallot-o7a7ccfn29dhyooj.salad.cloud/v1
      models:
        - id: qwen3.8-27b
          name: qwen3.8-27b
          contextWindow: 235520
          maxTokens: 24576
      apiKeyEnv: SALAD_API_KEY
agent-default-model:
  provider: salad
  model: qwen3.8-27b
```

### Direct Zero-Latency Local Tunnel (Optional)
To connect directly to the RTX 5090 instance bypassing cloud load balancers:
```powershell
ssh -i "$HOME\.ssh\id_ed25519" -p <SSH_PORT> -N -L 8000:localhost:8000 root@<SSH_IP>
```
Then set `baseURL: http://localhost:8000/v1` in your client settings.

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
