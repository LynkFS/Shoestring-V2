'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// claude-cli.js — Claude via the local `claude` binary (Claude Code CLI).
//
// Provider-native multi-turn: the CLI owns the conversation. We pass the
// LATEST user turn only and let the CLI resume its own session via
// --resume <providerSessionId>. The session id comes back in the result and
// is echoed to the client as providerSessionId for the next turn (opaque to
// the proxy — exactly the stateless contract).
//
// PREREQUISITE: the `claude` binary must be on PATH of the proxy host
// (override with providers.json "cliBin"). Missing binary → a clean 503,
// not a crash.
// ─────────────────────────────────────────────────────────────────────────────

const { spawn } = require('child_process');

function lastUserText(req) {
  const ms = Array.isArray(req.messages) ? req.messages : [];
  for (let i = ms.length - 1; i >= 0; i--) {
    if (ms[i] && ms[i].role === 'user') return String(ms[i].content || '');
  }
  return '';
}

function buildArgs(req, cfg, streaming) {
  const args = ['-p', lastUserText(req),
                '--output-format', streaming ? 'stream-json' : 'json'];
  if (streaming) args.push('--verbose');
  if (req.providerSessionId) args.push('--resume', req.providerSessionId);
  if (req.model) args.push('--model', req.model);
  return args;
}

function spawnClaude(req, cfg, streaming) {
  const bin = cfg.cliBin || 'claude';
  const child = spawn(bin, buildArgs(req, cfg, streaming), {
    stdio: ['ignore', 'pipe', 'pipe']
  });
  return child;
}

function notFound(e) {
  const err = new Error('Claude CLI not available on proxy host (' +
                        (e && e.code || 'spawn error') + ').');
  err.status = 503;
  return err;
}

async function complete(req, cfg) {
  return await new Promise((resolve, reject) => {
    let out = '', errb = '';
    let child;
    try { child = spawnClaude(req, cfg, false); }
    catch (e) { return reject(notFound(e)); }

    child.on('error', e => reject(notFound(e)));
    child.stdout.on('data', d => { out += d; });
    child.stderr.on('data', d => { errb += d; });
    child.on('close', code => {
      let j = null;
      try { j = JSON.parse(out); } catch (e) {}
      if (!j) {
        const err = new Error('CLI returned no JSON (exit ' + code + '): ' +
                              (errb || out).slice(0, 300));
        err.status = 502; return reject(err);
      }
      if (j.is_error) {
        const err = new Error(String(j.result || 'CLI error'));
        err.status = 502; return reject(err);
      }
      resolve({
        text: String(j.result || ''),
        usage: { inputTokens: 0, outputTokens: 0 },   // CLI does not report tokens
        finishReason:         'stop',
        webSearchUsed:        false,                   // unknown from CLI
        webSearchUnavailable: false,                   // CLI can search natively
        providerSessionId:    String(j.session_id || req.providerSessionId || '')
      });
    });
  });
}

async function stream(req, cfg, onEvent) {
  return await new Promise((resolve, reject) => {
    let child;
    try { child = spawnClaude(req, cfg, true); }
    catch (e) { return reject(notFound(e)); }

    let buf = '', errb = '', sessionId = req.providerSessionId || '';
    let emitted = 0;            // chars of assistant text already streamed

    child.on('error', e => reject(notFound(e)));
    child.stderr.on('data', d => { errb += d; });

    child.stdout.on('data', chunk => {
      buf += chunk;
      let i;
      while ((i = buf.indexOf('\n')) !== -1) {
        const line = buf.slice(0, i).trim();
        buf = buf.slice(i + 1);
        if (!line) continue;

        let ev;
        try { ev = JSON.parse(line); } catch (e) { continue; }

        if (ev.session_id) sessionId = ev.session_id;

        if (ev.type === 'assistant' && ev.message &&
            Array.isArray(ev.message.content)) {
          // Claude Code emits assistant messages as they complete, not per
          // token. Emit the new suffix so the client still sees progress.
          const full = ev.message.content
            .filter(b => b && b.type === 'text')
            .map(b => b.text).join('');
          if (full.length > emitted) {
            onEvent({ type: 'delta', text: full.slice(emitted) });
            emitted = full.length;
          }
        } else if (ev.type === 'result') {
          if (ev.is_error) {
            onEvent({ type: 'error', error: String(ev.result || 'CLI error') });
          }
        }
      }
    });

    child.on('close', code => {
      onEvent({
        type: 'done',
        usage: { inputTokens: 0, outputTokens: 0 },
        finishReason:         code === 0 ? 'stop' : 'error',
        webSearchUsed:        false,
        webSearchUnavailable: false,
        providerSessionId:    sessionId
      });
      resolve();
    });
  });
}

module.exports = { complete, stream };
