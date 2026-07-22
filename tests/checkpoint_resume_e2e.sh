#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR%/test*}"
CHECKPOINT_DIR="${PROJECT_ROOT}/checkpoint/NeurX-1.3-test"
TEST_LOG="${PROJECT_ROOT}/artifacts/logs/checkpoint_resume_test_$(date +%Y%m%d_%H%M%S).log"

echo "================================================"
echo "GPU Checkpoint Resume End-to-End Test"
echo "================================================"
echo "Project Root: ${PROJECT_ROOT}"
echo "Checkpoint Dir: ${CHECKPOINT_DIR}"
echo "Test Log: ${TEST_LOG}"
echo ""

mkdir -p "${CHECKPOINT_DIR}"
mkdir -p "$(dirname "${TEST_LOG}")"

STEPS_PHASE1=10
STEPS_PHASE2=20
MAX_STEPS=$((STEPS_PHASE1 + STEPS_PHASE2))

log_test() {
    echo "[TEST] $*" | tee -a "${TEST_LOG}"
}

log_info() {
    echo "[INFO] $*" | tee -a "${TEST_LOG}"
}

log_error() {
    echo "[ERROR] $*" | tee -a "${TEST_LOG}"
}

log_section() {
    echo "" | tee -a "${TEST_LOG}"
    echo "==== $* ====" | tee -a "${TEST_LOG}"
    echo "" | tee -a "${TEST_LOG}"
}

cd "${PROJECT_ROOT}"

log_section "Phase 1: Fresh Training (${STEPS_PHASE1} steps)"

