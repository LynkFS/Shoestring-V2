# Chapter 12: LLM Access

Chapter 11 introduced the Node target. This is the first thing worth building on it: a single typed Pascal surface for every LLM, designed to survive constant change.

## The Problem

Models multiply — Claude, OpenAI, DeepSeek, Ollama — and a single model is rarely reachable just one way. Claude alone has three front doors: the Messages API, the local `claude` CLI, and managed agents. Each comes with its own wire format, authentication, streaming dialect, and session model.

A ShoeString app should never see any of that. It should see *one* thing. And adding a provider next month should not mean touching the app, the form, or — given that Pascal here is compiled, not hot-reloaded — recompiling any Pascal at all.

## The Shape

Two layers, each with a single responsibility.

**The adapter** is thin Pascal: a typed client that holds the conversation and reports the capability matrix. It holds no keys and knows nothing about any wire format. Its surface is just `Send` and `SendStreaming`. Swapping `TOpenAIAdapter` for `TClaudeAdapter` changes nothing else in the app.

**The proxy** is a stateless ShoeString-compiled Node service. It owns the keys, routes each request by provider, and frames the SSE stream. It knows no wire format itself — each provider is a JavaScript plugin, loaded at runtime and named in `providers.json`.

The split is deliberate, and the reasoning is the whole point. The adapter surface is stable, so it lives in Pascal. Provider wire formats are where the churn is, so they live as data plus JS plugins that the compiled skeleton loads at runtime. Adding a provider is a row in `providers.json` and a small `.js` file — never a skeleton recompile. That is the future-proofing argument in one line: put the part that changes weekly where it can change without rebuilding anything.

```
app ─► TLLMAdapter ──POST /v1/chat──► JLLMProxy ──► plugins/<provider>.js ─► model
       (typed, no keys)  (stable skeleton, stateless)  (the churn, edit-and-run)
```

## Multi-turn is the shape, not a feature

The canonical request is always a `messages` array; a single prompt is just the one-element case. The adapter appends the user turn, appends the assistant turn on success, and pops the user turn on failure. So a follow-up question is simply another `Send` — there is nothing to switch on.

State stays out of the proxy entirely. The client sends the full history with every turn. Provider-native sessions — the Claude CLI's `--resume`, managed agents — ride along as an opaque `ProviderSessionId` that the proxy passes straight through and never interprets. Because the proxy holds no state, it restarts safely and scales sideways. It is the same lesson as the database proxy: keep the middle stateless and the hard problems stay simple.

## Streaming, and the decoupling that matters

`SendStreaming` delivers tokens as they arrive. The proxy normalises every provider's stream into one small vocabulary — `delta`, `done`, `error` — so the plugin owns the messy upstream stream while the skeleton owns only the clean SSE frame. The UI never sees a provider difference.

Each `delta` is just a callback, and where you send it is the whole design decision. The simplest forms append the chunk straight to a `JW3ChatPanel` and watch the reply type itself out — a one-line handler, perfect for a plain chat.

The fuller pattern routes the stream through state instead. Write each `delta`, and the `done` and `error` signals, into `JW3DataStore` keys (Chapter 10) — `llm.delta`, `llm.status`, `llm.error` — and have the view *subscribe* to those keys rather than receive the callback directly. Now the code that sends a turn and the panel that renders it never touch each other: one writes the store, the other reacts to it. The DataStore is the only coupling between transport and UI, which is exactly the decoupling the DataStore chapter prescribed.

That decoupling is what makes runtime swapping trivial, and it is worth seeing concretely. A single form can offer provider and transport as radio buttons — Claude over the API, Claude over the local CLI, OpenAI, a local Ollama — rebuild the adapter whenever the selection changes, and render every one of them identically, because the form only ever subscribes to those same three keys. The transport underneath varies wildly; the view never knows which it is. Multi-turn still rides along automatically, so a follow-up after switching providers is just another send. The form speaks no HTTP, knows no wire format, and polls nothing — it sends a prompt and watches a store.

## Capabilities, honestly

Each adapter reports what it can actually do. Web search, for instance, is enabled only where a provider supports it natively — the Claude API attaches Anthropic's `web_search` tool — and where it is absent, the result says so plainly via `webSearchUnavailable`. No fallback searcher is invented to paper over the gap. Reporting an absent capability is more useful than faking a present one.

| Concern | Where it lives | Cost of change |
|---|---|---|
| Conversation, capabilities | Pascal adapter | rare — recompile |
| Routing, auth, SSE frame | Pascal proxy skeleton | rare — recompile |
| Provider wire format, keys | `providers.json` + JS plugin | constant — **edit-and-run** |

## The Tradeoff

Using one language end to end costs a recompile of the skeleton when the skeleton itself changes. The design earns that back by confining the cost to the parts that almost never change, and pushing everything volatile out into data and plugins that need no rebuild.

If you only ever call one provider, the plain reference proxy is simpler and you should use it. But the moment the brief becomes "many providers, many changes," this is the shape that stops fighting you — and a single form that switches between four providers and three transports while rendering them all the same way is the proof that the surface really is one thing.
