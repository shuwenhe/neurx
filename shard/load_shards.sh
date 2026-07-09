#!/bin/bash
# 数据加载器 - Bash实现
# 读取并统计分片数据

SHARD_DIR="${1:-.}"
MAX_SAMPLES_PER_SHARD="${2:-500}"
MAX_SHARDS="${3:-10}"

if [ ! -d "$SHARD_DIR" ]; then
    echo "Error: Shard directory not found: $SHARD_DIR" >&2
    exit 1
fi

# 统计信息
total_samples=0
shard_count=0
first_sample=""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "数据加载配置" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "分片目录: $SHARD_DIR" >&2
echo "单个分片最大样本: $MAX_SAMPLES_PER_SHARD" >&2
echo "最大分片数: $MAX_SHARDS" >&2
echo "" >&2

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "加载分片数据" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

# 查找所有分片文件
shards=($(ls "$SHARD_DIR"/training_data-*.jsonl.gz 2>/dev/null | sort | head -"$MAX_SHARDS"))

for shard_file in "${shards[@]}"; do
    shard_name=$(basename "$shard_file")
    
    # 统计行数（样本数）
    samples_in_shard=$(gzip -dc "$shard_file" 2>/dev/null | wc -l)
    if [ "$samples_in_shard" -gt "$MAX_SAMPLES_PER_SHARD" ]; then
        samples_in_shard=$MAX_SAMPLES_PER_SHARD
    fi
    
    total_samples=$((total_samples + samples_in_shard))
    shard_count=$((shard_count + 1))
    
    # 获取第一个样本用于预览
    if [ -z "$first_sample" ]; then
        first_sample=$(gzip -dc "$shard_file" 2>/dev/null | head -1 | cut -c1-80)
    fi
    
    echo "  [$shard_count] $shard_name" >&2
    echo "      已加载: $samples_in_shard 个样本" >&2
done

echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "加载统计" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "分片总数: $shard_count" >&2

if [ $shard_count -gt 0 ]; then
    avg_samples=$((total_samples / shard_count))
    echo "总样本数: $total_samples" >&2
    echo "平均每分片: $avg_samples" >&2
else
    total_samples=0
    echo "未找到数据分片" >&2
fi
echo "" >&2

# 输出到标准输出（供脚本调用）
echo "$total_samples"
echo "${first_sample:0:80}..."
