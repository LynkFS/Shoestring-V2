unit MyFormEDAM2;

// ═══════════════════════════════════════════════════════════════════════════
//
//  MyFormEDAM2 — the phase-runner shell (desktop)
//
//  A left rail lists every phase (Setup, the seven EDAM2 artifacts, then the
//  not-yet-built Review and Generate, shown disabled). The right side is a
//  shared phase form: title, a one-line "what's being asked", and then either
//    • the Setup panel  (business case; theme/env/model settings come next), or
//    • the artifact panel (chat + input, the artifact surface, Accept), or
//    • a "done" message once everything is curated.
//
//  The rail RENDERS the state machine the loop already runs: glyphs come from
//  ArtifactCurated / NextArtifact, navigation just sets FActiveKey. The turn
//  logic underneath — the streaming prose/artifact split, persistence, the
//  propose/curate scaffold via Edam2SystemPrompt — is unchanged from the
//  proven loop; the shell only reframes it. Free navigation: click any phase.
//
//  Wiring: ExplicitUnitUses=1 — register in app.entrypoint.pas. PROXY_URL is
//  same-origin ('/proxy') through the tunnel path rule.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JForm, JElement, JChatPanel, JInput, JButton, JLLMTypes, JClaudeAdapter;

type
  TFormEDAM2 = class(TW3Form)
  private
    // rail
    FRail:       TElement;
    FRailBtns:   array of JW3Button;
    FRailKeys:   array of String;

    // right-side header + panels
    FTitle:        TElement;
    FDescLine:     TElement;
    FSetupPanel:   TElement;
    FArtifactPanel:TElement;
    FDonePanel:    TElement;

    // artifact panel widgets
    FChat:       JW3ChatPanel;
    FInput:      JW3Input;
    FSend:       JW3Button;
    FAccept:     JW3Button;
    FSurface:    TElement;        // <pre> showing the active artifact

    // setup panel widgets
    FBcLabel:      TElement;
    FBusinessCase: TElement;      // <textarea>
    FEnv:          TElement;      // <select> execution environment
    FTheme:        TElement;      // <select> theme
    FModel:        TElement;      // <select> model override (project over adapter)
    FSaveBC:       JW3Button;

    FAdapter:    TClaudeAdapter;
    FValidator:  TClaudeAdapter;   // one-shot consistency check, separate history
    FProject:    variant;
    FActiveKey:  String;          // selected phase: 'setup' | artifact key | 'review'
    FBusy:       Boolean;

    // review / validation panel
    FReviewPanel: TElement;
    FCheckBtn:    JW3Button;
    FValStatus:   TElement;
    FConflicts:   TElement;        // container for conflict cards
    FLastReport:  String;          // raw JSON from the last validation run

    // per-turn streaming state
    FSpan:       TElement;
    FRaw:        String;
    FShown:      Integer;
    FInArtifact: Boolean;

    // turn loop (unchanged)
    procedure DoSend;
    procedure DoAccept;
    procedure HandleDelta(const Chunk: String);
    procedure HandleDone(const AResult: TLLMResult);
    procedure HandleError(AStatus: Integer; const AMsg: String);
    procedure ClearInput;
    procedure PersistQuiet;
    function  BuildSystemPrompt: String;
    function  PosFrom(const Sub, S: String; FromIdx: Integer): Integer;
    function  ExtractArtifactBody(const Raw: String; var Body: String): Boolean;

    // setup
    procedure DoSaveSetup;
    procedure RefreshSetup;
    procedure ApplyModel;
    function  AddSetupSelect(const ALabel, AOptionsHtml: String): TElement;
    function  ElValue(El: TElement): String;
    procedure SetElValue(El: TElement; const AText: String);

    // runner shell
    procedure AddRailRow(const AKey: String; AEnabled: Boolean);
    procedure SelectPhase(const AKey: String);
    procedure RefreshAll;
    procedure RefreshRail;
    procedure RefreshHeader;
    procedure RefreshSurface;
    function  Glyph(const AKey: String): String;
    function  PhaseTitle(const AKey: String): String;
    function  PhaseDesc(const AKey: String): String;
    function  IsArtifact(const AKey: String): Boolean;
    function  InitialKey: String;

    // validation (Review phase)
    procedure DoValidate;
    procedure HandleValidation(const AResult: TLLMResult);
    procedure RenderConflicts;
    procedure AddConflictCard(const AId, ASev, AIss, ASug, AArts: String);
    procedure DismissCard(const AId: String);
    function  ParseConflicts(const AJson: String): variant;
    procedure ClearChildren(El: TElement);
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals, JProjectStore, JEdam2Prompts;

