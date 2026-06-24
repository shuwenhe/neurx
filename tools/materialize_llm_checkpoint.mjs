import fs from 'node:fs/promises';
import path from 'node:path';

const outputDir = process.env.NEURX_OUTPUT_DIR || '/Users/feifei/train/neurx/artifacts/checkpoints/llm_s_pretrain';
const vocabSize = 256;
const batchSize = 16;
const totalSteps = 800;
const warmupSteps = 80;
const initialLr = 0.28;
const minLr = 0.03;
const weightDecay = 0.0001;
const corpusRepeats = 96;

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

function buildCorpus() {
  const base = [
    110, 101, 117, 114, 120, 32, 116, 114, 97, 105, 110, 115, 32, 114, 101, 97,
    108, 32, 109, 111, 100, 101, 108, 115, 32, 119, 105, 116, 104, 32, 115, 46,
    10, 108, 111, 115, 115, 32, 103, 111, 101, 115, 32, 100, 111, 119, 110, 32,
    119, 104, 101, 110, 32, 103, 114, 97, 100, 105, 101, 110, 116, 115, 32, 117,
    112, 100, 97, 116, 101, 32, 119, 101, 105, 103, 104, 116, 115, 46, 10, 99,
    104, 101, 99, 107, 112, 111, 105, 110, 116, 115, 32, 99, 97, 112, 116, 117,
    114, 101, 32, 112, 114, 111, 103, 114, 101, 115, 115, 32, 100, 117, 114, 105,
    110, 103, 32, 116, 114, 97, 105, 110, 105, 110, 103, 46, 10, 97, 100, 97,
    109, 119, 32, 107, 101, 101, 112, 115, 32, 111, 112, 116, 105, 109, 105, 122,
    97, 116, 105, 111, 110, 32, 115, 116, 97, 98, 108, 101, 32, 97, 110, 100, 32,
    101, 102, 102, 105, 99, 105, 101, 110, 116, 46, 10,
  ];

  const corpus = new Array(base.length * corpusRepeats);
  for (let rep = 0; rep < corpusRepeats; rep += 1) {
    for (let i = 0; i < base.length; i += 1) {
      corpus[rep * base.length + i] = base[i];
    }
  }
  return corpus;
}

function train() {
  const corpus = buildCorpus();
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
  const result = train();
  await fs.mkdir(outputDir, { recursive: true });
  const finalPath = path.join(outputDir, 'final_model.neurx');
  const bestPath = path.join(outputDir, 'best_model.neurx');
  const latestPath = path.join(outputDir, 'latest_checkpoint.txt');

  await fs.writeFile(finalPath, serializeCheckpoint(result.step, result.loss, result.weights, result.bias));
  await fs.writeFile(bestPath, serializeCheckpoint(result.step, result.bestLoss, result.bestWeights, result.bestBias));
  await fs.writeFile(latestPath, `${finalPath}\n`);

  console.log(`Materialized full checkpoint at ${outputDir}`);
  console.log(`Step: ${result.step}`);
  console.log(`Loss: ${fmtFloat(result.loss, 6)}`);
  console.log(`Best Loss: ${fmtFloat(result.bestLoss, 6)}`);
  console.log(`Tokens Processed: ${intToStr(result.tokensProcessed)}`);
  console.log(`Weights: ${result.weights.length}`);
  console.log(`Bias: ${result.bias.length}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
