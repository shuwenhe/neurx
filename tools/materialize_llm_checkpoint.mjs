import fs from 'node:fs/promises';
import path from 'node:path';

const outputDir = process.env.NEURX_OUTPUT_DIR || path.resolve('artifacts/checkpoints/llm_s_pretrain');
const defaultCorpusPath = process.env.NEURX_CORPUS_PATH || path.resolve('data/corpus/train_corpus.txt');
const vocabSize = Math.max(64, Number.parseInt(process.env.NEURX_VOCAB_SIZE || '256', 10) || 256);
const batchSize = Math.max(1, Number.parseInt(process.env.NEURX_BATCH_SIZE || '24', 10) || 24);
const totalSteps = Math.max(1, Number.parseInt(process.env.NEURX_S_PRETRAIN_STEPS || '80', 10) || 80);
const warmupSteps = Math.min(
  totalSteps,
  Math.max(1, Number.parseInt(process.env.NEURX_S_PRETRAIN_WARMUP_STEPS || '12', 10) || 12),
);
const initialLr = Math.max(0.01, Number.parseFloat(process.env.NEURX_INITIAL_LR || '0.22') || 0.22);
const minLr = Math.max(0.001, Number.parseFloat(process.env.NEURX_MIN_LR || '0.02') || 0.02);
const weightDecay = Math.max(0.0, Number.parseFloat(process.env.NEURX_WEIGHT_DECAY || '0.0001') || 0.0001);
const corpusRepeats = Math.max(1, Number.parseInt(process.env.NEURX_CORPUS_REPEATS || '128', 10) || 128);

function mod(a, b) {
  return b === 0 ? 0 : a - Math.trunc(a / b) * b;
}

function expApprox(x) {
  if (x > 20.0) return 485165195.0;
  if (x < -20.0) return 0.0;
  let result = 1.0;
  let term = 1.0;
  for (let i = 1; i <= 12; i += 1) {
    term = (term * x) / i;
    result += term;
  }
  return result;
}

function logApprox(x) {
  let v = x;
  if (v <= 0.0) v = 1e-12;
  const y = (v - 1.0) / (v + 1.0);
  const y2 = y * y;
  const y3 = y2 * y;
  const y5 = y3 * y2;
  return 2.0 * (y + (y3 / 3.0) + (y5 / 5.0));
}

function cosApprox(x) {
  const x2 = x * x;
  let term = 1.0;
  let result = 1.0;
  for (let i = 1; i <= 10; i += 2) {
    term = (-term * x2) / (i * (i + 1 - 1));
    result += term;
  }
  return result;
}

function intToStr(n) {
  return String(Math.trunc(n));
}

function fmtFloat(val, decimals) {
  return Number(val).toFixed(decimals);
}

function normalizeCorpusText(text) {
  return String(text)
    .replace(/\r\n/g, '\n')
    .replace(/[^\t\n\r\x20-\x7E]/g, ' ');
}

function textToBytes(text) {
  const bytes = [];
  for (let i = 0; i < text.length; i += 1) {
    const code = text.charCodeAt(i);
    if (code === 10 || code === 13 || code === 9 || (code >= 32 && code <= 126)) {
      bytes.push(code);
    } else {
      bytes.push(32);
    }
  }
  return bytes;
}

function fallbackCorpusText() {
  return [
    'NeurX trains local models with simple checkpoint files.',
    'The assistant should answer clearly, briefly, and directly.',
    'If the model is unsure, it should say that it is unsure.',
    'Question: what is NeurX?',
    'Answer: NeurX is a local training and inference stack.',
    'Question: how do you debug inference?',
    'Answer: check the checkpoint path, checkpoint format, and runner output.',
    'Question: why is the response empty?',
    'Answer: the checkpoint may be weak, the manifest may be wrong, or the prompt may be malformed.',
    'Question: what should a good checkpoint contain?',
    'Answer: a compatible format, a valid latest checkpoint pointer, and useful training data.',
    'Question: how should a chat tool respond?',
    'Answer: it should produce a useful answer instead of echoing the prompt.',
    'NeurX checkpoint generation should prefer the best model when it exists.',
    'Training data quality matters more than repeated boilerplate.',
  ].join('\n');
}

async function buildCorpus() {
  const chunks = [];

  if (defaultCorpusPath) {
    try {
      const corpusText = await fs.readFile(defaultCorpusPath, 'utf8');
      const cleaned = normalizeCorpusText(corpusText).trim();
      if (cleaned.length > 0) {
        chunks.push(cleaned);
      }
    } catch (err) {
      if (process.env.NEURX_CORPUS_PATH) {
        throw new Error(`Failed to read corpus at ${defaultCorpusPath}: ${err.message}`);
      }
    }
  }

  chunks.push(fallbackCorpusText());

  const baseText = normalizeCorpusText(chunks.join('\n')).trim();
  const base = textToBytes(baseText);
  const corpus = new Array(base.length * corpusRepeats);
  for (let rep = 0; rep < corpusRepeats; rep += 1) {
    for (let i = 0; i < base.length; i += 1) {
      corpus[rep * base.length + i] = base[i];
    }
  }
  return corpus;
}

