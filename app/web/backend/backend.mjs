/**
 * NeurX LLM Backend - Node.js implementation
 * Provides OpenAI-compatible chat API for local S-based model
 */

import fs from 'node:fs';
import path from 'node:path';

function jsonEscape(text) {
  if (typeof text !== 'string') return String(text);
  let out = '';
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === '\\') {
      out += '\\\\';
    } else if (ch === '"') {
      out += '\\"';
    } else if (ch === '\n') {
      out += '\\n';
    } else if (ch === '\r') {
      out += '\\r';
    } else if (ch === '\t') {
      out += '\\t';
    } else {
      out += ch;
    }
  }
  return out;
}

function gptLargeState() {
  return {
    name: 'gpt_large',
    family: 'llm',
    architecture: 'decoder-only-transformer',
    dataset: 'synthetic_webtext_mix',
    vocab_size: 50257,
    max_seq_len: 2048,
    hidden_size: 4096,
    num_heads: 32,
    num_layers: 32,
    intermediate_size: 11008,
    context_window: 2048,
    parameter_count_m: 3400,
    training_steps: 0,
    training_tokens_b: 0,
    train_loss: 3.8,
    train_perplexity: 44.0,
    validation_loss: 3.9,
    validation_perplexity: 49.0,
    learning_rate: 0.00015,
    dropout: 0.0,
    rope_base: 10000.0,
    tied_embeddings: true,
    gradient_accum_steps: 8,
    global_batch_tokens: 1048576,
    current_step: 0,
    seen_tokens: 0,
    best_validation_loss: 3.9,
    trained: false,
  };
}

function cloneState(state) {
  return { ...state };
}

function gptLargeSummary(state) {
  return `${state.name}[${state.architecture},${state.parameter_count_m}M,layers=${state.num_layers},heads=${state.num_heads},ctx=${state.context_window}]`;
}

function resolveArtifactContext() {
  const root = (process.env.NEURX_BACKEND_CHECKPOINT_ROOT || '').trim();
  const explicitFile = (process.env.NEURX_BACKEND_CHECKPOINT_FILE || '').trim();

  if (!root && !explicitFile) {
    return {
      checkpointRoot: '',
      checkpointFile: '',
      artifactReady: false,
    };
  }

  let checkpointFile = explicitFile;
  if (!checkpointFile && root) {
    let latest = { path: '', mtimeMs: -1 };

    const walk = (dir) => {
      let entries = [];
      try {
        entries = fs.readdirSync(dir, { withFileTypes: true });
      } catch {
        return;
      }

      for (const entry of entries) {
        const candidate = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          walk(candidate);
          continue;
        }
        if (!entry.isFile() || !candidate.endsWith('.neurx')) {
          continue;
        }
        try {
          const stat = fs.statSync(candidate);
          if (stat.mtimeMs >= latest.mtimeMs) {
            latest = { path: candidate, mtimeMs: stat.mtimeMs };
          }
        } catch {
          // Ignore unreadable files.
        }
      }
    };

    walk(root);
    checkpointFile = latest.path;
  }

  return {
    checkpointRoot: root,
    checkpointFile,
    artifactReady: checkpointFile.length > 0,
  };
}

