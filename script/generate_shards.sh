#!/bin/bash
# ============================================================================
# NeurX 分片生成脚本
# 将 cleaned/train.jsonl 分割成 8192 个分片
# ============================================================================

set -e

NEURX_HOME="${NEURX_HOME:-$(cd "$(dirname "$0")" && pwd)}"
DATASET_ROOT="${DATASET_ROOT:-$NEURX_HOME/data/pretrain_dataset}"
INPUT_FILE="${INPUT_FILE:-$DATASET_ROOT/cleaned/train.jsonl}"
SHARD_DIR="${SHARD_DIR:-$DATASET_ROOT/shard}"
MANIFEST_FILE="${MANIFEST_FILE:-$DATASET_ROOT/manifest.json}"

file_size_bytes() {
    local target="$1"
    if stat -f%z "$target" >/dev/null 2>&1; then
        stat -f%z "$target"
    else
        stat -c%s "$target"
    fi
}

echo "╔════════════════════════════════════════════╗"
echo "║     NeurX 分片生成流程                     ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "📚 训练数据路径:"
echo "  • 原始目录: $DATASET_ROOT/raw"
echo "  • 清洗文件: $DATASET_ROOT/cleaned/pretrain_data_cleaned.jsonl"
echo "  • 训练文件: $INPUT_FILE"
echo "  • 分片目录: $SHARD_DIR"
echo "  • 清单文件: $MANIFEST_FILE"
echo ""

# 创建分片目录
mkdir -p "$SHARD_DIR"

echo "📋 计算分片大小..."
total_lines=$(wc -l < "$INPUT_FILE")
echo "  总行数: $total_lines"
echo "  输入文件: $INPUT_FILE"
# If input file is empty, write an empty manifest and exit gracefully
if [ "$total_lines" -eq 0 ]; then
        echo "No documents found in $INPUT_FILE — writing empty manifest and exiting."
        cat > "$MANIFEST_FILE" << EOF
{
    "dataset_name": "neurx-pretrain-dataset",
    "version": "1.0",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "total_shards": 0,
    "total_documents": 0,
    "total_size_bytes": 0,
    "average_docs_per_shard": 0,
    "shards": []
}
EOF
        echo "Empty manifest written to $MANIFEST_FILE"
        exit 0
fi

# 计算实际可用的分片数（考虑系统限制）
# 每个分片至少 100 行
MAX_SHARDS=128
ideal_shards=$(( (total_lines + 99) / 100 ))
actual_target_shards=$(( ideal_shards > MAX_SHARDS ? MAX_SHARDS : ideal_shards ))

# 计算每个分片的行数
lines_per_shard=$(( (total_lines + actual_target_shards - 1) / actual_target_shards ))  # 向上舍入
echo "  目标分片数: $actual_target_shards"
echo "  每个分片: $lines_per_shard 行"
echo ""

echo "✂️ 开始生成分片..."

# 使用 split 命令分割文件
split -l "$lines_per_shard" "$INPUT_FILE" "$SHARD_DIR/shard_"

echo ""
echo "📊 重命名和计数..."

# 重命名为标准格式
shard_count=0
for file in "$SHARD_DIR"/shard_*; do
    # 获取后缀
    suffix="${file##*shard_}"
    # 生成标准名称
    new_name=$(printf "shard_%05d.jsonl" "$shard_count")
    mv "$file" "$SHARD_DIR/$new_name"
    ((shard_count++))
done

echo "  • 生成的分片数: $shard_count"
echo ""

# 验证分片
echo "✅ 验证分片..."
actual_shards=$(ls -1 "$SHARD_DIR"/shard_*.jsonl 2>/dev/null | wc -l)
total_shard_lines=$(wc -l "$SHARD_DIR"/shard_*.jsonl | tail -1 | awk '{print $1}')
total_size=$(du -sh "$SHARD_DIR" | cut -f1)

echo "  • 实际分片数: $actual_shards"
echo "  • 分片中的总行数: $total_shard_lines"
echo "  • 总大小: $total_size"
echo ""

# 生成 manifest.json
echo "📋 生成 manifest.json..."
echo "  输出清单: $MANIFEST_FILE"

cat > "$MANIFEST_FILE" << EOF
{
  "dataset_name": "neurx-pretrain-dataset",
  "version": "1.0",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_shards": $actual_shards,
  "total_documents": $total_shard_lines,
  "total_size_bytes": $(file_size_bytes "$SHARD_DIR"),
  "average_docs_per_shard": $((total_shard_lines / actual_shards)),
  "shards": [
EOF

# 添加分片列表
for shard in "$SHARD_DIR"/shard_*.jsonl; do
    shard_name=$(basename "$shard")
    shard_lines=$(wc -l < "$shard")
    shard_size=$(file_size_bytes "$shard")
    
    echo "    {
      \"shard_id\": \"${shard_name%.jsonl}\",
      \"file_path\": \"$shard\",
      \"num_documents\": $shard_lines,
      \"size_bytes\": $shard_size
    }," >> "$MANIFEST_FILE"
done

# 移除最后一个逗号并关闭 JSON (portable sed)
sed -i '$ s/,$//' "$MANIFEST_FILE" 2>/dev/null || awk 'NR==FNR{a[NR]=$0;next} END{for(i=1;i<=NR;i++) print a[i]}' "$MANIFEST_FILE" "$MANIFEST_FILE" >/dev/null || true
echo "  ]
}" >> "$MANIFEST_FILE"

echo "  ✓ manifest.json 生成完成"
echo ""

# 列出前几个分片
echo "📁 分片文件列表 (前10个):"
ls -lh "$SHARD_DIR"/shard_*.jsonl | head -10 | awk '{print "  • " $9 " (" $5 ")"}'

# 计算预期 tokens
echo ""
echo "📊 分片统计:"
echo "  • 总分片数: $actual_shards"
echo "  • 总文档数: $total_shard_lines"
echo "  • 估计 tokens: $((total_shard_lines * 250))"  # 粗略估计每个文档250个token
echo ""

echo "✨ 分片生成完成!"
echo ""
echo "下一步:"
echo "  1️⃣  验证 manifest: cat $MANIFEST_FILE | head -30"
echo "  2️⃣  启动训练: bash train_1t_moe.sh"
