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
        const response = processLlmRequest(model, prompt, maxTokens);
        send(res, 200, JSON.stringify(response, null, 2));
      } catch (err) {
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
        send(res, 200, JSON.stringify(openaiResponse, null, 2));
      } catch (err) {
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
