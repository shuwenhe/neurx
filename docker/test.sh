#!/bin/bash
# NeurX Docker 容器测试脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONTAINER_NAME=${CONTAINER_NAME:-"neurx-inference"}
API_PORT=${NEURX_API_PORT:-"8080"}
METRICS_PORT=${NEURX_METRICS_PORT:-"9090"}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}NeurX Docker 容器测试${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}❌ 容器 $CONTAINER_NAME 未运行${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 容器 $CONTAINER_NAME 运行中${NC}"
echo ""

# 测试 1: 健康检查
echo -e "${BLUE}测试 1: 健康检查${NC}"
echo "GET http://localhost:$API_PORT/health/ready"
health_response=$(curl -s http://localhost:$API_PORT/health/ready)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 健康检查通过${NC}"
    echo "  响应: $health_response"
else
    echo -e "${RED}❌ 健康检查失败${NC}"
fi
echo ""

# 测试 2: Prometheus 指标
echo -e "${BLUE}测试 2: Prometheus 指标${NC}"
echo "GET http://localhost:$METRICS_PORT/metrics"
metrics=$(curl -s http://localhost:$METRICS_PORT/metrics | grep "neurx_" | head -5)
if [ -n "$metrics" ]; then
    echo -e "${GREEN}✓ 指标可用${NC}"
    echo "  样本指标:"
    echo "$metrics" | sed 's/^/    /'
else
    echo -e "${YELLOW}⚠️  未找到 NeurX 指标${NC}"
fi
echo ""

# 测试 3: 推理请求
echo -e "${BLUE}测试 3: 文本生成推理${NC}"
echo "POST http://localhost:$API_PORT/v1/completions"
inference_response=$(curl -s -X POST http://localhost:$API_PORT/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "base-model-posttrain",
        "prompt": "What is medical treatment?",
        "max_tokens": 50,
        "temperature": 0.7
    }')

if echo "$inference_response" | grep -q "choices"; then
    echo -e "${GREEN}✓ 推理请求成功${NC}"
    echo "  响应样本:"
    echo "$inference_response" | jq '.choices[0] // .' 2>/dev/null | head -10 | sed 's/^/    /'
else
    echo -e "${RED}❌ 推理请求失败${NC}"
    echo "  响应: $inference_response" | sed 's/^/    /'
fi
echo ""

# 测试 4: 流式输出
echo -e "${BLUE}测试 4: 流式输出${NC}"
echo "POST http://localhost:$API_PORT/v1/completions (stream=true)"
echo -e "${YELLOW}流式响应 (前 5 块):${NC}"
curl -s -X POST http://localhost:$API_PORT/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "base-model-posttrain",
        "prompt": "Medical care",
        "stream": true,
        "max_tokens": 20
    }' | head -5 | sed 's/^/    /'
echo ""

# 测试 5: 容器资源使用
echo -e "${BLUE}测试 5: 容器资源使用${NC}"
docker stats --no-stream $CONTAINER_NAME | tail -1 | sed 's/^/    /'
echo ""

# 测试 6: 容器日志
echo -e "${BLUE}测试 6: 最近的容器日志 (最后 10 行)${NC}"
docker logs $CONTAINER_NAME 2>&1 | tail -10 | sed 's/^/    /'
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}测试完成${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}下一步:${NC}"
echo ""
echo "  # 查看完整日志"
echo "  docker logs -f $CONTAINER_NAME"
echo ""
echo "  # 进入容器调试"
echo "  docker exec -it $CONTAINER_NAME bash"
echo ""
echo "  # 查看容器详情"
echo "  docker inspect $CONTAINER_NAME"
echo ""
