#!/bin/bash
#
# Complete MedMCQA SFT Training Pipeline
# 
# Usage: bash train_medmcqa_sft.sh [--dry-run] [--data-only]
#

set -e

NEURX_ROOT="${NEURX_ROOT:-/home/shuwen/shuwen/train/neurx}"
MODEL_PATH="/home/shuwen/shuwen/train/model/Qwen2.5-0.5B-Instruct"
OUTPUT_MODEL="/home/shuwen/shuwen/train/model/base-model-posttrain-medmcqa"

DRY_RUN=false
DATA_ONLY=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --data-only)
            DATA_ONLY=true
            ;;
    esac
done

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           MedMCQA SFT Training Pipeline (NeurX)                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verify base model exists
if [ ! -d "$MODEL_PATH" ]; then
    echo "❌ ERROR: Base model not found at $MODEL_PATH"
    exit 1
fi

echo "Configuration:"
echo "  NeurX Root:       $NEURX_ROOT"
echo "  Base Model:       $MODEL_PATH"
echo "  Output Model:     $OUTPUT_MODEL"
echo ""

# STEP 1: Convert data
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/3: Converting MedMCQA dataset"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$DRY_RUN" = false ]; then
    # Check if data already exists
    if [ -f "/home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl" ]; then
        echo "✓ Training data already exists (reusing)"
        TRAIN_SIZE=$(wc -l < "/home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl")
        VAL_SIZE=$(wc -l < "/home/shuwen/shuwen/train/dataset/medmcqa/val.jsonl")
    else
        echo "Converting dataset..."
        bash "$NEURX_ROOT/scripts/convert_medmcqa.sh"
        TRAIN_SIZE=$(wc -l < "/home/shuwen/shuwen/train/dataset/medmcqa/train.jsonl")
        VAL_SIZE=$(wc -l < "/home/shuwen/shuwen/train/dataset/medmcqa/val.jsonl")
    fi
    echo ""
    echo "✓ Dataset ready:"
    echo "  Train: $TRAIN_SIZE examples"
    echo "  Val:   $VAL_SIZE examples"
    echo ""
fi

# STEP 2: Configure output model path
if [ "$DATA_ONLY" = false ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 2/3: Starting SFT Training"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would run:"
        echo "  cd $NEURX_ROOT"
        echo "  make posttrain"
        echo "  make posttrain-merge-lora"
    else
        cd "$NEURX_ROOT"
        
        echo "Starting training..."
        if make posttrain; then
            echo ""
            echo "✓ SFT training completed successfully"
            echo ""
            
            # STEP 3: Merge LoRA adapters
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Step 3/3: Merging LoRA Adapters"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            
            if make posttrain-merge-lora; then
                echo ""
                echo "✓ LoRA adapters merged successfully"
            else
                echo "❌ ERROR: LoRA merge failed"
                exit 1
            fi
        else
            echo "❌ ERROR: SFT training failed"
            exit 1
        fi
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Pipeline Complete                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [ "$DRY_RUN" = false ] && [ "$DATA_ONLY" = false ]; then
    echo "Outputs:"
    echo "  📊 Checkpoints: $NEURX_ROOT/artifacts/checkpoints/"
    echo "  🤖 LoRA Adapter: $NEURX_ROOT/artifacts/checkpoints/lora_adapter/"
    echo "  💾 Merged Model: $NEURX_ROOT/../model/base-model-posttrain/"
    echo ""
    echo "Next steps:"
    echo "  1. Evaluate: cd $NEURX_ROOT && make eval"
    echo "  2. Deploy:  Copy model to production"
    echo "  3. Align:   Use DPO/GRPO for further refinement"
    echo ""
fi
