#!/bin/bash
# ============================================================================
# NeurX 数据清洗脚本
# 将 data/pretrain_dataset/raw 中的原始数据清洗为 cleaned 版本
# ============================================================================

set -euo pipefail

NEURX_HOME="${NEURX_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
# Allow overriding individual dirs; default to paths under NEURX_HOME
RAW_DIR="${RAW_DIR:-$NEURX_HOME/data/pretrain_dataset/raw}"
CLEANED_DIR="${CLEANED_DIR:-$NEURX_HOME/data/pretrain_dataset/cleaned}"
OUTPUT_FILE="${OUTPUT_FILE:-$CLEANED_DIR/pretrain_data_cleaned.jsonl}"
MANIFEST_FILE="${MANIFEST_FILE:-$NEURX_HOME/data/pretrain_dataset/manifest.json}"

mkdir -p "$CLEANED_DIR"

echo "╔════════════════════════════════════════════╗"
echo "║     NeurX 数据清洗流程 (Bash + Node)      ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "RAW_DIR: $RAW_DIR"
echo "CLEANED_DIR: $CLEANED_DIR"
echo "OUTPUT_FILE: $OUTPUT_FILE"
echo ""

export NEURX_RAW_DIR="$RAW_DIR"
export NEURX_CLEANED_DIR="$CLEANED_DIR"
export NEURX_OUTPUT_FILE="$OUTPUT_FILE"
export NEURX_MANIFEST_FILE="$MANIFEST_FILE"

node <<'NODE'
const fs = require('fs/promises');
const path = require('path');

const rawDir = process.env.NEURX_RAW_DIR;
const cleanedDir = process.env.NEURX_CLEANED_DIR;
const outputFile = process.env.NEURX_OUTPUT_FILE;
const manifestFile = process.env.NEURX_MANIFEST_FILE;

function normalizeText(text) {
  return String(text)
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .trim();
}

function compactKey(text) {
  return normalizeText(text).replace(/\s+/g, ' ');
}

function escapeJsonString(text) {
  return JSON.stringify(String(text));
}

async function readJsonlFile(filePath) {
  const content = await fs.readFile(filePath, 'utf8');
  return content.split(/\r?\n/).filter(Boolean);
}

