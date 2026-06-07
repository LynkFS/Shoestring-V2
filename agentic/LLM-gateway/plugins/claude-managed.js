'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// claude-managed.js — Claude via a managed-agents gateway (skill dispatch).
//
// Targets a CONFIGURABLE gateway (providers.json "endpoint", e.g.
// https://host/agents/api.php) that exposes the proven FormLLM contract:
//   POST ?action=run          { skill, task }      → { session_id }
//   POST ?action=send-message { session_id, message }
//   GET  ?action=stream&session=<id>               → SSE event log
//
// Provider-native multi-turn: first turn = run (new session); subsequent
// turns = send-message into the same session. providerSessionId carries the
// managed session id, opaque to the proxy.
//
// This gateway streams whole agent messages, not tokens, so we emit the new
// suffix of the latest message as a delta and finish on session idle —
// honest about the granularity.
// ─────────────────────────────────────────────────────────────────────────────

const MAX_POLLS  = 150;     // ~5 min at 2s
const POLL_MS    = 2000;

const sleep = ms => new Promise(r => setTimeout(r, ms));

function lastUserText(req) {
  const ms = Array.isArray(req.messages) ? req.messages : [];
  for (let i = ms.length - 1; i >= 0; i--) {
    if (ms[i] && ms[i].role === 'user') return String(ms[i].content || '');
  }
  return '';
}

async function postJSON(url, body) {
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  const t = await r.text();
  if (!r.ok) {
    const e = new Error('gateway ' + r.status + ': ' + t.slice(0, 300));
    e.status = 502; throw e;
  }
  try { return JSON.parse(t); } catch (e) {
    const err = new Error('gateway: bad JSON'); err.status = 502; throw err;
  }
}

// Begin or continue a managed session; returns the session id.
async function ensureSession(req, cfg) {
  const base  = cfg.managedEndpoint || cfg.endpoint;
  const skill = cfg.skill || req.model || 'generic_assistant';
  const text  = lastUserText(req);

  if (req.providerSessionId) {
    await postJSON(base + '?action=send-message',
                   { session_id: req.providerSessionId, message: text });
    return req.providerSessionId;
  }
  const j = await postJSON(base + '?action=run', { skill, task: text });
  if (!j.session_id) {
    const e = new Error('gateway returned no session_id'); e.status = 502; throw e;
  }
  return String(j.session_id);
}

// Poll the SSE log until a terminal event. Emits unified events.
async function runStream(req, cfg, onEvent) {
  const base = cfg.endpoint;
  const sessionId = await ensureSession(req, cfg);

  let processed = 0;     // data: lines already consumed (log is cumulative)
  let emitted   = 0;     // chars of the latest agent message already streamed
  let retries   = 0;

  for (let poll = 0; poll < MAX_POLLS; poll++) {
    let text;
    try {
      const r = await fetch(base + '?action=stream&session=' + sessionId);
      if (!r.ok) throw new Error('stream ' + r.status);
      text = await r.text();
      retries = 0;
    } catch (e) {
      if (++retries > 5) {
        onEvent({ type: 'error', error: 'stream: ' + (e && e.message) });
        return sessionId;
      }
      await sleep(POLL_MS);
      continue;
    }

    const lines = text.split('\n');
    let count = 0, terminal = false;

    for (const line of lines) {
      if (line.indexOf('data: ') !== 0) continue;
      count++;
      if (count <= processed) continue;

      let ev;
      try { ev = JSON.parse(line.slice(6)); } catch (e) { continue; }

      if (ev.type === 'agent.message') {
        const full = (ev.content || [])
          .filter(b => b && b.type === 'text')
          .map(b => b.text).join('');
        if (full.length > emitted) {
          onEvent({ type: 'delta', text: full.slice(emitted) });
          emitted = full.length;
        }
      } else if (ev.type === 'session.status_idle') {
        terminal = true;
      } else if (ev.type === 'session.status_error') {
        onEvent({ type: 'error',
                  error: (ev.error && ev.error.message) || 'agent error' });
        return sessionId;
      }
    }
    processed = count;
    if (terminal) break;
    await sleep(POLL_MS);
  }

  onEvent({
    type: 'done',
    usage: { inputTokens: 0, outputTokens: 0 },
    finishReason:         'stop',
    webSearchUsed:        false,    // managed skill may search; not reported here
    webSearchUnavailable: false,
    providerSessionId:    sessionId
  });
  return sessionId;
}

async function stream(req, cfg, onEvent) {
  await runStream(req, cfg, onEvent);
}

async function complete(req, cfg) {
  let acc = '', psid = '', errMsg = '';
  psid = await runStream(req, cfg, ev => {
    if (ev.type === 'delta') acc += ev.text;
    else if (ev.type === 'error') errMsg = ev.error;
    else if (ev.type === 'done') psid = ev.providerSessionId;
  });
  if (errMsg) { const e = new Error(errMsg); e.status = 502; throw e; }
  return {
    text: acc,
    usage: { inputTokens: 0, outputTokens: 0 },
    finishReason:         'stop',
    webSearchUsed:        false,
    webSearchUnavailable: false,
    providerSessionId:    psid || ''
  };
}

module.exports = { complete, stream };
