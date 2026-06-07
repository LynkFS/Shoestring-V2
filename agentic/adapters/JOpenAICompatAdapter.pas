unit JOpenAICompatAdapter;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JOpenAICompatAdapter — OpenAI, DeepSeek and Ollama
//
//  All three speak the OpenAI chat-completions wire format, so the client
//  side is identical: the only differences are the provider name, a default
//  model, and the capability matrix. The actual wire translation lives in
//  the proxy's JS plugins (openai.js / ollama.js) — adding or retuning a
//  provider never recompiles this Pascal.
//
//  TOpenAICompatAdapter is the shared base; the three concrete classes are
//  five lines each. Phase 1: multi-turn, non-streaming (inherited Send).
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JLLMTypes, JLLMAdapter;

type
  // Shared base — sets nothing itself; concrete classes configure.
  TOpenAICompatAdapter = class(TLLMAdapter)
  end;

  TOpenAIAdapter = class(TOpenAICompatAdapter)
  public
    constructor Create(const AProxyUrl: String); override;
  end;

  TDeepSeekAdapter = class(TOpenAICompatAdapter)
  public
    constructor Create(const AProxyUrl: String); override;
  end;

  TOllamaAdapter = class(TOpenAICompatAdapter)
  public
    constructor Create(const AProxyUrl: String); override;
  end;

implementation

// ── OpenAI ─────────────────────────────────────────────────────────────────
constructor TOpenAIAdapter.Create(const AProxyUrl: String);
begin
  inherited Create(AProxyUrl);
  FProvider       := 'openai';
  Model           := 'gpt-4o';
  FCaps.Streaming := True;
  FCaps.WebSearch := True;    // native web search tool
  FCaps.MultiTurn := True;
  FCaps.Tools     := True;
end;

// ── DeepSeek (OpenAI-compatible endpoint) ──────────────────────────────────
constructor TDeepSeekAdapter.Create(const AProxyUrl: String);
begin
  inherited Create(AProxyUrl);
  FProvider       := 'deepseek';
  Model           := 'deepseek-chat';
  FCaps.Streaming := True;
  FCaps.WebSearch := False;   // no native search — result flags if requested
  FCaps.MultiTurn := True;
  FCaps.Tools     := True;
end;

// ── Ollama (local, OpenAI-compatible) ──────────────────────────────────────
constructor TOllamaAdapter.Create(const AProxyUrl: String);
begin
  inherited Create(AProxyUrl);
  FProvider       := 'ollama';
  Model           := 'llama3.1';
  FCaps.Streaming := True;
  FCaps.WebSearch := False;   // local model, no native search
  FCaps.MultiTurn := True;
  FCaps.Tools     := False;
end;

end.
