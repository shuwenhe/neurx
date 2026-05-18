import { createServer } from 'node:http';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const gatewayPath = process.env.NEURX_BACKEND_GATEWAY || path.join(__dirname, 'gateway.sh');
const port = Number(process.env.PORT || 18080);

function jsonHeaders() {
  return {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  };
}

function send(res, statusCode, body) {
  res.writeHead(statusCode, jsonHeaders());
  res.end(body);
}

const server = createServer((req, res) => {
  if (req.method === 'GET' && (req.url === '/health' || req.url === '/neurx/health')) {
    send(
      res,
      200,
      JSON.stringify(
        {
          ok: true,
          service: 'neurx-app-backend',
          gateway: gatewayPath,
        },
        null,
        2,
      ),
    );
    return;
  }

  if (req.method !== 'POST' || req.url !== '/neurx/api/chat') {
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
    return;
  }

  const chunks = [];
  req.on('data', (chunk) => {
    chunks.push(chunk);
  });
  req.on('end', () => {
    const bodyText = Buffer.concat(chunks).toString('utf8');
    const result = spawnSync('bash', [gatewayPath], {
      input: bodyText,
      encoding: 'utf8',
      env: {
        ...process.env,
        NEURX_BACKEND_REQUEST_FILE: '',
      },
    });

    if (result.error) {
      send(
        res,
        500,
        JSON.stringify(
          {
            ok: false,
            error: String(result.error),
            gateway: gatewayPath,
          },
          null,
          2,
        ),
      );
      return;
    }

    if (result.status !== 0) {
      send(
        res,
        500,
        JSON.stringify(
          {
            ok: false,
            status: result.status,
            stderr: result.stderr || '',
            gateway: gatewayPath,
          },
          null,
          2,
        ),
      );
      return;
    }

    res.writeHead(200, jsonHeaders());
    res.end(result.stdout || '{}');
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`neurx backend listening on :${port}`);
});
