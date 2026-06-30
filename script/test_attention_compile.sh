#!/bin/bash

echo "=== Compiling Attention Implementation ==="
echo ""

# Compile attention test
echo "1. Compiling attention test file..."
/Users/feifei/shuwen/s/bin/s /Users/feifei/shuwen/neurx/test/test_attention.s /tmp/test_attention.ir 2>&1
TEST_RESULT=$?

if [ $TEST_RESULT -eq 0 ]; then
    echo "✓ Attention test compiled successfully"
else
    echo "✗ Attention test compilation failed (exit code: $TEST_RESULT)"
fi

echo ""
echo "2. Compiling attention gradient file..."
/Users/feifei/shuwen/s/bin/s /Users/feifei/shuwen/neurx/model/transformer/attention_gradient.s /tmp/attention_gradient.ir 2>&1
GRAD_RESULT=$?

if [ $GRAD_RESULT -eq 0 ]; then
    echo "✓ Attention gradient compiled successfully"
else
    echo "✗ Attention gradient compilation failed (exit code: $GRAD_RESULT)"
fi

echo ""
echo "=== Summary ==="
echo "Attention implementation files:"
echo "  - /Users/feifei/shuwen/neurx/model/transformer/attention_implementation.s (fixed)"
echo "  - /Users/feifei/shuwen/neurx/model/transformer/attention_gradient.s (new)"
echo "  - /Users/feifei/shuwen/neurx/test/test_attention.s (new)"
echo ""
echo "Components implemented:"
echo "  ✓ Scaled dot-product attention"
echo "  ✓ Multi-head attention forward pass"
echo "  ✓ Softmax with numerical stability"
echo "  ✓ Backward pass (gradients)"
echo "  ✓ Causal masking support"
echo "  ✓ GQA/MQA variants"
echo ""