function parseCheckpointSnapshot(text) {
  const snapshot = {
    checkpointVersion: '',
    modelName: '',
    family: '',
    architecture: '',
    dataset: '',
    step: 0,
    loss: 0,
    paramCount: 0,
    params: [],
    adapterProfile: [],
    adapterSignature: [],
    stageSignature: [],
    layerStates: [],
    fingerprint: 0,
    totalParamSum: 0,
    tokenBias: 0,
    lossScale: 1,
    profileSeed: 0,
    profileStride: 1,
    loaded: false,
  };

  if (!text) {
    return snapshot;
  }

  const paramMap = new Map();
  const lines = String(text).split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) {
      continue;
    }
    if (line.startsWith('# model:')) {
      snapshot.modelName = line.slice('# model:'.length).trim();
      continue;
    }
    if (line.startsWith('# family:')) {
      snapshot.family = line.slice('# family:'.length).trim();
      continue;
    }
    if (line.startsWith('# architecture:')) {
      snapshot.architecture = line.slice('# architecture:'.length).trim();
      continue;
    }
    if (line.startsWith('# dataset:')) {
      snapshot.dataset = line.slice('# dataset:'.length).trim();
      continue;
    }
    if (line === 'checkpoint_v1') {
      snapshot.checkpointVersion = line;
      snapshot.loaded = true;
      continue;
    }
    if (line.startsWith('step=')) {
      const parsed = Number.parseInt(line.slice('step='.length), 10);
      if (Number.isFinite(parsed)) {
        snapshot.step = parsed;
      }
      continue;
    }
    if (line.startsWith('loss=')) {
      const parsed = Number.parseFloat(line.slice('loss='.length));
      if (Number.isFinite(parsed)) {
        snapshot.loss = parsed;
      }
      continue;
    }
    if (line.startsWith('param_count=')) {
      const parsed = Number.parseInt(line.slice('param_count='.length), 10);
      if (Number.isFinite(parsed)) {
        snapshot.paramCount = parsed;
      }
      continue;
    }
    const paramMatch = /^param(\d+)\.(requires_grad|shape|data)=(.*)$/.exec(line);
    if (paramMatch) {
      const index = Number.parseInt(paramMatch[1], 10);
      const field = paramMatch[2];
      const value = paramMatch[3];
      let entry = paramMap.get(index);
      if (!entry) {
        entry = {
          index,
          requiresGrad: false,
          shape: [],
          data: [],
        };
      }
      if (field === 'requires_grad') {
        entry.requiresGrad = value === 'true' || value === '1';
      } else if (field === 'shape') {
        entry.shape = value
          .split(',')
          .map((part) => Number.parseInt(part.trim(), 10))
          .filter((part) => Number.isFinite(part));
      } else if (field === 'data') {
        entry.data = value
          .split(',')
          .map((part) => Number.parseFloat(part.trim()))
          .filter((part) => Number.isFinite(part));
      }
      paramMap.set(index, entry);
    }
  }

  snapshot.params = Array.from(paramMap.values()).sort((a, b) => a.index - b.index);
  if (!snapshot.paramCount) {
    snapshot.paramCount = snapshot.params.length;
  }

  let fingerprint = 0;
  let totalParamSum = 0;
  let weightedParamSum = 0;
  let profileSeed = 0;
  const adapterSignature = [];
  const adapterProfile = [];
  for (const param of snapshot.params) {
    const shapeSum = (param.shape || []).reduce((acc, value) => acc + value, 0);
    const shapeRank = (param.shape || []).length;
    const dataValues = (param.data || []).slice(0, 64);
    const dataSum = dataValues.reduce((acc, value) => acc + value, 0);
    const dataWeightedSum = dataValues.reduce((acc, value, index) => acc + value * (index + 1), 0);
    const dataChecksum = dataValues.reduce((acc, value, index) => acc + Math.round(value * 10000) * (index + 1), 0);
    const paramBias = Math.abs(Math.round(shapeSum * 31 + dataChecksum + param.index * 97)) % 65536;
    const paramWeight = 1 + (Math.abs(dataSum) % 7);
    let adapterKind = 'generic';
    if (shapeRank === 1) {
      adapterKind = param.index === 2 ? 'bias' : 'vector';
    } else if (shapeRank === 2) {
      adapterKind = param.index === 0 ? 'embedding' : 'projection';
    } else if (shapeRank >= 3) {
      adapterKind = 'transform';
    }
    fingerprint += shapeSum;
    fingerprint += dataValues.reduce((acc, value) => acc + Math.round(value * 1000), 0);
    totalParamSum += dataSum;
    weightedParamSum += dataWeightedSum + shapeSum;
    profileSeed += paramBias + shapeRank + Math.round(paramWeight * 10);
    adapterSignature.push(adapterKind);
    adapterProfile.push({
      index: param.index,
      bias: paramBias,
      weight: paramWeight,
      shapeRank,
      dataCount: dataValues.length,
      requiresGrad: !!param.requiresGrad,
      kind: adapterKind,
    });
  }
  snapshot.fingerprint = fingerprint;
  snapshot.totalParamSum = totalParamSum;
  snapshot.tokenBias = Math.abs(Math.round(weightedParamSum * 1000 + fingerprint)) % 65536;
  snapshot.lossScale = 1.0 + (Math.abs(totalParamSum) % 5.0) * 0.1;
  snapshot.adapterProfile = adapterProfile;
  snapshot.adapterSignature = adapterSignature;
  snapshot.stageSignature = buildStageSignature(adapterSignature);
  snapshot.layerStates = buildLayerStates(adapterProfile, snapshot.stageSignature);
  snapshot.profileSeed = profileSeed;
  snapshot.profileStride = Math.max(1, adapterProfile.length);

  return snapshot;
}