const
  PROXY_URL    = '/proxy';
  PROJECT_NAME = 'scratch';
  ARTIFACT_TAG = '<artifact';

  GL_DONE = '✓';
  GL_NOW  = '●';
  GL_TODO = '○';
  GL_OFF  = '·';
  HILITE  = 'var(--accent-soft, #eef2ff)';

  ARTIFACT_KEYS: array[0..6] of String =
    ('events', 'roles', 'policy', 'boundary',
     'reporting', 'notifications', 'errors');


// ── construction ────────────────────────────────────────────────────────────

procedure TFormEDAM2.InitializeObject;
var
  RightWrap, InputRow, railHdr, doneMsg, settingsHdr: TElement;
  i: Integer;
begin
  inherited;

  SetStyle('display', 'flex');
  SetStyle('height', '100vh');
  SetStyle('box-sizing', 'border-box');
  SetStyle('font-family', 'system-ui, sans-serif');

  // ── Left rail ──────────────────────────────────────────────────────────
  FRail := TElement.Create('div', Self);
  FRail.SetStyle('flex', '0 0 220px');
  FRail.SetStyle('display', 'flex');
  FRail.SetStyle('flex-direction', 'column');
  FRail.SetStyle('gap', '2px');
  FRail.SetStyle('padding', '10px');
  FRail.SetStyle('border-right', '1px solid var(--border-color, #e2e8f0)');
  FRail.SetStyle('overflow-y', 'auto');

  railHdr := TElement.Create('div', FRail);
  railHdr.SetText('PHASES');
  railHdr.SetStyle('font-size', '11px');
  railHdr.SetStyle('font-weight', '600');
  railHdr.SetStyle('letter-spacing', '0.08em');
  railHdr.SetStyle('color', '#64748b');
  railHdr.SetStyle('padding', '4px 10px 8px');

  AddRailRow('setup', True);
  for i := 0 to High(ARTIFACT_KEYS) do
    AddRailRow(ARTIFACT_KEYS[i], True);
  AddRailRow('review', True);
  AddRailRow('generate', False);

  // ── Right side ───────────────────────────────────────────────────────────
  RightWrap := TElement.Create('div', Self);
  RightWrap.SetStyle('flex', '1 1 auto');
  RightWrap.SetStyle('min-width', '0');
  RightWrap.SetStyle('display', 'flex');
  RightWrap.SetStyle('flex-direction', 'column');
  RightWrap.SetStyle('gap', '8px');
  RightWrap.SetStyle('padding', '14px');
  RightWrap.SetStyle('overflow', 'hidden');

  FTitle := TElement.Create('div', RightWrap);
  FTitle.SetStyle('font-size', '18px');
  FTitle.SetStyle('font-weight', '600');

  FDescLine := TElement.Create('div', RightWrap);
  FDescLine.SetStyle('font-size', '13px');
  FDescLine.SetStyle('color', '#64748b');

  // ── Setup panel ──
  FSetupPanel := TElement.Create('div', RightWrap);
  FSetupPanel.SetStyle('display', 'none');
  FSetupPanel.SetStyle('flex', '1 1 auto');
  FSetupPanel.SetStyle('min-height', '0');
  FSetupPanel.SetStyle('overflow-y', 'auto');
  FSetupPanel.SetStyle('flex-direction', 'column');
  FSetupPanel.SetStyle('gap', '8px');

  FBcLabel := TElement.Create('div', FSetupPanel);
  FBcLabel.SetText('Business case');
  FBcLabel.SetStyle('font-weight', '500');

  FBusinessCase := TElement.Create('textarea', FSetupPanel);
  FBusinessCase.SetStyle('width', '100%');
  FBusinessCase.SetStyle('box-sizing', 'border-box');
  FBusinessCase.SetStyle('min-height', '160px');
  FBusinessCase.SetStyle('resize', 'vertical');
  FBusinessCase.SetStyle('padding', '8px');
  FBusinessCase.SetStyle('border', '1px solid var(--border-color, #e2e8f0)');
  FBusinessCase.SetStyle('border-radius', '8px');
  FBusinessCase.SetStyle('font-family', 'system-ui, sans-serif');
  FBusinessCase.SetStyle('font-size', '13px');

  settingsHdr := TElement.Create('div', FSetupPanel);
  settingsHdr.SetText('Generation settings');
  settingsHdr.SetStyle('font-weight', '500');
  settingsHdr.SetStyle('margin-top', '6px');

  FEnv := AddSetupSelect('Execution environment',
    '<option value="webapp+sqljs">Web app + SQL.js</option>' +
    '<option value="webapp+mysql">Web app + MySQL</option>');

  FTheme := AddSetupSelect('Theme',
    '<option value="default">Default (Zinc Violet)</option>');

  // NOTE: replace these ids with whatever your proxy /v1/models accepts.
  // '' = use the adapter's built-in default (always safe).
  FModel := AddSetupSelect('Model (overrides adapter default)',
    '<option value="">Default (adapter)</option>' +
    '<option value="claude-opus-4-8">claude-opus-4-8</option>' +
    '<option value="claude-sonnet-4-6">claude-sonnet-4-6</option>');

  FSaveBC := JW3Button.Create(FSetupPanel);
  FSaveBC.Caption := 'Save setup';
  FSaveBC.OnClick := lambda DoSaveSetup; end;

  // ── Artifact panel ──
  FArtifactPanel := TElement.Create('div', RightWrap);
  FArtifactPanel.SetStyle('display', 'none');
  FArtifactPanel.SetStyle('flex', '1 1 auto');
  FArtifactPanel.SetStyle('flex-direction', 'column');
  FArtifactPanel.SetStyle('gap', '8px');
  FArtifactPanel.SetStyle('min-height', '0');

  FChat := JW3ChatPanel.Create(FArtifactPanel);
  FChat.SetStyle('flex', '1 1 42%');
  FChat.SetStyle('min-height', '0');
  FChat.SetStyle('overflow-y', 'auto');

  InputRow := TElement.Create('div', FArtifactPanel);
  InputRow.SetStyle('display', 'flex');
  InputRow.SetStyle('gap', '8px');

  FInput := JW3Input.Create(InputRow);
  FInput.Placeholder := 'Describe or refine the artifact...';
  FInput.InputType   := 'text';
  FInput.SetStyle('flex', '1 1 auto');

  FSend := JW3Button.Create(InputRow);
  FSend.Caption := 'Send';
  FSend.OnClick := lambda DoSend; end;

  FSurface := TElement.Create('pre', FArtifactPanel);
  FSurface.SetStyle('flex', '1 1 55%');
  FSurface.SetStyle('min-height', '0');
  FSurface.SetStyle('overflow', 'auto');
  FSurface.SetStyle('margin', '0');
  FSurface.SetStyle('padding', '12px');
  FSurface.SetStyle('background', 'var(--surface-3, #f5f5f7)');
  FSurface.SetStyle('border', '1px solid var(--border-color, #e2e8f0)');
  FSurface.SetStyle('border-radius', '8px');
  FSurface.SetStyle('white-space', 'pre-wrap');
  FSurface.SetStyle('word-break', 'break-word');
  FSurface.SetStyle('font-family', 'ui-monospace, monospace');
  FSurface.SetStyle('font-size', '12px');

  FAccept := JW3Button.Create(FArtifactPanel);
  FAccept.Caption := 'Accept & continue';
  FAccept.OnClick := lambda DoAccept; end;

  // ── Review / validation panel ──
  FReviewPanel := TElement.Create('div', RightWrap);
  FReviewPanel.SetStyle('display', 'none');
  FReviewPanel.SetStyle('flex', '1 1 auto');
  FReviewPanel.SetStyle('min-height', '0');
  FReviewPanel.SetStyle('overflow-y', 'auto');
  FReviewPanel.SetStyle('flex-direction', 'column');
  FReviewPanel.SetStyle('gap', '8px');

  FCheckBtn := JW3Button.Create(FReviewPanel);
  FCheckBtn.Caption := 'Check consistency';
  FCheckBtn.OnClick := lambda DoValidate; end;

  FValStatus := TElement.Create('div', FReviewPanel);
  FValStatus.SetStyle('font-size', '13px');
  FValStatus.SetStyle('color', '#64748b');

  FConflicts := TElement.Create('div', FReviewPanel);
  FConflicts.SetStyle('display', 'flex');
  FConflicts.SetStyle('flex-direction', 'column');
  FConflicts.SetStyle('gap', '8px');

  // ── Done panel ──
  FDonePanel := TElement.Create('div', RightWrap);
  FDonePanel.SetStyle('display', 'none');
  FDonePanel.SetStyle('flex', '1 1 auto');
  FDonePanel.SetStyle('align-items', 'center');
  FDonePanel.SetStyle('justify-content', 'center');
  FDonePanel.SetStyle('color', '#64748b');
  doneMsg := TElement.Create('div', FDonePanel);
  doneMsg.SetText('All seven artifacts are curated. Review and code generation are coming soon.');

  // ── state ──────────────────────────────────────────────────────────────
  FBusy    := False;
  FAdapter := TClaudeAdapter.Create(PROXY_URL);
  FAdapter.MaxTokens := 24000;

  FValidator := TClaudeAdapter.Create(PROXY_URL);
  FValidator.MaxTokens := 8000;
  FLastReport := '';

  FProject   := NewProject(PROJECT_NAME);
  FActiveKey := InitialKey;
  RefreshAll;

  // Resume a saved scratch project if one exists; otherwise keep the fresh one.
  LoadProject(PROJECT_NAME,
    procedure(Data: variant)
    begin
      FProject   := Data;
      ApplyModel;
      FActiveKey := InitialKey;
      RefreshAll;
    end,
    procedure(const AName: String) begin end,
    procedure(AStatus: Integer; AMessage: String) begin end);
