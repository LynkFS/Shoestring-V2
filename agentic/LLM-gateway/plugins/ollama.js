'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// ollama.js — local Ollama via its OpenAI-compatible endpoint
// (http://localhost:11434/v1/chat/completions).
//
// Wire-identical to openai.js, so we reuse complete() verbatim and only
// override the metadata. No API key (cfg.apiKey is empty → no Authorization
// header). Proof that "add a provider" can be near-zero code.
// ─────────────────────────────────────────────────────────────────────────────

const openai = require('./openai.js');

module.exports = {
  name: 'ollama',
  capabilities: { streaming: true, webSearch: false, multiTurn: true, tools: false },
  complete: openai.complete,
  stream:   openai.stream
};
