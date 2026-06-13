unit JLLMAdapter;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JLLMAdapter — base LLM adapter (Phase 1: multi-turn, non-streaming)
//
//  Thin typed client over the generic proxy (JLLMProxy). It holds NO API
//  keys and knows NO provider wire formats — those live in the proxy's JS
//  plugins. What it owns:
//
//    * the running conversation (multi-turn is automatic — callers just
//      call Send repeatedly; Reset starts a new conversation),
//    * the opaque ProviderSessionId round-trip for CLI/managed transports,
//    * typed capability reporting (Capabilities).
//
//  Streaming arrives in Phase 3 as CompleteStream; the non-streaming Send
//  here stays as the simple path.
//
//  Browser-side: delegates to HttpClient.PostJSON (XHR). The same callback
//  shape FormLLM.pas already uses.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JLLMTypes, HttpClient;

type
  TLLMAdapter = class
  protected
    FProxyUrl:          String;
    FProvider:          String;   // set by subclass
    FCaps:              TLLMCaps;  // set by subclass
    FMessages:          variant;  // running multi-turn history
    FProviderSessionId: String;   // opaque; echoed back each turn

    function BuildBody(const AStream: Boolean): String;
    function ParseResult(AData: variant): TLLMResult;
  public
    // Per-call configuration — set before Send if you want non-defaults.
    Transport:    String;   // claude only: 'api' | 'cli' | 'managed'
    Model:        String;
    System:       String;
    MaxTokens:    Integer;
    Temperature:  Float;
    WebSearch:    Boolean;  // request native search; result flags if absent

    constructor Create(const AProxyUrl: String); virtual;

    // Append the user turn, call the proxy, append the assistant turn on
    // success (so the next Send carries full context), pop the user turn on
    // failure (so a retry doesn't double it).
    procedure Send(const AUserText: String;
                   OnResult: TLLMResultCb; OnError: TLLMErrorCb);

    // Streaming turn. OnDelta fires per token span as it arrives; OnDone
    // fires once with the assembled result; OnError on failure. Multi-turn
    // is preserved exactly as Send: user turn appended now, assistant turn
    // appended (full accumulated text) on done, user turn popped on error.
    procedure SendStreaming(const AUserText: String;
                            OnDelta: TLLMDeltaCb;
                            OnDone:  TLLMResultCb;
                            OnError: TLLMErrorCb);

    // Start a fresh conversation (clears history + provider session).
    procedure Reset;

    function Provider: String;
    function Capabilities: TLLMCaps;
    function TurnCount: Integer;
  end;

implementation

constructor TLLMAdapter.Create(const AProxyUrl: String);
begin
  inherited Create;
  FProxyUrl          := AProxyUrl;
  FProvider          := '';
  FProviderSessionId := '';
  FMessages          := NewMessages;

  Transport          := '';
  Model              := '';
  System             := '';
  MaxTokens          := 1024;
  Temperature        := 0.7;
  WebSearch          := False;

  // Conservative defaults; subclasses overwrite.
  FCaps.Streaming    := False;
  FCaps.WebSearch    := False;
  FCaps.MultiTurn    := True;
  FCaps.Tools        := False;
end;

function TLLMAdapter.BuildBody(const AStream: Boolean): String;
var
  prov, trans, mdl, sys, psid: String;
  maxT: Integer;
  temp: Float;
  ws:   Boolean;
begin
  prov  := FProvider;
  trans := Transport;
  mdl   := Model;
  sys   := System;
  psid  := FProviderSessionId;
  maxT  := MaxTokens;
  temp  := Temperature;
  ws    := WebSearch;

  asm
    @Result = JSON.stringify({
      provider:          @prov,
      transport:         @trans,
      model:             @mdl,
      system:            @sys,
      messages:          @FMessages,
      maxTokens:         @maxT,
      temperature:       @temp,
      stream:            @AStream,
      webSearch:         @ws,
      providerSessionId: @psid
    });
  end;
end;

function TLLMAdapter.ParseResult(AData: variant): TLLMResult;
var
  txt, finish, psid: String;
  inTok, outTok: Integer;
  wsUsed, wsNA: Boolean;
begin
  // Parse into locals first — assigning record sub-fields directly inside
  // asm is unproven in this dialect; the codebase parses to scalars then
  // assigns in Pascal (cf. FormLLM.pas).
  txt := ''; finish := ''; psid := '';
  inTok := 0; outTok := 0; wsUsed := False; wsNA := False;
  asm
    var d = @AData || {};
    var u = d.usage || {};
    @txt    = String(d.text || '');
    @finish = String(d.finishReason || '');
    @psid   = String(d.providerSessionId || '');
    @inTok  = u.inputTokens  || 0;
    @outTok = u.outputTokens || 0;
    @wsUsed = d.webSearchUsed        === true;
    @wsNA   = d.webSearchUnavailable === true;
  end;
  Result.Text                 := txt;
  Result.InputTokens          := inTok;
  Result.OutputTokens         := outTok;
  Result.FinishReason         := finish;
  Result.WebSearchUsed        := wsUsed;
  Result.WebSearchUnavailable := wsNA;
  Result.ProviderSessionId    := psid;
