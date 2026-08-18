# ==============================================================================
# Stage 1: Build NInfer Engine for NVIDIA Blackwell (RTX 5090 / sm_120a)
# ==============================================================================
FROM nvidia/cuda:13.1.2-devel-ubuntu24.04 AS build

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --yes --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    ca-certificates \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libcurl4-openssl-dev \
    libswscale-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --recursive https://github.com/Neroued/ninfer.git /src/ninfer

WORKDIR /src/ninfer
RUN cmake -S . -B /build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DNINFER_BUILD_APPS=ON \
    -DBUILD_TESTING=OFF \
    -DNINFER_BUILD_BENCHMARKS=OFF \
    -DCMAKE_CUDA_ARCHITECTURES="120a"

RUN cmake --build /build --parallel $(nproc) --target ninfer ninfer-serve

# ==============================================================================
# Stage 2: Runtime with noVNC Desktop + Google Chrome + Nginx + NInfer
# ==============================================================================
FROM nvidia/cuda:13.1.2-runtime-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1 \
    DISPLAY=:1

# Install runtime libraries, X11, openbox, noVNC, websockify, NGINX, and download utilities
RUN apt-get update && apt-get install --yes --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    aria2 \
    python3 \
    python3-pip \
    libavcodec60 \
    libavformat60 \
    libavutil58 \
    libcurl4t64 \
    libswscale7 \
    xvfb \
    x11vnc \
    openbox \
    novnc \
    websockify \
    nginx \
    fonts-liberation \
    xdg-utils \
    && pip3 install --no-cache-dir --break-system-packages "huggingface_hub[cli]" \
    && rm -rf /var/lib/apt/lists/*

# Install official Google Chrome Stable
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y --no-install-recommends google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# Link noVNC static files
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || true

# Copy compiled binaries from build stage
COPY --from=build /build/apps/ninfer /usr/local/bin/ninfer
COPY --from=build /build/apps/ninfer-serve /usr/local/bin/ninfer-serve

WORKDIR /app

# Copy NGINX configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=5s --start-period=600s --retries=10 \
    CMD curl -f http://localhost:8000/health || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
