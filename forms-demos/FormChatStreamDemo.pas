unit FormChatStreamDemo;

// ═══════════════════════════════════════════════════════════════════════════
//
//  A minimal end-to-end LLM chat, the smallest useful example of the adapter
//  pattern:
//
//    user types  ->  TClaudeAdapter.SendStreaming  ->  proxy  ->  Anthropic
//    response    ->  OnDelta chunks streamed live into a JW3ChatPanel bubble
//                ->  OnDone finalises the bubble
//
//  Three pieces, and that is the whole story:
//    • TClaudeAdapter — construct with the proxy URL; it keeps conversation
//      history, so each SendStreaming continues the same chat. Reset starts over.
//    • JW3ChatPanel   — AppendUser, then BeginAssistant / AppendAssistantChunk
//      (per streamed delta) / FinishAssistant. The panel renders; the form just
//      feeds it text as it arrives.
//    • An FBusy flag serialises turns so a second Send can't overlap the first.
//
//  Real SSE streaming: each token span arrives as an OnDelta callback and is
//  appended immediately, so the reply types itself out as the model produces it.
//  No buffering, no timers — the network paces it.
//
//  Register in app.entrypoint.pas:
//      uses ..., FormChatStreamReal;
//      Application.CreateForm('FormChatLLM', TFormChatLLM);
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  JElement, JForm, JButton, JChatPanel,
  JLLMAdapter, JLLMTypes, JClaudeAdapter;

const
  // Same-origin path: the page is served from ide.lynkfs.com and a tunnel
  // path rule routes /proxy/* to the proxy. Staying same-origin means no CORS
  // and no separate Access login — the page's session covers the call.
  PROXY_URL = '/proxy';

type
  TFormChatLLM = class(TW3Form)
  private
    FChat:    JW3ChatPanel;
    FInput:   TElement;              // a plain <textarea> — no widget wrapper needed
    FSend:    JW3Button;
    FReset:   JW3Button;
    FAdapter: TClaudeAdapter;

    FSpan:    TElement;              // content span of the in-flight assistant bubble
    FBusy:    Boolean;              // a turn is in flight

    procedure HandleSend;
    procedure HandleReset;
    procedure StartTurn(const AUserText: String);
    procedure OnLLMDelta(const AChunk: String);
    procedure OnLLMDone(const AResult: TLLMResult);
    procedure OnLLMError(AStatus: Integer; const AMsg: String);
  public
    procedure InitializeObject; override;
  end;

implementation

uses Globals;

procedure TFormChatLLM.InitializeObject;
var
  row: TElement;
begin
  inherited;

  FChat := JW3ChatPanel.Create(Self);
  FChat.SetStyle('height', '500px');
  FChat.SetStyle('margin', '12px');

  // A multiline input. We read/write its value straight off the DOM handle,
  // since we don't need any widget behaviour beyond "hold some text".
  FInput := TElement.Create('textarea', Self);
  FInput.SetStyle('width', 'calc(100% - 24px)');
  FInput.SetStyle('margin', '0 12px');
  FInput.SetStyle('min-height', '60px');
  FInput.SetStyle('padding', '8px');
  FInput.SetStyle('font-family', 'inherit');
  FInput.SetStyle('font-size', '14px');
  FInput.SetStyle('border', '1px solid var(--border-color, #e2e8f0)');
  FInput.SetStyle('border-radius', 'var(--radius-md, 8px)');
  FInput.SetStyle('box-sizing', 'border-box');

  row := TElement.Create('div', Self);
  row.SetStyle('display', 'flex');
  row.SetStyle('gap', '8px');
  row.SetStyle('margin', '8px 12px');

  FSend := JW3Button.Create(row);
  FSend.Caption := 'Send';
  FSend.OnClick := lambda HandleSend; end;

  FReset := JW3Button.Create(row);
  FReset.Caption := 'New conversation';
  FReset.OnClick := lambda HandleReset; end;

  FAdapter := TClaudeAdapter.Create(PROXY_URL);
  FBusy    := False;
end;

// ── user actions ────────────────────────────────────────────────────────────

procedure TFormChatLLM.HandleSend;
var
  txt: String;
  H:   variant;
begin
  if FBusy then Exit;              // serialise turns

  H := FInput.Handle;
  asm @txt = (@H).value || ''; end;
  txt := Trim(txt);
  if txt = '' then Exit;

  asm (@H).value = ''; end;        // clear so the next turn can be typed straight away
  StartTurn(txt);
end;

procedure TFormChatLLM.HandleReset;
begin
  if FBusy then Exit;
  FAdapter.Reset;                  // forget the conversation history
  // Clear the transcript by rebuilding the panel — simpler than walking the DOM.
  FChat.Free;
  FChat := JW3ChatPanel.Create(Self);
  FChat.SetStyle('height', '500px');
  FChat.SetStyle('margin', '12px');
end;

// ── turn lifecycle ──────────────────────────────────────────────────────────

procedure TFormChatLLM.StartTurn(const AUserText: String);
begin
  FBusy := True;
  FChat.AppendUser(AUserText);
  FSpan := FChat.BeginAssistant;   // open an empty bubble; deltas fill it

  FAdapter.SendStreaming(AUserText,
    procedure(const AChunk: String)
    begin
      OnLLMDelta(AChunk);
    end,
    procedure(const AResult: TLLMResult)
    begin
      OnLLMDone(AResult);
    end,
    procedure(AStatus: Integer; const AMessage: String)
    begin
      OnLLMError(AStatus, AMessage);
    end);
end;

procedure TFormChatLLM.OnLLMDelta(const AChunk: String);
begin
  FChat.AppendAssistantChunk(FSpan, AChunk);   // append the token span as it arrives
end;

procedure TFormChatLLM.OnLLMDone(const AResult: TLLMResult);
begin
  FChat.FinishAssistant(FSpan);    // finalise (light markdown + copy affordance)
  FBusy := False;
end;

procedure TFormChatLLM.OnLLMError(AStatus: Integer; const AMsg: String);
begin
  FChat.FinishAssistant(FSpan);    // close the (possibly empty) bubble
  FChat.AppendAssistant('Error ' + IntToStr(AStatus) + ': ' + AMsg);
  FBusy := False;
end;

end.
