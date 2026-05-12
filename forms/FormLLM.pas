unit FormLLM;

// ─────────────────────────────────────────────────────────────────────────
//
//  FormLLM — multi-turn LLM caller with three provider backends.
//
//  Layout:
//    Prompt textarea  →  Radio (api | cli | managed)
//    [Send] [New conversation]
//    Conversation (JW3ChatPanel — bubble history, typing indicator)
//
//  CLI is multi-turn: gateway returns a session_id on the first response;
//  subsequent prompts send it back so the Claude CLI resumes the same
//  session. API and Managed start fresh each turn (no client-side
//  context accumulation in v1) — the chat panel still shows the visual
//  history but each call is independent on the server.
//
// ─────────────────────────────────────────────────────────────────────────

interface

uses
  JElement, JForm, JButton, JTextArea, JRadioGroup, JChatPanel;

type
  TFormLLM = class(TW3Form)
  private
    FPromptArea:        JW3TextArea;
    FChoiceGroup:       JW3RadioGroup;
    FSubmitBtn:         JW3Button;
    FNewConvBtn:        JW3Button;
    FChat:              JW3ChatPanel;

    // CLI multi-turn — set on first response, sent on follow-ups.
    FCliSessionId:      String;

    // API multi-turn — client-side history (Messages API is stateless).
    // Array of { role, content } objects, appended on each turn.
    FApiHistory:        variant;

    // Managed-agent polling state.
    FManagedSessionId:  String;
    FPolling:           Boolean;
    FEventsProcessed:   Integer;
    FRetryCount:        Integer;
    FLastMessage:       String;

    procedure HandleSubmit(Sender: TObject);
    procedure HandleNewConv(Sender: TObject);

    procedure CallApi    (const Prompt: String);
    procedure CallCli    (const Prompt: String);
    procedure CallManaged(const Prompt: String);

    procedure StartCall;
    procedure ReplyText(const Text: String);
    procedure ReplyError(const Msg: String);

    procedure StartManagedRun   (const Prompt: String);
    procedure ContinueManagedRun(const Prompt: String);
    procedure StopManagedStream;
    procedure PollManagedStream;
    procedure HandleManagedEvent(Evt: variant);
    procedure FinishManagedRun(IsError: Boolean; const ErrText: String);

  protected
    procedure InitializeObject; override;
  end;

implementation

uses
  Globals, ThemeStyles, HttpClient;

const
  API_URL = 'https://lynkfs.com/agents/api.php';
  CLI_URL = 'https://lynkfs.com/agents/agent-gateway.php';

// ═══════════════════════════════════════════════════════════════════════
//  Init
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.InitializeObject;
var
  Body, BtnRow: TElement;
begin
  inherited;

  FCliSessionId     := '';
  FManagedSessionId := '';
  FPolling          := false;
  FEventsProcessed  := 0;
  FRetryCount       := 0;
  FLastMessage      := '';
  asm @FApiHistory  = []; end;

  // ── Body ────────────────────────────────────────────────────────────
  Body := TElement.Create('div', Self);
  Body.SetStyle('padding',         'var(--space-6, 24px)');
  Body.SetStyle('display',         'flex');
  Body.SetStyle('flex-direction',  'column');
  Body.SetStyle('gap',             'var(--space-3, 12px)');
  Body.SetStyle('width',           '100%');
  Body.SetStyle('max-width',       '720px');
  Body.SetStyle('margin',          '0 auto');

  // ── Title ───────────────────────────────────────────────────────────
  var Title := TElement.Create('div', Body);
  Title.SetText('LLM Prompt');
  Title.SetStyle('font-size',   'var(--text-lg, 18px)');
  Title.SetStyle('font-weight', '700');

  // ── Provider radio (settings live at the top — small, glanceable) ───
  var L2 := TElement.Create('span', Body);
  L2.AddClass(csFieldLabel);
  L2.SetText('Provider');

  FChoiceGroup := JW3RadioGroup.Create(Body);
  FChoiceGroup.SetStyle('width', '100%');
  FChoiceGroup.AddButton('API',     'api');
  FChoiceGroup.AddButton('CLI',     'cli');
  FChoiceGroup.AddButton('Managed', 'managed');
  FChoiceGroup.SelectedIndex := 0;

  // ── Conversation (the focus — bubbles + typing indicator) ───────────
  FChat := JW3ChatPanel.Create(Body);
  FChat.SetStyle('height',      '420px');
  FChat.SetStyle('flex-shrink', '0');
  FChat.SetStyle('margin-top',  'var(--space-2, 8px)');

  // ── Input row (textarea + buttons at the bottom, chat-style) ───────
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
end;

