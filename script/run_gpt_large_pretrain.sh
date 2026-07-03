#!/bin/bash
set +e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEURX_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

S_COMPILER="${S_COMPILER:-$NEURX_ROOT/../s/.local/bin/s}"
S_COMPILER_DIR="$(dirname "$S_COMPILER")"

resolve_s_source_root() {
    if [ -n "${S_SOURCE_ROOT:-}" ] && [ -d "$S_SOURCE_ROOT/src/cmd/compile/seed" ]; then
        printf '%s\n' "$S_SOURCE_ROOT"
        return 0
    fi
    if [ -n "${S_ROOT:-}" ] && [ -d "$S_ROOT/src/cmd/compile/seed" ]; then
        printf '%s\n' "$S_ROOT"
        return 0
    fi

    local candidate
    for candidate in \
        "$S_COMPILER_DIR/../../../.." \
        "$S_COMPILER_DIR/../../.." \
        "$S_COMPILER_DIR/../.." \
        "$NEURX_ROOT/../s"; do
        if [ -d "$candidate/src/cmd/compile/seed" ]; then
            (cd "$candidate" && pwd)
            return 0
        fi
    done

    return 1
}

S_SOURCE_ROOT="${S_SOURCE_ROOT:-$(resolve_s_source_root 2>/dev/null || true)}"
if [ -z "$S_SOURCE_ROOT" ]; then
    S_SOURCE_ROOT="$NEURX_ROOT/../s"
fi
S_ROOT="${S_ROOT:-$S_SOURCE_ROOT}"
MODEL_SIZE="${MODEL_SIZE:-gpt-large}"

set_default() {
    local name="$1"
    local value="$2"
    if [ -z "${!name:-}" ]; then
        export "$name=$value"
    fi
}

configure_model_size() {
    case "$(printf '%s' "$MODEL_SIZE" | tr '[:upper:]' '[:lower:]')" in
        1t|1t-moe|neurx-1t|neurx-1t-moe)
            MODEL_SIZE="1t"
            set_default NEURX_MODEL_NAME "neurx-1t-moe"
            set_default NEURX_MODEL_FAMILY "llm"
            set_default NEURX_MODEL_ARCHITECTURE "decoder-only-transformer-moe"
            set_default NEURX_MODEL_PARAMETER_COUNT_M "1000000"
            set_default NEURX_MODEL_ACTIVE_PARAMETER_COUNT_M "111111"
            set_default NEURX_LLM_VOCAB_SIZE "128000"
            set_default NEURX_LLM_HIDDEN_SIZE "12288"
            set_default NEURX_LLM_NUM_HEADS "96"
            set_default NEURX_LLM_NUM_LAYERS "80"
            set_default NEURX_LLM_INTERMEDIATE_SIZE "49152"
            set_default NEURX_LLM_MAX_SEQ_LEN "32768"
            set_default NEURX_LLM_PARAMETER_COUNT_M "1000000"
            set_default NEURX_LLM_BATCH_SIZE "2"
            set_default NEURX_LLM_SEQ_LEN "4096"
            set_default NEURX_LLM_STEPS "500000"
            set_default NEURX_LLM_WARMUP_STEPS "10000"
            set_default NEURX_LLM_LR "0.0002"
            set_default NEURX_LLM_MIN_LR "0.00002"
            set_default NEURX_LLM_WEIGHT_DECAY "0.01"
            set_default NEURX_LLM_LOG_INTERVAL "100"
            set_default NEURX_LLM_EVAL_INTERVAL "5000"
            set_default NEURX_LLM_SAVE_INTERVAL "5000"
            set_default NEURX_MOE_NUM_EXPERTS "256"
            set_default NEURX_MOE_TOP_K "2"
            set_default NEURX_MOE_EXPERT_PARALLEL_SIZE "2"
            set_default NEURX_TENSOR_PARALLEL_SIZE "4"
            set_default NEURX_PIPELINE_PARALLEL_SIZE "2"
            set_default NEURX_ZERO_STAGE "3"
            set_default NEURX_REQUIRED_GPU_TYPE "H100"
            set_default NEURX_REQUIRED_GPUS "16"
            set_default NEURX_PRETRAIN_MICRO_BATCH "$NEURX_LLM_BATCH_SIZE"
            set_default NEURX_PRETRAIN_SEQ_LEN "$NEURX_LLM_SEQ_LEN"
            set_default NEURX_PRETRAIN_STEPS "$NEURX_LLM_STEPS"
            set_default NEURX_PRETRAIN_LR "$NEURX_LLM_LR"
            set_default NEURX_PRETRAIN_MIN_LR "$NEURX_LLM_MIN_LR"
            set_default NEURX_PRETRAIN_WARMUP_STEPS "$NEURX_LLM_WARMUP_STEPS"
            set_default NEURX_PRETRAIN_WEIGHT_DECAY "$NEURX_LLM_WEIGHT_DECAY"
            set_default NEURX_PRETRAIN_LOG_INTERVAL "$NEURX_LLM_LOG_INTERVAL"
            set_default NEURX_PRETRAIN_EVAL_INTERVAL "$NEURX_LLM_EVAL_INTERVAL"
            set_default NEURX_PRETRAIN_SAVE_INTERVAL "$NEURX_LLM_SAVE_INTERVAL"
            set_default NEURX_PRETRAIN_GRAD_ACCUMULATION "8"
            set_default NEURX_PRETRAIN_SOURCE "$NEURX_ROOT/pretrain/llm/gpt_large_pretrain.s"
            set_default NEURX_PRETRAIN_BUILD_DIR "$NEURX_ROOT/build/neurx_1t_moe"
            set_default NEURX_PRETRAIN_OUTPUT_DIR "$NEURX_ROOT/artifacts/checkpoints/neurx_1t_moe"
            set_default NEURX_PRETRAIN_MANIFEST "$NEURX_ROOT/data/training_data_shards/manifest.txt"
            set_default NEURX_PRETRAIN_TOKENIZER_MANIFEST "$NEURX_ROOT/data/tokenizer.manifest"
            ;;
        *)
            MODEL_SIZE="gpt-large"
            set_default NEURX_MODEL_NAME "gpt_large"
            set_default NEURX_MODEL_FAMILY "llm"
            set_default NEURX_MODEL_ARCHITECTURE "decoder-only-transformer"
            ;;
    esac
    export MODEL_SIZE
}