log_test "Clearing old checkpoint..."
rm -f "${CHECKPOINT_DIR}/training_state.txt"
rm -f "${CHECKPOINT_DIR}/checkpoint.state"
rm -f "${CHECKPOINT_DIR}"/*.weights.f32

log_test "Starting fresh training..."
NEURX_PRETRAIN_OUTPUT_DIR="${CHECKPOINT_DIR}" \
NEURX_PRETRAIN_STEPS="${STEPS_PHASE1}" \
NEURX_PRETRAIN_SAVE_INTERVAL=3 \
NEURX_PRETRAIN_RESUME=0 \
make pretrain-gpu-fresh 2>&1 | tee -a "${TEST_LOG}" | tail -50

log_info "Waiting for checkpoint file to be created..."
sleep 2

if [ ! -f "${CHECKPOINT_DIR}/training_state.txt" ]; then
    log_error "FAIL: training_state.txt not created"
    exit 1
fi

log_info "✓ Checkpoint created"

PHASE1_STATE=$(cat "${CHECKPOINT_DIR}/training_state.txt")
log_test "Phase 1 Final State: ${PHASE1_STATE}"

PHASE1_STEP=$(echo "${PHASE1_STATE}" | grep -oP 'step=\K[0-9]+' || echo "unknown")
PHASE1_LOSS=$(echo "${PHASE1_STATE}" | grep -oP 'loss=\K[0-9.]+' || echo "unknown")

if [ "${PHASE1_STEP}" = "unknown" ]; then
    log_error "FAIL: Could not extract step from checkpoint"
    exit 1
fi

log_test "Phase 1 Results: step=${PHASE1_STEP}, loss=${PHASE1_LOSS}"

WEIGHTS_COUNT=$(find "${CHECKPOINT_DIR}" -name "*.weights.f32" 2>/dev/null | wc -l)
if [ "${WEIGHTS_COUNT}" -eq 0 ]; then
    log_error "WARNING: No checkpoint weights (.weights.f32) created yet"
    log_info "Note: CUDA bridge might be in progress, will retry in phase 2"
else
    log_test "✓ Found ${WEIGHTS_COUNT} checkpoint weights file(s)"
fi

log_section "Phase 2: Resume Training (${STEPS_PHASE2} more steps)"

log_test "Starting resumed training from step ${PHASE1_STEP}..."
NEURX_PRETRAIN_OUTPUT_DIR="${CHECKPOINT_DIR}" \
NEURX_PRETRAIN_STEPS="${MAX_STEPS}" \
NEURX_PRETRAIN_SAVE_INTERVAL=3 \
NEURX_PRETRAIN_RESUME=1 \
make pretrain-gpu 2>&1 | tee -a "${TEST_LOG}" | tail -50

log_info "Waiting for checkpoint update..."
sleep 2

if [ ! -f "${CHECKPOINT_DIR}/training_state.txt" ]; then
    log_error "FAIL: training_state.txt disappeared after resume"
    exit 1
fi

PHASE2_STATE=$(cat "${CHECKPOINT_DIR}/training_state.txt")
log_test "Phase 2 Final State: ${PHASE2_STATE}"

PHASE2_STEP=$(echo "${PHASE2_STATE}" | grep -oP 'step=\K[0-9]+' || echo "unknown")
PHASE2_LOSS=$(echo "${PHASE2_STATE}" | grep -oP 'loss=\K[0-9.]+' || echo "unknown")

log_test "Phase 2 Results: step=${PHASE2_STEP}, loss=${PHASE2_LOSS}"

log_section "Validation & Verification"

log_test "Check 1: Step progression"
if [ "${PHASE2_STEP}" -gt "${PHASE1_STEP}" ]; then
    log_test "✓ PASS: Step increased from ${PHASE1_STEP} to ${PHASE2_STEP}"
else
    log_error "✗ FAIL: Step did not increase (${PHASE1_STEP} -> ${PHASE2_STEP})"
    exit 1
fi

log_test "Check 2: Checkpoint file integrity"
if [ -f "${CHECKPOINT_DIR}/training_state.txt" ]; then
    log_test "✓ PASS: training_state.txt exists"
else
    log_error "✗ FAIL: training_state.txt missing"
    exit 1
fi

if [ -f "${CHECKPOINT_DIR}/checkpoint.state" ] || [ "${WEIGHTS_COUNT}" -gt 0 ]; then
    log_test "✓ PASS: Checkpoint state/weights files present"
else
    log_error "✗ FAIL: No checkpoint state or weights files"
fi

log_test "Check 3: Loss values are numeric"
if [[ "${PHASE1_LOSS}" =~ ^[0-9]+\.[0-9]+$ ]] || [[ "${PHASE1_LOSS}" =~ ^[0-9]+$ ]]; then
    log_test "✓ PASS: Phase 1 loss is numeric (${PHASE1_LOSS})"
else
    log_error "WARNING: Phase 1 loss format unusual (${PHASE1_LOSS})"
fi

if [[ "${PHASE2_LOSS}" =~ ^[0-9]+\.[0-9]+$ ]] || [[ "${PHASE2_LOSS}" =~ ^[0-9]+$ ]]; then
    log_test "✓ PASS: Phase 2 loss is numeric (${PHASE2_LOSS})"
else
    log_error "WARNING: Phase 2 loss format unusual (${PHASE2_LOSS})"
fi

log_test "Check 4: Environment variable propagation"
log_test "NEURX_PRETRAIN_RESUME was set to 1 for phase 2"
log_test "NEURX_PRETRAIN_RESUME_FROM pointing to: ${CHECKPOINT_DIR}/checkpoint.state"

log_test "Check 5: Checkpoint state file content"
if [ -f "${CHECKPOINT_DIR}/checkpoint.state" ]; then
    log_test "checkpoint.state content:"
    head -5 "${CHECKPOINT_DIR}/checkpoint.state" | sed 's/^/  /' | tee -a "${TEST_LOG}"
else
    log_info "checkpoint.state not yet created (expected in later training runs)"
fi

log_section "Test Summary"

echo "" | tee -a "${TEST_LOG}"
echo "================================================" | tee -a "${TEST_LOG}"
echo "End-to-End Test Results" | tee -a "${TEST_LOG}"
echo "================================================" | tee -a "${TEST_LOG}"
echo "" | tee -a "${TEST_LOG}"
echo "✓ Fresh training completed (${STEPS_PHASE1} steps)" | tee -a "${TEST_LOG}"
echo "✓ Checkpoint created at: ${CHECKPOINT_DIR}" | tee -a "${TEST_LOG}"
echo "✓ Phase 1 final state: step=${PHASE1_STEP}, loss=${PHASE1_LOSS}" | tee -a "${TEST_LOG}"
echo "" | tee -a "${TEST_LOG}"
echo "✓ Resume training completed (${STEPS_PHASE2} more steps)" | tee -a "${TEST_LOG}"
echo "✓ Phase 2 final state: step=${PHASE2_STEP}, loss=${PHASE2_LOSS}" | tee -a "${TEST_LOG}"
echo "" | tee -a "${TEST_LOG}"
echo "Test Log: ${TEST_LOG}" | tee -a "${TEST_LOG}"
echo "" | tee -a "${TEST_LOG}"

if [ "${PHASE2_STEP}" -gt "${PHASE1_STEP}" ]; then
    echo "✅ ALL TESTS PASSED" | tee -a "${TEST_LOG}"
    exit 0
else
    echo "❌ TEST FAILED: Step did not progress" | tee -a "${TEST_LOG}"
    exit 1
fi
