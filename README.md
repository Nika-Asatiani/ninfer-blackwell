# NInfer Server for NVIDIA Blackwell (RTX 5090) on SaladCloud

Containerized, high-performance runtime for serving `.ninfer` models (e.g. `Qwen3.8-27B-Uncensored-NInfer`) on NVIDIA RTX 5090 (Blackwell `sm_120a`) instances on [SaladCloud](https://salad.com).

## 🚀 Architecture Highlights

- **Lean Docker Image**: Runtime & CUDA dependencies only (~2.5 GB).
- **Dynamic Weight Pulling**: Weights (`Qwen3_8_27b_abliterated.ninfer`, ~18.2 GB) are pulled directly at container boot from Hugging Face into memory/disk via accelerated `aria2c` multi-threaded downloading.
- **OpenAI Compatible API**: Exposes standard `/v1/chat/completions` and `/v1/models` on port `8000`.
- **SaladCloud Container Gateway Ready**: Built-in `/health` healthchecks and reverse proxy routing.

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
| `HF_FILENAME` | `Qwen3_8_27b_abliterated.ninfer` | Target `.ninfer` model file |
| `PORT` | `8000` | HTTP API port |
| `HOST` | `0.0.0.0` | Bind host |
| `MAX_CONTEXT` | `32768` | Maximum context length |
| `HF_TOKEN` | *(optional)* | Access token for private/gated HF repos |

## 🧪 Testing the Endpoint

```bash
set NINFER_API_URL=https://your-salad-gateway-url.salad.cloud
set SALAD_API_KEY=your_api_key

python test_endpoint.py
```
