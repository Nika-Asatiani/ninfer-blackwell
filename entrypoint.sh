#!/usr/bin/env bash
set -e

# ==============================================================================
# NInfer SaladCloud Dynamic Boot Entrypoint
# ==============================================================================

MODEL_DIR="/models"
HF_REPO_ID="${HF_REPO_ID:-fullmetaljackass/Qwen3.8-27B-Uncensored-NInfer}"
HF_FILENAME="${HF_FILENAME:-Qwen3_8_27b_abliterated.ninfer}"
MODEL_PATH="${MODEL_PATH:-${MODEL_DIR}/${HF_FILENAME}}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
MAX_CONTEXT="${MAX_CONTEXT:-262144}"

mkdir -p "${MODEL_DIR}"

echo "================================================================="
echo "⚡ Starting NInfer Runtime on RTX 5090 Blackwell Architecture"
echo "📂 Target Model File: ${MODEL_PATH}"
echo "🌐 HF Repository:     ${HF_REPO_ID}"
echo "🔌 Serving Port:      ${PORT}"
echo "================================================================="

# Check if model already exists locally (mounted volume or persistent cache)
if [ -f "${MODEL_PATH}" ] && [ -s "${MODEL_PATH}" ]; then
    echo "✅ Model weights found at ${MODEL_PATH} ($(du -h "${MODEL_PATH}" | cut -f1))"
else
    echo "⬇️ Model weights not found in ${MODEL_DIR}. Downloading from Hugging Face..."
    
    HF_AUTH_HEADER=""
    HF_TOKEN_PARAM=""
    if [ -n "${HF_TOKEN}" ]; then
        echo "🔑 Using Hugging Face Access Token"
        HF_AUTH_HEADER="--header=Authorization: Bearer ${HF_TOKEN}"
        HF_TOKEN_PARAM="--token ${HF_TOKEN}"
    fi

    # Download using huggingface_hub cli or aria2c fast multi-threaded chunking
    HF_URL="https://huggingface.co/${HF_REPO_ID}/resolve/main/${HF_FILENAME}"
    
    echo "🚀 Downloading ${HF_FILENAME} from ${HF_REPO_ID} via aria2c accelerated connection..."
    if command -v aria2c &> /dev/null; then
        aria2c \
            --dir="${MODEL_DIR}" \
            --out="${HF_FILENAME}" \
            --max-connection-per-server=16 \
            --split=16 \
            --min-split-size=10M \
            --continue=true \
            --auto-file-renaming=false \
            ${HF_AUTH_HEADER} \
            "${HF_URL}" || {
                echo "⚠️ aria2c failed, falling back to huggingface-cli..."
                hf download "${HF_REPO_ID}" "${HF_FILENAME}" --local-dir "${MODEL_DIR}" ${HF_TOKEN_PARAM}
            }
    else
        echo "🚀 Downloading with huggingface-cli..."
        hf download "${HF_REPO_ID}" "${HF_FILENAME}" --local-dir "${MODEL_DIR}" ${HF_TOKEN_PARAM}
    fi

    echo "✅ Download complete! File size: $(du -h "${MODEL_PATH}" | cut -f1)"
fi

# Verify model file integrity / existence
if [ ! -f "${MODEL_PATH}" ] || [ ! -s "${MODEL_PATH}" ]; then
    echo "❌ Error: Failed to find or download valid model file at ${MODEL_PATH}"
    exit 1
fi

echo "================================================================="
echo "🔥 Launching ninfer-serve engine..."
echo "================================================================="

exec ninfer-serve \
    --model "${MODEL_PATH}" \
    --host "${HOST}" \
    --port "${PORT}" \
    --max-context "${MAX_CONTEXT}" \
    "$@"
