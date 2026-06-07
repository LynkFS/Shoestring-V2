unit FormLLM;

// ─────────────────────────────────────────────────────────────────────────
//
//  FormLLM (agentic) — one unified path for every provider/transport.
//
//  Replaces the original forms/FormLLM.pas (~480 lines of hand-rolled
//  api/cli/managed + SSE polling). That file is left untouched; this is the
//  agentic rewrite.
//
//  Flow:
//    provider radio (+ Claude transport radio)
//        → TLLMAdapter (multi-turn is automatic)
//        → StreamIntoStore writes llm.delta / llm.status / llm.error
//        → this form SUBSCRIBES to those keys and renders.
//
//  The form never speaks HTTP, never knows a wire format, never polls. The
//  DataStore is the only coupling between transport and UI — exactly the
//  decoupling the booklet's DataStore chapter prescribes.
//
//  Streaming render: a live region shows partial text token-by-token; on
//  `done` it's finalised into a chat bubble (JW3ChatPanel has no
//  update-last-bubble API, so we own the live region rather than poke its
//  internals).
//
// ─────────────────────────────────────────────────────────────────────────

interface

uses
  JElement, JForm, JButton, JTextArea, JRadioGroup, JChatPanel,
  JDataStore, JLLMAdapter, JOpenAICompatAdapter, JClaudeAdapter, JLLMStore;

type
  TFormLLM = class(TW3Form)
  private
    FProviderGroup:  JW3RadioGroup;
    FTransportGroup: JW3RadioGroup;
    FPromptArea:     JW3TextArea;
    FSubmitBtn:      JW3Button;
    FNewConvBtn:     JW3Button;
    FChat:           JW3ChatPanel;
    FLive:           TElement;          // live partial assistant text

    FStore:          JW3DataStore;
    FAdapter:        TLLMAdapter;
    FCurProvider:    String;
    FCurTransport:   String;
    FBusy:           Boolean;

    procedure EnsureAdapter;            // (re)build when selection changes
    procedure HandleSubmit(Sender: TObject);
    procedure HandleNewConv(Sender: TObject);
    procedure SetLive(const AText: String);
    procedure WireStore;
  protected
    procedure InitializeObject; override;
  end;

implementation

uses
  Globals, ThemeStyles;

const
  // Point at the deployed LLM proxy (JLLMProxy). CORS_ORIGINS on the proxy
  // must allow this app's origin, or front both via one reverse proxy.
  PROXY_URL = '/proxy';  //'http://localhost:3000';
  STORE_BASE = 'llm';

// ═══════════════════════════════════════════════════════════════════════
//  Init
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.InitializeObject;
var
  Body, BtnRow: TElement;
begin
  inherited;

  FBusy         := False;
  FCurProvider  := '';
  FCurTransport := '';
  FStore        := JW3DataStore.Create;

  Body := TElement.Create('div', Self);
  Body.SetStyle('padding',        'var(--space-6, 24px)');
  Body.SetStyle('display',        'flex');
  Body.SetStyle('flex-direction', 'column');
  Body.SetStyle('gap',            'var(--space-3, 12px)');
  Body.SetStyle('width',          '100%');
  Body.SetStyle('max-width',      '720px');
  Body.SetStyle('margin',         '0 auto');

  var Title := TElement.Create('div', Body);
  Title.SetText('LLM');
  Title.SetStyle('font-size',   'var(--text-lg, 18px)');
  Title.SetStyle('font-weight', '700');

  var L1 := TElement.Create('span', Body);
  L1.AddClass(csFieldLabel);
  L1.SetText('Provider');

  FProviderGroup := JW3RadioGroup.Create(Body);
  FProviderGroup.SetStyle('width', '100%');
  FProviderGroup.AddButton('Claude',   'claude');
  FProviderGroup.AddButton('OpenAI',   'openai');
  FProviderGroup.AddButton('DeepSeek', 'deepseek');
  FProviderGroup.AddButton('Ollama',   'ollama');
  FProviderGroup.SelectedIndex := 0;

  var L2 := TElement.Create('span', Body);
  L2.AddClass(csFieldLabel);
  L2.SetText('Claude transport (ignored for other providers)');

  FTransportGroup := JW3RadioGroup.Create(Body);
  FTransportGroup.SetStyle('width', '100%');
  FTransportGroup.AddButton('API',     'api');
  FTransportGroup.AddButton('CLI',     'cli');
  FTransportGroup.AddButton('Managed', 'managed');
  FTransportGroup.SelectedIndex := 0;

  FChat := JW3ChatPanel.Create(Body);
  FChat.SetStyle('height',      '380px');
  FChat.SetStyle('flex-shrink', '0');
  FChat.SetStyle('margin-top',  'var(--space-2, 8px)');

  FLive := TElement.Create('div', Body);
  FLive.AddClass(csFieldLabel);
  FLive.SetStyle('white-space',  'pre-wrap');
  FLive.SetStyle('opacity',      '0.75');
  FLive.SetStyle('min-height',   '1em');
  FLive.SetStyle('display',      'none');

  FPromptArea := JW3TextArea.Create(Body);
  FPromptArea.Placeholder := 'Send a message - first prompt or follow-up...';
  FPromptArea.Rows := 3;

  BtnRow := TElement.Create('div', Body);
  BtnRow.SetStyle('display', 'flex');
  BtnRow.SetStyle('gap',     'var(--space-2, 8px)');

  FSubmitBtn := JW3Button.Create(BtnRow);
  FSubmitBtn.Caption := 'Send';
  FSubmitBtn.AddClass(csBtnPrimary);
  FSubmitBtn.OnClick := HandleSubmit;

  FNewConvBtn := JW3Button.Create(BtnRow);
  FNewConvBtn.Caption := 'New conversation';
  FNewConvBtn.AddClass(csBtnGhost);
  FNewConvBtn.OnClick := HandleNewConv;

  WireStore;
