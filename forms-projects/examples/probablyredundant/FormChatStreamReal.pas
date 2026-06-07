unit FormChatStreamReal;

// First end-to-end LLM-driven chat in the browser.
//
//   user types  ->  TClaudeAdapter.Send -> proxy -> Anthropic
//   response   ->  BeginAssistant + typewriter chunks -> FinishAssistant
//
// The proxy is currently non-streaming (Phase 2 of agentic), so we fake
// streaming visually by chunking the assembled response. When the proxy
// gains SSE later, we swap Send for SendStreaming and the OnDelta path
// runs without touching the form. The chat-panel surface is the same.
//
// Register in app.entrypoint.pas:
//     uses ..., FormChatStreamReal;
//     Application.CreateForm('FormChatLLM', TFormChatLLM);

interface

uses
  JElement, JForm, JButton, JChatPanel,
  JLLMAdapter, JLLMTypes, JClaudeAdapter;

const
  // Relative URL — resolves to same origin, routed to Win11:3030 via tunnel.
  PROXY_URL = 'https://proxy.lynkfs.com';
  // Typewriter pace.
  WORD_DELAY  = 30;          // ms between word reveals

type
  TFormChatLLM = class(TW3Form)
  private
    FChat:     JW3ChatPanel;
    FInput:    TElement;
    FSend:     JW3Button;
    FReset:    JW3Button;
    FAdapter:  TClaudeAdapter;

    // Live state for the in-flight assistant turn.
    FSpan:      TElement;            // content span returned by BeginAssistant
    FWords:     variant;             // JS array of word/whitespace tokens
    FWordCount: Integer;
    FWordIdx:   Integer;
    FBusy:      Boolean;

    procedure HandleSend;
    procedure HandleReset;
    procedure StartTurn(const AUserText: String);
    procedure OnLLMResult(const AResult: TLLMResult);
    procedure OnLLMError(AStatus: Integer; const AMsg: String);
    procedure TypeNextWord;
    procedure FinishTurn;
  public
    procedure InitializeObject; override;
  end;

implementation

uses Globals;

procedure TFormChatLLM.InitializeObject;
begin
  inherited;

  FChat := JW3ChatPanel.Create(Self);
  FChat.SetStyle('height', '500px');
  FChat.SetStyle('margin', '12px');

  // Input area: a textarea + two buttons. Plain TElement for the textarea
  // because we just need a multiline input and don't depend on any widget
  // behaviour.
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

  FSend := JW3Button.Create(Self);
  FSend.Caption := 'Send';
  FSend.SetStyle('margin', '8px 12px');
  FSend.OnClick := lambda HandleSend; end;

  FReset := JW3Button.Create(Self);
  FReset.Caption := 'New conversation';
  FReset.SetStyle('margin', '8px 0');
  FReset.OnClick := lambda HandleReset; end;

  FAdapter := TClaudeAdapter.Create(PROXY_URL);
  FBusy    := False;
end;

// ── User-action handlers ─────────────────────────────────────────────

procedure TFormChatLLM.HandleSend;
var
  txt: String;
  H:   variant;
begin
  if FBusy then exit;          // serialise turns

  // Read the textarea value from its JS handle. We assigned no Pascal
  // wrapper for the value, so go via DOM.
  H := FInput.Handle;
  asm @txt = (@H).value || ''; end;
  // Trim trailing newline / whitespace.
  while (Length(txt) > 0) and ((txt[Length(txt)] = ' ') or
                                (txt[Length(txt)] = #10) or
                                (txt[Length(txt)] = #13) or
                                (txt[Length(txt)] = #9)) do
    txt := Copy(txt, 1, Length(txt) - 1);

  if txt = '' then exit;

  // Clear the textarea so the user can type the next turn immediately.
  asm (@H).value = ''; end;

  StartTurn(txt);
end;

procedure TFormChatLLM.HandleReset;
begin
  if FBusy then exit;
  FAdapter.Reset;
  // Clear the panel by rebuilding it. Simpler than walking the DOM.
  FChat.Free;
  FChat := JW3ChatPanel.Create(Self);
  FChat.SetStyle('height', '500px');
  FChat.SetStyle('margin', '12px');
end;

// ── Turn lifecycle ───────────────────────────────────────────────────

procedure TFormChatLLM.StartTurn(const AUserText: String);
begin
  FBusy := True;
  FChat.AppendUser(AUserText);
  FChat.ShowTyping;
  FAdapter.Send(AUserText,
                @OnLLMResult,
                @OnLLMError);
end;

procedure TFormChatLLM.OnLLMResult(const AResult: TLLMResult);
var
  full: String;
  n:    Integer;
begin
  full := AResult.Text;

  // Open an empty streaming bubble.
  FSpan := FChat.BeginAssistant;

  // Split the full response into word/whitespace tokens. The regex
  // /(\s+)/ keeps the whitespace as separate elements, so a join of
  // all tokens reproduces the original string exactly.
  //
  // The token array lives entirely on the JS side (variant). We only
  // pull the length across to Pascal so the typewriter loop has a
  // termination condition.
  asm
    @FWords = String(@full).split(/(\s+)/);
    @n      = (@FWords).length;
  end;
  FWordCount := n;
  FWordIdx   := 0;
  TypeNextWord;
end;

procedure TFormChatLLM.TypeNextWord;
var
  M:     variant;
  token: String;
begin
  if FWordIdx >= FWordCount then
  begin
    FinishTurn;
    exit;
  end;

  // Pull one token from the JS array into a Pascal string.
  asm @token = (@FWords)[@FWordIdx] || ''; end;
  FChat.AppendAssistantChunk(FSpan, token);
  Inc(FWordIdx);

  // Schedule the next word.
  M := @TypeNextWord;
  asm setTimeout(@M, 30); end;
end;

procedure TFormChatLLM.FinishTurn;
begin
  FChat.FinishAssistant(FSpan);
  FBusy := False;
end;

procedure TFormChatLLM.OnLLMError(AStatus: Integer; const AMsg: String);
var
  msg: String;
begin
  FChat.HideTyping;
  msg := 'Error ' + IntToStr(AStatus) + ': ' + AMsg;
  FChat.AppendAssistant(msg);
  FBusy := False;
end;

end.
