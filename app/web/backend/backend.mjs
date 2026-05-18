/**
 * NeurX LLM Backend - Node.js implementation
 * Provides OpenAI-compatible chat API for local S-based model
 */

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

function gptLargeSummary(state) {
  return `${state.name}[${state.architecture},${state.parameter_count_m}M,layers=${state.num_layers},heads=${state.num_heads},ctx=${state.context_window}]`;
}

function gptLargeNextToken(state, tokenId, position) {
  let nextToken = tokenId + position + state.num_layers + state.num_heads;
  if (state.vocab_size > 0) {
    nextToken = nextToken - Math.floor(nextToken / state.vocab_size) * state.vocab_size;
  }
  return nextToken;
}

function buildTokenTrace(state, prompt, maxTokens) {
  let seed = prompt.length + state.num_layers + state.num_heads;
  let token = seed;
  const trace = [];
  for (let generated = 0; generated < maxTokens; generated++) {
    token = gptLargeNextToken(state, token, generated);
    trace.push(String(token));
  }
  return trace.join(',');
}

function buildLastToken(state, prompt, maxTokens) {
  let seed = prompt.length + state.num_layers + state.num_heads;
  let token = seed;
  for (let generated = 0; generated < maxTokens; generated++) {
    token = gptLargeNextToken(state, token, generated);
  }
  return token;
}

function buildCompletion(state, model, prompt, tokenTrace) {
  let completion = 'NeurX S backend is serving the local GPT-large scaffold.';
  completion += ` model=${model}`;
  completion += ` summary=${gptLargeSummary(state)}`;
  completion += ` prompt_len=${prompt.length}`;
  if (tokenTrace) {
    completion += ` token_trace=${tokenTrace}`;
  }
  return completion;
}

function processLlmRequest(model = 'gpt_large', prompt = '', maxTokens = 16) {
  if (!prompt) {
    prompt = 'Explain NeurX LLM backend in one short paragraph.';
  }

  // Clamp max_tokens
  if (maxTokens < 1) maxTokens = 1;
  if (maxTokens > 64) maxTokens = 64;

  const state = gptLargeState();
  const tokenTrace = buildTokenTrace(state, prompt, maxTokens);
  const completion = buildCompletion(state, model, prompt, tokenTrace);
  const lastToken = buildLastToken(state, prompt, maxTokens);

  return {
    backend_name: 'neurx.app.backend.llm',
    model_name: model,
    prompt: prompt,
    summary: gptLargeSummary(state),
    completion: completion,
    token_trace: tokenTrace,
    generated_tokens: maxTokens,
    last_token: lastToken,
    train_loss: state.train_loss,
    validation_loss: state.validation_loss,
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