end;

procedure TLLMAdapter.Send(const AUserText: String;
                           OnResult: TLLMResultCb; OnError: TLLMErrorCb);
var
  body: String;
begin
  PushMessage(FMessages, 'user', AUserText);
  body := BuildBody(False);

  PostJSON(FProxyUrl + '/v1/chat', body,
    procedure(Data: variant)
    var
      r: TLLMResult;
    begin
      r := ParseResult(Data);
      if r.ProviderSessionId <> '' then
        FProviderSessionId := r.ProviderSessionId;
      PushMessage(FMessages, 'assistant', r.Text);
      if Assigned(OnResult) then OnResult(r);
    end,
    procedure(Status: Integer; Msg: String)
    begin
      PopMessage(FMessages);   // keep history clean for a retry
      if Assigned(OnError) then OnError(Status, Msg);
    end
  );
end;

procedure TLLMAdapter.SendStreaming(const AUserText: String;
                                    OnDelta: TLLMDeltaCb;
                                    OnDone:  TLLMResultCb;
                                    OnError: TLLMErrorCb);
var
  body, url: String;
  // Continuations invoked from the JS stream loop. Building the record and
  // touching multi-turn state stays in Pascal (records don't cross asm well).
  finishCb: procedure(const AText, AFinish, APsid: String; AWsNA: Boolean; AInTok, AOutTok: Integer);
  errCb:    procedure(AStatus: Integer; const AMsg: String);
begin
  PushMessage(FMessages, 'user', AUserText);
  body := BuildBody(True);            // stream:true
  url  := FProxyUrl + '/v1/chat';

  finishCb := procedure(const AText, AFinish, APsid: String; AWsNA: Boolean; AInTok, AOutTok: Integer)
              var
                r: TLLMResult;
              begin
                if APsid <> '' then FProviderSessionId := APsid;
                PushMessage(FMessages, 'assistant', AText);
                r.Text                 := AText;
                r.InputTokens          := AInTok;
                r.OutputTokens         := AOutTok;
                r.FinishReason         := AFinish;
                r.WebSearchUsed        := False;
                r.WebSearchUnavailable := AWsNA;
                r.ProviderSessionId    := APsid;
                if Assigned(OnDone) then OnDone(r);
              end;

  errCb := procedure(AStatus: Integer; const AMsg: String)
           begin
             PopMessage(FMessages);   // keep history clean for a retry
             if Assigned(OnError) then OnError(AStatus, AMsg);
           end;

  asm
    (async function () {
      try {
        var resp = await fetch(@url, {
          method:  'POST',
          headers: { 'Content-Type': 'application/json' },
          body:    @body
        });
        if (!resp.ok) {
          var et = '';
          try { et = await resp.text(); } catch (e) {}
          (@errCb)(resp.status, 'proxy ' + resp.status + ': ' + et.slice(0, 300));
          return;
        }

        var reader = resp.body.getReader();
        var dec    = new TextDecoder();
        var buf    = '';
        var acc    = '';
        var finish = 'stop';
        var psid   = '';
        var wsNA   = false;
        var inTok  = 0;
        var outTok = 0;

        while (true) {
          var ch = await reader.read();
          if (ch.done) break;
          buf += dec.decode(ch.value, { stream: true });

          var idx;
          while ((idx = buf.indexOf('\n\n')) !== -1) {
            var frame = buf.slice(0, idx).trim();
            buf = buf.slice(idx + 2);
            if (frame.indexOf('data:') !== 0) continue;
            var payload = frame.slice(5).trim();
            if (payload === '[DONE]' || payload === '') continue;

            var ev;
            try { ev = JSON.parse(payload); } catch (e) { continue; }

            if (ev.type === 'delta') {
              var d = ev.text || '';
              if (d) { acc += d; (@OnDelta)(d); }
            } else if (ev.type === 'done') {
              finish = ev.finishReason || 'stop';
              psid   = ev.providerSessionId || '';
              wsNA   = ev.webSearchUnavailable === true;
              if (ev.usage) {
                inTok  = ev.usage.inputTokens  || 0;
                outTok = ev.usage.outputTokens || 0;
              }
            } else if (ev.type === 'error') {
              (@errCb)(502, ev.error || 'stream error');
              return;
            }
          }
        }
        (@finishCb)(acc, finish, psid, wsNA, inTok, outTok);
      } catch (e) {
        (@errCb)(0, 'transport: ' + (e && e.message));
      }
    })();
  end;
end;

procedure TLLMAdapter.Reset;
begin
  FMessages          := NewMessages;
  FProviderSessionId := '';
end;

function TLLMAdapter.Provider: String;
begin
  Result := FProvider;
end;

function TLLMAdapter.Capabilities: TLLMCaps;
begin
  Result := FCaps;
end;

function TLLMAdapter.TurnCount: Integer;
begin
  Result := MessageCount(FMessages);
end;

end.