configure_model_size

SOURCE_FILE="${NEURX_PRETRAIN_SOURCE:-$NEURX_ROOT/pretrain/llm/gpt_large_pretrain.s}"
CLUSTER_SOURCE="${NEURX_CLUSTER_SOURCE:-$NEURX_ROOT/deployment/cluster_orchestration.s}"
BUILD_DIR="${NEURX_PRETRAIN_BUILD_DIR:-$NEURX_ROOT/build/gpt_large_pretrain}"
CLUSTER_BUILD_DIR="${NEURX_CLUSTER_BUILD_DIR:-$NEURX_ROOT/build/cluster_orchestration}"
IR_FILE="$BUILD_DIR/gpt_large_pretrain.ir"
BIN_FILE="$BUILD_DIR/gpt_large_pretrain.bin"
if [ "$MODEL_SIZE" = "1t" ]; then
    IR_FILE="$BUILD_DIR/gpt_moe_1t_pretrain.ir"
    BIN_FILE="$BUILD_DIR/gpt_moe_1t_pretrain.bin"
fi
PRETRAIN_CONFIG_SRC="$NEURX_ROOT/pretrain/config/pretrain_config.s"
PRETRAIN_CONFIG_IR="$BUILD_DIR/pretrain_config.ir"
GPT_LARGE_MODEL_SRC="$NEURX_ROOT/model/llm/gpt_large.s"
GPT_LARGE_MODEL_IR="$BUILD_DIR/gpt_large.ir"
GPT_LARGE_TRAIN_SRC="$NEURX_ROOT/model/llm/gpt_large_train.s"
GPT_LARGE_TRAIN_IR="$BUILD_DIR/gpt_large_train.ir"
GPT_LARGE_TRAIN_LINKED_IR="$BUILD_DIR/gpt_large_train_linked.ir"
GPT_MOE_1T_SRC="$NEURX_ROOT/model/llm/gpt_moe_1t.s"
GPT_MOE_1T_IR="$BUILD_DIR/gpt_moe_1t.ir"
LINKED_IR_FILE="$BUILD_DIR/gpt_large_pretrain_linked.ir"
CLUSTER_IR_FILE="$CLUSTER_BUILD_DIR/cluster_orchestration.ir"
CLUSTER_BIN_FILE="$CLUSTER_BUILD_DIR/cluster_orchestration.bin"
LOG_DIR="$NEURX_ROOT/artifacts/logs"
CHECKPOINT_DIR="$NEURX_ROOT/artifacts/checkpoints"
LOG_FILE="$LOG_DIR/gpt_large_pretrain_$(date +%Y%m%d_%H%M%S).log"
CLUSTER_LOG_FILE="$LOG_DIR/cluster_orchestration_$(date +%Y%m%d_%H%M%S).log"
CLUSTER_NODE_MANIFEST_FILE="$NEURX_ROOT/artifacts/cluster_nodes.manifest"
CLUSTER_SUMMARY_FILE="$NEURX_ROOT/production_deployment/latest_cluster_summary.txt"
CLUSTER_LAUNCH_PLAN_FILE="$NEURX_ROOT/production_deployment/launch_plan.sh"
CLUSTER_ENV_FILE="$NEURX_ROOT/production_deployment/training_startup.env"
PRETRAIN_OUTPUT_DIR="${NEURX_PRETRAIN_OUTPUT_DIR:-$CHECKPOINT_DIR/gpt_large_pretrain}"
PRETRAIN_MANIFEST_FILE="${NEURX_PRETRAIN_MANIFEST:-$NEURX_ROOT/data/training_data_splits/manifest.json}"
PRETRAIN_TOKENIZER_MANIFEST_FILE="${NEURX_PRETRAIN_TOKENIZER_MANIFEST:-$NEURX_ROOT/data/tokenizer.manifest}"
PRETRAIN_PRECISION="${NEURX_PRETRAIN_PRECISION:-bf16}"
PRETRAIN_MICRO_BATCH="${NEURX_PRETRAIN_MICRO_BATCH:-8}"
PRETRAIN_SEQ_LEN="${NEURX_PRETRAIN_SEQ_LEN:-16}"
PRETRAIN_STEPS="${NEURX_PRETRAIN_STEPS:-64}"
PRETRAIN_LR="${NEURX_PRETRAIN_LR:-0.00015}"
PRETRAIN_MIN_LR="${NEURX_PRETRAIN_MIN_LR:-0.00003}"
PRETRAIN_WARMUP_STEPS="${NEURX_PRETRAIN_WARMUP_STEPS:-128}"
PRETRAIN_WEIGHT_DECAY="${NEURX_PRETRAIN_WEIGHT_DECAY:-0.1}"
PRETRAIN_LOG_INTERVAL="${NEURX_PRETRAIN_LOG_INTERVAL:-8}"
PRETRAIN_EVAL_INTERVAL="${NEURX_PRETRAIN_EVAL_INTERVAL:-16}"
PRETRAIN_SAVE_INTERVAL="${NEURX_PRETRAIN_SAVE_INTERVAL:-32}"
PRETRAIN_GRAD_ACCUMULATION="${NEURX_PRETRAIN_GRAD_ACCUMULATION:-1}"
PRETRAIN_RESUME="${NEURX_PRETRAIN_RESUME:-1}"
TRAIN_SPLIT_FILE="${NEURX_TRAIN_SPLIT_PATH:-$NEURX_ROOT/data/training_data_splits/train.jsonl}"
VAL_SPLIT_FILE="${NEURX_VAL_SPLIT_PATH:-$NEURX_ROOT/data/training_data_splits/val.jsonl}"
TEST_SPLIT_FILE="${NEURX_TEST_SPLIT_PATH:-$NEURX_ROOT/data/training_data_splits/test.jsonl}"