function loadArtifactSnapshot(context) {
  if (!context.checkpointFile) {
    return {
      ...context,
      checkpointSnapshot: parseCheckpointSnapshot(''),
      checkpointText: '',
    };
  }

  try {
    const checkpointText = fs.readFileSync(context.checkpointFile, 'utf8');
    return {
      ...context,
      checkpointSnapshot: parseCheckpointSnapshot(checkpointText),
      checkpointText,
    };
  } catch {
    return {
      ...context,
      checkpointSnapshot: parseCheckpointSnapshot(''),
      checkpointText: '',
    };
  }
}

function loadCheckpointModelState(baseState, artifact) {
  const snapshot = artifact.checkpointSnapshot || parseCheckpointSnapshot('');
  const state = cloneState(baseState);

  if (!snapshot.loaded) {
    return state;
  }

  state.name = snapshot.modelName || state.name;
  state.family = snapshot.family || state.family;
  state.architecture = snapshot.architecture || state.architecture;
  state.dataset = snapshot.dataset || state.dataset;
  state.training_steps = snapshot.step;
  state.current_step = snapshot.step;
  state.train_loss = snapshot.loss;
  state.train_perplexity = 1.0 + snapshot.loss * snapshot.loss * 3.0 * snapshot.lossScale;
  state.validation_loss = snapshot.loss + 0.08 * snapshot.lossScale;
  state.validation_perplexity = 1.0 + state.validation_loss * state.validation_loss * 3.0;
  state.best_validation_loss = Math.min(state.best_validation_loss, snapshot.loss);
  state.trained = snapshot.step > 0;
  state.checkpoint_step = snapshot.step;
  state.checkpoint_loss = snapshot.loss;
  state.checkpoint_param_count = snapshot.paramCount;
  state.checkpoint_fingerprint = snapshot.fingerprint;
  state.checkpoint_token_bias = snapshot.tokenBias;
  state.checkpoint_loss_scale = snapshot.lossScale;
  state.checkpoint_adapter_profile = snapshot.adapterProfile;
  state.checkpoint_adapter_signature = snapshot.adapterSignature;
  state.checkpoint_stage_signature = snapshot.stageSignature;
  state.checkpoint_layer_states = snapshot.layerStates;
  state.checkpoint_profile_seed = snapshot.profileSeed;
  state.checkpoint_profile_stride = snapshot.profileStride;
  state.checkpoint_loaded = true;
  return state;
}

function buildLayerStates(adapterProfile, stageSignature) {
  const layers = Array.isArray(adapterProfile) ? adapterProfile : [];
  const stage = stageSignature || { prefill: 'generic', decode: 'generic', finalize: 'generic' };
  return layers.map((entry) => {
    const kind = entry.kind || 'generic';
    const phaseScale = kind === stage.prefill
      ? 1.25
      : kind === stage.decode
        ? 1.15
        : kind === stage.finalize
          ? 1.35
          : 1.0;
    const promptScale = kind === 'embedding' ? 1.4 : kind === 'projection' ? 1.2 : kind === 'bias' ? 0.8 : 1.0;
    const stepScale = kind === 'embedding' ? 1.1 : kind === 'projection' ? 1.3 : kind === 'bias' ? 0.9 : 1.0;
    return {
      index: entry.index,
      kind,
      bias: entry.bias || 0,
      weight: entry.weight || 1,
      shapeRank: entry.shapeRank || 0,
      dataCount: entry.dataCount || 0,
      requiresGrad: !!entry.requiresGrad,
      phaseScale,
      promptScale,
      stepScale,
    };
  });
}

