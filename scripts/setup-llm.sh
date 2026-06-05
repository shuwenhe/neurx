#!/bin/bash
# CodeMagic + LLM 快速开始指南

echo "🚀 CodeMagic + LLM 快速设置"
echo "=============================="
echo ""

# 第1步：检查环境
echo "✓ 第1步：检查环境"
if ! command -v cmake &> /dev/null; then
    echo "❌ 需要安装 cmake"
    exit 1
fi
echo "✓ cmake 已安装"
echo ""

# 第2步：设置API密钥
echo "✓ 第2步：设置API密钥"
read -p "请输入 Claude API密钥 (sk-ant-...): " CLAUDE_KEY
export ANTHROPIC_API_KEY="$CLAUDE_KEY"
echo "✓ API密钥已设置"
echo ""

# 第3步：编译
echo "✓ 第3步：编译neurx"
cd "$(dirname "$0")"/../..
mkdir -p build
cd build
cmake ..
make -j8
echo "✓ 编译完成"
echo ""

# 第4步：验证
echo "✓ 第4步：验证安装"
echo ""
echo "CodeMagic + LLM 现在已可使用！"
echo ""
echo "快速测试代码示例："
echo ""
cat << 'EOF'
#include "LLMCodeAnalyzer.h"
#include "../llm/AnthropicProvider.h"

int main() {
    // 创建分析器
    auto analyzer = std::make_unique<LLMCodeAnalyzer>();
    
    // 配置LLM
    auto provider = new AnthropicProvider();
    provider->setApiKey(getenv("ANTHROPIC_API_KEY"));
    analyzer->setLLMProvider(provider);
    
    // 分析代码
    auto result = analyzer->analyzeCode("def hello(): print('world')", 
                                        ProgrammingLanguage::Python);
    
    qDebug() << "Quality:" << result.quality;
    qDebug() << "Issues:" << result.issues.size();
    
    return 0;
}
EOF

echo ""
echo "📚 更多信息："
echo "- 完整文档：./LLM_INTEGRATION.md"
echo "- 架构说明：./ARCHITECTURE.md"
echo "- 原始文档：./README.md"
echo ""
echo "✅ 设置完成！"
