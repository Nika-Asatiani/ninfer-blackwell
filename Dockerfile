# ==============================================================================
# Stage 1: Build NInfer Engine for NVIDIA Blackwell (RTX 5090 / sm_120a)
# ==============================================================================
FROM nvidia/cuda:13.1.2-devel-ubuntu24.04 AS build

ARG DEBIAN_FRONTEND=noninteractive

# Install compilation tools and required multimedia/networking libraries
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

# Clone the upstream NInfer repo with submodules
WORKDIR /src
RUN git clone --depth 1 --recursive https://github.com/Neroued/ninfer.git /src/ninfer

WORKDIR /src/ninfer

# Configure with CMake for Blackwell RTX 5090 / sm_120a
RUN cmake -S . -B /build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DNINFER_BUILD_APPS=ON \
    -DBUILD_TESTING=OFF \
    -DNINFER_BUILD_BENCHMARKS=OFF \
    -DCMAKE_CUDA_ARCHITECTURES="120a"

# Compile ninfer and ninfer-serve targets
RUN cmake --build /build --parallel $(nproc) --target ninfer ninfer-serve

# ==============================================================================
# Stage 2: Minimal Production Runtime
# ==============================================================================
FROM nvidia/cuda:13.1.2-runtime-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install runtime libraries and accelerated download tooling
RUN apt-get update && apt-get install --yes --no-install-recommends \
    ca-certificates \
    curl \
    aria2 \
    python3 \
    python3-pip \
    libavcodec60 \
    libavformat60 \
    libavutil58 \
    libcurl4t64 \
    libswscale7 \
    && pip3 install --no-cache-dir --break-system-packages "huggingface_hub[cli]" \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled binaries from build stage
COPY --from=build /build/apps/ninfer /usr/local/bin/ninfer
COPY --from=build /build/apps/ninfer-serve /usr/local/bin/ninfer-serve

WORKDIR /app

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose HTTP API port for SaladCloud Container Gateway
EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=5 \
    CMD curl -f http://localhost:8000/health || curl -f http://localhost:8000/v1/models || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