function initializeCheckpointRuntimeLayers(state, prompt, maxTokens) {
  const layers = Array.isArray(state.checkpoint_layer_states) ? state.checkpoint_layer_states : [];
  const promptLength = prompt.length;
  const step = Number.isFinite(state.current_step) ? state.current_step : 0;
  const tokenBias = Number.isFinite(state.checkpoint_token_bias) ? state.checkpoint_token_bias : 0;
  const seed = Number.isFinite(state.checkpoint_profile_seed) ? state.checkpoint_profile_seed : 0;

  return layers.map((layer, index) => {
    const promptScale = layer.promptScale || 1;
    const stepScale = layer.stepScale || 1;
    const phaseScale = layer.phaseScale || 1;
    const activation = Math.round(
      (layer.bias || 0)
      + (promptLength + index + 1) * promptScale
      + (maxTokens + step + 1) * stepScale
      + tokenBias * 0.01
    );

    return {
      ...layer,
      activation,
      promptEnergy: Math.round((promptLength + layer.dataCount + 1) * promptScale),
      decodeEnergy: Math.round((maxTokens + layer.weight + index + 1) * stepScale),
      finalizeEnergy: Math.round(((layer.bias || 0) % 97) + step + index + 1),
      phaseEnergy: Math.round((activation + seed + index) * phaseScale),
      stageCounts: {
        prefill: 0,
        decode: 0,
        finalize: 0,
      },
      rollingSignal: Math.abs((seed + tokenBias + layer.bias + index * 31) % 65536),
    };
  });
}

function runtimeLayerForPosition(runtimeLayers, state, position, maxTokens) {
  const layers = Array.isArray(runtimeLayers) ? runtimeLayers : [];
  if (layers.length === 0) {
    return null;
  }

  const stageName = stageNameForPosition(state, position, maxTokens);
  const matching = layers.filter((layer) => profileKindMatchesStage(layer.kind, stageName));
  const seed = Number.isFinite(state.checkpoint_profile_seed) ? state.checkpoint_profile_seed : 0;

  if (matching.length > 0) {
    return matching[Math.abs((position + seed) % matching.length)];
  }

  return layers[Math.abs((position + seed) % layers.length)];
}

function advanceCheckpointRuntimeLayers(state, runtimeLayers, tokenId, position, maxTokens) {
  const layers = Array.isArray(runtimeLayers) ? runtimeLayers : [];
  if (layers.length === 0) {
    return layers;
  }

  const stageName = stageNameForPosition(state, position, maxTokens);
  const selected = runtimeLayerForPosition(layers, state, position, maxTokens);
  const stageGainMap = {
    prefill: 11,
    decode: 17,
    finalize: 23,
  };
  const stageGain = stageGainMap[stageName] || 7;

  for (const layer of layers) {
    const kindBoost = layer.kind === 'embedding'
      ? 3
      : layer.kind === 'projection'
        ? 5
        : layer.kind === 'bias'
          ? 7
          : layer.kind === 'vector'
            ? 4
            : 2;
    const positionGain = Math.round((layer.weight || 1) * (position + 1) / (layer.index + 1));
    layer.rollingSignal = Math.abs((layer.rollingSignal + tokenId + position + kindBoost + stageGain) % 65536);
    layer.activation += Math.round((positionGain + kindBoost + stageGain) * (layer.stepScale || 1));
    if (!layer.stageCounts) {
      layer.stageCounts = {
        prefill: 0,
        decode: 0,
        finalize: 0,
      };
    }
    if (layer === selected) {
      layer.stageCounts[stageName] = (layer.stageCounts[stageName] || 0) + 1;
      layer.activation += Math.round((layer.promptEnergy || 0) + (layer.decodeEnergy || 0) + (layer.finalizeEnergy || 0)) % 97;
      layer.phaseEnergy = Math.round((layer.phaseEnergy || 0) + tokenId + position + stageGain);
    } else {
      layer.activation += Math.round(stageGain / (layer.index + 1));
    }
  }

  return layers;
}

