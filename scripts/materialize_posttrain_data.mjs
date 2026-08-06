#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
const { Array: array, Number: number, String: string } = globalThis;
function parse_args(argv) {
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
      args.samples = number(argv[++i] || '4');
    } else if (arg === '--hidden') {
      args.hidden = number(argv[++i] || '896');
    } else if (arg === '--vout') {
      args.vout = number(argv[++i] || '128');
    }
  }
  return args;
}
function text_vector(text, dim) {
  const vec = new array(dim).fill(0);
  for (let i = 0; i < text.length; i += 1) {
    const code = text.charCodeAt(i);
    const slot = i % dim;
    let component = 0.0009;
    if (code === 32) {
      component = -0.0004;
    } else if (code === 10 || code === 9) {
      component = -0.0007;
    } else if ('.,:;'.includes(string.fromCharCode(code))) {
      component = 0.0003;
    } else if (code >= 48 && code <= 57) {
      component = 0.0015;
    } else if ('aeiouAEIOU'.includes(string.fromCharCode(code))) {
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
function option_for_choice(sample) {
  const choice = number(sample.cop || 1);
  if (choice === 1) return sample.opa || sample.exp || sample.question || '';
  if (choice === 2) return sample.opb || sample.exp || sample.question || '';
  if (choice === 3) return sample.opc || sample.exp || sample.question || '';
  if (choice === 4) return sample.opd || sample.exp || sample.question || '';
  return sample.exp || sample.question || '';
}
function build_prompt(sample) {
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
function build_target(sample) {
  return `${optionForChoice(sample)}\n${sample.exp || ''}`;
}
function emit_vec(name, values) {
  const lines = [];
  lines.push(`    []float ${name} = []float{cap: ${values.length}}`);
  for (let i = 0; i < values.length; i += 1) {
    lines.push(`    ${name}[${i}] = ${values[i].toFixed(12)}`);
  }
  return lines.join('\n');
}
function emit_flat_array_function(func_name, samples, dim, value_selector, value_dim) {
  const lines = [];
  lines.push(`func ${func_name}() []float {`);
  lines.push(`    []float values = []float{cap: ${samples.length * value_dim}}`);
  for (let idx = 0; idx < samples.length; idx += 1) {
    const vector = value_selector(samples[idx], dim);
    const offset = idx * value_dim;
    for (let i = 0; i < vector.length; i += 1) {
      lines.push(`    values[${offset + i}] = ${vector[i].toFixed(12)}`);
    }
  }
  lines.push('    return values');
  lines.push('}');
  return lines.join('\n');
}
function write_float_text_file(file_path, values) {
  const lines = values.map((value) => value.toFixed(12));
  fs.writeFileSync(file_path, `${lines.join('\n')}\n`);
}
function main() {
  const args = parse_args(process.argv);
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
  out.push(emit_flat_array_function('posttrain_materialized_prompt', samples, args.hidden, (sample, dim) => textVector(build_prompt(sample), dim), args.hidden));
  out.push('');
  out.push(emit_flat_array_function('posttrain_materialized_target_q', samples, args.hidden, (sample, dim) => textVector(build_target(sample), dim), args.hidden));
  out.push('');
  out.push(emit_flat_array_function('posttrain_materialized_target_v', samples, args.vout, (sample, dim) => textVector(build_target(sample), dim), args.vout));
  fs.writeFileSync(args.output, out.join('\n') + '\n');
}
main();
