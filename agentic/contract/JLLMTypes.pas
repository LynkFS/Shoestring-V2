unit JLLMTypes;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JLLMTypes — the messages-first LLM contract for the agentic layer
//
//  Supersedes JAgent.pas's TLLMRequest. The original is left untouched;
//  everything new lives under agentic/.
//
//  Design commitments (see the plan):
//    * Multi-turn is the SHAPE, not a feature. The canonical input is always
//      a `messages` array. A single prompt is a one-element array.
//    * The proxy is stateless. ProviderSessionId is an opaque token for
//      provider-native sessions (Claude CLI --resume, Managed) — the client
//      stores it and sends it back; nobody interprets it but the provider.
//    * Records don't round-trip through variant cleanly (JAgent.pas:16), so
//      the wire `messages` lives in a `variant` JS array, manipulated through
//      the helpers here, never reconstructed from a Pascal array.
//
//  Wire request the proxy (JLLMProxy) expects:
//    { provider, transport, model, system,
//      messages:[{role,content}…], maxTokens, temperature,
//      stream, webSearch, providerSessionId }
//
//  Unified response the proxy returns:
//    { text, usage:{inputTokens,outputTokens}, finishReason,
//      webSearchUsed, webSearchUnavailable, providerSessionId }
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type

  // What a provider/transport can do. Reported by every adapter so callers
  // (and the UI) can adapt without provider conditionals.
  TLLMCaps = record
    Streaming:  Boolean;   // SSE token streaming
    WebSearch:  Boolean;   // NATIVE web search (no fallback is ever built)
    MultiTurn:  Boolean;   // always true here — kept explicit for honesty
    Tools:      Boolean;   // MCP / function calling (future phases)
  end;

  // One conversation turn. Content is String in v1; widens to variant for
  // multimodal later without changing callers that use the helpers.
  TLLMMessage = record
    Role:     String;      // 'user' | 'assistant' | 'system'
    Content:  String;
  end;

  // The request. `Messages` is the canonical input and is always populated.
  TLLMRequest = record
    Provider:          String;   // 'claude' | 'openai' | 'deepseek' | 'ollama'
    Transport:         String;   // claude only: 'api' | 'cli' | 'managed'
    Model:             String;
    System:            String;
    Messages:          variant;  // JS array [{role,content}…] — see helpers
    MaxTokens:         Integer;
    Temperature:       Float;
    Stream:            Boolean;
    WebSearch:         Boolean;   // request native search; flagged if absent
    ProviderSessionId: String;    // opaque passthrough for CLI/managed resume
  end;

  // The normalised result every provider resolves to.
  TLLMResult = record
    Text:                 String;
    InputTokens:          Integer;
    OutputTokens:         Integer;
    FinishReason:         String;
    WebSearchUsed:        Boolean;
    WebSearchUnavailable: Boolean;  // requested but provider has no native search
    ProviderSessionId:    String;   // echoed back for the next turn
  end;

  TLLMResultCb = procedure(const AResult: TLLMResult);
  TLLMErrorCb  = procedure(Status: Integer; const Message: String);
  TLLMDeltaCb  = procedure(const Chunk: String);   // one streamed token span


// ── Message-array helpers (the only sanctioned way to touch Messages) ──────

// A fresh empty conversation array.
function  NewMessages: variant;

// Append one turn. Mutates AMessages in place.
procedure PushMessage(AMessages: variant;
                      const ARole, AContent: String);

// Drop the last turn (used to keep history clean when a call fails).
procedure PopMessage(AMessages: variant);

// How many turns are buffered.
function  MessageCount(const AMessages: variant): Integer;

// Convenience: a one-message request — the degenerate single-prompt case
// expressed in the multi-turn shape.
function  RequestFromPrompt(const AProvider, AModel, ASystem,
                            APrompt: String): TLLMRequest;

implementation

function NewMessages: variant;
begin
  asm @Result = []; end;
end;

procedure PushMessage(AMessages: variant;
                      const ARole, AContent: String);
begin
  asm
    (@AMessages).push({ role: @ARole, content: @AContent });
  end;
end;

procedure PopMessage(AMessages: variant);
begin
  asm
    if ((@AMessages).length > 0) (@AMessages).pop();
  end;
end;

function MessageCount(const AMessages: variant): Integer;
begin
  Result := 0;
  asm
    @Result = Array.isArray(@AMessages) ? (@AMessages).length : 0;
  end;
end;

function RequestFromPrompt(const AProvider, AModel, ASystem,
                           APrompt: String): TLLMRequest;
begin
  Result.Provider          := AProvider;
  Result.Transport         := '';
  Result.Model             := AModel;
  Result.System            := ASystem;
  Result.Messages          := NewMessages;
  PushMessage(Result.Messages, 'user', APrompt);
  Result.MaxTokens         := 1024;
  Result.Temperature       := 0.7;   //note : opus 4.8 refuses any temp values, so claude.js omits it
  Result.Stream            := False;
  Result.WebSearch         := False;
  Result.ProviderSessionId := '';
end;

end.