function runtimeLayerSignal(state, runtimeLayers, position, maxTokens) {
  const selected = runtimeLayerForPosition(runtimeLayers, state, position, maxTokens);
  if (!selected) {
    return {
      activation: 0,
      signal: 0,
      promptEnergy: 0,
      decodeEnergy: 0,
      finalizeEnergy: 0,
      phaseEnergy: 0,
    };
  }

  return {
    activation: selected.activation || 0,
    signal: selected.rollingSignal || 0,
    promptEnergy: selected.promptEnergy || 0,
    decodeEnergy: selected.decodeEnergy || 0,
    finalizeEnergy: selected.finalizeEnergy || 0,
    phaseEnergy: selected.phaseEnergy || 0,
  };
}

function buildRuntimeLayerSummary(runtimeLayers) {
  const layers = Array.isArray(runtimeLayers) ? runtimeLayers : [];
  return layers.map((layer) => ({
    index: layer.index,
    kind: layer.kind,
    activation: layer.activation || 0,
    signal: layer.rollingSignal || 0,
    prompt_energy: layer.promptEnergy || 0,
    decode_energy: layer.decodeEnergy || 0,
    finalize_energy: layer.finalizeEnergy || 0,
    phase_energy: layer.phaseEnergy || 0,
    stage_counts: layer.stageCounts || { prefill: 0, decode: 0, finalize: 0 },
    bias: layer.bias || 0,
    weight: layer.weight || 1,
  }));
}

function buildStageSignature(adapterSignature) {
  const kinds = Array.isArray(adapterSignature) ? adapterSignature : [];
  const stage = {
    prefill: 'generic',
    decode: 'generic',
    finalize: 'generic',
  };
  if (kinds.length === 0) {
    return stage;
  }

  const hasEmbedding = kinds.includes('embedding');
  const hasProjection = kinds.includes('projection');
  const hasBias = kinds.includes('bias');
  const hasVector = kinds.includes('vector');
  const hasTransform = kinds.includes('transform');

  if (hasEmbedding) {
    stage.prefill = 'embedding';
  } else if (hasVector) {
    stage.prefill = 'vector';
  }
  if (hasProjection) {
    stage.decode = 'projection';
  } else if (hasTransform) {
    stage.decode = 'transform';
  }
  if (hasBias) {
    stage.finalize = 'bias';
  } else if (hasVector) {
    stage.finalize = 'vector';
  }
  return stage;
}

function checkpointProfileForPosition(state, position) {
  const layers = Array.isArray(state.checkpoint_layer_states) ? state.checkpoint_layer_states : [];
  if (layers.length === 0) {
    return {
      bias: Number.isFinite(state.checkpoint_token_bias) ? state.checkpoint_token_bias : 0,
      weight: 1,
      shapeRank: 0,
      dataCount: 0,
      requiresGrad: false,
      kind: 'generic',
      phaseScale: 1,
      promptScale: 1,
      stepScale: 1,
    };
  }

  const stride = Number.isFinite(state.checkpoint_profile_stride) && state.checkpoint_profile_stride > 0
    ? state.checkpoint_profile_stride
    : layers.length;
  const seed = Number.isFinite(state.checkpoint_profile_seed) ? state.checkpoint_profile_seed : 0;
  const index = Math.abs((position + seed) % stride) % layers.length;
  return layers[index];
}

function stageNameForPosition(state, position, maxTokens) {
  const prefillLimit = Math.max(1, Math.ceil(maxTokens / 3));
  const decodeLimit = Math.max(prefillLimit + 1, Math.ceil((maxTokens * 2) / 3));
  if (position < prefillLimit) {
    return 'prefill';
  }
  if (position >= decodeLimit) {
    return 'finalize';
  }
  return 'decode';
}

