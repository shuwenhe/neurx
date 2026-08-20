#!/usr/bin/env bash
# QuickSort Multilingual Support Test Script
# Tests both Chinese and English algorithm requests against NeurX GPU backend
# Usage: ./test_quicksort_multilingual.sh

set -e

BACKEND_URL="http://127.0.0.1:18083/v1/generate"
BACKEND_TIMEOUT=60

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  NeurX QuickSort 多语言支持测试                              ║"
echo "║  Multilingual Algorithm Detection Verification               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 检查后端是否运行
echo "🔍 检查后端服务状态..."
RESPONSE=$(curl -s -m 5 http://127.0.0.1:18083/v1/generate \
  -d '{"action":"generate","prompt":"test"}' 2>&1 || echo "TIMEOUT")

if [[ "$RESPONSE" == "TIMEOUT" ]]; then
    echo "❌ 后端未响应，请先启动:"
    echo "   /home/shuwen/shuwen/neurx/artifacts/build/s_runner/s_ir_runner \\"
    echo "     gpu_backend_enhanced.ir"
    exit 1
fi

echo "✅ 后端在线"
echo ""

# 测试 1: 中文快速排序
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 测试 1: 中文快速排序"
echo "   输入: '用c++实现快速排序'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RESPONSE=$(curl -s -X POST "$BACKEND_URL" \
  -H "Content-Type: application/json" \
  -d '{"action":"generate","prompt":"用c++实现快速排序"}')

OUTPUT=$(echo "$RESPONSE" | grep -o '"output":"[^"]*"' | sed 's/"output":"\(.*\)"/\1/')

if [[ "$OUTPUT" == *"QuickSort"* ]]; then
    echo "✅ 正确识别: 中文快速排序"
    echo "   响应: $OUTPUT"
else
    echo "❌ 未能识别中文快速排序"
    echo "   响应: $RESPONSE"
fi
echo ""

# 测试 2: 英文快速排序
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 测试 2: 英文快速排序"
echo "   输入: 'implement quicksort'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RESPONSE=$(curl -s -X POST "$BACKEND_URL" \
  -H "Content-Type: application/json" \
  -d '{"action":"generate","prompt":"implement quicksort"}')

OUTPUT=$(echo "$RESPONSE" | grep -o '"output":"[^"]*"' | sed 's/"output":"\(.*\)"/\1/')

if [[ "$OUTPUT" == *"QuickSort"* ]]; then
    echo "✅ 正确识别: 英文快速排序"
    echo "   响应: $OUTPUT"
else
    echo "❌ 未能识别英文快速排序"
    echo "   响应: $RESPONSE"
fi
echo ""

# 测试 3: 中文冒泡排序
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 测试 3: 中文冒泡排序"
echo "   输入: '用python实现冒泡排序'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RESPONSE=$(curl -s -X POST "$BACKEND_URL" \
  -H "Content-Type: application/json" \
  -d '{"action":"generate","prompt":"用python实现冒泡排序"}')

OUTPUT=$(echo "$RESPONSE" | grep -o '"output":"[^"]*"' | sed 's/"output":"\(.*\)"/\1/')

if [[ "$OUTPUT" == *"Bubble"* ]] || [[ "$OUTPUT" == *"冒泡"* ]]; then
    echo "✅ 正确识别: 冒泡排序"
    echo "   响应: $OUTPUT"
else
    echo "ℹ️  通用响应（可能需要实现)"
    echo "   响应: $OUTPUT"
fi
echo ""

# 总结
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  测试完成 - Test Complete                                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
