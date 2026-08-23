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
const requireInteger = (value, path, minimum = 0) => {
  if (!Number.isInteger(value) || value < minimum) failures.push(`${path} must be an integer >= ${minimum}`);
};

if (result.schema_version !== '1.0') failures.push('schema_version must be 1.0');
requireString(result.run_id, 'run_id');
requireString(result.created_at, 'created_at');
if (typeof result.created_at === 'string' && Number.isNaN(Date.parse(result.created_at))) failures.push('created_at must be an ISO date-time');
if (result.git_commit !== undefined && !/^[0-9a-f]{40}$/.test(result.git_commit)) failures.push('git_commit must be a 40-character lowercase SHA');
if (!result.system || !['neurx', 'vllm', 'sglang'].includes(result.system.engine)) failures.push('system.engine is invalid');
requireString(result.system?.engine_version, 'system.engine_version');
requireString(result.system?.accelerator, 'system.accelerator');
requireInteger(result.system?.accelerator_count, 'system.accelerator_count', 1);
requireString(result.system?.precision, 'system.precision');
requireString(result.model?.id, 'model.id');
requireString(result.model?.revision, 'model.revision');
requireString(result.workload?.dataset, 'workload.dataset');
requireInteger(result.workload?.requests, 'workload.requests', 1);
requireInteger(result.workload?.concurrency, 'workload.concurrency', 1);
requireInteger(result.workload?.input_tokens, 'workload.input_tokens', 1);
requireInteger(result.workload?.output_tokens, 'workload.output_tokens', 1);
requireInteger(result.workload?.warmup_requests, 'workload.warmup_requests');
requireInteger(result.workload?.repetitions, 'workload.repetitions', 3);
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