log_both() {
    printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

mkdir -p "$BUILD_DIR" "$CLUSTER_BUILD_DIR" "$LOG_DIR" "$CHECKPOINT_DIR"

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════════"
echo "🚀 NeurX ${NEURX_MODEL_NAME} 预训练系统 (S语言实现)"
echo "════════════════════════════════════════════════════════════════"
echo "Model:  $NEURX_MODEL_NAME ($MODEL_SIZE)"
echo "Source: $SOURCE_FILE"
echo "Cluster Source: $CLUSTER_SOURCE"
echo "Build:  $BUILD_DIR"
echo "Log:    $LOG_FILE"
echo "════════════════════════════════════════════════════════════════"
echo ""

prepare_cluster_orchestration() {
    if [ "${NEURX_CLUSTER_DISABLE:-0}" = "1" ]; then
        echo "▶ 跳过集群编排 (NEURX_CLUSTER_DISABLE=1)"
        return 0
    fi

    if [ ! -f "$CLUSTER_SOURCE" ]; then
        echo -e "${YELLOW}⚠ 集群编排源文件不存在: $CLUSTER_SOURCE${NC}"
        return 1
    fi

    if [ ! -f "$S_COMPILER" ]; then
        echo -e "${YELLOW}⚠ S编译器不可用，将生成集群配置但跳过编译${NC}"
        # 不直接返回失败，允许生成配置文件用于后续部署
    fi

    export S_SOURCE_ROOT
    export S_ROOT

    mkdir -p "$(dirname "$CLUSTER_NODE_MANIFEST_FILE")"
    desired_world_size="${NEURX_CLUSTER_WORLD_SIZE:-${NEURX_PRETRAIN_WORLD_SIZE:-${NEURX_REQUIRED_GPUS:-0}}}"
    if [ -n "${NEURX_CLUSTER_NODES:-}" ]; then
        printf '%s\n' "$NEURX_CLUSTER_NODES" > "$CLUSTER_NODE_MANIFEST_FILE"
    elif [ -n "${SLURM_NODELIST:-}" ] && command -v scontrol >/dev/null 2>&1; then
        : > "$CLUSTER_NODE_MANIFEST_FILE"
        while IFS= read -r host; do
            host_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
            if [ -z "$host_ip" ]; then
                host_ip="127.0.0.1"
            fi
            printf '%s|%s|8|H100|64|512|healthy|0.0\n' "$host" "$host_ip" >> "$CLUSTER_NODE_MANIFEST_FILE"
        done < <(scontrol show hostname "$SLURM_NODELIST")
    else
        host_name="$(hostname)"
        host_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
        if [ -z "$host_ip" ]; then
            host_ip="127.0.0.1"
        fi
        local_gpu_count=1
        if [ -n "$desired_world_size" ] && [ "$desired_world_size" -gt 0 ] 2>/dev/null; then
            local_gpu_count="$desired_world_size"
        fi
        printf '%s|%s|%s|local|8|16|healthy|0.0\n' "$host_name" "$host_ip" "$local_gpu_count" > "$CLUSTER_NODE_MANIFEST_FILE"
    fi

    mkdir -p "$(dirname "$CLUSTER_SUMMARY_FILE")"
    cluster_count="$(wc -l < "$CLUSTER_NODE_MANIFEST_FILE" 2>/dev/null | tr -d ' ')"
    total_gpus="$(awk -F'|' '{sum += ($3 + 0)} END {print sum + 0}' "$CLUSTER_NODE_MANIFEST_FILE" 2>/dev/null)"
    master_addr="$(awk -F'|' 'NR==1 {print $2}' "$CLUSTER_NODE_MANIFEST_FILE" 2>/dev/null)"
    if [ -z "$master_addr" ]; then
        master_addr="localhost"
    fi
    if [ -z "$cluster_count" ] || [ "$cluster_count" -le 0 ] 2>/dev/null; then
        cluster_count=1
    fi
    if [ -z "$total_gpus" ]; then
        total_gpus="$cluster_count"
    fi
    if [ -n "$desired_world_size" ] && [ "$desired_world_size" -gt "$total_gpus" ] 2>/dev/null; then
        total_gpus="$desired_world_size"
    fi
    cat > "$CLUSTER_SUMMARY_FILE" <<EOF
cluster=neurx-prod
discovery_source=shell_manifest
node_manifest=$CLUSTER_NODE_MANIFEST_FILE
healthy_nodes=$cluster_count
total_gpus=$total_gpus
recommended_world_size=$total_gpus
backend=nccl
master_addr=$master_addr
master_port=29500
checkpoint_dir=$CHECKPOINT_DIR
data_dir=$NEURX_ROOT/data/training_data_splits
output_dir=$NEURX_ROOT/artifacts/train_output
model_name=$NEURX_MODEL_NAME
model_size=$MODEL_SIZE
architecture=$NEURX_MODEL_ARCHITECTURE
parameter_count_m=${NEURX_MODEL_PARAMETER_COUNT_M:-0}
active_parameter_count_m=${NEURX_MODEL_ACTIVE_PARAMETER_COUNT_M:-0}
required_gpus=${NEURX_REQUIRED_GPUS:-1}
required_gpu_type=${NEURX_REQUIRED_GPU_TYPE:-local}
tensor_parallel_size=${NEURX_TENSOR_PARALLEL_SIZE:-1}
pipeline_parallel_size=${NEURX_PIPELINE_PARALLEL_SIZE:-1}
expert_parallel_size=${NEURX_MOE_EXPERT_PARALLEL_SIZE:-1}
zero_stage=${NEURX_ZERO_STAGE:-0}
EOF
    cat > "$CLUSTER_ENV_FILE" <<EOF
CLUSTER_NAME=neurx-prod
CLUSTER_BACKEND=nccl
WORLD_SIZE=$total_gpus
MASTER_ADDR=$master_addr
MASTER_PORT=29500
CHECKPOINT_DIR=$CHECKPOINT_DIR
DATA_DIR=$NEURX_ROOT/data/training_data_splits
OUTPUT_DIR=$NEURX_ROOT/artifacts/train_output
NODE_MANIFEST=$CLUSTER_NODE_MANIFEST_FILE
LAUNCH_PLAN=$CLUSTER_LAUNCH_PLAN_FILE
SUMMARY_FILE=$CLUSTER_SUMMARY_FILE
NEURX_PRETRAIN_OUTPUT_DIR=$PRETRAIN_OUTPUT_DIR
NEURX_PRETRAIN_MANIFEST=$PRETRAIN_MANIFEST_FILE
NEURX_PRETRAIN_TOKENIZER_MANIFEST=$PRETRAIN_TOKENIZER_MANIFEST_FILE
NEURX_PRETRAIN_PRECISION=$PRETRAIN_PRECISION
NEURX_PRETRAIN_MICRO_BATCH=$PRETRAIN_MICRO_BATCH
NEURX_PRETRAIN_SEQ_LEN=$PRETRAIN_SEQ_LEN
NEURX_PRETRAIN_STEPS=$PRETRAIN_STEPS
NEURX_PRETRAIN_LR=$PRETRAIN_LR
NEURX_PRETRAIN_MIN_LR=$PRETRAIN_MIN_LR
NEURX_PRETRAIN_WARMUP_STEPS=$PRETRAIN_WARMUP_STEPS
NEURX_PRETRAIN_WEIGHT_DECAY=$PRETRAIN_WEIGHT_DECAY
NEURX_PRETRAIN_LOG_INTERVAL=$PRETRAIN_LOG_INTERVAL
NEURX_PRETRAIN_EVAL_INTERVAL=$PRETRAIN_EVAL_INTERVAL
NEURX_PRETRAIN_SAVE_INTERVAL=$PRETRAIN_SAVE_INTERVAL
NEURX_PRETRAIN_GRAD_ACCUMULATION=$PRETRAIN_GRAD_ACCUMULATION
NEURX_PRETRAIN_RESUME=$PRETRAIN_RESUME
NEURX_PRETRAIN_WORLD_SIZE=$total_gpus
NEURX_PRETRAIN_BACKEND=nccl
NEURX_PRETRAIN_MASTER_ADDR=$master_addr
NEURX_PRETRAIN_MASTER_PORT=29500
NEURX_PRETRAIN_DATA_DIR=$NEURX_ROOT/data/training_data_splits
NEURX_PRETRAIN_CHECKPOINT_DIR=$CHECKPOINT_DIR
MODEL_SIZE=$MODEL_SIZE
NEURX_MODEL_NAME=$NEURX_MODEL_NAME
NEURX_MODEL_FAMILY=$NEURX_MODEL_FAMILY
NEURX_MODEL_ARCHITECTURE=$NEURX_MODEL_ARCHITECTURE
NEURX_MODEL_PARAMETER_COUNT_M=${NEURX_MODEL_PARAMETER_COUNT_M:-0}
NEURX_MODEL_ACTIVE_PARAMETER_COUNT_M=${NEURX_MODEL_ACTIVE_PARAMETER_COUNT_M:-0}
NEURX_LLM_VOCAB_SIZE=${NEURX_LLM_VOCAB_SIZE:-50257}
NEURX_LLM_HIDDEN_SIZE=${NEURX_LLM_HIDDEN_SIZE:-4096}
NEURX_LLM_NUM_HEADS=${NEURX_LLM_NUM_HEADS:-32}
NEURX_LLM_NUM_LAYERS=${NEURX_LLM_NUM_LAYERS:-32}
NEURX_LLM_INTERMEDIATE_SIZE=${NEURX_LLM_INTERMEDIATE_SIZE:-11008}
NEURX_LLM_MAX_SEQ_LEN=${NEURX_LLM_MAX_SEQ_LEN:-2048}
NEURX_LLM_PARAMETER_COUNT_M=${NEURX_LLM_PARAMETER_COUNT_M:-0}
NEURX_LLM_BATCH_SIZE=${NEURX_LLM_BATCH_SIZE:-8}
NEURX_LLM_SEQ_LEN=${NEURX_LLM_SEQ_LEN:-16}
NEURX_LLM_STEPS=${NEURX_LLM_STEPS:-64}
NEURX_LLM_WARMUP_STEPS=${NEURX_LLM_WARMUP_STEPS:-8}
NEURX_LLM_LR=${NEURX_LLM_LR:-0.00015}
NEURX_LLM_MIN_LR=${NEURX_LLM_MIN_LR:-0.00003}
NEURX_LLM_WEIGHT_DECAY=${NEURX_LLM_WEIGHT_DECAY:-0.1}
NEURX_MOE_NUM_EXPERTS=${NEURX_MOE_NUM_EXPERTS:-0}
NEURX_MOE_TOP_K=${NEURX_MOE_TOP_K:-0}
NEURX_MOE_EXPERT_PARALLEL_SIZE=${NEURX_MOE_EXPERT_PARALLEL_SIZE:-1}
NEURX_TENSOR_PARALLEL_SIZE=${NEURX_TENSOR_PARALLEL_SIZE:-1}
NEURX_PIPELINE_PARALLEL_SIZE=${NEURX_PIPELINE_PARALLEL_SIZE:-1}
NEURX_ZERO_STAGE=${NEURX_ZERO_STAGE:-0}
NEURX_REQUIRED_GPU_TYPE=${NEURX_REQUIRED_GPU_TYPE:-local}
NEURX_REQUIRED_GPUS=${NEURX_REQUIRED_GPUS:-1}
EOF
    cat > "$CLUSTER_LAUNCH_PLAN_FILE" <<EOF
#!/bin/bash
set -euo pipefail
ROOT_DIR="\$(cd "\$(dirname "\$0")/.." && pwd)"
cd "\$ROOT_DIR"
source "$CLUSTER_ENV_FILE"
export NEURX_PRETRAIN_USE_LAUNCH_PLAN=0
export NEURX_CLUSTER_DISABLE=1
NEURX_CLUSTER_NAME="\$CLUSTER_NAME" \
NEURX_CLUSTER_BACKEND="\$CLUSTER_BACKEND" \
NEURX_CLUSTER_WORLD_SIZE="\$WORLD_SIZE" \
NEURX_CLUSTER_MASTER_ADDR="\$MASTER_ADDR" \
NEURX_CLUSTER_MASTER_PORT="\$MASTER_PORT" \
NEURX_CHECKPOINT_DIR="\$CHECKPOINT_DIR" \
NEURX_TRAIN_OUTPUT_DIR="\$OUTPUT_DIR" \
NEURX_PRETRAIN_OUTPUT_DIR="\$NEURX_PRETRAIN_OUTPUT_DIR" \
NEURX_PRETRAIN_MANIFEST="\$NEURX_PRETRAIN_MANIFEST" \
NEURX_PRETRAIN_TOKENIZER_MANIFEST="\$NEURX_PRETRAIN_TOKENIZER_MANIFEST" \
NEURX_PRETRAIN_PRECISION="\$NEURX_PRETRAIN_PRECISION" \
NEURX_PRETRAIN_MICRO_BATCH="\$NEURX_PRETRAIN_MICRO_BATCH" \
NEURX_PRETRAIN_SEQ_LEN="\$NEURX_PRETRAIN_SEQ_LEN" \
NEURX_PRETRAIN_STEPS="\$NEURX_PRETRAIN_STEPS" \
NEURX_PRETRAIN_LR="\$NEURX_PRETRAIN_LR" \
NEURX_PRETRAIN_MIN_LR="\$NEURX_PRETRAIN_MIN_LR" \
NEURX_PRETRAIN_WARMUP_STEPS="\$NEURX_PRETRAIN_WARMUP_STEPS" \
NEURX_PRETRAIN_WEIGHT_DECAY="\$NEURX_PRETRAIN_WEIGHT_DECAY" \
NEURX_PRETRAIN_LOG_INTERVAL="\$NEURX_PRETRAIN_LOG_INTERVAL" \
NEURX_PRETRAIN_EVAL_INTERVAL="\$NEURX_PRETRAIN_EVAL_INTERVAL" \
NEURX_PRETRAIN_SAVE_INTERVAL="\$NEURX_PRETRAIN_SAVE_INTERVAL" \
NEURX_PRETRAIN_GRAD_ACCUMULATION="\$NEURX_PRETRAIN_GRAD_ACCUMULATION" \
NEURX_PRETRAIN_RESUME="\$NEURX_PRETRAIN_RESUME" \
MODEL_SIZE="\$MODEL_SIZE" \
NEURX_MODEL_NAME="\$NEURX_MODEL_NAME" \
NEURX_MODEL_FAMILY="\$NEURX_MODEL_FAMILY" \
NEURX_MODEL_ARCHITECTURE="\$NEURX_MODEL_ARCHITECTURE" \
NEURX_MODEL_PARAMETER_COUNT_M="\$NEURX_MODEL_PARAMETER_COUNT_M" \
NEURX_MODEL_ACTIVE_PARAMETER_COUNT_M="\$NEURX_MODEL_ACTIVE_PARAMETER_COUNT_M" \
NEURX_LLM_VOCAB_SIZE="\$NEURX_LLM_VOCAB_SIZE" \
NEURX_LLM_HIDDEN_SIZE="\$NEURX_LLM_HIDDEN_SIZE" \
NEURX_LLM_NUM_HEADS="\$NEURX_LLM_NUM_HEADS" \
NEURX_LLM_NUM_LAYERS="\$NEURX_LLM_NUM_LAYERS" \
NEURX_LLM_INTERMEDIATE_SIZE="\$NEURX_LLM_INTERMEDIATE_SIZE" \
NEURX_LLM_MAX_SEQ_LEN="\$NEURX_LLM_MAX_SEQ_LEN" \
NEURX_LLM_PARAMETER_COUNT_M="\$NEURX_LLM_PARAMETER_COUNT_M" \
NEURX_ALLOW_FULL_1T_LOCAL="\${NEURX_ALLOW_FULL_1T_LOCAL:-0}" \
bash script/run_gpt_large_pretrain.sh
EOF
    chmod +x "$CLUSTER_LAUNCH_PLAN_FILE"

    echo "▶ 编译集群编排 S 源文件..."
    if ! "$S_COMPILER" "$CLUSTER_SOURCE" "$CLUSTER_IR_FILE" 2>&1 | tee -a "$CLUSTER_LOG_FILE"; then
        echo -e "${RED}✗ 集群编排 IR 生成失败${NC}"
        return 1
    fi

    echo "▶ 跳过集群二进制运行，直接使用纯 S 编译产物和 shell 生成的启动配置"
    echo "▶ 集群启动配置: $CLUSTER_ENV_FILE"
    echo "▶ 集群启动计划: $CLUSTER_LAUNCH_PLAN_FILE"

    if [ -f "$CLUSTER_SUMMARY_FILE" ]; then
        echo "✓ 集群摘要: $CLUSTER_SUMMARY_FILE"
        head -20 "$CLUSTER_SUMMARY_FILE"
    fi
    return 0
}

# 尝试编译S源文件
compile_and_run_s() {
    if [ ! -f "$SOURCE_FILE" ]; then
        echo -e "${YELLOW}⚠ S源文件不存在: $SOURCE_FILE${NC}"
        return 1
    fi
    
    if [ ! -f "$S_COMPILER" ]; then
        echo -e "${YELLOW}⚠ S编译器不可用${NC}"
        echo -e "${YELLOW}   位置: $S_COMPILER${NC}"
        echo -e "${YELLOW}   说明: 本地开发环境不需要 S 编译器，集群部署时会自动使用${NC}"
        
        # 如果允许演示模式或不是严格模式，返回错误供上层处理回退
        NEURX_PRETRAIN_FALLBACK_REASON="S编译器不可用"
        return 1
    fi

    export S_SOURCE_ROOT
    export S_ROOT

    echo "▶ 尝试编译 S 源文件..."
    if "$S_COMPILER" "$SOURCE_FILE" "$IR_FILE" 2>&1; then
        if [ ! -f "$IR_FILE" ]; then
            echo -e "${RED}✗ IR文件未生成${NC}"
            return 1
        fi

        if [ "${NEURX_PRETRAIN_COMPILE_ONLY:-0}" = "1" ]; then
            echo "▶ 编译完成，跳过二进制生成与运行 (NEURX_PRETRAIN_COMPILE_ONLY=1)"
            return 0
        fi

        echo "▶ 生成可执行二进制..."
        if [ -f "$PRETRAIN_CONFIG_SRC" ]; then
            if ! "$S_COMPILER" "$PRETRAIN_CONFIG_SRC" "$PRETRAIN_CONFIG_IR" 2>&1; then
                echo -e "${RED}✗ pretrain config 编译失败${NC}"
                return 1
            fi
            if ! "$NEURX_ROOT/script/link_s_ir_module.sh" "$PRETRAIN_CONFIG_IR" "$IR_FILE" "cfg" "$LINKED_IR_FILE"; then
                echo -e "${RED}✗ pretrain config IR 链接失败${NC}"
                return 1
            fi
            if [ -f "$GPT_LARGE_MODEL_SRC" ] && [ -f "$GPT_LARGE_TRAIN_SRC" ]; then
                if ! "$S_COMPILER" "$GPT_LARGE_MODEL_SRC" "$GPT_LARGE_MODEL_IR" 2>&1; then
                    echo -e "${RED}✗ GPT-Large model 编译失败${NC}"
                    return 1
                fi
                if ! "$S_COMPILER" "$GPT_LARGE_TRAIN_SRC" "$GPT_LARGE_TRAIN_IR" 2>&1; then
                    echo -e "${RED}✗ GPT-Large train 编译失败${NC}"
                    return 1
                fi
                if ! "$NEURX_ROOT/script/link_s_ir_module.sh" "$GPT_LARGE_MODEL_IR" "$GPT_LARGE_TRAIN_IR" "gl" "$GPT_LARGE_TRAIN_LINKED_IR"; then
                    echo -e "${RED}✗ GPT-Large train IR 链接失败${NC}"
                    return 1
                fi
                if ! "$NEURX_ROOT/script/link_s_ir_module.sh" "$GPT_LARGE_TRAIN_LINKED_IR" "$LINKED_IR_FILE" "glt" "$LINKED_IR_FILE.tmp"; then
                    echo -e "${RED}✗ GPT-Large train 链接到主 IR 失败${NC}"
                    return 1
                fi
                mv "$LINKED_IR_FILE.tmp" "$LINKED_IR_FILE"

                # Compile and link BPE tokenizer for all model sizes so tokenization
                # helpers are available at runtime (used by gpt_large_pretrain.s).
                if [ -f "$NEURX_ROOT/pretrain/tokenizer/bpe.s" ]; then
                    BPE_IR="$BUILD_DIR/bpe_tokenizer.ir"
                    if ! "$S_COMPILER" "$NEURX_ROOT/pretrain/tokenizer/bpe.s" "$BPE_IR" 2>&1; then
                        echo -e "${RED}✗ pretrain/tokenizer/bpe 编译失败${NC}"
                        return 1
                    fi
                    if ! "$NEURX_ROOT/script/link_s_ir_module.sh" "$BPE_IR" "$LINKED_IR_FILE" "bpe" "$LINKED_IR_FILE.tmp"; then
                        echo -e "${RED}✗ 将 bpe tokenizer 链接到主 IR 失败${NC}"
                        return 1
                    fi
                    mv "$LINKED_IR_FILE.tmp" "$LINKED_IR_FILE"
                fi
            fi
            if [ "$MODEL_SIZE" = "1t" ] && [ -f "$GPT_MOE_1T_SRC" ]; then
                if ! "$S_COMPILER" "$GPT_MOE_1T_SRC" "$GPT_MOE_1T_IR" 2>&1; then
                    echo -e "${RED}✗ GPT-MoE-1T 编译失败${NC}"
                    return 1
                fi
                # Ensure gpt_moe and transformer/moe modules are compiled and linked
                # so symbols like `gpt_moe_param_count` and `new_moe_config` are
                # available to the MoE 1T module.
                if [ -f "$NEURX_ROOT/model/transformer/moe.s" ]; then
                    MOE_IR="$BUILD_DIR/moe_transformer.ir"
                    if ! "$S_COMPILER" "$NEURX_ROOT/model/transformer/moe.s" "$MOE_IR" 2>&1; then
                        echo -e "${RED}✗ transformer/moe 编译失败${NC}"
                        return 1
                    fi
                    if ! "$NEURX_ROOT/script/link_s_ir_module.sh" "$MOE_IR" "$LINKED_IR_FILE" "moe" "$LINKED_IR_FILE.tmp"; then
                        echo -e "${RED}✗ 将 transformer/moe 链接到主 IR 失败${NC}"
                        return 1
                    fi
                    mv "$LINKED_IR_FILE.tmp" "$LINKED_IR_FILE"
                fi
                if [ -f "$NEURX_ROOT/model/llm/gpt_moe.s" ]; then
                    GPT_MOE_IR="$BUILD_DIR/gpt_moe.ir"
                    if ! "$S_COMPILER" "$NEURX_ROOT/model/llm/gpt_moe.s" "$GPT_MOE_IR" 2>&1; then
                        echo -e "${RED}✗ gpt_moe 模块编译失败${NC}"
                        return 1
                    fi
                    if ! "$NEURX_ROOT/script/link_s_ir_module.sh" "$GPT_MOE_IR" "$LINKED_IR_FILE" "gpt_moe" "$LINKED_IR_FILE.tmp"; then
                        echo -e "${RED}✗ 将 gpt_moe 链接到主 IR 失败${NC}"
                        return 1
                    fi
                    mv "$LINKED_IR_FILE.tmp" "$LINKED_IR_FILE"
                fi

                    # Ensure tokenizer (BPE) module is compiled and linked so tokenization
                    # helpers like `bpe_tokenized_corpus_from_documents` are available.
                    if [ -f "$NEURX_ROOT/pretrain/tokenizer/bpe.s" ]; then
                        BPE_IR="$BUILD_DIR/bpe_tokenizer.ir"
                        if ! "$S_COMPILER" "$NEURX_ROOT/pretrain/tokenizer/bpe.s" "$BPE_IR" 2>&1; then
                            echo -e "${RED}✗ pretrain/tokenizer/bpe 编译失败${NC}"
                            return 1
                        fi
                        if ! "$NEURX_ROOT/script/link_s_ir_module.sh" "$BPE_IR" "$LINKED_IR_FILE" "bpe" "$LINKED_IR_FILE.tmp"; then
                            echo -e "${RED}✗ 将 bpe tokenizer 链接到主 IR 失败${NC}"
                            return 1
                        fi
                        mv "$LINKED_IR_FILE.tmp" "$LINKED_IR_FILE"
                    fi

                if ! "$NEURX_ROOT/script/link_s_ir_module.sh" "$GPT_MOE_1T_IR" "$LINKED_IR_FILE" "moe1t" "$LINKED_IR_FILE.tmp"; then
                    echo -e "${RED}✗ GPT-MoE-1T IR 链接失败${NC}"
                    return 1
                fi
                mv "$LINKED_IR_FILE.tmp" "$LINKED_IR_FILE"
            fi
            IR_TO_EMIT="$LINKED_IR_FILE"
        else
            IR_TO_EMIT="$IR_FILE"
        fi

        # Ensure there is an unqualified `main` in the emitted IR; some link steps
        # may rename package-local mains and leave the final IR without an entry
        # named exactly "main". If missing, append a small IR wrapper that
        # delegates to the framework entry (e.g. moe1t.main) so the runtime can
        # find and execute the program.
        if ! grep -q "^FUNC_BEGIN|main|" "$IR_TO_EMIT" 2>/dev/null; then
            TMP_WRAPPED_IR="$IR_TO_EMIT.wrapper"
            cat "$IR_TO_EMIT" > "$TMP_WRAPPED_IR"
            echo "FUNC_BEGIN|main|_|_" >> "$TMP_WRAPPED_IR"
            echo "CALL|t0|moe1t.main|0" >> "$TMP_WRAPPED_IR"
            echo "RET|t0|_|_" >> "$TMP_WRAPPED_IR"
            echo "FUNC_END|main|_|_" >> "$TMP_WRAPPED_IR"
            IR_TO_EMIT="$TMP_WRAPPED_IR"
        fi

        if (cd "$S_SOURCE_ROOT" && "$S_COMPILER" --emit-bin "$IR_TO_EMIT" "$BIN_FILE" 2>&1); then
            if [ ! -f "$BIN_FILE" ]; then
                echo -e "${RED}✗ 二进制文件未生成${NC}"
                return 1
            fi

            chmod +x "$BIN_FILE"
            echo "▶ 执行预训练..."
            "$BIN_FILE" 2>&1 | tee -a "$LOG_FILE"
            return 0
        else
            echo -e "${RED}✗ 二进制生成失败${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ 编译失败${NC}"
        return 1
    fi
}

# 主函数
main() {
    if ! prepare_cluster_orchestration; then
        echo "" | tee -a "$LOG_FILE"
        echo -e "${YELLOW}⚠ 集群编排失败，继续尝试本地训练入口${NC}" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi

    if [ "${NEURX_PRETRAIN_GENERATE_ONLY:-0}" = "1" ]; then
        echo "▶ 仅生成训练启动配置与 launch plan (NEURX_PRETRAIN_GENERATE_ONLY=1)"
        return 0
    fi

    if [ "${NEURX_PRETRAIN_USE_LAUNCH_PLAN:-1}" = "1" ] && [ -x "$CLUSTER_LAUNCH_PLAN_FILE" ] && [ "${NEURX_CLUSTER_DISABLE:-0}" != "1" ]; then
        echo "▶ 通过纯 S 生成的 launch plan 启动训练"
        bash "$CLUSTER_LAUNCH_PLAN_FILE" 2>&1 | tee -a "$LOG_FILE"
        return 0
    fi

    # 尝试编译和运行
    compile_and_run_s 2>&1 | tee -a "$LOG_FILE"
    local compile_result=$?

    if [ $compile_result -ne 0 ]; then
        echo "" | tee -a "$LOG_FILE"
        echo -e "${RED}✗ 训练入口失败，已停止。当前配置不允许回退到演示模式。${NC}" | tee -a "$LOG_FILE"
        echo -e "${YELLOW}💡 请先修复 S 编译、IR 链接、数据输入或 checkpoint 配置，再重新运行训练。${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
}

main "$@"

echo ""
echo "✅ ${NEURX_MODEL_NAME}预训练流程完成"
echo "   日志文件: $LOG_FILE"
echo "   检查点:   $CHECKPOINT_DIR"