end;


// ── runner shell ────────────────────────────────────────────────────────────

procedure TFormEDAM2.AddRailRow(const AKey: String; AEnabled: Boolean);
var
  btn: JW3Button;
begin
  btn := JW3Button.Create(FRail);
  btn.Caption := PhaseTitle(AKey);
  btn.SetStyle('display', 'block');
  btn.SetStyle('width', '100%');
  btn.SetStyle('text-align', 'left');
  btn.SetStyle('background', 'transparent');
  btn.SetStyle('border', 'none');
  btn.SetStyle('border-radius', '6px');
  btn.SetStyle('padding', '8px 10px');
  btn.SetStyle('font', 'inherit');
  btn.SetStyle('color', 'inherit');
  btn.SetStyle('cursor', 'pointer');
  if not AEnabled then
  begin
    btn.SetStyle('opacity', '0.4');
    btn.SetStyle('cursor', 'default');
  end
  else
    btn.OnClick := lambda SelectPhase(AKey); end;
  FRailBtns.Add(btn);
  FRailKeys.Add(AKey);
end;

procedure TFormEDAM2.SelectPhase(const AKey: String);
begin
  if FBusy then Exit;
  FActiveKey := AKey;
  if IsArtifact(AKey) then
    SetPhase(FProject, AKey);
  RefreshAll;