function profileKindMatchesStage(profileKind, stageName) {
  if (stageName === 'prefill') {
    return profileKind === 'embedding' || profileKind === 'vector';
  }
  if (stageName === 'decode') {
    return profileKind === 'projection' || profileKind === 'transform';
  }
  if (stageName === 'finalize') {
    return profileKind === 'bias' || profileKind === 'vector';
  }
  return true;
}

function stageSpecificProfile(state, position, maxTokens) {
  const profile = Array.isArray(state.checkpoint_adapter_profile) ? state.checkpoint_adapter_profile : [];
  if (profile.length === 0) {
    return checkpointProfileForPosition(state, position);
  }

  const stageName = stageNameForPosition(state, position, maxTokens);
  const matching = profile.filter((entry) => profileKindMatchesStage(entry.kind, stageName));
  if (matching.length > 0) {
    const seed = Number.isFinite(state.checkpoint_profile_seed) ? state.checkpoint_profile_seed : 0;
    return matching[Math.abs((position + seed) % matching.length)];
  }
  return checkpointProfileForPosition(state, position);
}

function stageSpecificBiases(state, maxTokens) {
  return {
    prefill: stageSpecificProfile(state, 0, maxTokens).bias || 0,
    decode: stageSpecificProfile(state, Math.max(1, Math.floor(maxTokens / 2)), maxTokens).bias || 0,
    finalize: stageSpecificProfile(state, Math.max(0, maxTokens - 1), maxTokens).bias || 0,
  };
}

function gptLargeNextToken(state, tokenId, position, maxTokens) {
  const tokenBias = Number.isFinite(state.checkpoint_token_bias) ? state.checkpoint_token_bias : 0;
  const fingerprintBias = Number.isFinite(state.checkpoint_fingerprint) ? state.checkpoint_fingerprint : 0;
  const tokenBudget = Number.isFinite(maxTokens) && maxTokens > 0
    ? maxTokens
    : (Number.isFinite(state.checkpoint_max_tokens) ? state.checkpoint_max_tokens : 4);
  const profile = stageSpecificProfile(state, position, tokenBudget);
  const stageName = stageNameForPosition(state, position, tokenBudget);
  const stageSignature = state.checkpoint_stage_signature || { prefill: 'generic', decode: 'generic', finalize: 'generic' };
  const stageKind = stageSignature[stageName] || 'generic';
  const runtimeLayers = Array.isArray(state.checkpoint_runtime_layer_states) ? state.checkpoint_runtime_layer_states : [];
  const runtimeSignal = runtimeLayerSignal(state, runtimeLayers, position, tokenBudget);
  const profileBias = profile.bias || 0;
  const profileWeight = profile.weight || 1;
  const gradBonus = profile.requiresGrad ? 13 : 7;
  const rankBonus = profile.shapeRank || 0;
  const kindBonusMap = {
    embedding: 19,
    projection: 23,
    bias: 11,
    vector: 17,
    transform: 29,
    generic: 5,
  };
  const kindBonus = kindBonusMap[profile.kind] || kindBonusMap.generic;
  const stageBonusMap = {
    embedding: 31,
    projection: 37,
    bias: 17,
    vector: 23,
    transform: 41,
    generic: 3,
  };
  const stageBonus = stageBonusMap[stageKind] || stageBonusMap.generic;
  const stageBias = stageSpecificBiases(state, tokenBudget)[stageName] || 0;
  const layerScale = profile.phaseScale || 1;
  const promptScale = profile.promptScale || 1;
  const stepScale = profile.stepScale || 1;
  let nextToken = tokenId + position + state.num_layers + state.num_heads + tokenBias + fingerprintBias;
  nextToken += Math.round((profileBias + Math.round(profileWeight * 11) + gradBonus + rankBonus + kindBonus) * layerScale);
  nextToken += Math.round(stageBonus * stepScale);
  nextToken += Math.round(stageBias * promptScale);
  nextToken += Math.round((runtimeSignal.activation % 997) * 0.5);
  nextToken += Math.round((runtimeSignal.signal % 389) * 0.25);
  nextToken += Math.round((runtimeSignal.phaseEnergy % 251) * 0.2);
  if (state.vocab_size > 0) {
    nextToken = nextToken - Math.floor(nextToken / state.vocab_size) * state.vocab_size;
  }
  return nextToken;
}

