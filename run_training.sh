#!/bin/bash

set -euo pipefail

NEURX_DIR="/Users/feifei/train/neurx"
S_ROOT="/Users/feifei/train/s"
PYTHON_BIN="${PYTHON_BIN:-python3}"
REAL_TRAINER="$NEURX_DIR/run_real_training.py"

echo "======================================================================="
echo "NeurX 深度学习框架 - Real Training Entry"
echo "======================================================================="
echo ""

if [[ "${NEURX_USE_LEGACY_S:-0}" == "1" ]]; then
  SOURCE_FILE="$NEURX_DIR/train_llm.s"
  IR_FILE="$NEURX_DIR/build/train_llm.ir"
  RUNNER_SCRIPT="$NEURX_DIR/run_train_model_ir.sh"

  echo "✓ 创建 build 目录..."
  mkdir -p "$NEURX_DIR/build"
  echo ""

  echo "✓ 构建最新 seed 编译器 ..."
  cd "$S_ROOT"
  LATEST_COMPILER="$(./bin/build_s_arm64.sh)"
  echo "  编译器: $LATEST_COMPILER"
  echo ""

  echo "✓ 使用最新 seed 编译器编译 train_llm.s ..."
  echo "  编译器目录: $S_ROOT"
  echo "  源文件: $SOURCE_FILE"
  echo ""

  "$LATEST_COMPILER" "$SOURCE_FILE" "$IR_FILE"

  echo ""
  echo "✓ IR 编译成功: $IR_FILE"
  echo ""

  echo "======================================================================="
  echo "执行训练"
  echo "======================================================================="
  echo ""

  EVAL_OUTPUT_COMMAND=1 SOURCE_FILE="$SOURCE_FILE" IR_FILE="$IR_FILE" bash "$RUNNER_SCRIPT"

  echo ""
  echo "✓ source -> IR -> standalone runtime execution 已完成"
  echo "======================================================================="
  exit 0
fi

echo "✓ 使用 Python 真实训练流程..."
echo "  训练脚本: $REAL_TRAINER"
echo "  Python: $PYTHON_BIN"
echo ""

exec "$PYTHON_BIN" "$REAL_TRAINER" "$@"