end;

procedure TFormEDAM2.RefreshRail;
var
  i: Integer;
  k: String;
begin
  for i := 0 to High(FRailBtns) do
  begin
    k := FRailKeys[i];
    FRailBtns[i].Caption := Glyph(k) + '  ' + PhaseTitle(k);
    if k = FActiveKey then
      FRailBtns[i].SetStyle('background', HILITE)
    else
      FRailBtns[i].SetStyle('background', 'transparent');
  end;
end;

procedure TFormEDAM2.RefreshHeader;
begin
  FTitle.SetText(PhaseTitle(FActiveKey));
  FDescLine.SetText(PhaseDesc(FActiveKey));
end;

procedure TFormEDAM2.RefreshAll;
var
  isSetup, isArt, isReview: Boolean;
begin
  RefreshRail;
  RefreshHeader;
  isSetup  := FActiveKey = 'setup';
  isArt    := IsArtifact(FActiveKey);
  isReview := FActiveKey = 'review';

  if isSetup then FSetupPanel.SetStyle('display', 'flex')
             else FSetupPanel.SetStyle('display', 'none');
  if isArt   then FArtifactPanel.SetStyle('display', 'flex')
             else FArtifactPanel.SetStyle('display', 'none');
  if isReview then FReviewPanel.SetStyle('display', 'flex')
              else FReviewPanel.SetStyle('display', 'none');
  if (not isSetup) and (not isArt) and (not isReview) then
    FDonePanel.SetStyle('display', 'flex')
  else
    FDonePanel.SetStyle('display', 'none');

  if isSetup then RefreshSetup
  else if isArt then RefreshSurface
  else if isReview then RenderConflicts;
