#!/bin/bash
# 高效的数据转换工具 - 将training_data.jsonl转换为工业级格式
# 使用Bash实现（S语言逻辑，Bash执行）

set -e

NEURX_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$NEURX_HOME/data/training_data.jsonl"
OUTPUT_FILE="$NEURX_HOME/data/training_data_industrial.jsonl"

# 分类函数
classify_type() {
    local text="$1"
    text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')
    
    if [[ $text_lower == *"代码"* ]] || [[ $text_lower == *"code"* ]] || [[ $text_lower == *"def "* ]]; then
        echo "code_example"
    elif [[ $text_lower == *"问"* ]] || [[ $text_lower == *"答"* ]] || [[ $text_lower == *"qa"* ]]; then
        echo "qa_pair"
    elif [[ $text_lower == *"最佳"* ]] || [[ $text_lower == *"best"* ]]; then
        echo "best_practices"
    elif [[ $text_lower == *"架构"* ]] || [[ $text_lower == *"architecture"* ]]; then
        echo "architectural_pattern"
    else
        echo "technical_explanation"
    fi
}

classify_domain() {
    local text="$1"
    text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')
    
    if [[ $text_lower == *"模型"* ]] || [[ $text_lower == *"model"* ]] || [[ $text_lower == *"neural"* ]]; then
        echo "ml"
    elif [[ $text_lower == *"后端"* ]] || [[ $text_lower == *"backend"* ]]; then
        echo "backend"
    elif [[ $text_lower == *"前端"* ]] || [[ $text_lower == *"frontend"* ]]; then
        echo "frontend"
    elif [[ $text_lower == *"算法"* ]] || [[ $text_lower == *"algorithm"* ]]; then
        echo "algorithms"
    else
        echo "nlp"
    fi
}

infer_complexity() {
    local length=$1
    if [ $length -lt 200 ]; then
        echo "basic"
    elif [ $length -lt 500 ]; then
        echo "intermediate"
    elif [ $length -lt 1000 ]; then
        echo "advanced"
    else
        echo "expert"
    fi
}

infer_language() {
    local text="$1"
    # 检查是否包含中文字符
    if echo "$text" | grep -q '[^\x00-\x7F]'; then
        echo "zh"
    else
        echo "en"
    fi
}

infer_quality() {
    local length=$1
    local base=75  # 0.75 * 100
    
    if [ $length -gt 300 ]; then
        base=$((base + 10))  # +0.1
    fi
    if [ $length -gt 800 ]; then
        base=$((base + 5))   # +0.05
    fi
    
    # 限制最大值
    if [ $base -gt 99 ]; then
        base=99
    fi
    
    echo "0.$base"
}

estimate_tokens() {
    local text="$1"
    local length=${#text}
    local tokens=$((length / 3))
    
    if [ $tokens -lt 100 ]; then
        tokens=100
    fi
    
    echo $tokens
}

# 主处理函数
echo "🔄 转换训练数据为工业级格式..."
echo ""

if [ ! -f "$SOURCE_FILE" ]; then
    echo "❌ 错误: 找不到源文件 $SOURCE_FILE"
    exit 1
fi

# 临时文件
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

total=0
converted=0
start_time=$(date +%s)

while IFS= read -r line || [ -n "$line" ]; do
    ((total++))
    
    # 提取text字段（使用sed和grep）
    text=$(echo "$line" | sed -n 's/.*"text":"\([^"]*\)".*/\1/p' | head -1)
    
    # 如果文本为空，尝试jq解析
    if [ -z "$text" ] && command -v jq &> /dev/null; then
        text=$(echo "$line" | jq -r '.text' 2>/dev/null || echo "")
    fi
    
    if [ -z "$text" ]; then
        continue
    fi
    
    ((converted++))
    
    # 计算元数据
    length=${#text}
    type_val=$(classify_type "$text")
    domain=$(classify_domain "$text")
    complexity=$(infer_complexity $length)
    language=$(infer_language "$text")
    quality=$(infer_quality $length)
    tokens=$(estimate_tokens "$text")
    
    # 转义引号用于JSON
    text_escaped=$(echo "$text" | sed 's/"/\\"/g')
    
    # 构建JSON行
    json_line="{\"text\":\"$text_escaped\",\"type\":\"$type_val\",\"category\":\"$type_val\",\"domain\":\"$domain\",\"language\":\"$language\",\"quality_score\":$quality,\"complexity\":\"$complexity\",\"length\":$length,\"estimated_tokens\":$tokens}"
    
    echo "$json_line" >> "$TEMP_FILE"
    
    # 进度显示
    if [ $((total % 1000)) -eq 0 ]; then
        echo "  处理中... $total 行 ✓ 成功: $converted"
    fi
    
done < "$SOURCE_FILE"

# 移动文件
mv "$TEMP_FILE" "$OUTPUT_FILE"

end_time=$(date +%s)
elapsed=$((end_time - start_time))

# 完成信息
echo ""
echo "✅ 转换完成!"
echo ""
echo "📊 转换统计:"
printf "  总行数:        %d\n" $total
printf "  成功转换:      %d\n" $converted
printf "  用时:          %d 秒\n" $elapsed
if [ $elapsed -gt 0 ]; then
    throughput=$((converted / elapsed))
    printf "  吞吐:          %d 行/秒\n" $throughput
fi
echo "  输出文件:      $OUTPUT_FILE"
echo "  文件大小:      $(du -h "$OUTPUT_FILE" | cut -f1)"
echo ""

# 显示统计信息
echo "📋 数据类型分布:"
grep -o '"type":"[^"]*"' "$OUTPUT_FILE" | cut -d'"' -f4 | sort | uniq -c | sort -rn | awk '{print "    " $2 ": " $1}' | head -10
echo ""

echo "📚 领域分布:"
grep -o '"domain":"[^"]*"' "$OUTPUT_FILE" | cut -d'"' -f4 | sort | uniq -c | sort -rn | awk '{print "    " $2 ": " $1}' | head -10
echo ""

# 显示样本
echo "📋 转换样本 (前1条):"
echo ""
head -1 "$OUTPUT_FILE" | grep -o '[^}]*}' | head -c 400
echo "..."
echo ""
