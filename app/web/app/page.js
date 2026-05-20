'use client';

import { useEffect, useMemo, useState } from 'react';

const endpoint = '/neurx/api/chat';
const modelEndpoint = '/neurx/api/models';

function fallbackResponse(payload) {
  return {
    backend_name: 'neurx.web.fallback',
    model_name: payload.model,
    prompt: payload.prompt,
    completion: 'Web fallback: the S backend gateway is not reachable yet.',
    token_trace: [],
    generated_tokens: 0,
    ready: false,
    note: 'Point /neurx/api/chat to app/service/gateway.sh or an equivalent HTTP wrapper.',
  };
}

function groupModelOptions(modelOptions) {
  const groups = new Map();

  for (const option of modelOptions) {
    const label = option.label || option.value || '';
    const parts = label.split('/').filter(Boolean);
    const groupLabel = parts.length > 0 ? parts[0] : 'checkpoints';
    const displayLabel = parts.length > 1 ? parts.slice(1).join('/') : label;
    const group = groups.get(groupLabel) || [];
    group.push({
      ...option,
      displayLabel,
    });
    groups.set(groupLabel, group);
  }

  return Array.from(groups.entries()).map(([groupLabel, options]) => ({
    groupLabel,
    options,
  }));
}

export default function Page() {
  const [prompt, setPrompt] = useState('Explain how NeurX exposes an S-based LLM backend.');
  const [model, setModel] = useState('gpt_large');
  const [modelOptions, setModelOptions] = useState([]);
  const [maxTokens, setMaxTokens] = useState(16);
  const [status, setStatus] = useState('idle');
  const [responseText, setResponseText] = useState('{}');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function loadModels() {
      try {
        const response = await fetch(modelEndpoint, { cache: 'no-store' });
        if (!response.ok) {
          return;
        }

        const data = await response.json();
        const models = Array.isArray(data.models) ? data.models : [];
        if (cancelled) {
          return;
        }

        setModelOptions(models);
        if (models.length > 0) {
          setModel((current) => {
            if (!current || current === 'gpt_large') {
              return models[0].value || current;
            }
            return current;
          });
        }
      } catch {
        if (!cancelled) {
          setModelOptions([]);
        }
      }
    }

    loadModels();
    return () => {
      cancelled = true;
    };
  }, []);

  const groupedModelOptions = useMemo(() => groupModelOptions(modelOptions), [modelOptions]);

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
            <span>Model checkpoint</span>
            <select
              id="model"
              value={model}
              onChange={(event) => setModel(event.target.value)}
            >
              {groupedModelOptions.length === 0 ? (
                <option value="gpt_large">gpt_large</option>
              ) : (
                groupedModelOptions.map((group) => (
                  <optgroup key={group.groupLabel} label={group.groupLabel}>
                    {group.options.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.displayLabel}
                      </option>
                    ))}
                  </optgroup>
                ))
              )}
            </select>
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

        <p className="hint">
          Checkpoints are loaded from <code>/neurx/api/models</code> and grouped by run name from <code>artifacts/checkpoints/</code>.
        </p>

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
