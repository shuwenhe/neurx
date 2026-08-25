#!/bin/bash

# NeurX 项目 var/let 到 := 迁移脚本
# 功能: 自动将所有 let 和 var 声明转换为 := 操作符

set -e

PROJECT_ROOT="${1:-.}"
TOTAL_FILES=0
TOTAL_CHANGES=0

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║          开始迁移 NeurX 项目 - 将 var/let 转换为 :=                       ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# 创建备份
echo "📦 创建项目备份..."
BACKUP_DIR="/tmp/neurx_backup_$(date +%s)"
cp -r "$PROJECT_ROOT" "$BACKUP_DIR"
echo "✓ 备份位置: $BACKUP_DIR"
echo ""

echo "🔄 开始转换文件..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 遍历所有 .s 文件
find "$PROJECT_ROOT" -name "*.s" -type f | sort | while read file; do
    # 跳过某些目录
    if [[ "$file" == *".git"* ]] || [[ "$file" == *"node_modules"* ]] || [[ "$file" == *"build"* ]]; then
        continue
    fi
    
    original_content=$(cat "$file")
    modified_content="$original_content"
    
    # 规则1: let name: type = value  →  name := value
    # 例如: let x: int = 5  →  x := 5
    modified_content=$(echo "$modified_content" | sed -E 's/^([[:space:]]*)let[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*[^=]+=[[:space:]]*/\1\2 := /g')
    
    # 规则2: let name = value  →  name := value  (不带类型)
    # 例如: let x = 5  →  x := 5
    modified_content=$(echo "$modified_content" | sed -E 's/^([[:space:]]*)let[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*/\1\2 := /g')
    
    # 规则3: var name: type = value  →  name := value
    # 例如: var x: int = 5  →  x := 5
    modified_content=$(echo "$modified_content" | sed -E 's/^([[:space:]]*)var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*[^=]+=[[:space:]]*/\1\2 := /g')
    
    # 规则4: var name = value  →  name := value  (不带类型)
    # 例如: var x = 5  →  x := 5
    modified_content=$(echo "$modified_content" | sed -E 's/^([[:space:]]*)var[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*/\1\2 := /g')
    
    # 检查是否有变化
    if [ "$original_content" != "$modified_content" ]; then
        # 计算变化数
        original_let=$(echo "$original_content" | grep -c "^[[:space:]]*let " 2>/dev/null || true)
        original_var=$(echo "$original_content" | grep -c "^[[:space:]]*var " 2>/dev/null || true)
        original_total=$((original_let + original_var))
        
        modified_let=$(echo "$modified_content" | grep -c "^[[:space:]]*let " 2>/dev/null || true)
        modified_var=$(echo "$modified_content" | grep -c "^[[:space:]]*var " 2>/dev/null || true)
        modified_total=$((modified_let + modified_var))
        
        changes=$((original_total - modified_total))
        
        # 写入修改
        echo "$modified_content" > "$file"
        
        # 显示结果
        echo "✓ ${file#$PROJECT_ROOT/} (+$changes 行)"
        
        TOTAL_CHANGES=$((TOTAL_CHANGES + changes))
    fi
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ 迁移完成！"
echo ""
echo "📊 统计结果"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  处理文件数:    $TOTAL_FILES"
echo "  转换行数:      $TOTAL_CHANGES"
echo ""
echo "📂 备份位置: $BACKUP_DIR"
echo ""
echo "💡 后续步骤:"
echo "  1. 检查转换结果: git diff"
echo "  2. 编译验证:    make compile"
echo "  3. 测试验证:    make test"
echo "  4. 提交修改:    git add . && git commit"
