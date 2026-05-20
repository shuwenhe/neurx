export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

function resolveBackendUrl() {
  return process.env.NEURX_BACKEND_URL || 'http://127.0.0.1:18080/neurx/api/chat';
}

function responseHeaders() {
  return {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  };
}

export async function GET() {
  return Response.json(
    {
      ok: true,
      route: '/neurx/api/chat',
      backend: 'neurx.app.backend.llm',
      backend_url: resolveBackendUrl(),
    },
    { headers: responseHeaders() },
  );
}

export async function POST(request) {
  const bodyText = await request.text();
  const backendUrl = resolveBackendUrl();

  let upstream;
  try {
    upstream = await fetch(backendUrl, {
      method: 'POST',
      headers: {
        'Content-Type': request.headers.get('content-type') || 'application/json',
      },
      body: bodyText,
      cache: 'no-store',
    });
  } catch (error) {
    return Response.json(
      {
        ok: false,
        error: String(error),
        backend_url: backendUrl,
      },
      { status: 500, headers: responseHeaders() },
    );
  }

  const text = await upstream.text();
  return new Response(text || '{}', {
    status: upstream.status,
    headers: responseHeaders(),
  });
}
