#!/bin/bash
# NeurX Docker 镜像构建脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}NeurX Docker 镜像构建${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装${NC}"
    exit 1
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

echo ""
echo -e "${YELLOW}项目根目录: $PROJECT_ROOT${NC}"
echo -e "${YELLOW}Dockerfile: $SCRIPT_DIR/Dockerfile.inference${NC}"

# 检查必要的文件
echo ""
echo -e "${YELLOW}检查必要的文件...${NC}"

if [ ! -d "$PROJECT_ROOT/neurx" ]; then
    echo -e "${RED}❌ neurx 目录不存在${NC}"
    exit 1
fi

if [ ! -d "$PROJECT_ROOT/posttrain" ]; then
    echo -e "${RED}❌ posttrain 目录不存在${NC}"
    exit 1
fi

if [ ! -d "$PROJECT_ROOT/s" ]; then
    echo -e "${RED}❌ S 编译器目录不存在${NC}"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/posttrain/model.safetensors" ]; then
    echo -e "${RED}❌ 模型文件不存在: $PROJECT_ROOT/posttrain/model.safetensors${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 所有文件检查通过${NC}"

# 构建镜像
IMAGE_NAME="neurx-inference"
IMAGE_TAG="latest"
IMAGE_FULL="${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
echo -e "${YELLOW}开始构建 Docker 镜像...${NC}"
echo -e "${YELLOW}镜像名称: $IMAGE_FULL${NC}"
echo ""

cd "$PROJECT_ROOT"

docker build \
    -t "$IMAGE_FULL" \
    -f "$SCRIPT_DIR/Dockerfile.inference" \
    --progress=plain \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Docker 镜像构建成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}下一步: 启动容器${NC}"
    echo ""
    echo "  docker run -d \\"
    echo "    --name neurx-inference \\"
    echo "    --gpus all \\"
    echo "    -p 8080:8080 \\"
    echo "    -p 9090:9090 \\"
    echo "    -v $PROJECT_ROOT/posttrain:/opt/app/posttrain:ro \\"
    echo "    $IMAGE_FULL"
    echo ""
    echo -e "${YELLOW}或使用 docker-compose:${NC}"
    echo ""
    echo "  cd $SCRIPT_DIR"
    echo "  docker-compose up -d"
    echo ""
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}❌ Docker 镜像构建失败！${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
