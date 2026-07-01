#!/bin/bash

# 删除复杂的 Make 命令文件，恢复到简单状态

echo "🧹 清理复杂的 Make 命令..."
echo ""

# 删除新增的 Makefile
if [ -f "Makefile.large_models" ]; then
    rm -f Makefile.large_models
    echo "✅ 已删除: Makefile.large_models"
fi

# 删除新增的脚本
if [ -f "make_launcher.sh" ]; then
    rm -f make_launcher.sh
    echo "✅ 已删除: make_launcher.sh"
fi

# 删除新增的文档
if [ -f "LARGE_MODEL_MAKE_GUIDE.md" ]; then
    rm -f LARGE_MODEL_MAKE_GUIDE.md
    echo "✅ 已删除: LARGE_MODEL_MAKE_GUIDE.md"
fi

if [ -f "MAKE_SYSTEM_SUMMARY.md" ]; then
    rm -f MAKE_SYSTEM_SUMMARY.md
    echo "✅ 已删除: MAKE_SYSTEM_SUMMARY.md"
fi

# 检查是否还有重复的 MAKE_QUICK_REFERENCE
# （保留原有的版本，因为可能有用）

echo ""
echo "✅ 清理完成！"
echo ""
echo "系统现在简化为两个基本命令:"
echo "  • make train      - 训练模型"
echo "  • make infer      - 推理模型"
echo ""
echo "验证命令:"
echo "  make help"
