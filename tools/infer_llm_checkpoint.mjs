import fs from 'node:fs/promises';
import path from 'node:path';

function resolveCheckpointPath(inputPath) {
  const root = inputPath || 'artifacts/checkpoints/llm_s_pretrain';
  if (root.endsWith('.neurx')) {
    return path.resolve(root);
  }
  return path.resolve(root, 'latest_checkpoint.txt');
}

async function loadCheckpointFile(inputPath) {
  const resolved = resolveCheckpointPath(inputPath);
  let checkpointPath = resolved;

  if (resolved.endsWith('.txt')) {
    const manifest = await fs.readFile(resolved, 'utf8');
    checkpointPath = manifest.trim();
  }

  const content = await fs.readFile(checkpointPath, 'utf8');
  return { checkpointPath, content };
}

function parseCsvNumbers(text) {
  if (!text) return [];
  return text.split(',').map((value) => Number.parseFloat(value.trim()));
}

function parseCsvInts(text) {
  if (!text) return [];
  return text.split(',').map((value) => Number.parseInt(value.trim(), 10));
}

function parseCheckpoint(content) {
  const lines = content
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  if (lines[0] !== 'checkpoint_v1') {
    throw new Error(`Unsupported checkpoint format: ${lines[0] || '<empty>'}`);
  }

  const record = {
    step: 0,
    loss: 0,
    paramCount: 0,
    weightsShape: [],
    biasShape: [],
    weights: [],
    bias: [],
  };

  for (const line of lines) {
    if (line.startsWith('step=')) {
      record.step = Number.parseInt(line.slice(5), 10);
    } else if (line.startsWith('loss=')) {
      record.loss = Number.parseFloat(line.slice(5));
    } else if (line.startsWith('param_count=')) {
      record.paramCount = Number.parseInt(line.slice('param_count='.length), 10);
    } else if (line.startsWith('param0.shape=')) {
      record.weightsShape = parseCsvInts(line.slice('param0.shape='.length));
    } else if (line.startsWith('param0.data=')) {
      record.weights = parseCsvNumbers(line.slice('param0.data='.length));
    } else if (line.startsWith('param1.shape=')) {
      record.biasShape = parseCsvInts(line.slice('param1.shape='.length));
    } else if (line.startsWith('param1.data=')) {
      record.bias = parseCsvNumbers(line.slice('param1.data='.length));
    }
  }

  if (record.paramCount < 2) {
    throw new Error(`Checkpoint param_count=${record.paramCount}, expected at least 2`);
  }
  if (record.weightsShape.length !== 2) {
    throw new Error(`Bad weight shape: ${record.weightsShape.join(',')}`);
  }
  if (record.biasShape.length !== 1) {
    throw new Error(`Bad bias shape: ${record.biasShape.join(',')}`);
  }

  return record;
}

function argmaxNext(weights, bias, prevId, vocabSize) {
  let base = prevId * vocabSize;
  if (base + vocabSize > weights.length) {
    base = 0;
  }

  let bestId = 0;
  let bestLogit = weights[base] + bias[0];
  for (let i = 1; i < vocabSize; i += 1) {
    const logit = weights[base + i] + bias[i];
    if (logit > bestLogit) {
      bestLogit = logit;
      bestId = i;
    }
  }
  return bestId;
}

function generateText(weights, bias, seed, maxNewChars) {
  const vocabSize = bias.length;
  let output = seed;
  let prevId = seed.length > 0 ? seed.charCodeAt(seed.length - 1) % vocabSize : 32;

  for (let i = 0; i < maxNewChars; i += 1) {
    const nextId = argmaxNext(weights, bias, prevId, vocabSize);
    output += String.fromCharCode(nextId);
    prevId = nextId;
  }

  return output;
}

async function main() {
  const checkpointArg = process.argv[2] || process.env.NEURX_INFER_CHECKPOINT || 'artifacts/checkpoints/llm_s_pretrain';
  const seed = process.argv[3] || process.env.NEURX_INFER_SEED || 'neurx ';
  const maxNewChars = Math.max(1, Number.parseInt(process.argv[4] || process.env.NEURX_INFER_MAX_NEW_CHARS || '120', 10) || 120);

  const { checkpointPath, content } = await loadCheckpointFile(checkpointArg);
  const checkpoint = parseCheckpoint(content);
  const generated = generateText(checkpoint.weights, checkpoint.bias, seed, maxNewChars);

  console.log('================================================');
  console.log('NeurX local checkpoint inference');
  console.log('================================================');
  console.log(`Checkpoint path: ${checkpointPath}`);
  console.log(`Step: ${checkpoint.step}`);
  console.log(`Loss: ${checkpoint.loss.toFixed(6)}`);
  console.log(`Param count: ${checkpoint.paramCount}`);
  console.log(`Weight shape: ${checkpoint.weightsShape.join('x')}`);
  console.log(`Bias shape: ${checkpoint.biasShape.join('x')}`);
  console.log(`Seed: ${seed}`);
  console.log('Generated:');
  console.log(generated);
  console.log('================================================');
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exitCode = 1;
});
