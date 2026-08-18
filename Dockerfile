# ==============================================================================
# Stage 1: Build NInfer Engine for NVIDIA Blackwell (RTX 5090 / sm_120a)
# ==============================================================================
FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install compilation tools and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    git \
    ca-certificates \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone the official NInfer engine repository
WORKDIR /src
RUN git clone --depth 1 https://github.com/Neroued/ninfer.git /src/ninfer

WORKDIR /src/ninfer

# Configure with CMake targeting Blackwell sm_120a / RTX 5090
RUN cmake -S . -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="120a"

# Compile ninfer-serve and core binaries
RUN cmake --build build --parallel $(nproc)

# ==============================================================================
# Stage 2: Minimal Production Runtime
# ==============================================================================
FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# Install runtime utilities, accelerated downloader (aria2), and Python for Hugging Face CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    aria2 \
    python3 \
    python3-pip \
    && pip3 install --no-cache-dir "huggingface_hub[cli]" \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled ninfer binaries from builder stage
COPY --from=builder /src/ninfer/build/ninfer-serve /usr/local/bin/ninfer-serve
# Copy any additional built tools if present
COPY --from=builder /src/ninfer/build/ninfer* /usr/local/bin/

WORKDIR /app

# Copy startup script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose HTTP API port for SaladCloud Container Gateway
EXPOSE 8000

# Set healthcheck for SaladCloud monitoring
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=5 \
    CMD curl -f http://localhost:8000/health || curl -f http://localhost:8000/v1/models || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
