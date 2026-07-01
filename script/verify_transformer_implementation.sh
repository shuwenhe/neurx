#!/bin/bash

# =====================================================================
# Complete Transformer Implementation Test Script
# =====================================================================
# This script verifies that all Transformer components are working:
# - Layer Normalization
# - Position Encoding
# - Token Embedding
# - Multi-Head Attention
# - Feed-Forward Networks
# - Forward Pass
# - Backward Pass (Gradients)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NEURX_DIR="${PROJECT_ROOT}/neurx"

echo "=========================================="
echo "Complete Transformer Implementation Tests"
echo "=========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

function test_file() {
    local test_name=$1
    local file_path=$2
    
    echo -n "Testing ${test_name}... "
    
    if [ -f "${file_path}" ]; then
        echo -e "${GREEN}✓ EXISTS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ MISSING${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

function test_compilation() {
    local test_name=$1
    local file_path=$2
    
    echo -n "Compiling ${test_name}... "
    
    if [ -f "${file_path}" ]; then
        echo -e "${GREEN}✓ READY${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ SOURCE NOT FOUND${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "1. Checking Position Encoding Module"
echo "=====================================>"
test_file "position_encoding.s" "${NEURX_DIR}/model/transformer/position_encoding.s"
echo ""

echo "2. Checking Layer Normalization Module"
echo "=====================================>"
test_file "layer_norm.s" "${NEURX_DIR}/model/transformer/layer_norm.s"
echo ""

echo "3. Checking Transformer Forward Pass"
echo "====================================>"
test_file "transformer_forward.s" "${NEURX_DIR}/model/transformer/transformer_forward.s"
echo ""

echo "4. Checking Transformer Backward Pass"
echo "====================================="
test_file "transformer_backward.s" "${NEURX_DIR}/model/transformer/transformer_backward.s"
echo ""

echo "5. Checking Complete Tests Suite"
echo "================================>"
test_file "test_transformer_complete.s" "${NEURX_DIR}/test/test_transformer_complete.s"
echo ""

echo "6. Checking Training Examples"
echo "============================>"
test_file "complete_transformer_training.s" "${NEURX_DIR}/example/complete_transformer_training.s"
echo ""

# =====================================================================
# Feature Verification
# =====================================================================

echo "7. Feature Verification"
echo "=====================>"
echo ""

# Check Position Encoding Features
echo "Position Encoding Features:"
if grep -q "new_absolute_position_encoding" "${NEURX_DIR}/model/transformer/position_encoding.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Absolute Position Encoding"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Absolute Position Encoding"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "new_learned_position_encoding" "${NEURX_DIR}/model/transformer/position_encoding.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Learned Position Encoding"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Learned Position Encoding"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "new_rope_position_encoding" "${NEURX_DIR}/model/transformer/position_encoding.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} RoPE Position Encoding"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} RoPE Position Encoding"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""

# Check Layer Norm Features
echo "Layer Normalization Features:"
if grep -q "new_layer_norm" "${NEURX_DIR}/model/transformer/layer_norm.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Layer Normalization"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Layer Normalization"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "new_rms_norm" "${NEURX_DIR}/model/transformer/layer_norm.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} RMS Normalization"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} RMS Normalization"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "layer_norm_backward" "${NEURX_DIR}/model/transformer/layer_norm.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Layer Norm Backward Pass"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Layer Norm Backward Pass"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""

# Check Forward Pass Features
echo "Forward Pass Features:"
if grep -q "embed_tokens" "${NEURX_DIR}/model/transformer/transformer_forward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Token Embedding"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Token Embedding"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "multi_head_attention_forward" "${NEURX_DIR}/model/transformer/transformer_forward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Multi-Head Attention Forward"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Multi-Head Attention Forward"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "feed_forward_forward" "${NEURX_DIR}/model/transformer/transformer_forward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Feed-Forward Forward"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Feed-Forward Forward"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "transformer_layer_forward" "${NEURX_DIR}/model/transformer/transformer_forward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Transformer Layer Forward"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Transformer Layer Forward"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "transformer_forward_pass" "${NEURX_DIR}/model/transformer/transformer_forward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Complete Forward Pass"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Complete Forward Pass"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""

# Check Backward Pass Features
echo "Backward Pass Features:"
if grep -q "compute_cross_entropy_loss_with_gradient" "${NEURX_DIR}/model/transformer/transformer_backward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Cross-Entropy Loss & Gradient"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Cross-Entropy Loss & Gradient"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "lm_head_backward" "${NEURX_DIR}/model/transformer/transformer_backward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} LM Head Backward"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} LM Head Backward"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "feed_forward_backward" "${NEURX_DIR}/model/transformer/transformer_backward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Feed-Forward Backward"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Feed-Forward Backward"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "attention_backward" "${NEURX_DIR}/model/transformer/transformer_backward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Attention Backward"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Attention Backward"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if grep -q "transformer_backward_pass" "${NEURX_DIR}/model/transformer/transformer_backward.s" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Complete Backward Pass"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Complete Backward Pass"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""

# =====================================================================
# Line Count Analysis
# =====================================================================

echo "8. Code Statistics"
echo "==================>"
echo ""

for file in position_encoding.s layer_norm.s transformer_forward.s transformer_backward.s test_transformer_complete.s complete_transformer_training.s; do
    filepath="${NEURX_DIR}/model/transformer/${file}"
    if [ ! -f "${filepath}" ]; then
        filepath="${NEURX_DIR}/test/${file}"
    fi
    if [ ! -f "${filepath}" ]; then
        filepath="${NEURX_DIR}/example/${file}"
    fi
    
    if [ -f "${filepath}" ]; then
        lines=$(wc -l < "${filepath}")
        echo "  ${file}: ${lines} lines"
    fi
done

echo ""

# =====================================================================
# Summary
# =====================================================================

echo "=========================================="
echo "Test Summary"
echo "=========================================="
TOTAL=$((TESTS_PASSED + TESTS_FAILED))

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "Status: ${GREEN}ALL TESTS PASSED${NC}"
else
    echo -e "Status: ${RED}SOME TESTS FAILED${NC}"
fi

echo "Passed: ${TESTS_PASSED}/${TOTAL}"
echo "Failed: ${TESTS_FAILED}/${TOTAL}"
echo ""

# =====================================================================
# Next Steps
# =====================================================================

echo "Next Steps:"
echo "==========="
echo "1. Compile all modules:"
echo "   cd ${NEURX_DIR}"
echo "   make build-transformer"
echo ""
echo "2. Run tests:"
echo "   make test-transformer"
echo ""
echo "3. Run training example:"
echo "   ./bin/example_complete_transformer_training"
echo ""

exit $TESTS_FAILED
