#!/usr/bin/env node
import fs from 'fs';
import path from 'path';

function parseArgs(argv) {
  const args = {
    input: '',
    output: '',
    samples: 4,
    hidden: 896,
    vout: 128,
  };
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--input') {
      args.input = argv[++i] || '';
    } else if (arg === '--output') {
      args.output = argv[++i] || '';
    } else if (arg === '--samples') {
      args.samples = Number(argv[++i] || '4');
    } else if (arg === '--hidden') {
      args.hidden = Number(argv[++i] || '896');
    } else if (arg === '--vout') {
      args.vout = Number(argv[++i] || '128');
    }
  }
  return args;
}

function textVector(text, dim) {
  const vec = new Array(dim).fill(0);
  for (let i = 0; i < text.length; i += 1) {
    const code = text.charCodeAt(i);
    const slot = i % dim;
    let component = 0.0009;
    if (code === 32) {
      component = -0.0004;
    } else if (code === 10 || code === 9) {
      component = -0.0007;
    } else if ('.,:;'.includes(String.fromCharCode(code))) {
      component = 0.0003;
    } else if (code >= 48 && code <= 57) {
      component = 0.0015;
    } else if ('aeiouAEIOU'.includes(String.fromCharCode(code))) {
      component = 0.002;
    }
    const position = ((i % 11) - 5) * 0.0002;
    vec[slot] += component + position;
  }
  const scale = 1 / (text.length + 1);
  for (let i = 0; i < vec.length; i += 1) {
    vec[i] *= scale;
  }
  return vec;
}

function optionForChoice(sample) {
  const choice = Number(sample.cop || 1);
  if (choice === 1) return sample.opa || sample.exp || sample.question || '';
  if (choice === 2) return sample.opb || sample.exp || sample.question || '';
  if (choice === 3) return sample.opc || sample.exp || sample.question || '';
  if (choice === 4) return sample.opd || sample.exp || sample.question || '';
  return sample.exp || sample.question || '';
}

function buildPrompt(sample) {
  const parts = [];
  if (sample.question) parts.push(sample.question);
  if (sample.subject_name) parts.push(`Subject: ${sample.subject_name}`);
  if (sample.topic_name) parts.push(`Topic: ${sample.topic_name}`);
  if (sample.opa || sample.opb || sample.opc || sample.opd) {
    parts.push(`A. ${sample.opa || ''}`);
    parts.push(`B. ${sample.opb || ''}`);
    parts.push(`C. ${sample.opc || ''}`);
    parts.push(`D. ${sample.opd || ''}`);
  }
  return parts.join('\n');
}

function buildTarget(sample) {
  return `${optionForChoice(sample)}\n${sample.exp || ''}`;
}

function emitVec(name, values) {
  const lines = [];
  lines.push(`    []float ${name} = []float{cap: ${values.length}}`);
  for (let i = 0; i < values.length; i += 1) {
    lines.push(`    ${name}[${i}] = ${values[i].toFixed(12)}`);
  }
  return lines.join('\n');
}

function emitSampleBlock(sample, idx, hidden, vout) {
  const prompt = textVector(buildPrompt(sample), hidden);
  const targetQ = textVector(buildTarget(sample), hidden);
  const targetV = textVector(buildTarget(sample), vout);
  const lines = [];
  const promptOffset = idx * hidden;
  const targetVOffset = idx * vout;
  for (let i = 0; i < prompt.length; i += 1) {
    lines.push(`    prompt[${promptOffset + i}] = ${prompt[i].toFixed(12)}`);
  }
  for (let i = 0; i < targetQ.length; i += 1) {
    lines.push(`    target_q[${promptOffset + i}] = ${targetQ[i].toFixed(12)}`);
  }
  for (let i = 0; i < targetV.length; i += 1) {
    lines.push(`    target_v[${targetVOffset + i}] = ${targetV[i].toFixed(12)}`);
  }
  return lines.join('\n');
}

function main() {
  const args = parseArgs(process.argv);
  if (!args.input || !args.output) {
    process.stderr.write('usage: materialize_posttrain_data.mjs --input FILE --output FILE [--samples N] [--hidden N] [--vout N]\n');
    process.exit(2);
  }
  const raw = fs.readFileSync(args.input, 'utf8');
  const lines = raw.split(/\r?\n/);
  const samples = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      const sample = JSON.parse(trimmed);
      if (sample.question) samples.push(sample);
    } catch (_) {
      continue;
    }
    if (samples.length >= args.samples) break;
  }
  if (samples.length === 0) {
    process.stderr.write(`no usable samples found in ${args.input}\n`);
    process.exit(1);
  }
  fs.mkdirSync(path.dirname(args.output), { recursive: true });
  const out = [];
  out.push('package neurx.posttrain.materialized');
  out.push('');
  out.push('struct posttrain_dataset {');
  out.push('    []float prompt');
  out.push('    []float target_q');
  out.push('    []float target_v');
  out.push('    int sample_count');
  out.push('    int prompt_dim');
  out.push('    int target_v_dim');
  out.push('}');
  out.push('');
  out.push('func posttrain_materialized_dataset() posttrain_dataset {');
  out.push(`    []float prompt = []float{cap: ${samples.length * args.hidden}}`);
  out.push(`    []float target_q = []float{cap: ${samples.length * args.hidden}}`);
  out.push(`    []float target_v = []float{cap: ${samples.length * args.vout}}`);
  for (let i = 0; i < samples.length; i += 1) {
    out.push(emitSampleBlock(samples[i], i, args.hidden, args.vout));
    out.push('');
  }
  out.push('    posttrain_dataset dataset');
  out.push('    dataset.prompt = prompt');
  out.push('    dataset.target_q = target_q');
  out.push('    dataset.target_v = target_v');
  out.push(`    dataset.sample_count = ${samples.length}`);
  out.push(`    dataset.prompt_dim = ${args.hidden}`);
  out.push(`    dataset.target_v_dim = ${args.vout}`);
  out.push('    return dataset');
  out.push('}');
  fs.writeFileSync(args.output, out.join('\n') + '\n');
}

main();