end;

function TFormEDAM2.Glyph(const AKey: String): String;
begin
  if AKey = 'setup' then
  begin
    if GetSetup(FProject, 'businessCase') <> '' then Result := GL_DONE
    else Result := GL_TODO;
  end
  else if AKey = 'generate' then
    Result := GL_OFF
  else if AKey = 'review' then
    Result := GL_TODO
  else if ArtifactCurated(FProject, AKey) then
    Result := GL_DONE
  else if AKey = NextArtifact(FProject) then
    Result := GL_NOW
  else
    Result := GL_TODO;
end;

function TFormEDAM2.PhaseTitle(const AKey: String): String;
begin
  if AKey = 'setup' then Result := 'Setup'
  else if AKey = 'events' then Result := 'Events'
  else if AKey = 'roles' then Result := 'Roles & Permissions'
  else if AKey = 'policy' then Result := 'Policy Rules'
  else if AKey = 'boundary' then Result := 'Boundary Map'
  else if AKey = 'reporting' then Result := 'Reporting'
  else if AKey = 'notifications' then Result := 'Notifications'
  else if AKey = 'errors' then Result := 'Errors & Recovery'
  else if AKey = 'review' then Result := 'Review'
  else if AKey = 'generate' then Result := 'Generate'
  else Result := AKey;
end;

function TFormEDAM2.PhaseDesc(const AKey: String): String;
begin
  if AKey = 'setup' then
    Result := 'Enter the business case. Theme and execution settings come next.'
  else if AKey = 'review' then
    Result := 'Check the curated artifacts for cross-artifact inconsistencies.'
  else if AKey = 'generate' then
    Result := 'Coming soon.'
  else
    Result := Edam2ArtifactSummary(AKey);
end;

function TFormEDAM2.IsArtifact(const AKey: String): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(ARTIFACT_KEYS) do
    if ARTIFACT_KEYS[i] = AKey then
    begin
      Result := True;
      Exit;
    end;
end;

function TFormEDAM2.InitialKey: String;
var
  f: String;
begin
  if GetSetup(FProject, 'businessCase') = '' then
    Result := 'setup'
  else
  begin
    f := NextArtifact(FProject);
    if f = '' then Result := 'review' else Result := f;
  end;
end;


// ── a turn (unchanged loop) ──────────────────────────────────────────────────

procedure TFormEDAM2.DoSend;
var
  Txt: String;
begin
  if FBusy then Exit;
  if not IsArtifact(FActiveKey) then Exit;
  Txt := Trim(FInput.Value);
  if Txt = '' then Exit;

  FBusy := True;
  FChat.AppendUser(Txt);
  ClearInput;

  FAdapter.System := BuildSystemPrompt;

  FRaw        := '';
  FShown      := 0;
  FInArtifact := False;
  FSpan       := FChat.BeginAssistant;

  FAdapter.SendStreaming(Txt,
    procedure(const Chunk: String)
    begin
      HandleDelta(Chunk);
    end,
    procedure(const AResult: TLLMResult)
    begin
      HandleDone(AResult);
    end,
    procedure(AStatus: Integer; const AMessage: String)
    begin
      HandleError(AStatus, AMessage);
    end);
end;

// Pure-Pascal split: reveal prose up to the artifact delimiter, then stop.
procedure TFormEDAM2.HandleDelta(const Chunk: String);
var
  idx, revealEnd, safeEnd: Integer;
