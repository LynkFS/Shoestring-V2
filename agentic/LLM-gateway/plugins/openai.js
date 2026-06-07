'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// openai.js — OpenAI-compatible chat completions plugin.
//
// Used by `openai` AND `deepseek` (DeepSeek is wire-compatible — same plugin,
// different providers.json row). This is the churn surface: edit-and-run, no
// Quartex recompile.
//
// Contract: async complete(req, cfg) → unified result. The plugin owns the
// upstream call entirely (Node 18+ global fetch); the Pascal skeleton never
// sees the wire format.
// ─────────────────────────────────────────────────────────────────────────────

module.exports = {
  name: 'openai',
  capabilities: { streaming: true, webSearch: false, multiTurn: true, tools: true },

  async complete(req, cfg) {
    const messages = Array.isArray(req.messages) ? req.messages.slice() : [];
    if (req.system) messages.unshift({ role: 'system', content: req.system });

    const body = {
      model:       req.model || cfg.modelDefault,
      messages,
      max_tokens:  req.maxTokens || 1024,
      temperature: (req.temperature != null) ? req.temperature : 0.7
    };

    const headers = { 'Content-Type': 'application/json' };
    if (cfg.apiKey) headers['Authorization'] = 'Bearer ' + cfg.apiKey;

    let r, txt;
    try {
      r   = await fetch(cfg.endpoint, {
        method: 'POST', headers, body: JSON.stringify(body)
      });
      txt = await r.text();
    } catch (e) {
      const err = new Error('transport: ' + (e && e.message));
      err.status = 502;
      throw err;
    }

    if (!r.ok) {
      const err = new Error('upstream ' + r.status + ': ' + txt.slice(0, 400));
      // 4xx from the provider is usually a bad request we should surface;
      // 5xx is an upstream fault. Either way the proxy answers 502 unless
      // it was auth (so the caller knows to fix credentials server-side).
      err.status = (r.status === 401 || r.status === 403) ? 502 : 502;
      throw err;
    }

    let j;
    try { j = JSON.parse(txt); }
    catch (e) {
      const err = new Error('bad upstream JSON');
      err.status = 502;
      throw err;
    }

    const ch = (j.choices && j.choices[0]) || {};
    const u  = j.usage || {};

    return {
      text:         (ch.message && ch.message.content) || '',
      usage: {
        inputTokens:  u.prompt_tokens     || 0,
        outputTokens: u.completion_tokens  || 0
      },
      finishReason: ch.finish_reason || 'stop',
      webSearchUsed: false,
      // Plain chat-completions has no native web search. If the caller asked
      // for it, flag it honestly — no fallback searcher is ever built.
      webSearchUnavailable: !!req.webSearch,
      // Stateless provider: echo the opaque token back unchanged so the
      // client's multi-turn loop is uniform across providers.
      providerSessionId: req.providerSessionId || ''
    };
  },

  // Streaming. Emits unified events via onEvent({type:'delta'|'done'|'error'});
  // the skeleton just frames them as SSE. Owns the upstream SSE entirely.
  async stream(req, cfg, onEvent) {
    const messages = Array.isArray(req.messages) ? req.messages.slice() : [];
    if (req.system) messages.unshift({ role: 'system', content: req.system });

    const body = {
      model:        req.model || cfg.modelDefault,
      messages,
      max_tokens:   req.maxTokens || 1024,
      temperature:  (req.temperature != null) ? req.temperature : 0.7,
      stream:       true,
      stream_options: { include_usage: true }   // get a final usage chunk
    };
    const headers = { 'Content-Type': 'application/json' };
    if (cfg.apiKey) headers['Authorization'] = 'Bearer ' + cfg.apiKey;

    let r;
    try {
      r = await fetch(cfg.endpoint, {
        method: 'POST', headers, body: JSON.stringify(body)
      });
    } catch (e) {
      const err = new Error('transport: ' + (e && e.message));
      err.status = 502; throw err;
    }
    if (!r.ok) {
      let t = ''; try { t = await r.text(); } catch (e) {}
      const err = new Error('upstream ' + r.status + ': ' + t.slice(0, 300));
      err.status = 502; throw err;
    }

    const reader = r.body.getReader();
    const dec    = new TextDecoder();
    let buf = '', finish = 'stop', inTok = 0, outTok = 0;

    while (true) {
      const c = await reader.read();
      if (c.done) break;
      buf += dec.decode(c.value, { stream: true });

      let i;
      while ((i = buf.indexOf('\n')) !== -1) {
        const line = buf.slice(0, i).trim();
        buf = buf.slice(i + 1);
        if (!line || line.indexOf('data:') !== 0) continue;
        const p = line.slice(5).trim();
        if (p === '[DONE]') continue;

        let j;
        try { j = JSON.parse(p); } catch (e) { continue; }

        const ch = (j.choices && j.choices[0]) || {};
        const delta = ch.delta && ch.delta.content;
        if (delta) onEvent({ type: 'delta', text: delta });
        if (ch.finish_reason) finish = ch.finish_reason;
        if (j.usage) {
          inTok  = j.usage.prompt_tokens     || 0;
          outTok = j.usage.completion_tokens  || 0;
        }
      }
    }

    onEvent({
      type:                 'done',
      usage:                { inputTokens: inTok, outputTokens: outTok },
      finishReason:         finish,
      webSearchUsed:        false,
      webSearchUnavailable: !!req.webSearch,
      providerSessionId:    req.providerSessionId || ''
    });
  }
};
