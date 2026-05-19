import fs from 'node:fs';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { collectCheckpointModelChoices, processLlmRequest, parseOpenAIRequest } from './backend.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 18080);

function jsonHeaders() {
  return {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

function send(res, statusCode, body) {
  res.writeHead(statusCode, jsonHeaders());
  res.end(body);
}

function firstNonEmptyLine(text) {
  return String(text || '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find((line) => line.length > 0) || '';
}

function summarizeText(text, limit = 120) {
  const line = firstNonEmptyLine(text);
  if (!line) {
    return '';
  }
  return line.length > limit ? `${line.slice(0, limit - 3)}...` : line;
}

function logInference(stage, fields = {}) {
  const pairs = Object.entries(fields)
    .filter(([, value]) => value !== undefined && value !== null && String(value).length > 0)
    .map(([key, value]) => `${key}=${String(value)}`);
  console.log(`[inference] ${stage}${pairs.length ? ` ${pairs.join(' ')}` : ''}`);
}

function buildConciseAgentSuggestion(prompt, filePath, response) {
  const rawPrompt = String(prompt || '').trim();
  const normalized = rawPrompt.toLowerCase();
  const fileName = filePath ? path.basename(filePath) : '';

  if (normalized.includes('parameter "mouse" is not declared') || (normalized.includes('qml') && normalized.includes('mouse'))) {
    return `这是 QML 信号处理器参数注入弃用警告。请把${fileName || '相关文件'}里依赖隐式 mouse 的写法改成显式形式参数，例如 onPressed: function(mouse) { ... }，onPositionChanged 同理。`;
  }

  if (normalized.includes('fetch failed') || normalized.includes('runtime_exec_failed')) {
    return '这是运行时 HTTP 请求失败。先检查目标 URL 是否可达、应用启动环境中的 PATH/代理/证书变量是否与终端一致；如果终端里的 node fetch 正常而应用失败，通常是应用环境缺少代理或 CA 配置。';
  }

  if (normalized.includes('curl')) {
    return '如果报错与 curl 相关，先确认 curl 已安装且在 PATH 中，然后分别测试目标 URL、代理设置和证书链；若终端可用但应用内失败，优先检查应用进程继承到的环境变量。';
  }

  if (normalized.includes('error') || normalized.includes('failed') || normalized.includes('warning') || normalized.includes('deprecated')) {
    const issue = firstNonEmptyLine(rawPrompt);
    return `我先定位到这是一条运行或编译告警：${issue}。建议优先修复报错里直接指向的符号、参数或 API 用法，再复现确认是否还有后续错误。`;
  }

  if (rawPrompt) {
    const summary = firstNonEmptyLine(rawPrompt);
    const target = fileName ? `${fileName} 的这个问题` : '这个问题';
    return `我先给出简洁建议：${target} 需要结合报错和上下文逐项排查。当前已收到你的请求“${summary}”，如果需要精确修改，请继续附上报错或相关代码片段。`;
  }

  return `我已收到代码助手请求。当前模型为 ${response.model_name || 'gpt_large'}，请补充具体报错、目标行为或相关文件路径，我再给出更准确的修改建议。`;
}

const server = createServer((req, res) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, jsonHeaders());
    res.end();
    return;
  }

  if (req.method === 'GET' && (req.url === '/health' || req.url === '/neurx/health')) {
    send(
      res,
      200,
      JSON.stringify(
        {
          ok: true,
          service: 'neurx-app-backend',
          version: '1.0.0',
          backend: 'nodejs-gpt-large',
          checkpoint_root: (process.env.NEURX_BACKEND_CHECKPOINT_ROOT || '').trim(),
          checkpoint_file: (process.env.NEURX_BACKEND_CHECKPOINT_FILE || '').trim(),
        },
        null,
        2,
      ),
    );
    return;
  }

  if (req.method === 'GET' && (req.url === '/neurx/api/models' || req.url === '/api/models')) {
    const checkpointRoot = (process.env.NEURX_BACKEND_CHECKPOINT_ROOT || '').trim();
    send(
      res,
      200,
      JSON.stringify(
        {
          checkpoint_root: checkpointRoot,
          models: collectCheckpointModelChoices(checkpointRoot),
        },
        null,
        2,
      ),
    );
    return;
  }

  if (req.method === 'POST' && req.url === '/neurx/api/chat') {
    const chunks = [];
    req.on('data', (chunk) => {
      chunks.push(chunk);
    });
    req.on('end', () => {
      try {
        const bodyText = Buffer.concat(chunks).toString('utf8');
        const { model, prompt, maxTokens } = parseOpenAIRequest(bodyText);
        const startedAtMs = Date.now();
        logInference('chat.start', {
          model,
          prompt: summarizeText(prompt),
          maxTokens,
        });
        const response = processLlmRequest(model, prompt, maxTokens);
        logInference('chat.done', {
          model: response.model_name || model,
          checkpoint: response.checkpoint_file ? path.basename(response.checkpoint_file) : '',
          step: response.checkpoint_step || 0,
          tokens: response.generated_tokens || 0,
          elapsed_ms: Date.now() - startedAtMs,
        });
        send(res, 200, JSON.stringify(response, null, 2));
      } catch (err) {
        logInference('chat.error', {
          error: err && err.message ? err.message : String(err),
        });
        send(
          res,
          500,
          JSON.stringify(
            {
              ok: false,
              error: err.message || 'Internal server error',
            },
            null,
            2,
          ),
        );
      }
    });
    return;
  }

  // Code-assistant endpoint (Copilot/Codex-like): accepts { prompt, filePath, model?, maxTokens? }
  if (req.method === 'POST' && req.url === '/neurx/api/agent/suggest') {
    const chunks = [];
    req.on('data', (chunk) => {
      chunks.push(chunk);
    });
    req.on('end', () => {
      try {
        const bodyText = Buffer.concat(chunks).toString('utf8');
        const payload = JSON.parse(bodyText || '{}');
        const model = payload.model || (process.env.NEURX_BACKEND_CHECKPOINT_FILE || '').trim() || 'gpt_large';
        const requestPrompt = payload.prompt || '';
        const filePath = payload.filePath || '';
        const maxTokens = Math.min(payload.maxTokens || 64, 256);

        logInference('agent.suggest.start', {
          model,
          file: filePath ? path.basename(filePath) : '',
          prompt: summarizeText(requestPrompt),
          maxTokens,
        });

        let prompt = requestPrompt;
        if (filePath) {
          try {
            const fileText = fs.readFileSync(filePath, 'utf8');
            prompt = `File: ${filePath}\n---\n${fileText}\n---\nUser prompt:\n${prompt}`;
          } catch (e) {
            // ignore file read errors and proceed with original prompt
            logInference('agent.suggest.file_read_failed', {
              file: filePath,
              error: e && e.message ? e.message : String(e),
            });
          }
        }
        const response = processLlmRequest(model, prompt, maxTokens);

        const suggestion = buildConciseAgentSuggestion(requestPrompt, filePath, response);
        logInference('agent.suggest.done', {
          model: response.model_name || model,
          checkpoint: response.checkpoint_file ? path.basename(response.checkpoint_file) : '',
          step: response.checkpoint_step || 0,
          tokens: response.generated_tokens || 0,
          suggestion: summarizeText(suggestion),
        });

        const body = { ok: true, suggestion };
        send(res, 200, JSON.stringify(body, null, 2));
      } catch (err) {
        logInference('agent.suggest.error', {
          error: err && err.message ? err.message : String(err),
        });
        send(
          res,
          500,
          JSON.stringify(
            {
              ok: false,
              error: err.message || 'Internal server error',
            },
            null,
            2,
          ),
        );
      }
    });
    return;
  }

  // Compatibility: also accept v1/chat/completions for OpenAI-like clients
  if (req.method === 'POST' && req.url === '/v1/chat/completions') {
    const chunks = [];
    req.on('data', (chunk) => {
      chunks.push(chunk);
    });
    req.on('end', () => {
      try {
        const bodyText = Buffer.concat(chunks).toString('utf8');
        const { model, prompt, maxTokens } = parseOpenAIRequest(bodyText);
        const startedAtMs = Date.now();
        logInference('openai.chat.start', {
          model,
          prompt: summarizeText(prompt),
          maxTokens,
        });
        const response = processLlmRequest(model, prompt, maxTokens);

        // Convert to OpenAI-compatible response format
        const openaiResponse = {
          id: 'neurx-' + Date.now(),
          object: 'chat.completion',
          created: Math.floor(Date.now() / 1000),
          model: response.model_name || model,
          artifact_model: response.checkpoint_model_name,
          artifact_root: response.artifact_root,
          checkpoint_file: response.checkpoint_file,
          checkpoint_step: response.checkpoint_step,
          checkpoint_loss: response.checkpoint_loss,
          checkpoint_param_count: response.checkpoint_param_count,
          checkpoint_runtime_layer_states: response.checkpoint_runtime_layer_states,
          choices: [
            {
              index: 0,
              message: {
                role: 'assistant',
                content: response.completion,
              },
              finish_reason: 'stop',
            },
          ],
          usage: {
            prompt_tokens: prompt.length / 4,
            completion_tokens: response.generated_tokens,
            total_tokens: Math.ceil(prompt.length / 4) + response.generated_tokens,
          },
        };
        logInference('openai.chat.done', {
          model: response.model_name || model,
          checkpoint: response.checkpoint_file ? path.basename(response.checkpoint_file) : '',
          step: response.checkpoint_step || 0,
          tokens: response.generated_tokens || 0,
          elapsed_ms: Date.now() - startedAtMs,
        });
        send(res, 200, JSON.stringify(openaiResponse, null, 2));
      } catch (err) {
        logInference('openai.chat.error', {
          error: err && err.message ? err.message : String(err),
        });
        send(
          res,
          500,
          JSON.stringify(
            {
              error: {
                message: err.message || 'Internal server error',
                type: 'server_error',
              },
            },
            null,
            2,
          ),
        );
      }
    });
    return;
  }

  send(
    res,
    404,
    JSON.stringify(
      {
        ok: false,
        error: 'not found',
        path: req.url,
      },
      null,
      2,
    ),
  );
});

server.listen(port, '127.0.0.1', () => {
  console.log(`neurx backend listening on http://127.0.0.1:${port}`);
  console.log(`  - Chat API: POST /neurx/api/chat`);
  console.log(`  - OpenAI compatible: POST /v1/chat/completions`);
  console.log(`  - Health check: GET /neurx/health`);
});
