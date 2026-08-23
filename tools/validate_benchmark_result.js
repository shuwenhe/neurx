#!/usr/bin/env node
'use strict';

const fs = require('fs');

const file = process.argv[2];
if (!file) {
  process.stderr.write('usage: validate_benchmark_result.js <result.json>\n');
  process.exit(2);
}

let result;
try {
  result = JSON.parse(fs.readFileSync(file, 'utf8'));
} catch (error) {
  process.stderr.write(`invalid benchmark JSON: ${error.message}\n`);
  process.exit(1);
}

const failures = [];
const requireString = (value, path) => {
  if (typeof value !== 'string' || value.length === 0) failures.push(`${path} must be a non-empty string`);
};
const requireNumber = (value, path, minimum = 0) => {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < minimum) failures.push(`${path} must be >= ${minimum}`);
};

if (result.schema_version !== '1.0') failures.push('schema_version must be 1.0');
requireString(result.run_id, 'run_id');
requireString(result.created_at, 'created_at');
if (!result.system || !['neurx', 'vllm', 'sglang'].includes(result.system.engine)) failures.push('system.engine is invalid');
requireString(result.system?.engine_version, 'system.engine_version');
requireString(result.system?.accelerator, 'system.accelerator');
requireNumber(result.system?.accelerator_count, 'system.accelerator_count', 1);
requireString(result.system?.precision, 'system.precision');
requireString(result.model?.id, 'model.id');
requireString(result.model?.revision, 'model.revision');
requireNumber(result.workload?.repetitions, 'workload.repetitions', 3);
requireNumber(result.metrics?.ttft_ms_p50, 'metrics.ttft_ms_p50');
requireNumber(result.metrics?.tpot_ms_p50, 'metrics.tpot_ms_p50');
requireNumber(result.metrics?.request_latency_ms_p99, 'metrics.request_latency_ms_p99');
requireNumber(result.metrics?.output_tokens_per_second, 'metrics.output_tokens_per_second');
requireNumber(result.metrics?.requests_per_second, 'metrics.requests_per_second');
requireNumber(result.metrics?.error_rate, 'metrics.error_rate');
if (typeof result.metrics?.error_rate === 'number' && result.metrics.error_rate > 1) failures.push('metrics.error_rate must be <= 1');

if (failures.length > 0) {
  process.stderr.write(`${failures.join('\n')}\n`);
  process.exit(1);
}

process.stdout.write('Benchmark result validation passed.\n');
