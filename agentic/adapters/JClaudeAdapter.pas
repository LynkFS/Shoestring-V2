unit JClaudeAdapter;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JClaudeAdapter (agentic) — Claude across all three transports
//
//  One class. `Transport` ('api' | 'cli' | 'managed') selects the path; the
//  proxy's claude.js dispatches and normalises all three to the same unified
//  events, so Send / SendStreaming / multi-turn work identically regardless.
//
//  This supersedes the standalone agents/JClaudeAdapter.pas for agentic use
//  (that one is API-only and bound to TLLMAdapter in JAgent). The original
//  is left untouched.
//
//    var c := TClaudeAdapter.Create('https://host/llm');
//    c.Transport := 'cli';            // local Claude Code, provider-native session
//    c.Send('Refactor this unit', OnReply, OnErr);
//    c.Send('Now add tests', OnReply, OnErr);   // multi-turn: automatic
//
//  Capabilities are transport-aware (CLI/managed don't expose token usage;
//  web search is native on the API transport).
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JLLMTypes, JLLMAdapter;

type
  TClaudeAdapter = class(TLLMAdapter)
  public
    constructor Create(const AProxyUrl: String); override;

    // Convenience: set Transport and return Self for fluent setup.
    function Using(const ATransport: String): TClaudeAdapter;
  end;

implementation

constructor TClaudeAdapter.Create(const AProxyUrl: String);
begin
  inherited Create(AProxyUrl);
  FProvider       := 'claude';
  Transport       := 'api';            // 'api' | 'cli' | 'managed'
  Model           := '';               // empty → proxy uses providers.json modelDefault
  FCaps.Streaming := True;
  FCaps.WebSearch := True;             // native web_search tool (API transport)
  FCaps.MultiTurn := True;
  FCaps.Tools     := True;
end;

function TClaudeAdapter.Using(const ATransport: String): TClaudeAdapter;
begin
  Transport := ATransport;
  Result    := Self;
end;

end.