end;

// ═══════════════════════════════════════════════════════════════════════
//  Store wiring — the only transport↔UI coupling
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.SetLive(const AText: String);
begin
  FLive.SetText(AText);
  if AText = '' then
    FLive.SetStyle('display', 'none')
  else
    FLive.SetStyle('display', 'block');
end;

procedure TFormLLM.WireStore;
var
  subDelta, subStatus: Integer;   // ids kept (Subscribe returns Integer)
begin
  subDelta := FStore.Subscribe(STORE_BASE + '.delta',
    procedure(const Key: String; Value: variant)
    begin
      SetLive(String(Value));
    end);

  subStatus := FStore.Subscribe(STORE_BASE + '.status',
    procedure(const Key: String; Value: variant)
    var
      st, finalTxt, errTxt: String;
    begin
      st := String(Value);

      if st = 'streaming' then
      begin
        FSubmitBtn.Enabled := False;
        FChat.ShowTyping;
      end

      else if st = 'done' then
      begin
        FChat.HideTyping;
        finalTxt := String(FStore.Get(STORE_BASE + '.delta'));
        if finalTxt <> '' then
          FChat.AppendAssistant(finalTxt)
        else
          FChat.AppendAssistant('*(empty response)*');
        SetLive('');
        FSubmitBtn.Enabled := True;
        FBusy := False;
      end

      else if st = 'error' then
      begin
        FChat.HideTyping;
        errTxt := String(FStore.Get(STORE_BASE + '.error'));
        FChat.AppendAssistant('**Error**: ' + errTxt);
        SetLive('');
        FSubmitBtn.Enabled := True;
        FBusy := False;
      end;
    end);
end;

// ═══════════════════════════════════════════════════════════════════════
//  Adapter selection
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.EnsureAdapter;
var
  prov, trans: String;
begin
  prov  := FProviderGroup.SelectedValue;
  trans := FTransportGroup.SelectedValue;

  // Rebuild on any selection change. A new adapter = a fresh conversation
  // (multi-turn state is per-adapter), so the visible history resets too.
  if (FAdapter <> nil) and (prov = FCurProvider) and
     ((prov <> 'claude') or (trans = FCurTransport)) then
    exit;

  if      prov = 'openai'   then FAdapter := TOpenAIAdapter.Create(PROXY_URL)
  else if prov = 'deepseek' then FAdapter := TDeepSeekAdapter.Create(PROXY_URL)
  else if prov = 'ollama'   then FAdapter := TOllamaAdapter.Create(PROXY_URL)
  else
  begin
    FAdapter := TClaudeAdapter.Create(PROXY_URL);
    FAdapter.Transport := trans;
  end;

  FCurProvider  := prov;
  FCurTransport := trans;

  FChat.Reset;
  SetLive('');
end;

// ═══════════════════════════════════════════════════════════════════════
//  Submit / new conversation
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.HandleSubmit(Sender: TObject);
var
  Prompt: String;
begin
  if FBusy then exit;
  Prompt := Trim(FPromptArea.Value);
  if Prompt = '' then exit;

  EnsureAdapter;

  FChat.AppendUser(Prompt);
  FPromptArea.Value := '';
  FBusy := True;

  // One call, every provider/transport. StreamIntoStore drives the UI via
  // the subscriptions in WireStore. Multi-turn is automatic in the adapter.
  StreamIntoStore(FAdapter, FStore, STORE_BASE, Prompt);
end;

procedure TFormLLM.HandleNewConv(Sender: TObject);
begin
  if FAdapter <> nil then
    FAdapter.Reset;
  FChat.Reset;
  SetLive('');
  FStore.Put(STORE_BASE + '.error', '');
  FBusy := False;
  FSubmitBtn.Enabled := True;
end;

end.
