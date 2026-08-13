#!/bin/bash

# NeurX API 测试脚本
# 用于测试推理服务的各种 API 端点

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         NeurX API 测试工具                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查服务是否可用
check_service() {
    local url=$1
    local name=$2
    
    echo -e "${BLUE}检查 $name 服务...${NC}"
    if curl -s "$url/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $name 服务正常运行${NC}"
        return 0
    else
        echo -e "${RED}❌ $name 服务不可用${NC}"
        return 1
    fi
}

# 测试文本模型 API
test_text_model() {
    echo ""
    echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}文本模型 API 测试${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
    echo ""
    
    if ! check_service "http://localhost:8000" "文本模型"; then
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}测试 1: 简单对话${NC}"
    echo 'curl -X POST http://localhost:8000/v1/chat/completions \'
    echo '  -H "Content-Type: application/json" \'
    echo "  -d '{\"messages\": [{\"role\": \"user\", \"content\": \"你好\"}]}'"
    echo ""
    
    response=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{"messages": [{"role": "user", "content": "你好"}], "max_tokens": 50}')
    
    if echo "$response" | grep -q "role"; then
        echo -e "${GREEN}✅ 响应成功${NC}"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        echo -e "${RED}❌ 响应失败${NC}"
        echo "$response"
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}测试 2: 数学计算${NC}"
    response=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{"messages": [{"role": "user", "content": "1 + 1 = ?"}], "max_tokens": 20}')
    
    echo "$response" | jq '.choices[0].message.content' 2>/dev/null || echo "$response"
    
    echo ""
    echo -e "${YELLOW}测试 3: 参数配置${NC}"
    echo "测试不同的采样参数..."
    
    response=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{
            "messages": [{"role": "user", "content": "说一个笑话"}],
            "max_tokens": 100,
            "temperature": 0.9,
            "top_p": 0.8,
            "top_k": 30
        }')
    
    if echo "$response" | grep -q "role"; then
        echo -e "${GREEN}✅ 参数配置成功${NC}"
    else
        echo -e "${RED}❌ 参数配置失败${NC}"
    fi
}

# 测试 VL 模型 API
test_vl_model() {
    echo ""
    echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}VL 多模态模型 API 测试${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
    echo ""
    
    if ! check_service "http://localhost:8001" "VL 模型"; then
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}测试 1: 图像描述${NC}"
    echo "提示: 需要提供实际的图像路径"
    echo ""
    
    # 注意: 实际测试需要真实的图像文件
    echo -e "${YELLOW}示例请求:${NC}"
    echo 'curl -X POST http://localhost:8001/v1/chat/completions \'
    echo '  -H "Content-Type: application/json" \'
    echo '  -d '"'"'{
    echo '    "messages": [{"role": "user", "content": "描述这张图片"}],
    echo '    "images": ["/path/to/image.jpg"],
    echo '    "max_tokens": 512
    echo '  }'"'"
}

# 测试批量请求
test_batch_requests() {
    echo ""
    echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}批量请求测试${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}发送 3 个连续请求...${NC}"
    
    for i in {1..3}; do
        echo ""
        echo "请求 $i/3..."
        curl -s -X POST http://localhost:8000/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"messages\": [{\"role\": \"user\", \"content\": \"问题 $i\"}], \"max_tokens\": 20}" \
            | jq '.choices[0].message.content' 2>/dev/null || echo "请求失败"
    done
    
    echo -e "${GREEN}✅ 批量请求完成${NC}"
}

# 性能测试
test_performance() {
    echo ""
    echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}性能测试${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}测试推理延迟...${NC}"
    echo "发送 5 个请求并测量响应时间"
    echo ""
    
    total_time=0
    for i in {1..5}; do
        start_time=$(date +%s%N)
        
        curl -s -X POST http://localhost:8000/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d '{"messages": [{"role": "user", "content": "hi"}], "max_tokens": 20}' \
            > /dev/null
        
        end_time=$(date +%s%N)
        elapsed=$((($end_time - $start_time) / 1000000))  # 转换为毫秒
        
        echo "请求 $i: ${elapsed}ms"
        total_time=$((total_time + elapsed))
    done
    
    avg_time=$((total_time / 5))
    echo ""
    echo -e "${GREEN}平均响应时间: ${avg_time}ms${NC}"
}

# 显示菜单
show_menu() {
    echo ""
    echo -e "${BLUE}选择测试项目:${NC}"
    echo "  1) 文本模型 API 测试"
    echo "  2) VL 多模态模型测试"
    echo "  3) 批量请求测试"
    echo "  4) 性能测试"
    echo "  5) 全部测试"
    echo "  6) 仅检查服务状态"
    echo ""
}

# 主程序
if [ -z "$1" ]; then
    show_menu
    read -p "请选择 (1-6): " choice
else
    choice=$1
fi

case $choice in
    1)
        test_text_model
        ;;
    2)
        test_vl_model
        ;;
    3)
        test_batch_requests
        ;;
    4)
        test_performance
        ;;
    5)
        test_text_model
        test_vl_model
        test_batch_requests
        test_performance
        ;;
    6)
        check_service "http://localhost:8000" "文本模型"
        check_service "http://localhost:8001" "VL 模型"
        ;;
    *)
        echo -e "${RED}无效选择${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ 测试完成！${NC}"
echo ""