function simulateCheckpointGeneration(state, prompt, maxTokens) {
  state.checkpoint_max_tokens = maxTokens;
  state.checkpoint_runtime_layer_states = initializeCheckpointRuntimeLayers(state, prompt, maxTokens);
  const tokenBias = Number.isFinite(state.checkpoint_token_bias) ? state.checkpoint_token_bias : 0;
  const fingerprintBias = Number.isFinite(state.checkpoint_fingerprint) ? state.checkpoint_fingerprint : 0;
  const profileSeed = Number.isFinite(state.checkpoint_profile_seed) ? state.checkpoint_profile_seed : 0;
  let seed = prompt.length + state.num_layers + state.num_heads + tokenBias + fingerprintBias + profileSeed;
  let token = seed;
  const trace = [];
  for (let generated = 0; generated < maxTokens; generated++) {
    token = gptLargeNextToken(state, token, generated, maxTokens);
    trace.push(String(token));
    state.checkpoint_runtime_layer_states = advanceCheckpointRuntimeLayers(state, state.checkpoint_runtime_layer_states, token, generated, maxTokens);
  }
  return {
    tokenTrace: trace.join(','),
    lastToken: token,
    runtimeLayers: state.checkpoint_runtime_layer_states,
  };
}

function buildTokenTrace(state, prompt, maxTokens) {
  return simulateCheckpointGeneration(state, prompt, maxTokens).tokenTrace;
}

function buildLastToken(state, prompt, maxTokens) {
  return simulateCheckpointGeneration(state, prompt, maxTokens).lastToken;
}

function buildCompletion(state, model, prompt, tokenTrace, artifact, runtimeLayers) {
  let completion = 'NeurX S backend is serving a local checkpoint snapshot.';
  completion += ` model=${model}`;
  completion += ` summary=${gptLargeSummary(state)}`;
  completion += ` prompt_len=${prompt.length}`;
  if (state.checkpoint_loaded) {
    completion += ` loaded_step=${state.checkpoint_step}`;
    completion += ` loaded_loss=${state.checkpoint_loss}`;
    completion += ` loaded_params=${state.checkpoint_param_count}`;
  }
  if (artifact.checkpointFile) {
    completion += ` checkpoint=${artifact.checkpointFile}`;
  } else if (artifact.checkpointRoot) {
    completion += ` checkpoint_root=${artifact.checkpointRoot}`;
  }
  if (artifact.checkpointSnapshot && artifact.checkpointSnapshot.loaded) {
    completion += ` step=${artifact.checkpointSnapshot.step}`;
    completion += ` loss=${artifact.checkpointSnapshot.loss}`;
    completion += ` params=${artifact.checkpointSnapshot.paramCount}`;
    completion += ` token_bias=${artifact.checkpointSnapshot.tokenBias}`;
    completion += ` profile_seed=${artifact.checkpointSnapshot.profileSeed}`;
    if (artifact.checkpointSnapshot.stageSignature) {
      completion += ` stage_signature=${artifact.checkpointSnapshot.stageSignature.prefill}:${artifact.checkpointSnapshot.stageSignature.decode}:${artifact.checkpointSnapshot.stageSignature.finalize}`;
    }
    if (artifact.checkpointSnapshot.stageBiases) {
      completion += ` stage_biases=${artifact.checkpointSnapshot.stageBiases.prefill}:${artifact.checkpointSnapshot.stageBiases.decode}:${artifact.checkpointSnapshot.stageBiases.finalize}`;
    }
    if (Array.isArray(artifact.checkpointSnapshot.layerStates)) {
      completion += ` layers=${artifact.checkpointSnapshot.layerStates.length}`;
    }
    if (Array.isArray(runtimeLayers) && runtimeLayers.length > 0) {
      completion += ` runtime_layers=${runtimeLayers.length}`;
      completion += ` runtime_activation=${runtimeLayers.reduce((acc, layer) => acc + (layer.activation || 0), 0)}`;
      completion += ` runtime_signal=${runtimeLayers.reduce((acc, layer) => acc + (layer.rollingSignal || 0), 0)}`;
    }
    if (artifact.checkpointSnapshot.adapterSignature && artifact.checkpointSnapshot.adapterSignature.length > 0) {
      completion += ` adapters=${artifact.checkpointSnapshot.adapterSignature.join('|')}`;
    }
    if (artifact.checkpointSnapshot.modelName) {
      completion += ` artifact_model=${artifact.checkpointSnapshot.modelName}`;
    }
  }
  if (tokenTrace) {
    completion += ` token_trace=${tokenTrace}`;
  }
  return completion;
}

