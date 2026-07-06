#!/bin/bash

echo "=========================================="
echo "NeurX LLM Training Integration - Compilation Test"
echo "=========================================="
echo ""

FILES=(
  "/Users/feifei/shuwen/neurx/pretrain/tokenizer/bpe.s"
  "/Users/feifei/shuwen/neurx/model/transformer/norm_embed.s"
  "/Users/feifei/shuwen/neurx/model/transformer/ffn.s"
  "/Users/feifei/shuwen/neurx/model/transformer/attention.s"
  "/Users/feifei/shuwen/neurx/model/transformer/transformer.s"
  "/Users/feifei/shuwen/neurx/model/transformer/attention_implementation.s"
  "/Users/feifei/shuwen/neurx/model/transformer/attention_gradient.s"
  "/Users/feifei/shuwen/neurx/opt/optim.s"
  "/Users/feifei/shuwen/neurx/opt/lr_scheduler.s"
  "/Users/feifei/shuwen/neurx/model/llm/model_large_train.s"
  "/Users/feifei/shuwen/neurx/pretrain/llm/model_large_pretrain.s"
  "/Users/feifei/shuwen/neurx/train_llm.s"
)

OK_COUNT=0
TOTAL_COUNT=0

for FILE in "${FILES[@]}"; do
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    NAME=$(basename "$FILE")
    echo "$TOTAL_COUNT. Compiling $NAME..."
    /Users/feifei/shuwen/s/bin/s "$FILE" "/tmp/${NAME}.ir" 2>&1 > "/tmp/${NAME}.log"
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        echo "   ✓ $NAME compiled successfully"
        OK_COUNT=$((OK_COUNT + 1))
    else
        echo "   ✗ FAILED (exit $RESULT)"
        head -20 "/tmp/${NAME}.log"
    fi
    echo ""
done

echo "=========================================="
echo "Compilation Summary"
echo "=========================================="
echo ""
echo "Passed: $OK_COUNT / $TOTAL_COUNT"
echo ""

if [ $OK_COUNT -eq $TOTAL_COUNT ]; then
    echo "✓ All integration files compiled successfully"
    exit 0
fi

echo "✗ Some integration files still need work"
exit 1