begin
  FRaw := FRaw + Chunk;
  if FInArtifact then Exit;

  idx := Pos(ARTIFACT_TAG, FRaw);
  if idx > 0 then
  begin
    revealEnd := idx - 1;
    if revealEnd > FShown then
    begin
      FChat.AppendAssistantChunk(FSpan, Copy(FRaw, FShown + 1, revealEnd - FShown));
      FShown := revealEnd;
    end;
    FInArtifact := True;
  end
  else
  begin
    safeEnd := Length(FRaw) - (Length(ARTIFACT_TAG) - 1);
    if safeEnd > FShown then
    begin
      FChat.AppendAssistantChunk(FSpan, Copy(FRaw, FShown + 1, safeEnd - FShown));
      FShown := safeEnd;
    end;
  end;
end;

procedure TFormEDAM2.HandleDone(const AResult: TLLMResult);
var
  Body: String;
begin
  if AResult.FinishReason = 'max_tokens' then
    FChat.AppendAssistant('That response was cut off at the token limit — the ' +
      'artifact is incomplete. Try again, or I can raise the limit.');

  if (not FInArtifact) and (Length(FRaw) > FShown) then
  begin
    FChat.AppendAssistantChunk(FSpan, Copy(FRaw, FShown + 1, Length(FRaw) - FShown));
    FShown := Length(FRaw);
  end;

  FChat.FinishAssistant(FSpan);

  if ExtractArtifactBody(FRaw, Body) then
  begin
    SetArtifact(FProject, FActiveKey, Body, False);   // proposed, not yet curated
    RefreshAll;
    PersistQuiet;
  end;

  FBusy := False;
end;

procedure TFormEDAM2.HandleError(AStatus: Integer; const AMsg: String);
begin
  if Length(FRaw) > FShown then
  begin
    FChat.AppendAssistantChunk(FSpan, Copy(FRaw, FShown + 1, Length(FRaw) - FShown));
    FShown := Length(FRaw);
  end;
  FChat.FinishAssistant(FSpan);
  FChat.AppendAssistant('Error ' + IntToStr(AStatus) + ': ' + AMsg);
  FBusy := False;
end;

procedure TFormEDAM2.DoAccept;
var
  f: String;
begin
  if FBusy then Exit;
  if not IsArtifact(FActiveKey) then Exit;

  if Trim(ArtifactContent(FProject, FActiveKey)) = '' then
  begin
    FChat.AppendAssistant('Nothing to accept yet — the ' + FActiveKey +
                          ' artifact is still empty.');
    Exit;
  end;

  SetArtifact(FProject, FActiveKey, ArtifactContent(FProject, FActiveKey), True);
  PersistQuiet;

  f := NextArtifact(FProject);
  if f <> '' then
  begin
    FActiveKey := f;
    SetPhase(FProject, f);
  end
  else
    FActiveKey := 'review';

  FAdapter.Reset;          // new phase = fresh within-phase history; state via System
  RefreshAll;
end;


// ── setup ─────────────────────────────────────────────────────────────────

procedure TFormEDAM2.DoSaveSetup;
var
  bc: String;
begin
  bc := Trim(ElValue(FBusinessCase));
  SetSetup(FProject, 'businessCase', bc);
  SetSetup(FProject, 'deployment',   ElValue(FEnv));
  SetSetup(FProject, 'style',        ElValue(FTheme));
  SetSetup(FProject, 'model',        ElValue(FModel));
  ApplyModel;
  PersistQuiet;
  RefreshRail;             // the Setup glyph reflects whether a business case exists
  if bc = '' then
    FChat.AppendAssistant('Settings saved. The business case is empty — add one so ' +
                          'each artifact can derive from it.')
  else
    FChat.AppendAssistant('Setup saved - the business case and generation settings ' +
                          'inform every artifact from here on.');
end;

procedure TFormEDAM2.RefreshSetup;
var
  dep, sty: String;
begin
  SetElValue(FBusinessCase, GetSetup(FProject, 'businessCase'));

  dep := GetSetup(FProject, 'deployment');
  if (dep <> 'webapp+sqljs') and (dep <> 'webapp+mysql') then dep := 'webapp+sqljs';
  SetElValue(FEnv, dep);

  sty := GetSetup(FProject, 'style');
  if sty = '' then sty := 'default';
  SetElValue(FTheme, sty);

  SetElValue(FModel, GetSetup(FProject, 'model'));   // '' selects "Default (adapter)"
