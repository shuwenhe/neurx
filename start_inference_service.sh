#!/bin/bash

# NeurX 推理服务启动脚本
# 支持文本模型和 VL 模型部署

set -e

NEURX_HOME="/home/shuwen/shuwen/neurx"
MODEL_DIR="/model"
LOG_DIR="$NEURX_HOME/artifacts/logs"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 获取当前时间戳用于日志文件名
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "╔════════════════════════════════════════════════════╗"
echo "║         NeurX 推理服务启动向导                      ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "选择要启动的服务："
echo "  1) 文本模型推理服务 (Qwen2.5-0.5B-Instruct, 端口 8000)"
echo "  2) VL 多模态模型服务 (Qwen2.5-VL-7B, 端口 8001)"
echo "  3) 同时启动两个服务"
echo ""

# 如果没有提供参数，提示用户选择
if [ -z "$1" ]; then
    read -p "请选择 (1-3): " choice
else
    choice=$1
fi

case $choice in
    1)
        echo "🚀 启动文本模型推理服务..."
        echo "模型: Qwen2.5-0.5B-Instruct"
        echo "位置: /model/Qwen2.5-0.5B-Instruct"
        echo "端口: 8000"
        echo ""
        cd "$NEURX_HOME"
        make start-inference-service 2>&1 | tee -a "$LOG_DIR/inference_service_$TIMESTAMP.log"
        ;;
    2)
        echo "🚀 启动 VL 多模态推理服务..."
        echo "模型: Qwen2.5-VL-7B"
        echo "位置: /model/Qwen2.5-VL-7B"
        echo "端口: 8001"
        echo ""
        cd "$NEURX_HOME"
        make start-vl-inference 2>&1 | tee -a "$LOG_DIR/vl_inference_service_$TIMESTAMP.log"
        ;;
    3)
        echo "🚀 同时启动两个推理服务..."
        echo ""
        echo "终端 1: 文本模型服务 (端口 8000)"
        echo "终端 2: VL 模型服务 (端口 8001)"
        echo ""
        echo "启动文本模型..."
        cd "$NEURX_HOME"
        make start-inference-service 2>&1 | tee -a "$LOG_DIR/inference_service_$TIMESTAMP.log" &
        TEXT_PID=$!
        echo "文本服务 PID: $TEXT_PID"
        
        sleep 3
        
        echo ""
        echo "启动 VL 模型..."
        make start-vl-inference 2>&1 | tee -a "$LOG_DIR/vl_inference_service_$TIMESTAMP.log" &
        VL_PID=$!
        echo "VL 服务 PID: $VL_PID"
        
        echo ""
        echo "✅ 两个服务已启动!"
        echo "  • 文本模型: http://localhost:8000"
        echo "  • VL 模型:  http://localhost:8001"
        echo ""
        echo "按 Ctrl+C 停止所有服务"
        
        # 等待两个进程
        wait
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

echo ""
echo "✅ 服务启动完成！"