// ═══════════════════════════════════════════════════════════════════════
//  Submit / new conversation
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.HandleSubmit(Sender: TObject);
var
  Prompt, Choice: String;
begin
  Prompt := Trim(FPromptArea.Value);
  if Prompt = '' then exit;

  Choice := FChoiceGroup.SelectedValue;

  // Append user bubble first so the user sees their turn immediately,
  // then clear the input. Reply lands as an assistant bubble later.
  FChat.AppendUser(Prompt);
  FPromptArea.Value := '';

  if      Choice = 'api'     then CallApi(Prompt)
  else if Choice = 'cli'     then CallCli(Prompt)
  else if Choice = 'managed' then CallManaged(Prompt);
end;

procedure TFormLLM.HandleNewConv(Sender: TObject);
begin
  FCliSessionId     := '';
  FManagedSessionId := '';
  FPolling          := false;
  FEventsProcessed  := 0;
  asm @FApiHistory = []; end;
  FChat.Reset;
end;

// ═══════════════════════════════════════════════════════════════════════
//  Reply helpers — provider-agnostic chat-panel writes
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.StartCall;
begin
  FSubmitBtn.Enabled := false;
  FChat.ShowTyping;
end;

procedure TFormLLM.ReplyText(const Text: String);
begin
  FChat.HideTyping;
  FChat.AppendAssistant(Text);
  FSubmitBtn.Enabled := true;
end;

procedure TFormLLM.ReplyError(const Msg: String);
begin
  FChat.HideTyping;
  FChat.AppendAssistant('**Error**: ' + Msg);
  FSubmitBtn.Enabled := true;
end;

// ═══════════════════════════════════════════════════════════════════════
//  Provider: API — direct Messages API via api.php proxy
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.CallApi(const Prompt: String);
var Body: String;
begin
  StartCall;

  // Messages API is stateless — to keep context across turns, the
  // client maintains the full history and replays it. Prompt caching
  // on the server side makes this cheap from turn 2 onwards.
  asm
    (@FApiHistory).push({ role: 'user', content: @Prompt });
    @Body = JSON.stringify({ messages: @FApiHistory });
  end;

  PostJSON(API_URL + '?action=messages', Body,
    procedure(Data: variant)
    var Text_: String;
    begin
      asm @Text_ = (@Data).text || ''; end;
      if Text_ = '' then
        ReplyError('No text in response.')
      else
      begin
        // Append the assistant turn so the next call sees full context.
        asm (@FApiHistory).push({ role: 'assistant', content: @Text_ }); end;
        ReplyText(Text_);
      end;
    end,
    procedure(Status: Integer; Msg: String)
    begin
      ReplyError(Msg);
    end
  );
end;

// ═══════════════════════════════════════════════════════════════════════
//  Provider: CLI — local Claude CLI via PHP gateway, multi-turn
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.CallCli(const Prompt: String);
var Body: String;
begin
  StartCall;
  // Send session_id back on follow-ups so the CLI resumes the conversation.
  // On the first turn FCliSessionId is empty and the field is omitted.
  asm
    var msg = { action: 'rca', prompt: @Prompt };
    if (@FCliSessionId) msg.session_id = @FCliSessionId;
    @Body = JSON.stringify(msg);
  end;

  PostJSON(CLI_URL, Body,
    procedure(Data: variant)
    var
      IsError: Boolean;
      Result_: String;
      SessId:  String;
    begin
      asm
        @IsError = (@Data).is_error === true;
        @Result_ = (@Data).result || '';
        @SessId  = (@Data).session_id || '';
      end;
      // Latch the session id from the first response.
      if (SessId <> '') and (FCliSessionId = '') then
        FCliSessionId := SessId;

      if      IsError       then ReplyError(Result_)
      else if Result_ = ''  then ReplyError('No result in response.')
      else                       ReplyText(Result_);
    end,
    procedure(Status: Integer; Msg: String)
    begin
      ReplyError('Gateway: ' + Msg);
    end
  );
end;

// ═══════════════════════════════════════════════════════════════════════
//  Provider: Managed — skill-dispatch + SSE polling
// ═══════════════════════════════════════════════════════════════════════

procedure TFormLLM.CallManaged(const Prompt: String);
begin
  // First turn: spin up a fresh agent + session. Subsequent turns: send
  // the prompt as a new user.message into the running session and keep
  // polling the same stream.
  if FManagedSessionId = '' then
    StartManagedRun(Prompt)
  else
    ContinueManagedRun(Prompt);
end;

