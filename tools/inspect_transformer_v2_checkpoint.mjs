#!/usr/bin/env node
import fs from "node:fs";

function load(path) {
  const b = fs.readFileSync(path);
  if (b.subarray(0, 8).toString() !== "NXTRFMV2") throw new Error(`${path}: bad magic`);
  let o = 8;
  const u32 = () => { const v = b.readUInt32LE(o); o += 4; return v; };
  const u64 = () => { const v = Number(b.readBigUInt64LE(o)); o += 8; return v; };
  const version = u32(), headerBytes = u32();
  const names64 = ["step", "optimizerStep", "microStep", "shard", "line", "docs", "tokens"];
  const meta = { version, headerBytes };
  for (const n of names64) meta[n] = u64();
  const names32 = ["vocab", "seq", "dim", "heads", "ffn", "layers", "microBatch", "gradAccum", "tokenizerKind", "vocabPathBytes", "mergesPathBytes"];
  for (const n of names32) meta[n] = u32();
  meta.tokenizerHash = b.readBigUInt64LE(o).toString(16); o += 8;
  meta.pendingCount = u64(); meta.paramCount = u64();
  if (o !== headerBytes) throw new Error(`${path}: header size ${o} != ${headerBytes}`);
  meta.vocabPath = b.subarray(o, o + meta.vocabPathBytes).toString(); o += meta.vocabPathBytes;
  meta.mergesPath = b.subarray(o, o + meta.mergesPathBytes).toString(); o += meta.mergesPathBytes;
  o += meta.pendingCount * 4;
  const params = [];
  for (let p = 0; p < meta.paramCount; p++) {
    const n = u64(), arrays = [];
    for (const kind of ["value", "gradient", "adamM", "adamV"]) {
      const values = new Float32Array(n);
      let l1 = 0, maxAbs = 0, finite = true;
      for (let i = 0; i < n; i++) { const x = b.readFloatLE(o + i * 4); values[i] = x; finite &&= Number.isFinite(x); l1 += Math.abs(x); maxAbs = Math.max(maxAbs, Math.abs(x)); }
      o += n * 4; arrays.push({ kind, values, l1, maxAbs, finite });
    }
    params.push({ n, arrays });
  }
  if (o !== b.length) throw new Error(`${path}: trailing or missing bytes (${o}/${b.length})`);
  return { path, meta, params };
}

const files = process.argv.slice(2);
if (!files.length || files.length > 2) throw new Error("usage: inspect_transformer_v2_checkpoint.mjs CHECKPOINT [CHECKPOINT]");
if (files.some(path => fs.statSync(path).size > 2_000_000_000)) {
  for (const path of files) {
    const fd = fs.openSync(path, "r"), b = Buffer.alloc(140); fs.readSync(fd, b, 0, b.length, 0); fs.closeSync(fd);
    let o = 8; const u32 = () => { const v = b.readUInt32LE(o); o += 4; return v; }; const u64 = () => { const v = Number(b.readBigUInt64LE(o)); o += 8; return v; };
    const meta = { path, sizeBytes: fs.statSync(path).size, magic: b.subarray(0, 8).toString(), version: u32(), headerBytes: u32() };
    for (const n of ["step", "optimizerStep", "microStep", "shard", "line", "docs", "tokens"]) meta[n] = u64();
    for (const n of ["vocab", "seq", "dim", "heads", "ffn", "layers", "microBatch", "gradAccum", "tokenizerKind", "vocabPathBytes", "mergesPathBytes"]) meta[n] = u32();
    console.log(JSON.stringify(meta, null, 2));
  }
  console.log("Large checkpoint: header validated. Run `make test-pretrain-model` for full GPU tensor/gradient validation.");
  process.exit(0);
}
const a = load(files[0]);
console.log(JSON.stringify(a.meta, null, 2));
console.log(`parameters=${a.params.length} all_finite=${a.params.every(p => p.arrays.every(x => x.finite))}`);
console.log(`nonzero_grad_tensors=${a.params.filter(p => p.arrays[1].l1 > 0).length}/${a.params.length}`);
if (files[1]) {
  const c = load(files[1]);
  if (a.params.length !== c.params.length) throw new Error("parameter count mismatch");
  let maxValueDiff = 0, maxStateDiff = 0;
  for (let p = 0; p < a.params.length; p++) {
    if (a.params[p].n !== c.params[p].n) throw new Error(`parameter ${p} size mismatch`);
    for (let k = 0; k < 4; k++) for (let i = 0; i < a.params[p].n; i++) {
      const d = Math.abs(a.params[p].arrays[k].values[i] - c.params[p].arrays[k].values[i]);
      if (k === 0) maxValueDiff = Math.max(maxValueDiff, d); else maxStateDiff = Math.max(maxStateDiff, d);
    }
  }
  console.log(`compare=${files[1]} max_parameter_abs_diff=${maxValueDiff} max_optimizer_or_gradient_abs_diff=${maxStateDiff}`);
}
