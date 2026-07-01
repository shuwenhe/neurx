#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEURX_ROOT="$SCRIPT_DIR"
CONFIG_FILE="${NEURX_7B_CONFIG:-$NEURX_ROOT/configs/7b_training.json}"
TRAINER_SOURCE="${NEURX_7B_TRAINER_SOURCE:-$NEURX_ROOT/script/large_model_trainer.s}"
S_COMPILER="${S_COMPILER:-/Users/feifei/shuwen/train/s/.local/bin/s}"
BUILD_DIR="${NEURX_7B_BUILD_DIR:-$NEURX_ROOT/build/7b_training}"
BIN_FILE="$BUILD_DIR/large_model_trainer"
ENV_FILE="${NEURX_7B_ENV_FILE:-$BUILD_DIR/7b_training.env}"

mkdir -p "$BUILD_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file missing: $CONFIG_FILE" >&2
    exit 1
fi

if [ ! -f "$TRAINER_SOURCE" ]; then
    echo "❌ Trainer source missing: $TRAINER_SOURCE" >&2
    exit 1
fi

python3 - "$CONFIG_FILE" "$ENV_FILE" <<'PY'
import json
import sys

config_path, env_path = sys.argv[1], sys.argv[2]
with open(config_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

training = cfg.get("training", {})
distributed = cfg.get("distributed", {})
optimization = cfg.get("optimization", {})
data = cfg.get("data", {})
checkpoint = cfg.get("checkpoint", {})
logging_cfg = cfg.get("logging", {})

def b(value):
    return str(bool(value)).lower()

lines = [
    f"MODEL_SIZE=7b",
    f"NEURX_7B_CONFIG_FILE={config_path}",
    f"NEURX_7B_MODEL_NAME={cfg.get('model_name', 'neurx-7b')}",
    f"NEURX_7B_NUM_PARAMS={cfg.get('num_parameters', 7000000000)}",
    f"NEURX_7B_HIDDEN_SIZE={cfg.get('hidden_size', 4096)}",
    f"NEURX_7B_NUM_LAYERS={cfg.get('num_hidden_layers', 32)}",
    f"NEURX_7B_NUM_HEADS={cfg.get('num_attention_heads', 32)}",
    f"NEURX_7B_VOCAB_SIZE={cfg.get('vocab_size', 128000)}",
    f"NEURX_7B_MAX_SEQ_LEN={cfg.get('max_position_embeddings', 32768)}",
    f"NEURX_7B_BATCH_SIZE={training.get('batch_size', 8)}",
    f"NEURX_7B_GRADIENT_ACCUMULATION={training.get('gradient_accumulation_steps', 4)}",
    f"NEURX_7B_LEARNING_RATE={training.get('learning_rate', 5e-4)}",
    f"NEURX_7B_WARMUP_STEPS={training.get('warmup_steps', 1000)}",
    f"NEURX_7B_TOTAL_STEPS={training.get('num_training_steps', 100000)}",
    f"NEURX_7B_SAVE_STEPS={training.get('save_steps', 5000)}",
    f"NEURX_7B_LOG_STEPS={training.get('logging_steps', 100)}",
    f"NEURX_7B_EVAL_STEPS={training.get('eval_steps', 500)}",
    f"NEURX_7B_WEIGHT_DECAY={training.get('weight_decay', 0.01)}",
    f"NEURX_7B_MAX_GRAD_NORM={training.get('max_grad_norm', 1.0)}",
    f"WORLD_SIZE={distributed.get('world_size', 4)}",
    f"RANK={distributed.get('rank', 0)}",
    f"MASTER_ADDR={distributed.get('master_addr', 'localhost')}",
    f"MASTER_PORT={distributed.get('master_port', 29500)}",
    f"BACKEND={distributed.get('backend', 'nccl')}",
    f"ZERO_STAGE={distributed.get('zero_stage', 1)}",
    f"NEURX_7B_TENSOR_PARALLEL={distributed.get('tensor_parallel_size', 1)}",
    f"NEURX_7B_PIPELINE_PARALLEL={distributed.get('pipeline_parallel_stages', 1)}",
    f"NEURX_7B_DATASET={data.get('dataset_name', 'wikitext')}",
    f"NEURX_7B_DATASET_CONFIG={data.get('dataset_config', 'wikitext-103-v1')}",
    f"NEURX_7B_DATA_SPLIT={data.get('split', 'train')}",
    f"NEURX_7B_MAX_SEQ_LENGTH={data.get('max_seq_length', 4096)}",
    f"NEURX_7B_CACHE_DATASET={b(data.get('cache_dataset', True))}",
    f"NEURX_7B_DATA_STREAMING={b(data.get('streaming', True))}",
    f"NEURX_7B_DATA_SHUFFLE={b(data.get('shuffle', True))}",
    f"NEURX_7B_DATA_SEED={data.get('seed', 42)}",
    f"NEURX_7B_DATASET_ROOT={data.get('dataset_root', 'data/training_data_splits')}",
    f"NEURX_7B_DATA_MANIFEST={data.get('manifest_path', 'data/training_data_splits/manifest.json')}",
    f"NEURX_7B_TRAIN_MANIFEST={data.get('train_manifest_path', 'data/training_data_splits/train.jsonl')}",
    f"NEURX_7B_VAL_MANIFEST={data.get('val_manifest_path', 'data/training_data_splits/val.jsonl')}",
    f"NEURX_7B_TEST_MANIFEST={data.get('test_manifest_path', 'data/training_data_splits/test.jsonl')}",
    f"NEURX_7B_SHARD_DIR={data.get('shard_dir', 'data/training_data_shards')}",
    f"NEURX_7B_SHARD_MANIFEST={data.get('shard_manifest_path', 'data/training_data_shards/manifest.json')}",
    f"NEURX_7B_RESHARD_ON_START={b(data.get('reshard_on_start', True))}",
    f"NEURX_7B_EPOCH_SAMPLING={b(data.get('epoch_sampling', True))}",
    f"NEURX_7B_SHUFFLE_BUFFER_SIZE={data.get('shuffle_buffer_size', 10000)}",
    f"NEURX_7B_TOKENIZER_NAME={data.get('tokenizer_name', 'neurx-bpe')}",
    f"NEURX_7B_TOKENIZER_MODEL_PATH={data.get('tokenizer_model_path', 'tokenizer/neurx_bpe_128k.model')}",
    f"NEURX_7B_TOKENIZER_MERGES_PATH={data.get('tokenizer_merges_path', 'tokenizer/neurx_bpe_128k.merges')}",
    f"NEURX_7B_TOKENIZER_VOCAB_PATH={data.get('tokenizer_vocab_path', 'tokenizer/neurx_bpe_128k.vocab')}",
    f"NEURX_7B_TOKENIZER_MANIFEST_PATH={data.get('tokenizer_manifest_path', 'data/tokenizer.manifest')}",
    f"NEURX_7B_CHECKPOINT_DIR={checkpoint.get('save_path', 'checkpoints')}",
    f"NEURX_7B_RESUME_FROM_CHECKPOINT={checkpoint.get('resume_from_checkpoint', '') or ''}",
    f"NEURX_7B_SAVE_OPTIMIZER_STATE={b(checkpoint.get('save_optimizer_state', True))}",
    f"NEURX_7B_SAVE_RNG_STATE={b(checkpoint.get('save_rng_state', True))}",
    f"NEURX_7B_SAVE_SHARDED_OPTIMIZER_STATE={b(checkpoint.get('save_sharded_optimizer_state', True))}",
    f"NEURX_7B_CHECKPOINT_FORMAT={checkpoint.get('checkpoint_format', 'sharded')}",
    f"NEURX_7B_CHECKPOINT_VALIDATION={b(checkpoint.get('checkpoint_validation_enabled', True))}",
    f"NEURX_7B_CHECKPOINT_RESUME_STRICT={b(checkpoint.get('resume_strict', True))}",
    f"NEURX_7B_KEEP_LAST={checkpoint.get('keep_last', 3)}",
    f"NEURX_7B_SAVE_BEST_ONLY={b(checkpoint.get('save_best_only', False))}",
    f"NEURX_7B_LATEST_CHECKPOINT_FILE={checkpoint.get('latest_checkpoint_file', 'checkpoints/neurx-7b/latest_checkpoint.txt')}",
    f"NEURX_7B_LOG_OUTPUT_DIR={logging_cfg.get('output_dir', 'logs')}",
    f"NEURX_7B_METRICS_DIR={logging_cfg.get('metrics_dir', 'logs/metrics')}",
    f"NEURX_7B_CHECKPOINT_AUDIT_DIR={logging_cfg.get('checkpoint_audit_dir', 'logs/checkpoint_audit')}",
    f"NEURX_7B_STARTUP_REPORT_FILE={logging_cfg.get('startup_report_file', 'logs/startup_report.json')}",
    f"NEURX_7B_MIXED_PRECISION={b(optimization.get('mixed_precision', {}).get('enabled', True))}",
    f"NEURX_7B_MIXED_PRECISION_DTYPE={optimization.get('mixed_precision', {}).get('dtype', 'fp16')}",
    f"NEURX_7B_ACTIVATION_CHECKPOINTING={b(optimization.get('activation_checkpointing', {}).get('enabled', True))}",
    f"NEURX_7B_FLASH_ATTENTION={b(optimization.get('flash_attention', {}).get('enabled', True))}",
    f"NEURX_7B_FUSED_OPS={b(optimization.get('fused_operations', {}).get('enabled', True))}",
]

with open(env_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
PY

set -a
source "$ENV_FILE"
set +a

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  NeurX 7B Model Training Launcher                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo "Config: $CONFIG_FILE"
echo "Env:    $ENV_FILE"
echo "Build:  $BUILD_DIR"
echo ""
echo "Model:  $NEURX_7B_MODEL_NAME"
echo "Params: $NEURX_7B_NUM_PARAMS"
echo "World:  $WORLD_SIZE"
echo "Rank:   $RANK"
echo "Master: $MASTER_ADDR:$MASTER_PORT"
echo "SeqLen: $NEURX_7B_MAX_SEQ_LEN"
echo "Batch:  $NEURX_7B_BATCH_SIZE x $NEURX_7B_GRADIENT_ACCUMULATION"
echo "Checkpoint: $NEURX_7B_CHECKPOINT_DIR"
echo "Dataset: $NEURX_7B_DATASET / $NEURX_7B_DATASET_CONFIG"
echo "ShardDir: $NEURX_7B_SHARD_DIR"
echo "Tokenizer: $NEURX_7B_TOKENIZER_MODEL_PATH"
echo "Resume: $NEURX_7B_RESUME_FROM_CHECKPOINT"
echo "CheckpointFormat: $NEURX_7B_CHECKPOINT_FORMAT"
echo ""

if [ "${NEURX_7B_COMPILE_ONLY:-0}" = "1" ]; then
    echo "▶ 仅生成 7B 启动环境 (NEURX_7B_COMPILE_ONLY=1)"
    exit 0
fi

if ! command -v "$S_COMPILER" >/dev/null 2>&1 && [ ! -x "$S_COMPILER" ]; then
    echo "❌ S compiler not found: $S_COMPILER" >&2
    exit 1
fi

echo "▶ Compiling 7B trainer..."
if "$S_COMPILER" build "$TRAINER_SOURCE" -o "$BIN_FILE"; then
    echo "✓ Trainer compiled: $BIN_FILE"
else
    echo "❌ Failed to compile trainer source" >&2
    exit 1
fi

echo "▶ Launching 7B trainer..."
MODEL_SIZE="$MODEL_SIZE" \
WORLD_SIZE="$WORLD_SIZE" \
RANK="$RANK" \
MASTER_ADDR="$MASTER_ADDR" \
MASTER_PORT="$MASTER_PORT" \
CHECKPOINT_DIR="$NEURX_7B_CHECKPOINT_DIR" \
bash "$BIN_FILE"
