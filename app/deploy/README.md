# app/deploy

Deployment helpers for the NeurX app layer.

## Current layout

- `web/`: Next.js browser UI
- `service/`: S-based LLM backend core and thin gateway

## Recommended local run

1. Start the S backend gateway on the host:

```bash
cd app/service
./gateway.sh < request.sample.json
```

2. Start the web app:

```bash
cd app/web
export NEURX_BACKEND_URL=http://127.0.0.1:18080/neurx/api/chat
./run.sh
```

## HTTP reverse proxy

If you already have Nginx on `:8080`, proxy the public NeurX entry to the Next.js web app:

- `/neurx/` -> `http://127.0.0.1:3000`
- `/neurx/api/chat` -> Next.js API route, which forwards to `NEURX_BACKEND_URL`

That makes the public page available at:

- `http://111.202.231.146:8080/neurx`

The backend core itself stays in `app/service/serve.s`.

## Bind Qwen2.5-VL-7B

If you want the public entry `http://111.202.231.146:8080/neurx` to use `Qwen2.5-VL-7B` as the backend model service, run the VL API first and point the NeurX backend gateway at it:

```bash
cd serving/serve
bash qwen25_vl_cpu_api_container.sh
```

Then export the gateway variables before starting the app stack:

```bash
export NEURX_BACKEND_MODEL=Qwen2.5-VL-7B
export NEURX_VL_BASE_URL=http://127.0.0.1:8004
export NEURX_VL_MODEL=Qwen2.5-VL-7B
```

After that, `POST /neurx/api/chat` will route `Qwen2.5-VL-7B` requests to the VL service instead of the default Ollama fallback.

## Docker Compose

You can also bring up the full stack locally:

```bash
cd app/deploy
docker compose up --build
```

Or use the wrapper:

```bash
./run.sh
```

This starts:

- `backend` on `:18080`
- `web` on `:3000`
- `nginx` on `:8080`

The compose backend container expects the host `s` binary at `/home/shuwen/.local/bin/s`.
If your host uses a different location, update the bind mount and `NEURX_S_BINARY` value in `docker-compose.yml`.
You can keep local overrides in a shell export or by copying `env.example` into a local `.env`.
