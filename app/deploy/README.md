# app/deploy

Deployment helpers for the NeurX app layer.

## Current layout

- `frontend/`: Next.js browser frontend
- `backend/`: S-based LLM backend core and thin gateway

## Recommended local run

1. Start the S backend gateway on the host:

```bash
cd app/backend
./gateway.sh < request.sample.json
```

2. Start the frontend:

```bash
cd app/frontend
export NEURX_BACKEND_URL=http://127.0.0.1:18080/neurx/api/chat
./run.sh
```

## HTTP reverse proxy

If you already have Nginx on `:8080`, proxy the public NeurX entry to the Next.js frontend:

- `/neurx/` -> `http://127.0.0.1:3000`
- `/neurx/api/chat` -> Next.js API route, which forwards to `NEURX_BACKEND_URL`

That makes the public page available at:

- `http://111.202.231.146:8080/neurx`

The backend core itself stays in `app/backend/serve.s`.

## Docker Compose

You can also bring up the full stack locally:

```bash
cd app/deploy
docker compose up --build
```

This starts:

- `backend` on `:18080`
- `frontend` on `:3000`
- `nginx` on `:8080`

The compose backend container expects the host `s` binary at `/home/shuwen/.local/bin/s`.
