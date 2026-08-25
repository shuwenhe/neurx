#!/usr/bin/env bash
# NeurX 分词和权重加载快速导航脚本 (2026-08-25)

set -e

NEURX_ROOT="${1:-/home/shuwen/shuwen/neurx}"

show_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  NeurX 分词和权重加载代码快速导航 (2026-08-25)                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

show_tokenizer_options() {
    echo "🔤 分词 (Tokenizer) 实现"
    echo ""
    echo "  [1] 快速导航到 Qwen Tokenizer (推荐)"
    echo "      📍 /src/inference/tokenizer/qwen_tokenizer.s"
    echo "      ✅ 性能最快、代码紧凑、适合 Qwen 模型"
    echo ""
    echo "  [2] 导航到 HF BPE Tokenizer (通用)"
    echo "      📍 /src/inference/tokenizer/hf_bpe_tokenizer.s"
    echo "      ✅ 支持所有 Hugging Face 模型"
    echo ""
    echo "  [3] 导航到完整 Tokenizer"
    echo "      📍 /src/inference/tokenizer/tokenizer_complete.s"
    echo "      ✅ 集成所有 tokenizer 版本"
    echo ""
    echo "  [4] 导航到 C++ 原生实现"
    echo "      📍 /src/runtime/model/bpe_tokenizer.cpp"
    echo "      ⚠️  高性能但复杂，不推荐修改"
    echo ""
}

show_weights_options() {
    echo "⚙️ 权重加载 (Weights Loading) 实现"
    echo ""
    echo "  [5] 快速导航到 SafeTensors Weight Loader (推荐)"
    echo "      📍 /src/inference/memory/model_loader/safetensors_weight_loader.s"
    echo "      ✅ 优化版本、快速、生产就绪"
    echo ""
    echo "  [6] 导航到 HF 权重转换"
    echo "      📍 /src/model/transformers/weight_conversion/safetensors_loader.s"
    echo "      ✅ Hugging Face 专用"
    echo ""
    echo "  [7] 导航到基础 SafeTensors 加载"
    echo "      📍 /src/inference/memory/model_loader/safetensors_loader.s"
    echo "      ✅ 核心实现"
    echo ""
    echo "  [8] 导航到 C++ 原生实现"
    echo "      📍 /src/runtime/model/safetensors.cpp"
    echo "      ⚠️  高性能但复杂，不推荐修改"
    echo ""
}

show_hf_model_options() {
    echo "🤖 HF 模型加载"
    echo ""
    echo "  [9] 导航到 HF Model Loader (推荐)"
    echo "      📍 /src/model/transformers/hf_model_loader.s"
    echo "      ✅ 集成 config + tokenizer + weights 加载"
    echo ""
    echo "  [10] 导航到 C++ 原生实现"
    echo "       📍 /src/runtime/model/hf_model.cpp"
    echo "       ⚠️  不推荐修改"
    echo ""
}

show_support_options() {
    echo "📋 支持模块"
    echo ""
    echo "  [11] 导航到 JSON 解析器 (迁移目标)"
    echo "       📍 /src/runtime/model/json.cpp"
    echo "       📍 /src/runtime/model/json_parser_pure_s.s (开发中)"
    echo ""
    echo "  [12] 显示完整代码位置指南"
    echo "       📍 /docs/tokenizer_weights_code_location_guide.s"
    echo ""
}

show_testing_options() {
    echo "🧪 测试"
    echo ""
    echo "  [13] 导航到 Tokenizer 测试"
    echo "       📍 /test/contract/hf_bpe_tokenizer_test.s"
    echo ""
    echo "  [0] 退出"
    echo ""
}

navigate_to_file() {
    local file="$NEURX_ROOT/$1"
    if [ -f "$file" ]; then
        echo "✅ 打开文件: $file"
        code "$file"
    else
        echo "❌ 文件不存在: $file"
        return 1
    fi
}

show_file_info() {
    local file="$NEURX_ROOT/$1"
    if [ -f "$file" ]; then
        local lines=$(wc -l < "$file")
        local size=$(ls -lh "$file" | awk '{print $5}')
        echo ""
        echo "📊 文件信息: $1"
        echo "   行数: $lines"
        echo "   大小: $size"
        echo "   路径: $file"
        echo ""
    fi
}

main() {
    show_header
    
    if [ -z "$1" ] || [ "$1" == "menu" ]; then
        # Interactive menu mode
        while true; do
            show_tokenizer_options
            show_weights_options
            show_hf_model_options
            show_support_options
            show_testing_options
            
            read -p "请选择 (0-13): " choice
            
            case "$choice" in
                1) navigate_to_file "src/inference/tokenizer/qwen_tokenizer.s" ;;
                2) navigate_to_file "src/inference/tokenizer/hf_bpe_tokenizer.s" ;;
                3) navigate_to_file "src/inference/tokenizer/tokenizer_complete.s" ;;
                4) navigate_to_file "src/runtime/model/bpe_tokenizer.cpp" ;;
                5) navigate_to_file "src/inference/memory/model_loader/safetensors_weight_loader.s" ;;
                6) navigate_to_file "src/model/transformers/weight_conversion/safetensors_loader.s" ;;
                7) navigate_to_file "src/inference/memory/model_loader/safetensors_loader.s" ;;
                8) navigate_to_file "src/runtime/model/safetensors.cpp" ;;
                9) navigate_to_file "src/model/transformers/hf_model_loader.s" ;;
                10) navigate_to_file "src/runtime/model/hf_model.cpp" ;;
                11) navigate_to_file "src/runtime/model/json.cpp" ;;
                12) 
                    show_file_info "docs/tokenizer_weights_code_location_guide.s"
                    navigate_to_file "docs/tokenizer_weights_code_location_guide.s"
                    ;;
                13) navigate_to_file "test/contract/hf_bpe_tokenizer_test.s" ;;
                0) 
                    echo "👋 再见！"
                    exit 0
                    ;;
                *)
                    echo "❌ 无效选择"
                    ;;
            esac
            
            read -p "按 Enter 继续..."
        done
    else
        # Command line mode - list all files
        echo "✅ 快速参考 - 所有代码位置"
        echo ""
        echo "🔤 分词实现:"
        find "$NEURX_ROOT" -name "*tokenizer*.s" -o -name "bpe_tokenizer.cpp" | sort
        echo ""
        echo "⚙️ 权重加载实现:"
        find "$NEURX_ROOT" -path "*/inference/memory/model_loader/*" -name "*.s" | sort
        find "$NEURX_ROOT" -path "*/transformers/weight*" -name "*.s" | sort
        echo ""
        echo "🤖 HF 模型加载:"
        find "$NEURX_ROOT" -name "*hf_model*" | sort
    fi
}

main "$@"