end;

procedure TFormEDAM2.ApplyModel;
var
  m: String;
begin
  m := GetSetup(FProject, 'model');
  if m <> '' then
  begin
    FAdapter.Model := m;
    FValidator.Model := m;
  end;
end;

function TFormEDAM2.AddSetupSelect(const ALabel, AOptionsHtml: String): TElement;
var
  lbl, sel: TElement;
begin
  lbl := TElement.Create('div', FSetupPanel);
  lbl.SetText(ALabel);
  lbl.SetStyle('font-size', '13px');
  lbl.SetStyle('color', '#475569');
  lbl.SetStyle('margin-top', '4px');

  sel := TElement.Create('select', FSetupPanel);
  sel.SetHTML(AOptionsHtml);            // static option markup, no user input
  sel.SetStyle('padding', '6px 8px');
  sel.SetStyle('border', '1px solid var(--border-color, #e2e8f0)');
  sel.SetStyle('border-radius', '6px');
  sel.SetStyle('font', 'inherit');
  sel.SetStyle('max-width', '340px');
  Result := sel;
end;

function TFormEDAM2.ElValue(El: TElement): String;
var
  h: variant;
begin
  h := El.Handle;
  asm @Result = (@h).value || ''; end;
end;

procedure TFormEDAM2.SetElValue(El: TElement; const AText: String);
var
  h: variant;
begin
  h := El.Handle;
  asm (@h).value = @AText; end;
end;


// ── validation (Review phase) ───────────────────────────────────────────────

procedure TFormEDAM2.DoValidate;
begin
  if FBusy then Exit;
  FBusy := True;
  ClearChildren(FConflicts);
  FValStatus.SetText('Checking consistency across the curated artifacts...');

  FValidator.Reset;
  FValidator.System := Edam2ValidationPrompt(FProject);
  FValidator.Send('Validate now and return the JSON array of conflicts.',
    procedure(const AResult: TLLMResult)
    begin
      HandleValidation(AResult);
    end,
    procedure(AStatus: Integer; const AMessage: String)
    begin
      FValStatus.SetText('Validation failed: ' + IntToStr(AStatus) + ' ' + AMessage);
      FBusy := False;
    end);
end;

procedure TFormEDAM2.HandleValidation(const AResult: TLLMResult);
begin
  asm console.log('VAL>>>', @AResult.FinishReason, @AResult.Text); end;
  FLastReport := AResult.Text;
  SetValidationReport(FProject, FLastReport);
  PersistQuiet;
  RenderConflicts;
  FBusy := False;
end;

procedure TFormEDAM2.RenderConflicts;
var
  arr: variant;
  n, i, shown: Integer;
  id, sev, iss, sug, arts: String;
begin
  ClearChildren(FConflicts);

  if Trim(FLastReport) = '' then
  begin
    FValStatus.SetText('Click "Check consistency" to validate the curated artifacts.');
    Exit;
  end;

  arr := ParseConflicts(FLastReport);
  n := 0;
  asm @n = Array.isArray(@arr) ? (@arr).length : 0; end;

  if n = 0 then
  begin
    FValStatus.SetText('No inconsistencies found on this pass. Validation is ' +
                       'probabilistic — run Check consistency again to confirm.');
    Exit;
  end;

  shown := 0;
  for i := 0 to n - 1 do
  begin
    id := ''; sev := ''; iss := ''; sug := ''; arts := '';
    asm
      var c = (@arr)[@i] || {};
      @id   = String(c.id || '');
      @sev  = String(c.severity || '');
      @iss  = String(c.issue || '');
      @sug  = String(c.suggestion || '');
      @arts = Array.isArray(c.artifacts) ? c.artifacts.join(', ') : String(c.artifacts || '');
    end;
    if IsDismissed(FProject, id) then Continue;
    AddConflictCard(id, sev, iss, sug, arts);
    shown := shown + 1;
  end;

  if shown = 0 then
    FValStatus.SetText('All detected issues were previously dismissed.')
  else
    FValStatus.SetText('Found ' + IntToStr(shown) + ' issue(s) to review:');
end;

procedure TFormEDAM2.AddConflictCard(const AId, ASev, AIss, ASug, AArts: String);
var
  card, head, body, meta: TElement;
  dismiss: JW3Button;
