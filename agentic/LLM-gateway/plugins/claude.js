'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// claude.js — Anthropic Claude, three transports behind one provider.
//
//   req.transport = 'api'      → Messages API (this file)
//                 = 'cli'      → ./claude-cli.js      (spawns the claude binary)
//                 = 'managed'  → ./claude-managed.js  (managed-agents gateway)
//
// One provider row in providers.json; the adapter's Transport selects. All
// three normalise to the same unified events — callers never branch.
//
// Native web search: when req.webSearch is set, the API transport attaches
// Anthropic's server-side web_search tool. webSearchUsed reflects whether the
// model actually invoked it. (cli/managed have their own tools — they report
// conservatively.) No fallback searcher is ever built.
// ─────────────────────────────────────────────────────────────────────────────

const cli     = require('./claude-cli.js');
const managed = require('./claude-managed.js');

const ANTHROPIC_VERSION = '2023-06-01';
const WEB_SEARCH_TOOL    = { type: 'web_search_20250305', name: 'web_search' };

function splitMessages(req) {
  // Anthropic takes `system` top-level; messages are user/assistant only.
  const msgs = (Array.isArray(req.messages) ? req.messages : [])
    .filter(m => m && m.role !== 'system')
    .map(m => ({ role: m.role, content: m.content }));
  return msgs;
}

function buildBody(req, cfg, stream) {
  const body = {
    model:       req.model || cfg.modelDefault,
    max_tokens:  req.maxTokens || 1024,
    temperature: (req.temperature != null) ? req.temperature : 0.7,
    messages:    splitMessages(req),
    stream:      !!stream
  };
  if (req.system) body.system = req.system;
  if (req.webSearch) body.tools = [WEB_SEARCH_TOOL];
  return body;
}

function headers(cfg) {
  return {
    'x-api-key':         cfg.apiKey,
    'anthropic-version': ANTHROPIC_VERSION,
    'content-type':      'application/json'
  };
}

function isSearchBlock(b) {
  return b && (b.type === 'server_tool_use' ||
               b.type === 'web_search_tool_result');
}

async function apiComplete(req, cfg) {
  let r, txt;
  try {
    r = await fetch(cfg.endpoint, {
      method: 'POST', headers: headers(cfg), body: JSON.stringify(buildBody(req, cfg, false))
    });
    txt = await r.text();
  } catch (e) {
    const err = new Error('transport: ' + (e && e.message)); err.status = 502; throw err;
  }
  if (!r.ok) {
    const err = new Error('upstream ' + r.status + ': ' + txt.slice(0, 400));
    err.status = 502; throw err;
  }
  let j;
  try { j = JSON.parse(txt); }
  catch (e) { const err = new Error('bad upstream JSON'); err.status = 502; throw err; }

  const blocks = Array.isArray(j.content) ? j.content : [];
  const text = blocks.filter(b => b && b.type === 'text')
                     .map(b => b.text).join('');
  const u = j.usage || {};
  return {
    text,
    usage: { inputTokens: u.input_tokens || 0, outputTokens: u.output_tokens || 0 },
    finishReason:         j.stop_reason || 'stop',
    webSearchUsed:        blocks.some(isSearchBlock),
    webSearchUnavailable: false,
    providerSessionId:    req.providerSessionId || ''   // stateless API
  };
}

async function apiStream(req, cfg, onEvent) {
  let r;
  try {
    r = await fetch(cfg.endpoint, {
      method: 'POST', headers: headers(cfg), body: JSON.stringify(buildBody(req, cfg, true))
    });
  } catch (e) {
    const err = new Error('transport: ' + (e && e.message)); err.status = 502; throw err;
  }
  if (!r.ok) {
    let t = ''; try { t = await r.text(); } catch (e) {}
    const err = new Error('upstream ' + r.status + ': ' + t.slice(0, 300));
    err.status = 502; throw err;
  }

  const reader = r.body.getReader();
  const dec = new TextDecoder();
  let buf = '', inTok = 0, outTok = 0, finish = 'stop', wsUsed = false;

  while (true) {
    const c = await reader.read();
    if (c.done) break;
    buf += dec.decode(c.value, { stream: true });

    let i;
    while ((i = buf.indexOf('\n')) !== -1) {
      const line = buf.slice(0, i).trim();
      buf = buf.slice(i + 1);
      if (line.indexOf('data:') !== 0) continue;       // ignore `event:` lines
      const p = line.slice(5).trim();
      if (!p) continue;

      let ev;
      try { ev = JSON.parse(p); } catch (e) { continue; }

      if (ev.type === 'content_block_start' && isSearchBlock(ev.content_block)) {
        wsUsed = true;
      } else if (ev.type === 'content_block_delta' &&
                 ev.delta && ev.delta.type === 'text_delta') {
        if (ev.delta.text) onEvent({ type: 'delta', text: ev.delta.text });
      } else if (ev.type === 'message_start' && ev.message && ev.message.usage) {
        inTok = ev.message.usage.input_tokens || 0;
      } else if (ev.type === 'message_delta') {
        if (ev.usage) outTok = ev.usage.output_tokens || outTok;
        if (ev.delta && ev.delta.stop_reason) finish = ev.delta.stop_reason;
      }
    }
  }

  onEvent({
    type: 'done',
    usage: { inputTokens: inTok, outputTokens: outTok },
    finishReason:         finish,
    webSearchUsed:        wsUsed,
    webSearchUnavailable: false,
    providerSessionId:    req.providerSessionId || ''
  });
}

module.exports = {
  name: 'claude',
  capabilities: { streaming: true, webSearch: true, multiTurn: true, tools: true },

  async complete(req, cfg) {
    const t = req.transport || 'api';
    if (t === 'cli')     return cli.complete(req, cfg);
    if (t === 'managed') return managed.complete(req, cfg);
    return apiComplete(req, cfg);
  },

  async stream(req, cfg, onEvent) {
    const t = req.transport || 'api';
    if (t === 'cli')     return cli.stream(req, cfg, onEvent);
    if (t === 'managed') return managed.stream(req, cfg, onEvent);
    return apiStream(req, cfg, onEvent);
  }
};
