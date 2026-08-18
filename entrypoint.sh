#!/usr/bin/env bash
set -e

# ==============================================================================
# NInfer + Web Desktop (Chrome & noVNC) Startup Entrypoint
# ==============================================================================

MODEL_DIR="/models"
HF_REPO_ID="${HF_REPO_ID:-fullmetaljackass/Qwen3.8-27B-Uncensored-NInfer}"
HF_FILENAME="${HF_FILENAME:-Qwen3_8_27b_abliterated.ninfer}"
MODEL_PATH="${MODEL_PATH:-${MODEL_DIR}/${HF_FILENAME}}"
HOST="127.0.0.1"
NINFER_PORT="8080"
MAX_CONTEXT="${MAX_CONTEXT:-262144}"
DISPLAY_NUM=":1"

mkdir -p "${MODEL_DIR}"

echo "================================================================="
echo "🖥️ Initializing Virtual Display & Web GUI (noVNC + Chrome)..."
echo "================================================================="

# 1. Start Xvfb virtual framebuffer
export DISPLAY="${DISPLAY_NUM}"
Xvfb ${DISPLAY_NUM} -screen 0 1920x1080x24 &
sleep 1

# 2. Start Openbox window manager
openbox &

# 3. Start x11vnc server
x11vnc -display ${DISPLAY_NUM} -nopw -forever -shared -bg -rfbport 5900 -quiet &

# 4. Start Websockify bridge for noVNC
websockify --web /usr/share/novnc 6080 127.0.0.1:5900 &

# 5. Launch Google Chrome in desktop environment
google-chrome-stable \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --start-maximized \
    --no-first-run \
    --no-default-browser-check \
    https://www.google.com &

# 6. Start NGINX reverse proxy on port 8000
echo "🌐 Starting NGINX Gateway Router on port 8000..."
nginx

echo "================================================================="
echo "⚡ Starting NInfer Engine on RTX 5090 Blackwell (Internal Port ${NINFER_PORT})"
echo "📂 Target Model:   ${MODEL_PATH}"
echo "🌐 HF Repository:  ${HF_REPO_ID}"
echo "================================================================="

# Check if model exists locally
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

# Verify model file integrity
if [ ! -f "${MODEL_PATH}" ] || [ ! -s "${MODEL_PATH}" ]; then
    echo "❌ Error: Failed to find valid model file at ${MODEL_PATH}"
    exit 1
fi

echo "================================================================="
echo "🔥 Launching ninfer-serve on 127.0.0.1:${NINFER_PORT}..."
echo "================================================================="

exec ninfer-serve \
    "${MODEL_PATH}" \
    --host "${HOST}" \
    --port "${NINFER_PORT}" \
    --max-context "${MAX_CONTEXT}" \
    --kv-capacity auto \
    --kv-dtype int8 \
    --cors \
    "$@"
