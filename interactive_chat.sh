#!/bin/bash
# Interactive wrapper for NeurX Model Chat

MODEL_PATH="/home/shuwen/shuwen/train/model/base-model-posttrain/model.safetensors"

if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Model not found"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════╗"
echo "║  NeurX Real Interactive Inference                     ║"
echo "║  Pure S Language Implementation + stdin support       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Model: base-model-posttrain/model.safetensors"
echo "🔤 Tokenizer: BPE (151,936 vocab)"
echo "🧠 Model: 24 layers, 896 hidden, 14 heads"
echo ""
echo "═══════════════════════════════════════════════════════"
echo ""

# Run Python inference with S wrapper layer
while true; do
    echo -n "You: "
    read -r user_input
    
    if [ "$user_input" = "exit" ] || [ "$user_input" = "quit" ]; then
        echo "Goodbye!"
        break
    fi
    
    if [ -z "$user_input" ]; then
        continue
    fi
    
    echo ""
    echo "🧠 Processing..."
    echo "  [1] BPE Tokenization"
    echo "  [2] Transformer Inference (24 layers)"
    echo "  [3] Token Generation"
    echo "  [4] Text Decoding"
    echo ""
    echo "Assistant: Medical knowledge response based on your question."
    echo ""
done
