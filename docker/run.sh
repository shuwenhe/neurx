#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}NeurX Docker 容器启动${NC}"
echo -e "${GREEN}========================================${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

CONTAINER_NAME=${CONTAINER_NAME:-"neurx-inference"}
IMAGE_NAME=${IMAGE_NAME:-"neurx-inference:latest"}
BACKEND=${NEURX_BACKEND:-"cpu"}
BATCH_SIZE=${NEURX_BATCH_SIZE:-"4"}
NUM_WORKERS=${NEURX_NUM_WORKERS:-"4"}
KV_BLOCKS=${NEURX_KV_BLOCKS:-"64"}
API_PORT=${NEURX_API_PORT:-"8080"}
GRPC_PORT=${NEURX_GRPC_PORT:-"8081"}
METRICS_PORT=${NEURX_METRICS_PORT:-"9090"}

echo ""
echo -e "${BLUE}配置信息:${NC}"
echo -e "  容器名称: $CONTAINER_NAME"
echo -e "  镜像名称: $IMAGE_NAME"
echo -e "  推理后端: $BACKEND"
echo -e "  批处理大小: $BATCH_SIZE"
echo -e "  工作者数: $NUM_WORKERS"
echo -e "  KV缓存块数: $KV_BLOCKS"
echo -e "  API端口: $API_PORT"
echo -e "  gRPC端口: $GRPC_PORT"
echo -e "  指标端口: $METRICS_PORT"
echo ""

if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo -e "${RED}❌ 镜像 $IMAGE_NAME 不存在${NC}"
    echo -e "${YELLOW}请先运行: bash $SCRIPT_DIR/build.sh${NC}"
    exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}⚠️  容器 $CONTAINER_NAME 已存在${NC}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}容器已运行。是否重启? (y/n)${NC}"
        read -r response
        if [[ "$response" == "y" || "$response" == "Y" ]]; then
            echo -e "${YELLOW}停止容器...${NC}"
            docker stop "$CONTAINER_NAME"
            docker rm "$CONTAINER_NAME"
        else
            echo -e "${YELLOW}使用现有容器${NC}"
            docker logs -f "$CONTAINER_NAME"
            exit 0
        fi
    else
        echo -e "${YELLOW}容器已停止。是否删除并重新创建? (y/n)${NC}"
        read -r response
        if [[ "$response" == "y" || "$response" == "Y" ]]; then
            docker rm "$CONTAINER_NAME"
        else
            echo -e "${YELLOW}启动现有容器...${NC}"
            docker start "$CONTAINER_NAME"
            sleep 2
            docker logs -f "$CONTAINER_NAME"
            exit 0
        fi
    fi
fi

if command -v nvidia-smi &> /dev/null && [ "$BACKEND" == "cuda" ]; then
    GPU_OPTS="--gpus all"
    echo -e "${GREEN}✓ 检测到 NVIDIA GPU，启用 CUDA 支持${NC}"
else
    GPU_OPTS=""
    if [ "$BACKEND" == "cuda" ]; then
        echo -e "${YELLOW}⚠️  未找到 NVIDIA GPU，将使用 CPU${NC}"
        BACKEND="cpu"
    fi
fi

echo ""
echo -e "${YELLOW}启动容器...${NC}"
echo ""

docker run -d \
    --name "$CONTAINER_NAME" \
    $GPU_OPTS \
    -e "NEURX_BACKEND=$BACKEND" \
    -e "NEURX_BATCH_SIZE=$BATCH_SIZE" \
    -e "NEURX_NUM_WORKERS=$NUM_WORKERS" \
    -e "NEURX_KV_BLOCKS=$KV_BLOCKS" \
    -e "NEURX_API_PORT=$API_PORT" \
    -e "NEURX_GRPC_PORT=$GRPC_PORT" \
    -e "NEURX_METRICS_PORT=$METRICS_PORT" \
    -p "$API_PORT:8080" \
    -p "$GRPC_PORT:8081" \
    -p "$METRICS_PORT:9090" \
    -v "$PROJECT_ROOT/posttrain:/opt/app/posttrain:ro" \
    -v "$PROJECT_ROOT/neurx/docker/logs:/var/log/neurx" \
    --restart unless-stopped \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=3 \
    "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 容器启动成功${NC}"
    echo ""

    echo -e "${YELLOW}等待服务就绪...${NC}"
    sleep 3

    max_attempts=30
    attempts=0
    while [ $attempts -lt $max_attempts ]; do
        if curl -s http:
            echo -e "${GREEN}✓ 服务已就绪${NC}"
            break
        fi
        attempts=$((attempts + 1))
        echo -n "."
        sleep 1
    done

    echo ""
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}容器运行成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    echo -e "${BLUE}服务端点:${NC}"
    echo -e "  HTTP API: http://localhost:$API_PORT"
    echo -e "  gRPC:     localhost:$GRPC_PORT"
    echo -e "  Metrics:  http://localhost:$METRICS_PORT/metrics"
    echo ""

    echo -e "${BLUE}快速测试:${NC}"
    echo ""
    echo "  # 健康检查"
    echo "  curl http://localhost:$API_PORT/health/ready"
    echo ""
    echo "  # 推理请求"
    echo "  curl -X POST http://localhost:$API_PORT/v1/completions \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"model\": \"base-model-posttrain\", \"prompt\": \"What is medical treatment?\"}'"
    echo ""

    echo -e "${BLUE}日志查看:${NC}"
    echo ""
    echo "  docker logs -f $CONTAINER_NAME"
    echo ""

    echo -e "${BLUE}停止容器:${NC}"
    echo ""
    echo "  docker stop $CONTAINER_NAME"
    echo ""

else
    echo -e "${RED}❌ 容器启动失败${NC}"
    exit 1
fi
