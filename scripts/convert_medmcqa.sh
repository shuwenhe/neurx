#!/bin/bash
# MedMCQA to SFT Converter Wrapper (S Language Framework + System Tools)
# 
# This is an S language integration point - the actual conversion is handled
# by S-callable system commands, maintaining S-first design

set -e

NEURX_ROOT="${NEURX_ROOT:-/home/shuwen/shuwen/train/neurx}"
MEDMCQA_INPUT="${MEDMCQA_INPUT:-/home/shuwen/shuwen/train/dataset/medmcqa/train.json}"
MEDMCQA_OUTPUT_DIR="${MEDMCQA_OUTPUT_DIR:-/home/shuwen/shuwen/train/dataset/medmcqa}"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ MedMCQA → SFT Dataset Converter                               ║"
echo "║ Framework: S Language (Scripts + System Integration)          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verify input
if [ ! -f "$MEDMCQA_INPUT" ]; then
    echo "❌ ERROR: Input file not found: $MEDMCQA_INPUT"
    exit 1
fi

echo "Configuration:"
echo "  NeurX root:    $NEURX_ROOT"
echo "  Input file:    $MEDMCQA_INPUT"
echo "  Output dir:    $MEDMCQA_OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$MEDMCQA_OUTPUT_DIR"

echo "Converting MedMCQA dataset..."
python3 << 'PYTHON_EOF'
import json
import sys
import os

input_file = os.environ.get('MEDMCQA_INPUT', '/home/shuwen/shuwen/train/dataset/medmcqa/train.json')
output_dir = os.environ.get('MEDMCQA_OUTPUT_DIR', '/home/shuwen/shuwen/train/dataset/medmcqa')

def medmcqa_to_sft(question_obj):
    """Convert MedMCQA format to SFT format"""
    q = question_obj
    
    instruction = "Answer the following medical multiple-choice question accurately."
    
    # Build input
    input_text = q.get('question', '') + "\n\nOptions:\n"
    input_text += f"A) {q.get('opa', '')}\n"
    input_text += f"B) {q.get('opb', '')}\n"
    input_text += f"C) {q.get('opc', '')}\n"
    input_text += f"D) {q.get('opd', '')}"
    
    # Build output
    correct = q.get('cop', -1)
    labels = ['A', 'B', 'C', 'D']
    output = f"Answer: {labels[correct] if 0 <= correct < 4 else 'Unknown'}"
    
    if q.get('exp'):
        output += f"\n\nExplanation: {q['exp']}"
    
    if q.get('subject_name'):
        output += f"\n\nSubject: {q['subject_name']}"
    if q.get('topic_name'):
        output += f" | Topic: {q['topic_name']}"
    
    return {
        "instruction": instruction,
        "input": input_text,
        "output": output
    }

# Read and convert
print(f"Reading {input_file}...")
with open(input_file) as f:
    lines = [line for line in f if line.strip()]

total = len(lines)
print(f"✓ Found {total} questions")

print("Converting to SFT format...")
train_size = int(total * 0.95)

train_examples = []
val_examples = []

for i, line in enumerate(lines):
    try:
        q_obj = json.loads(line)
        sft_ex = medmcqa_to_sft(q_obj)
        
        if i < train_size:
            train_examples.append(sft_ex)
        else:
            val_examples.append(sft_ex)
        
        if (i+1) % 20000 == 0:
            print(f"  Processed: {i+1}/{total}")
    except Exception as e:
        print(f"Warning: Skipped line {i+1}: {e}")

print(f"✓ Converted {len(train_examples) + len(val_examples)} examples")

# Write train.jsonl
train_file = os.path.join(output_dir, 'train.jsonl')
with open(train_file, 'w') as f:
    for ex in train_examples:
        f.write(json.dumps(ex) + '\n')
print(f"✓ {train_file} ({len(train_examples)} examples)")

# Write val.jsonl
val_file = os.path.join(output_dir, 'val.jsonl')
with open(val_file, 'w') as f:
    for ex in val_examples:
        f.write(json.dumps(ex) + '\n')
print(f"✓ {val_file} ({len(val_examples)} examples)")

print("")
print("✅ Conversion complete!")
PYTHON_EOF

echo ""
echo "Output files created:"
echo "  Train: $MEDMCQA_OUTPUT_DIR/train.jsonl"
echo "  Val:   $MEDMCQA_OUTPUT_DIR/val.jsonl"
echo ""
echo "Next: Configure Makefile and run 'make posttrain'"
echo ""
