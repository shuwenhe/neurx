const http = require("http");
const { spawn } = require("child_process");
const path = require("path");

const port = Number(process.env.PORT || 18080);
const bindHost = "127.0.0.1";
const scriptDir = __dirname;
const handlerPath = path.join(scriptDir, "http_handler.sh");
const bashCommand = process.env.NEURX_BASH || "bash";

function buildRawRequest(req, body) {
  const lines = [];
  lines.push(`${req.method} ${req.url} HTTP/${req.httpVersion}`);
  for (const [name, value] of Object.entries(req.headers)) {
    if (Array.isArray(value)) {
      for (const item of value) {
        lines.push(`${name}: ${item}`);
      }
    } else if (value !== undefined) {
      lines.push(`${name}: ${value}`);
    }
  }
  lines.push("");
  return Buffer.concat([
    Buffer.from(lines.join("\r\n") + "\r\n", "utf8"),
    body,
  ]);
}

function parseRawResponse(buffer) {
  const separator = buffer.indexOf(Buffer.from("\r\n\r\n"));
  if (separator === -1) {
    throw new Error("handler returned malformed HTTP response");
  }

  const headerText = buffer.subarray(0, separator).toString("utf8");
  const body = buffer.subarray(separator + 4);
  const headerLines = headerText.split("\r\n");
  const statusLine = headerLines.shift() || "HTTP/1.1 500 Internal Server Error";
  const match = statusLine.match(/^HTTP\/\d+\.\d+\s+(\d{3})(?:\s+(.*))?$/);
  const statusCode = match ? Number(match[1]) : 500;
  const statusMessage = match && match[2] ? match[2] : "Internal Server Error";
  const headers = {};

  for (const line of headerLines) {
    const idx = line.indexOf(":");
    if (idx === -1) {
      continue;
    }
    const name = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim();
    if (!name) {
      continue;
    }
    if (/^connection$/i.test(name) || /^content-length$/i.test(name)) {
      continue;
    }
    headers[name] = value;
  }

  return { statusCode, statusMessage, headers, body };
}

function runHandler(req, body) {
  return new Promise((resolve, reject) => {
    const child = spawn(bashCommand, [handlerPath], {
      cwd: scriptDir,
      env: process.env,
      stdio: ["pipe", "pipe", "pipe"],
    });

    const stdoutChunks = [];
    const stderrChunks = [];

    child.stdout.on("data", (chunk) => stdoutChunks.push(chunk));
    child.stderr.on("data", (chunk) => stderrChunks.push(chunk));
    child.on("error", reject);
    child.on("close", (code) => {
      if (stderrChunks.length > 0) {
        process.stderr.write(Buffer.concat(stderrChunks));
      }
      if (code !== 0) {
        reject(new Error(`http_handler.sh exited with code ${code}`));
        return;
      }
      try {
        resolve(parseRawResponse(Buffer.concat(stdoutChunks)));
      } catch (error) {
        reject(error);
      }
    });

    child.stdin.end(buildRawRequest(req, body));
  });
}

const server = http.createServer(async (req, res) => {
  try {
    const bodyChunks = [];
    for await (const chunk of req) {
      bodyChunks.push(chunk);
    }
    const body = Buffer.concat(bodyChunks);
    const response = await runHandler(req, body);

    res.writeHead(response.statusCode, response.statusMessage, response.headers);
    res.end(response.body);
  } catch (error) {
    const payload = JSON.stringify({
      ok: false,
      error: error.message || String(error),
    });
    res.writeHead(500, "Internal Server Error", {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Content-Length": Buffer.byteLength(payload),
    });
    res.end(payload);
  }
});

server.listen(port, bindHost, () => {
  process.stderr.write(`neurx node-backend http wrapper listening on ${bindHost}:${port}\n`);
});
