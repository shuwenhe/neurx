# app/web

Next.js web entry for the NeurX LLM.

## Contract

- The page posts chat requests to `/neurx/api/chat`
- The backend response is expected to be JSON
- The app is configured with `basePath: /neurx` so it can be hosted behind that prefix
- The API route forwards to `NEURX_BACKEND_URL` or `http://127.0.0.1:18080/neurx/api/chat`

When deployed behind Nginx on port `8080`, the public entry page is `http://111.202.231.146:8080/neurx`.

## Files

- `package.json`: Next.js app dependencies and scripts
- `next.config.js`: Next.js routing configuration
- `app/layout.js`: root document shell
- `app/page.js`: chat UI and request runner
- `app/api/chat/route.js`: server-side API route that forwards to the backend URL
- `app/globals.css`: page styling

## Run

```bash
cd app/web
npm install
npm run dev
```

If the API route should target a different backend URL, set:

```bash
export NEURX_BACKEND_URL=http://127.0.0.1:18080/neurx/api/chat
```

To run the web app in development with the local gateway wrapper:

```bash
./run.sh
```

For a production build:

```bash
npm run build
npm run start
```

## Notes

The web app does not implement inference itself. The `/neurx/api/chat` route forwards to the backend HTTP endpoint, which can be backed by the S gateway in `app/service/gateway.sh` or any equivalent wrapper around `app/service/serve.s`.