function processLlmRequest(model = 'gpt_large', prompt = '', maxTokens = 16) {
  const artifact = loadArtifactSnapshot(resolveArtifactContext());
  if (!prompt) {
    prompt = 'Explain NeurX LLM backend in one short paragraph.';
  }

  // Clamp max_tokens
  if (maxTokens < 1) maxTokens = 1;
  if (maxTokens > 64) maxTokens = 64;

  const baseState = gptLargeState();
  const state = loadCheckpointModelState(baseState, artifact);
  const stageBiases = stageSpecificBiases(state, maxTokens);
  artifact.checkpointSnapshot.stageBiases = stageBiases;
  const generation = simulateCheckpointGeneration(state, prompt, maxTokens);
  const tokenTrace = generation.tokenTrace;
  const runtimeLayers = generation.runtimeLayers;
  const completion = buildCompletion(state, model, prompt, tokenTrace, artifact, runtimeLayers);
  const lastToken = generation.lastToken;
  const artifactModel = artifact.checkpointSnapshot.modelName || model;
  const lossScale = Number.isFinite(state.checkpoint_loss_scale) ? state.checkpoint_loss_scale : 1.0;
  const runtimeSummary = buildRuntimeLayerSummary(runtimeLayers);

  return {
    backend_name: 'neurx.app.backend.llm',
    model_name: artifactModel,
    request_model_name: model,
    artifact_root: artifact.checkpointRoot,
    checkpoint_file: artifact.checkpointFile,
    artifact_ready: artifact.artifactReady,
    checkpoint_step: artifact.checkpointSnapshot.step,
    checkpoint_loss: artifact.checkpointSnapshot.loss,
    checkpoint_param_count: artifact.checkpointSnapshot.paramCount,
    checkpoint_model_name: artifact.checkpointSnapshot.modelName,
    checkpoint_family: artifact.checkpointSnapshot.family,
    checkpoint_architecture: artifact.checkpointSnapshot.architecture,
    checkpoint_dataset: artifact.checkpointSnapshot.dataset,
    checkpoint_profile_seed: artifact.checkpointSnapshot.profileSeed,
    checkpoint_profile_stride: artifact.checkpointSnapshot.profileStride,
    checkpoint_adapter_signature: artifact.checkpointSnapshot.adapterSignature,
    checkpoint_stage_signature: artifact.checkpointSnapshot.stageSignature,
    checkpoint_stage_biases: stageBiases,
    checkpoint_layer_states: artifact.checkpointSnapshot.layerStates,
    checkpoint_runtime_layer_states: runtimeSummary,
    prompt: prompt,
    summary: gptLargeSummary(state),
    completion: completion,
    token_trace: tokenTrace,
    generated_tokens: maxTokens,
    last_token: lastToken,
    train_loss: state.train_loss,
    validation_loss: state.validation_loss,
    checkpoint_loss_scale: lossScale,
    ready: true,
  };
}

function parseOpenAIRequest(body) {
  try {
    const req = typeof body === 'string' ? JSON.parse(body) : body;
    const messages = req.messages || [];
    const prompt = messages.map((m) => `${m.role}: ${m.content}`).join('\n') || '';
    const model = req.model || 'gpt_large';
    const maxTokens = Math.min(req.max_tokens || 16, 64);

    return { model, prompt, maxTokens };
  } catch {
    return { model: 'gpt_large', prompt: '', maxTokens: 16 };
  }
}

export { processLlmRequest, parseOpenAIRequest, gptLargeState, gptLargeSummary };
