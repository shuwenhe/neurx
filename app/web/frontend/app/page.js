'use client';

import { useMemo, useState } from 'react';

const endpoint = '/neurx/api/chat';

function fallbackResponse(payload) {
  return {
    backend_name: 'neurx.frontend.fallback',
    model_name: payload.model,
    prompt: payload.prompt,
    completion: 'Frontend fallback: the S backend gateway is not reachable yet.',
    token_trace: [],
    generated_tokens: 0,
    ready: false,
    note: 'Point /neurx/api/chat to app/backend/gateway.sh or an equivalent HTTP wrapper.',
  };
}

export default function Page() {
  const [prompt, setPrompt] = useState('Explain how NeurX exposes an S-based LLM backend.');
  const [model, setModel] = useState('gpt_large');
  const [maxTokens, setMaxTokens] = useState(16);
  const [status, setStatus] = useState('idle');
  const [responseText, setResponseText] = useState('{}');
  const [loading, setLoading] = useState(false);

  const requestPreview = useMemo(
    () =>
      JSON.stringify(
        {
          model,
          prompt,
          max_tokens: maxTokens,
        },
        null,
        2,
      ),
    [model, prompt, maxTokens],
  );

  async function handleSend() {
    const payload = {
      model: model.trim() || 'gpt_large',
      prompt,
      max_tokens: Number(maxTokens || 16),
    };

    setStatus('sending');
    setLoading(true);

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      const text = await response.text();
      setResponseText(text);
      setStatus(response.ok ? 'ok' : `http ${response.status}`);
    } catch (error) {
      setResponseText(JSON.stringify(fallbackResponse(payload), null, 2));
      setStatus('error');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="shell">
      <section className="hero">
        <p className="eyebrow">NeurX</p>
        <h1>LLM Frontend</h1>
        <p className="lede">
          Next.js UI wired for the S backend at <code>/neurx/api/chat</code>.
        </p>
      </section>

      <section className="panel composer">
        <label htmlFor="prompt">Prompt</label>
        <textarea
          id="prompt"
          rows={8}
          spellCheck="false"
          value={prompt}
          onChange={(event) => setPrompt(event.target.value)}
        />

        <div className="row">
          <label className="inline" htmlFor="model">
            <span>Model</span>
            <input
              id="model"
              type="text"
              value={model}
              onChange={(event) => setModel(event.target.value)}
            />
          </label>
          <label className="inline" htmlFor="maxTokens">
            <span>Max tokens</span>
            <input
              id="maxTokens"
              type="number"
              min="1"
              max="64"
              value={maxTokens}
              onChange={(event) => setMaxTokens(Number(event.target.value))}
            />
          </label>
        </div>

        <button type="button" onClick={handleSend} disabled={loading}>
          {loading ? 'Sending...' : 'Send'}
        </button>
      </section>

      <section className="panel output">
        <div className="output-head">
          <h2>Response</h2>
          <span id="status">{status}</span>
        </div>
        <pre>{responseText}</pre>
      </section>

      <section className="panel request">
        <div className="output-head">
          <h2>Request Preview</h2>
          <span>POST /neurx/api/chat</span>
        </div>
        <pre>{requestPreview}</pre>
      </section>
    </main>
  );
}
