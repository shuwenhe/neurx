# Stage 1: Builder
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    NEURX_BUILD_DIR=/build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    wget \
    curl \
    ca-certificates \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app/neurx

WORKDIR /app/neurx

RUN mkdir -p ${NEURX_BUILD_DIR}

RUN echo "✓ 使用预编译的 NeurX artifacts"

# Stage 2: Runtime
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    NEURX_HOME=/app/neurx \
    NEURX_MODEL_DIR=/models/default \
    NEURX_INFER_DEVICE=cpu \
    NEURX_S_PORT=8000 \
    NEURX_S_HOST=0.0.0.0 \
    NEURX_CPU_THREADS=4 \
    NEURX_CHAT_MAX_NEW_TOKENS=512 \
    PATH=/app/neurx/artifacts/build:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    lsof \
    vim \
    python3 \
    python3-pip \
    git \
    && pip3 install --no-cache-dir huggingface-hub \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/neurx

COPY --from=builder /app/neurx/artifacts/build /app/neurx/artifacts/build
COPY --from=builder /app/neurx/inference /app/neurx/inference
COPY --from=builder /app/neurx/api /app/neurx/api
COPY --from=builder /app/neurx/tools /app/neurx/tools

RUN mkdir -p /models/default /logs /data

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000 8001 9090

VOLUME ["/models", "/logs", "/data"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${NEURX_S_PORT}/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]
