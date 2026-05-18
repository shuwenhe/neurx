# app/backend

S-based backend core for the NeurX app.

This directory holds the model-facing response generator that a web server or gateway can call.

## Contract

- Input prompt comes from `NEURX_BACKEND_PROMPT`
- Optional request file override: `NEURX_BACKEND_REQUEST_FILE`
- Optional model selector: `NEURX_BACKEND_MODEL`
- Optional token budget: `NEURX_BACKEND_MAX_TOKENS`

The backend prints a JSON response to stdout.

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
- `token_trace`
- `generated_tokens`
- `last_token`
- `train_loss`
- `validation_loss`
- `ready`

## Entry

- `serve.s`: standalone S entrypoint for the LLM backend core
- `run.sh`: convenience launcher for local smoke tests
- `gateway.sh`: JSON-to-env gateway suitable for a thin HTTP wrapper or CGI host

## Examples

- `request.sample.json`: example POST body for `/neurx/api/chat`
- `response.sample.json`: example JSON emitted by `serve.s`
- `nginx.neurx.conf`: reverse-proxy snippet for `/neurx` and `/neurx/api/`

## Notes

This is the S inference core. The actual HTTP listener or reverse proxy can live outside the core and forward requests here.
For a host-level quick integration, `gateway.sh` can read a JSON request body on stdin and export `NEURX_BACKEND_*` before executing `serve.s`.