function train(corpus) {
  const corpusLen = corpus.length;
  const paramCount = vocabSize * vocabSize;
  const weights = new Array(paramCount);
  const bias = new Array(vocabSize);

  for (let i = 0; i < paramCount; i += 1) {
    const bucket = mod(i, 23) - 11;
    weights[i] = bucket / 500.0;
  }
  for (let i = 0; i < vocabSize; i += 1) {
    bias[i] = 0.0;
  }

  let bestLoss = 9999.0;
  let currentLoss = 0.0;
  let tokensProcessed = 0;
  let bestWeights = weights.slice();
  let bestBias = bias.slice();

  for (let step = 1; step <= totalSteps; step += 1) {
    let batchLoss = 0.0;
    let lrVal;
    if (step <= warmupSteps) {
      lrVal = initialLr * step / warmupSteps;
    } else {
      let progress = (step - warmupSteps) / (totalSteps - warmupSteps);
      if (progress > 1.0) progress = 1.0;
      lrVal = minLr + 0.5 * (initialLr - minLr) * (1.0 + cosApprox(Math.PI * progress));
      if (lrVal < minLr) lrVal = minLr;
      if (lrVal > initialLr) lrVal = initialLr;
    }

    for (let b = 0; b < batchSize; b += 1) {
      const pos = mod(step * 17 + b * 13, corpusLen - 1);
      const inputId = corpus[pos];
      const targetId = corpus[pos + 1];
      const rowOffset = inputId * vocabSize;

      let maxLogit = weights[rowOffset] + bias[0];
      for (let c = 1; c < vocabSize; c += 1) {
        const logit = weights[rowOffset + c] + bias[c];
        if (logit > maxLogit) maxLogit = logit;
      }

      let sumExp = 0.0;
      const probs = new Array(vocabSize);
      for (let c = 0; c < vocabSize; c += 1) {
        const logit = weights[rowOffset + c] + bias[c];
        const e = expApprox(logit - maxLogit);
        probs[c] = e;
        sumExp += e;
      }

      let targetProb = 0.0;
      for (let c = 0; c < vocabSize; c += 1) {
        const p = probs[c] / sumExp;
        if (c === targetId) targetProb = p;
        let grad = p;
        if (c === targetId) grad -= 1.0;
        weights[rowOffset + c] = weights[rowOffset + c] - lrVal * (grad + weightDecay * weights[rowOffset + c]);
        bias[c] = bias[c] - lrVal * grad;
      }

      batchLoss += -logApprox(targetProb);
      tokensProcessed += 1;
    }

    currentLoss = batchLoss / batchSize;
    if (currentLoss < bestLoss) {
      bestLoss = currentLoss;
      bestWeights = weights.slice();
      bestBias = bias.slice();
    }
  }

  return {
    step: totalSteps,
    loss: currentLoss,
    bestLoss,
    tokensProcessed,
    weights,
    bias,
    bestWeights,
    bestBias,
  };
}

function serializeCheckpoint(step, loss, weights, bias) {
  const lines = [
    'checkpoint_v1',
    `step=${step}`,
    `loss=${fmtFloat(loss, 6)}`,
    'param_count=2',
    'param0.requires_grad=false',
    `param0.shape=${vocabSize},${vocabSize}`,
    `param0.data=${weights.map((v) => fmtFloat(v, 6)).join(',')}`,
    'param1.requires_grad=false',
    `param1.shape=${vocabSize}`,
    `param1.data=${bias.map((v) => fmtFloat(v, 6)).join(',')}`,
    '',
  ];
  return lines.join('\n');
}

async function main() {
  const corpus = await buildCorpus();
  const result = train(corpus);
  await fs.mkdir(outputDir, { recursive: true });
  const finalPath = path.join(outputDir, 'final_model.neurx');
  const bestPath = path.join(outputDir, 'best_model.neurx');
  const latestPath = path.join(outputDir, 'latest_checkpoint.txt');

  await fs.writeFile(finalPath, serializeCheckpoint(result.step, result.loss, result.weights, result.bias));
  await fs.writeFile(bestPath, serializeCheckpoint(result.step, result.bestLoss, result.bestWeights, result.bestBias));
  await fs.writeFile(latestPath, `${bestPath}\n`);

  console.log(`Materialized full checkpoint at ${outputDir}`);
  console.log(`Step: ${result.step}`);
  console.log(`Loss: ${fmtFloat(result.loss, 6)}`);
  console.log(`Best Loss: ${fmtFloat(result.bestLoss, 6)}`);
  console.log(`Tokens Processed: ${intToStr(result.tokensProcessed)}`);
  console.log(`Weights: ${result.weights.length}`);
  console.log(`Bias: ${result.bias.length}`);
  console.log(`Corpus Path: ${defaultCorpusPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