procedure TFormLLM.StartManagedRun(const Prompt: String);
var Body: String;
begin
  StartCall;
  FLastMessage     := '';
  FEventsProcessed := 0;
  FRetryCount      := 0;

  asm
    @Body = JSON.stringify({ skill: 'generic_assistant', task: @Prompt });
  end;

  PostJSON(API_URL + '?action=run', Body,
    procedure(Data: variant)
    var SessId: String;
    begin
      asm @SessId = (@Data).session_id || ''; end;
      if SessId = '' then
      begin
        FinishManagedRun(true, 'No session ID returned.');
        exit;
      end;
      FManagedSessionId := SessId;
      FPolling          := true;
      PollManagedStream;
    end,
    procedure(Status: Integer; Msg: String)
    begin
      FinishManagedRun(true, 'Gateway: ' + Msg);
    end
  );
end;

procedure TFormLLM.ContinueManagedRun(const Prompt: String);
var Body: String;
begin
  StartCall;
  FLastMessage := '';
  FRetryCount  := 0;
  // Do NOT reset FEventsProcessed — the stream is cumulative across turns,
  // so we keep the counter to skip events we've already rendered.

  asm
    @Body = JSON.stringify({ session_id: @FManagedSessionId, message: @Prompt });
  end;

  PostJSON(API_URL + '?action=send-message', Body,
    procedure(Data: variant)
    begin
      FPolling := true;
      PollManagedStream;
    end,
    procedure(Status: Integer; Msg: String)
    begin
      FinishManagedRun(true, 'Gateway: ' + Msg);
    end
  );
end;

procedure TFormLLM.StopManagedStream;
begin
  FPolling := false;
end;

procedure TFormLLM.PollManagedStream;
var Url: String;
begin
  if not FPolling then exit;
  Url := API_URL + '?action=stream&session=' + FManagedSessionId;

  FetchText(Url,
    procedure(Text: String)
    var
      Lines:       variant;
      N, i, Count: Integer;
      GotTerminal: Boolean;
    begin
      FRetryCount := 0;
      GotTerminal := false;
      Count       := 0;
      asm
        @Lines = (@Text).split('\n');
        @N     = (@Lines).length;
      end;

      for i := 0 to N - 1 do
      begin
        var Line: String;
        asm @Line = @Lines[@i] || ''; end;

        var IsData: Boolean;
        asm @IsData = (@Line).indexOf('data: ') === 0; end;
        if not IsData then continue;

        Inc(Count);
        if Count <= FEventsProcessed then continue;

        var JsonStr: String;
        asm @JsonStr = (@Line).slice(6); end;

        var Evt: variant;
        try
          asm @Evt = JSON.parse(@JsonStr); end;
        except
          continue;
        end;

        HandleManagedEvent(Evt);

        var EvtType: String;
        asm @EvtType = (@Evt) ? (@Evt).type : ''; end;
        if (EvtType = 'session.status_idle') or
           (EvtType = 'session.status_error') then
          GotTerminal := true;
      end;
      FEventsProcessed := Count;

      if FPolling and not GotTerminal then
      begin
        var Cb: variant;
        Cb := procedure() begin PollManagedStream; end;
        asm setTimeout(@Cb, 2000); end;
      end;
    end,
    procedure(Status: Integer; Msg: String)
    begin
      if FPolling and (Status < 400) and (FRetryCount < 5) then
      begin
        Inc(FRetryCount);
        var Cb: variant;
        Cb := procedure() begin PollManagedStream; end;
        asm setTimeout(@Cb, 5000); end;
      end
      else
        FinishManagedRun(true, 'Stream: ' + Msg);
    end
  );
end;

procedure TFormLLM.HandleManagedEvent(Evt: variant);
var EvtType: String;
begin
  asm @EvtType = (@Evt) ? (@Evt).type : ''; end;

  if EvtType = 'agent.message' then
  begin
    var Text_: String;
    asm
      var parts = ((@Evt).content || [])
        .filter(function(b){ return b.type === 'text'; })
        .map(function(b){ return b.text; });
      @Text_ = parts.join('');
    end;
    if Text_ <> '' then
      FLastMessage := Text_;
  end
  else if EvtType = 'session.status_idle' then
    FinishManagedRun(false, '')
  else if EvtType = 'session.status_error' then
  begin
    var ErrMsg: String;
    asm @ErrMsg = (@Evt).error ? (@Evt).error.message : 'Unknown error'; end;
    FinishManagedRun(true, ErrMsg);
  end;
end;

procedure TFormLLM.FinishManagedRun(IsError: Boolean; const ErrText: String);
begin
  StopManagedStream;
  if      IsError              then ReplyError(ErrText)
  else if FLastMessage = ''    then ReplyError('No response from agent.')
  else                              ReplyText(FLastMessage);
end;

end.
