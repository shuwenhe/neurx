#!/bin/bash

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${COLOR_GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${COLOR_RED}✗${NC} $1"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ${NC} $1"
}

print_step() {
    echo -e "\n${COLOR_YELLOW}━━━ $1 ━━━${NC}"
}   

echo -e "${COLOR_BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${COLOR_BLUE}║     NeurX API 功能测试${NC}"
echo -e "${COLOR_BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# 测试 1: 健康检查
print_step "测试 1: 健康检查"
HEALTH=$(curl -s http://localhost:8000/health 2>/dev/null || echo "FAILED")
if echo "$HEALTH" | grep -q "ok"; then
    print_success "健康检查通过"
    echo "响应: $HEALTH"
else
    print_error "健康检查失败"
    echo "响应: $HEALTH"
    exit 1
fi

# 测试 2: 简单对话
print_step "测试 2: 简单对话"
RESPONSE=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "hello"}],
    "max_tokens": 20
  }' 2>/dev/null || echo "FAILED")

if echo "$RESPONSE" | grep -q "chatcmpl"; then
    print_success "聊天 API 响应正常"
    echo ""
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null | head -20
else
    print_error "聊天 API 失败"
    echo "响应: $RESPONSE"
fi

# 测试 3: 中文对话
print_step "测试 3: 中文对话"
CN_RESPONSE=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "你好"}],
    "max_tokens": 20
  }' 2>/dev/null || echo "FAILED")

if echo "$CN_RESPONSE" | grep -q "chatcmpl"; then
    print_success "中文对话正常"
    echo "$CN_RESPONSE" | python3 -c "import json, sys; d=json.load(sys.stdin); print('  应答:', d['choices'][0]['message']['content'][:100])" 2>/dev/null
else
    print_error "中文对话失败"
fi

# 测试 4: 长文本生成
print_step "测试 4: 长文本生成"
LONG_RESPONSE=$(curl -s -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role": "user", "content": "介绍一下 Linux"}],
    "max_tokens": 100
  }' 2>/dev/null || echo "FAILED")

if echo "$LONG_RESPONSE" | grep -q "chatcmpl"; then
    print_success "长文本生成正常"
    CONTENT=$(echo "$LONG_RESPONSE" | python3 -c "import json, sys; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])" 2>/dev/null)
    PREVIEW="${CONTENT:0:100}"
    echo "  应答 (前 100 字): ${PREVIEW}..."
else
    print_error "长文本生成失败"
fi

# 测试 5: 并发请求
print_step "测试 5: 并发请求"
print_info "发送 3 个并发请求..."

for i in {1..3}; do
    curl -s -X POST http://localhost:8000/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"default\",\"messages\":[{\"role\":\"user\",\"content\":\"测试 $i\"}],\"max_tokens\":10}" > /tmp/test_$i.json &
done

wait
COUNT=0
for i in {1..3}; do
    if grep -q "chatcmpl" /tmp/test_$i.json; then
        COUNT=$((COUNT + 1))
    fi
done

if [ $COUNT -eq 3 ]; then
    print_success "并发请求全部成功 (3/3)"
else
    print_error "并发请求部分失败 ($COUNT/3)"
fi

# 清理
rm -f /tmp/test_*.json

# 最终总结
echo ""
echo -e "${COLOR_GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${COLOR_GREEN}║${NC} ${COLOR_YELLOW}所有测试完成！${NC}${COLOR_GREEN}                   ║${NC}"
echo -e "${COLOR_GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "📊 ${COLOR_BLUE}服务状态${NC}"
docker ps | grep neurx

echo ""
echo -e "📈 ${COLOR_BLUE}资源使用${NC}"
docker stats --no-stream | grep neurx