begin
  card := TElement.Create('div', FConflicts);
  card.SetStyle('border', '1px solid var(--border-color, #e2e8f0)');
  card.SetStyle('border-left', '4px solid #f59e0b');
  card.SetStyle('border-radius', '8px');
  card.SetStyle('padding', '10px 12px');
  card.SetStyle('background', 'var(--surface-2, #fafafa)');

  head := TElement.Create('div', card);
  head.SetText('[' + ASev + ']  ' + AIss);
  head.SetStyle('font-weight', '500');

  meta := TElement.Create('div', card);
  meta.SetText('Affects: ' + AArts);
  meta.SetStyle('font-size', '12px');
  meta.SetStyle('color', '#64748b');
  meta.SetStyle('margin-top', '4px');

  body := TElement.Create('div', card);
  body.SetText('Suggestion: ' + ASug);
  body.SetStyle('font-size', '13px');
  body.SetStyle('margin-top', '4px');

  dismiss := JW3Button.Create(card);
  dismiss.Caption := 'Dismiss';
  dismiss.SetStyle('margin-top', '8px');
  dismiss.OnClick := lambda DismissCard(AId); end;
end;

procedure TFormEDAM2.DismissCard(const AId: String);
begin
  DismissConflict(FProject, AId);
  PersistQuiet;
  RenderConflicts;     // the dismissed card drops out on re-render
end;

function TFormEDAM2.ParseConflicts(const AJson: String): variant;
var
  s: String;
begin
  s := AJson;
  asm
    var t = @s;
    var a = t.indexOf('[');
    var b = t.lastIndexOf(']');
    var out = [];
    if (a >= 0 && b > a) {
      try { out = JSON.parse(t.slice(a, b + 1)); } catch (e) { out = []; }
    }
    @Result = Array.isArray(out) ? out : [];
  end;
end;

procedure TFormEDAM2.ClearChildren(El: TElement);
var
  h: variant;
begin
  h := El.Handle;
  asm (@h).innerHTML = ''; end;
end;


// ── helpers ───────────────────────────────────────────────────────────────

procedure TFormEDAM2.RefreshSurface;
begin
  if IsArtifact(FActiveKey) then
    FSurface.SetText(ArtifactContent(FProject, FActiveKey))
  else
    FSurface.SetText('');
end;

procedure TFormEDAM2.ClearInput;
var
  h: variant;
begin
  h := FInput.Handle;
  asm
    var el = @h;
    if (el && el.tagName === 'INPUT') el.value = '';
    else if (el) { var inp = el.querySelector('input'); if (inp) inp.value = ''; }
  end;
end;

procedure TFormEDAM2.PersistQuiet;
begin
  SaveProject(PROJECT_NAME, FProject,
    procedure(Data: variant) begin end,
    procedure(AStatus: Integer; AMessage: String) begin end);
end;

function TFormEDAM2.BuildSystemPrompt: String;
begin
  Result := Edam2SystemPrompt(FProject, FActiveKey);
end;

// Pos for Sub in S, starting at FromIdx (1-based). 0 if absent.
function TFormEDAM2.PosFrom(const Sub, S: String; FromIdx: Integer): Integer;
var
  rel: Integer;
  tail: String;
begin
  if FromIdx < 1 then FromIdx := 1;
  tail := Copy(S, FromIdx, Length(S) - FromIdx + 1);
  rel  := Pos(Sub, tail);
  if rel = 0 then Result := 0 else Result := FromIdx + rel - 1;
end;

// Body is whatever sits between the first '<artifact ...>' open tag and the
// next '</artifact>'. Name attribute is ignored — FActiveKey is authoritative.
function TFormEDAM2.ExtractArtifactBody(const Raw: String; var Body: String): Boolean;
var
  o, gt, c: Integer;
begin
  Result := False;
  Body   := '';
  o := Pos(ARTIFACT_TAG, Raw);
  if o = 0 then Exit;
  gt := PosFrom('>', Raw, o);
  if gt = 0 then Exit;
  c := PosFrom('</artifact>', Raw, gt + 1);
  if c = 0 then Exit;
  Body   := Trim(Copy(Raw, gt + 1, c - (gt + 1)));
  Result := True;
end;

end.
