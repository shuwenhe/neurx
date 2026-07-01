#!/bin/bash

# NeurX Training + Inference Orchestrator
# 先训练，再推理，并生成一份可追踪的摘要

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
LOG_DIR="$PROJECT_DIR/artifacts/logs"
OUTPUT_DIR="$PROJECT_DIR/artifacts/train_and_infer"
CHECKPOINT_DIR="$PROJECT_DIR/artifacts/checkpoints/llm_training"
INFERENCE_DIR="$PROJECT_DIR/artifacts/inference_output"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
MASTER_LOG="$LOG_DIR/train_and_infer_${TIMESTAMP}.log"
SUMMARY_FILE="$OUTPUT_DIR/summary_${TIMESTAMP}.txt"

MODE="${1:-all}"
TRAIN_LOG="$LOG_DIR/train_and_infer_train_${TIMESTAMP}.log"
INFER_LOG="$LOG_DIR/train_and_infer_infer_${TIMESTAMP}.log"

NEURX_TOTAL_STEPS="${NEURX_TOTAL_STEPS:-10}"
NEURX_CHECKPOINT_INTERVAL="${NEURX_CHECKPOINT_INTERVAL:-1}"
NEURX_INFER_SMOKE_TEST="${NEURX_INFER_SMOKE_TEST:-1}"
NEURX_INFER_VALIDATE_ONLY="${NEURX_INFER_VALIDATE_ONLY:-}"
NEURX_INFER_MAX_NEW_CHARS="${NEURX_INFER_MAX_NEW_CHARS:-120}"

mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$CHECKPOINT_DIR" "$INFERENCE_DIR"

log() {
    printf '%s\n' "$*" | tee -a "$MASTER_LOG"
}

run_logged() {
    local log_file="$1"
    shift
    "$@" 2>&1 | tee -a "$log_file"
}

print_banner() {
    log "============================================================"
    log "NeurX Training + Inference Orchestrator"
    log "============================================================"
}

print_section() {
    log ""
    log "[$1]"
}

write_summary() {
    cat > "$SUMMARY_FILE" <<EOF
NeurX Training + Inference Summary
===================================

Mode: $MODE
Timestamp: $TIMESTAMP

Training
--------
Steps: $NEURX_TOTAL_STEPS
Checkpoint interval: $NEURX_CHECKPOINT_INTERVAL
Log: $TRAIN_LOG
Checkpoint dir: $CHECKPOINT_DIR

Inference
---------
Smoke test: $NEURX_INFER_SMOKE_TEST
Validate only: $NEURX_INFER_VALIDATE_ONLY
Max new chars: $NEURX_INFER_MAX_NEW_CHARS
Log: $INFER_LOG
Output dir: $INFERENCE_DIR

Artifacts
---------
Master log: $MASTER_LOG
Summary: $SUMMARY_FILE
EOF
}

run_training() {
    print_section "TRAIN"
    log "Running make train-llm"
    run_logged "$TRAIN_LOG" env \
        NEURX_TOTAL_STEPS="$NEURX_TOTAL_STEPS" \
        NEURX_CHECKPOINT_INTERVAL="$NEURX_CHECKPOINT_INTERVAL" \
        make -C "$PROJECT_DIR" train-llm
}

run_inference() {
    print_section "INFER"
    log "Running make infer"
    run_logged "$INFER_LOG" env \
        NEURX_INFER_SMOKE_TEST="$NEURX_INFER_SMOKE_TEST" \
        NEURX_INFER_VALIDATE_ONLY="$NEURX_INFER_VALIDATE_ONLY" \
        NEURX_INFER_MAX_NEW_CHARS="$NEURX_INFER_MAX_NEW_CHARS" \
        make -C "$PROJECT_DIR" infer
}

main() {
    print_banner
    log "Project: $PROJECT_DIR"
    log "Mode: $MODE"
    log "Logs: $MASTER_LOG"

    case "$MODE" in
        train-only)
            run_training
            ;;
        infer-only)
            run_inference
            ;;
        all)
            run_training
            run_inference
            ;;
        *)
            log "Unknown mode: $MODE"
            log "Usage: bash run_train_and_infer.sh [all|train-only|infer-only]"
            exit 1
            ;;
    esac

    write_summary

    print_section "DONE"
    log "Training checkpoint dir: $CHECKPOINT_DIR"
    log "Inference output dir: $INFERENCE_DIR"
    log "Summary file: $SUMMARY_FILE"
}

main "$@"