async function main() {
  await fs.mkdir(cleanedDir, { recursive: true });

  const entries = await fs.readdir(rawDir, { withFileTypes: true });
  const sourceFiles = entries
    .filter((entry) => entry.isFile() && /\.(jsonl|txt)$/i.test(entry.name))
    .map((entry) => entry.name)
    .sort();

  const seen = new Set();
  const records = [];
  const stats = {
    total_documents: 0,
    valid_documents: 0,
    duplicates_removed: 0,
    empty_documents: 0,
    short_documents: 0,
    long_documents: 0,
    total_tokens_estimate: 0,
    total_size_bytes: 0,
  };

  for (const fileName of sourceFiles) {
    const fullPath = path.join(rawDir, fileName);
    const fileStat = await fs.stat(fullPath);
    stats.total_size_bytes += fileStat.size;

    if (fileName.endsWith('.txt')) {
      const rawText = normalizeText(await fs.readFile(fullPath, 'utf8'));
      stats.total_documents += 1;
      if (!rawText) {
        stats.empty_documents += 1;
        continue;
      }
      if (rawText.length < 50) {
        stats.short_documents += 1;
        continue;
      }
      const clipped = rawText.length > 100000 ? rawText.slice(0, 100000) : rawText;
      if (rawText.length > 100000) {
        stats.long_documents += 1;
      }
      const key = compactKey(clipped);
      if (seen.has(key)) {
        stats.duplicates_removed += 1;
        continue;
      }
      seen.add(key);
      records.push({
        text: clipped,
        metadata: {
          source_file: fileName,
          source_type: 'txt',
          source: 'raw',
          length: clipped.length,
          tokens_estimate: Math.max(1, Math.floor(clipped.length / 4)),
        },
      });
      stats.valid_documents += 1;
      stats.total_tokens_estimate += Math.max(1, Math.floor(clipped.length / 4));
      continue;
    }

    const lines = await readJsonlFile(fullPath);
    for (let index = 0; index < lines.length; index += 1) {
      stats.total_documents += 1;
      let item;
      try {
        item = JSON.parse(lines[index]);
      } catch {
        continue;
      }

      let text = '';
      if (typeof item.text === 'string') {
        text = normalizeText(item.text);
      } else if (typeof item.content === 'string') {
        text = normalizeText(item.content);
      } else if (typeof item.prompt === 'string' && typeof item.response === 'string') {
        text = normalizeText(`${item.prompt}\n${item.response}`);
      }

      if (!text) {
        stats.empty_documents += 1;
        continue;
      }
      if (text.length < 50) {
        stats.short_documents += 1;
        continue;
      }
      const clipped = text.length > 100000 ? text.slice(0, 100000) : text;
      if (text.length > 100000) {
        stats.long_documents += 1;
      }
      const key = compactKey(clipped);
      if (seen.has(key)) {
        stats.duplicates_removed += 1;
        continue;
      }
      seen.add(key);
      records.push({
        text: clipped,
        metadata: {
          source_file: fileName,
          source_type: 'jsonl',
          source: 'raw',
          source_index: index + 1,
          length: clipped.length,
          tokens_estimate: Math.max(1, Math.floor(clipped.length / 4)),
          original_keys: Object.keys(item).slice(0, 16),
        },
      });
      stats.valid_documents += 1;
      stats.total_tokens_estimate += Math.max(1, Math.floor(clipped.length / 4));
    }
  }

  const cleanedLines = records.map((record) => JSON.stringify(record));
  await fs.writeFile(outputFile, cleanedLines.join('\n') + (cleanedLines.length ? '\n' : ''));

  const total = records.length;
  const trainSize = Math.floor(total * 0.8);
  const valSize = Math.floor(total * 0.1);
  const testSize = total - trainSize - valSize;

  const trainLines = cleanedLines.slice(0, trainSize).join('\n');
  const valLines = cleanedLines.slice(trainSize, trainSize + valSize).join('\n');
  const testLines = cleanedLines.slice(trainSize + valSize).join('\n');

  await fs.writeFile(path.join(cleanedDir, 'train.jsonl'), trainLines + (trainLines ? '\n' : ''));
  await fs.writeFile(path.join(cleanedDir, 'val.jsonl'), valLines + (valLines ? '\n' : ''));
  await fs.writeFile(path.join(cleanedDir, 'test.jsonl'), testLines + (testLines ? '\n' : ''));

  if (manifestFile) {
    let manifest = {};
    try {
      manifest = JSON.parse(await fs.readFile(manifestFile, 'utf8'));
    } catch {
      manifest = {};
    }

    manifest.dataset_name = manifest.dataset_name || 'neurx-pretrain-dataset';
    manifest.version = manifest.version || '1.0';
    manifest.status = 'cleaned data generated';
    manifest.cleaned_file = 'cleaned/pretrain_data_cleaned.jsonl';
    manifest.cleaned_splits = {
      train: 'cleaned/train.jsonl',
      val: 'cleaned/val.jsonl',
      test: 'cleaned/test.jsonl',
    };
    manifest.raw_files = sourceFiles;
    manifest.statistics = {
      total_shards: manifest.statistics?.total_shards || 0,
      total_tokens: stats.total_tokens_estimate,
      total_documents: total,
      total_size_bytes: stats.total_size_bytes,
    };
    manifest.cleaning_stats = stats;
    await fs.writeFile(manifestFile, JSON.stringify(manifest, null, 2) + '\n');
  }

  console.log(`总原始文件: ${sourceFiles.length}`);
  console.log(`有效文档: ${stats.valid_documents}`);
  console.log(`去重数量: ${stats.duplicates_removed}`);
  console.log(`空文档: ${stats.empty_documents}`);
  console.log(`短文档: ${stats.short_documents}`);
  console.log(`长文档: ${stats.long_documents}`);
  console.log(`估计 tokens: ${stats.total_tokens_estimate}`);
  console.log(`清洗输出: ${outputFile}`);
  console.log(`训练分割: ${path.join(cleanedDir, 'train.jsonl')}`);
  console.log(`验证分割: ${path.join(cleanedDir, 'val.jsonl')}`);
  console.log(`测试分割: ${path.join(cleanedDir, 'test.jsonl')}`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exitCode = 1;
});
NODE

echo ""
echo "✨ 数据清洗流程完成"
echo "下一步可执行:"
echo "  bash train_1t_moe.sh"
