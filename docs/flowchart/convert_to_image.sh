#!/bin/bash
# neurx-code Mermaid Flowchart to Image Converter
# 将 Mermaid 流程图转换为 PNG/SVG 格式 (macOS 兼容版本)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MMD_FILE="$SCRIPT_DIR/neurx-code-architecture.mmd"
OUTPUT_DIR="$SCRIPT_DIR"

echo "=========================================="
echo "🎨 neurx-code Flowchart Converter"
echo "=========================================="
echo ""

if [ ! -f "$MMD_FILE" ]; then
    echo "❌ Error: $MMD_FILE not found"
    exit 1
fi

echo "📄 Input: $MMD_FILE"
echo "📁 Output: $OUTPUT_DIR"
echo ""

# 检查是否有 curl
if ! command -v curl &> /dev/null; then
    echo "❌ curl 未找到，请安装 curl"
    exit 1
fi

# 检查是否有 jq (用于 JSON 编码)
if ! command -v jq &> /dev/null; then
    echo "❌ jq 未找到，请安装 jq 后重试"
    exit 1
else
    # 使用 jq 进行 JSON 编码
    DIAGRAM_CONTENT=$(jq -Rs . < "$MMD_FILE")
fi

echo "🔄 方法 1: 使用 kroki.io API (在线，无需依赖)"
echo "--------------------------------------------"
echo "📡 发送请求到 kroki.io..."

# 生成 PNG
echo "🎨 生成 PNG..."
if curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"diagram_source\":${DIAGRAM_CONTENT}}" \
    "https://kroki.io/mermaid/png" \
    -o "$OUTPUT_DIR/neurx-code-architecture.png" 2>/dev/null; then
    
    if [ -f "$OUTPUT_DIR/neurx-code-architecture.png" ] && [ -s "$OUTPUT_DIR/neurx-code-architecture.png" ]; then
        SIZE=$(du -h "$OUTPUT_DIR/neurx-code-architecture.png" | cut -f1)
        echo "✅ PNG 创建成功: neurx-code-architecture.png (大小: $SIZE)"
        PNG_CREATED=1
    else
        echo "⚠️  PNG 生成失败或文件为空"
    fi
else
    echo "⚠️  PNG 请求失败"
fi

# 生成 SVG
echo "🎨 生成 SVG..."
if curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"diagram_source\":${DIAGRAM_CONTENT}}" \
    "https://kroki.io/mermaid/svg" \
    -o "$OUTPUT_DIR/neurx-code-architecture.svg" 2>/dev/null; then
    
    if [ -f "$OUTPUT_DIR/neurx-code-architecture.svg" ] && [ -s "$OUTPUT_DIR/neurx-code-architecture.svg" ]; then
        SIZE=$(du -h "$OUTPUT_DIR/neurx-code-architecture.svg" | cut -f1)
        echo "✅ SVG 创建成功: neurx-code-architecture.svg (大小: $SIZE)"
        SVG_CREATED=1
    else
        echo "⚠️  SVG 生成失败或文件为空"
    fi
else
    echo "⚠️  SVG 请求失败"
fi

echo ""

# 检查是否成功
if [ "$PNG_CREATED" = "1" ] || [ "$SVG_CREATED" = "1" ]; then
    echo "✨ 转换完成！"
    echo ""
    echo "📁 文件位置:"
    if [ "$PNG_CREATED" = "1" ]; then
        echo "   - $OUTPUT_DIR/neurx-code-architecture.png"
    fi
    if [ "$SVG_CREATED" = "1" ]; then
        echo "   - $OUTPUT_DIR/neurx-code-architecture.svg"
    fi
    exit 0
fi

echo "❌ 所有转换方法都失败了"
echo ""
echo "🔄 方法 2: 尝试本地 mermaid-cli"
echo "--------------------------------------------"

if command -v mmdc &> /dev/null; then
    echo "📦 找到 mermaid-cli，生成图像..."
    if mmdc -i "$MMD_FILE" -o "$OUTPUT_DIR/neurx-code-architecture.png" 2>/dev/null; then
        echo "✅ PNG 创建成功: neurx-code-architecture.png"
    fi
    if mmdc -i "$MMD_FILE" -o "$OUTPUT_DIR/neurx-code-architecture.svg" 2>/dev/null; then
        echo "✅ SVG 创建成功: neurx-code-architecture.svg"
    fi
    exit 0
else
    echo "❌ mermaid-cli 未安装"
fi

# 替代方案
echo ""
echo "📋 替代方案："
echo "=========================================="
echo ""
echo "选项 1: 安装 mermaid-cli (推荐)"
echo "  npm install -g @mermaid-js/mermaid-cli"
echo "  mmdc -i neurx-code-architecture.mmd -o neurx-code-architecture.png"
echo ""
echo "选项 2: 使用在线 Mermaid 编辑器"
echo "  1. 访问: https://mermaid.live"
echo "  2. 复制 neurx-code-architecture.mmd 的内容"
echo "  3. 粘贴到编辑器中"
echo "  4. 点击 'Download' 下载为 PNG/SVG/PDF"
echo ""
echo "选项 3: VS Code Markdown 预览"
echo "  1. 打开 neurx-code-architecture.md 文件"
echo "  2. 按 Cmd+Shift+V 预览 Markdown"
echo "  3. 右键点击图表选择 'Save as image'"
echo ""
echo "选项 4: 使用 Graphviz (如果已安装)"
echo "  brew install graphviz"
echo "  需要手动转换 Mermaid 到 DOT 格式"
echo ""

exit 1
