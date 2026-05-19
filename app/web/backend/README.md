# app/web/backend

S-based backend core for the NeurX app, with a shell HTTP wrapper for local execution.

This directory holds the model-facing response generator that a web server or gateway can call.

## Quick Start

```bash
# Start the backend (S core + shell HTTP wrapper)
bash http_server.sh

# In another terminal, test it
curl -X POST http://127.0.0.1:18080/neurx/api/chat \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt_large","prompt":"Hello","max_tokens":16}'
```

The backend implements local inference using the S entrypoint in `serve.s`.

## Architecture

- **`serve.s`**: Core S backend response generator
- **`gateway.sh`**: JSON-to-env adapter that invokes `serve.s`
- **`http_handler.sh`**: Per-request HTTP handler, returns OpenAI-compatible JSON
- **`http_server.sh`**: `socat` listener that dispatches requests to `http_handler.sh`

## Contract

- Input prompt comes from `NEURX_BACKEND_PROMPT`
- Optional request file override: `NEURX_BACKEND_REQUEST_FILE`
- Optional model selector: `NEURX_BACKEND_MODEL`
- Optional token budget: `NEURX_BACKEND_MAX_TOKENS`
- Optional checkpoint root: `NEURX_BACKEND_CHECKPOINT_ROOT`
- Optional explicit checkpoint file: `NEURX_BACKEND_CHECKPOINT_FILE`
- Optional S binary override: `NEURX_S_BINARY`

The backend prints a JSON response to stdout.
Current response path is intentionally concise; detailed inference traces are emitted to runtime logs with `[inference]` prefixes.

### Request shape

If a gateway writes the incoming HTTP body to a file, the backend can consume it via `NEURX_BACKEND_REQUEST_FILE`.

Expected JSON fields:

- `model`
- `prompt`
- `max_tokens`

### Response shape

The backend emits a JSON document with:

- `backend_name`
- `model_name`
- `summary`
- `prompt`
- `completion`
- `generated_tokens`
- `last_token`
- `train_loss`
- `validation_loss`
- `ready`

## Entry

- `serve.s`: standalone S entrypoint for the LLM backend core
- `run.sh`: convenience launcher for local smoke tests
- `gateway.sh`: JSON-to-env gateway suitable for a thin HTTP wrapper or CGI host
- `http_handler.sh`: HTTP request handler script
- `http_server.sh`: shell listener for local deployment and docker compose
- `Dockerfile`: backend container image

## Examples

- `request.sample.json`: example POST body for `/neurx/api/chat`
- `response.sample.json`: example JSON emitted by `serve.s`
- `nginx.neurx.conf`: reverse-proxy snippet for `/neurx` and `/neurx/api/`

## Notes

This is the S inference core. The actual HTTP listener or reverse proxy can live outside the core and forward requests here.
For a host-level quick integration, `gateway.sh` can read a JSON request body on stdin and export `NEURX_BACKEND_*` before executing `serve.s`.
