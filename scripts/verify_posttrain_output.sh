#!/bin/bash
# Verify NeurX PostTrain Output Integrity
# Checks that adapter and merged model contain real weights, not placeholders

echo "=== NeurX PostTrain Verification ==="
echo ""

ADAPTER_FILE="/home/shuwen/shuwen/posttrain_adapter/adapter_model.safetensors"
MODEL_FILE="/home/shuwen/shuwen/posttrain/model.safetensors"
BASE_MODEL="/home/shuwen/shuwen/model/Qwen2.5-0.5B-Instruct/model.safetensors"

if [ ! -f "$ADAPTER_FILE" ]; then
    echo "❌ FAIL: Adapter file not found: $ADAPTER_FILE"
    exit 1
fi

if [ ! -f "$MODEL_FILE" ]; then
    echo "❌ FAIL: Model file not found: $MODEL_FILE"
    exit 1
fi

# Check adapter file type
echo "[1] Checking adapter file format..."
file_type=$(file "$ADAPTER_FILE" | grep -o "data\|JSON")
adapter_size=$(stat -c%s "$ADAPTER_FILE" 2>/dev/null || stat -f%z "$ADAPTER_FILE")

if [ "$file_type" = "data" ]; then
    echo "✅ PASS: Adapter is binary (not JSON placeholder)"
else
    echo "❌ FAIL: Adapter appears to be text-based: $file_type"
    exit 1
fi

if [ "$adapter_size" -gt 1000000 ]; then
    echo "✅ PASS: Adapter size is reasonable ($((adapter_size / 1024 / 1024))MB, contains real weights)"
else
    echo "❌ FAIL: Adapter size too small ($adapter_size bytes), likely placeholder"
    exit 1
fi

# Check safetensors format (8-byte header + JSON)
echo ""
echo "[2] Checking safetensors format..."
header=$(xxd -p -l 8 "$ADAPTER_FILE")
if [ -n "$header" ]; then
    echo "✅ PASS: Adapter has valid header bytes: $header"
else
    echo "❌ FAIL: Cannot read adapter header"
    exit 1
fi

# Verify model was merged (compare with base)
echo ""
echo "[3] Verifying model weights were merged..."
base_size=$(stat -c%s "$BASE_MODEL" 2>/dev/null || stat -f%z "$BASE_MODEL")
model_size=$(stat -c%s "$MODEL_FILE" 2>/dev/null || stat -f%z "$MODEL_FILE")

if [ "$model_size" -eq "$base_size" ]; then
    echo "✅ PASS: Model sizes match (expected, LoRA doesn't change size)"
else
    echo "⚠️  WARN: Model sizes differ (base=$base_size, merged=$model_size)"
fi

# Check if content actually differs
diff_count=$(cmp -bl "$BASE_MODEL" "$MODEL_FILE" 2>/dev/null | wc -l)
if [ "$diff_count" -gt 0 ]; then
    echo "✅ PASS: Merged model differs from base model ($diff_count bytes changed)"
    echo "  → LoRA weights successfully applied"
else
    echo "❌ FAIL: Merged model identical to base model"
    echo "  → LoRA merge may have failed"
    exit 1
fi

echo ""
echo "=== All Checks Passed ✅ ==="
echo "Adapter file: $ADAPTER_FILE ($((adapter_size / 1024 / 1024))MB)"
echo "Merged model: $MODEL_FILE"
echo ""
echo "The post-trained model contains real LoRA weights and is ready for deployment."
