unit FormResearch;

// ═══════════════════════════════════════════════════════════════════════════
//  FormResearch — the by-hand console for the research ledger.
//
//  The store is the only coupling (the FormLLM idiom): the engine
//  (JLedger / JGates / JBudget) writes ledger.* and meter.* keys; this form
//  subscribes and renders, and its controls call the ledger's guarded
//  transitions. No gate logic lives here — it adds a surface, not a rule.
//
//  Self-contained: enter a claim, attach evidence and the steelman, set the
//  fields the gates read, then Promote (runs the gates) and Publish (a human
//  act, asks for a sign-off). A refused promote shows the exact gate reasons.
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  JForm, JElement, JButton, JTextArea,
  JDataStore, JGates, JLedger, JBudget;

type
  TVoidProc = procedure;

  TFormResearch = class(TW3Form)
  private
    FStore:    JW3DataStore;
    FLedger:   TLedger;
    FBudget:   TBudget;
    FArticleBtn: JW3Button;
    FPack:     variant;
    FSelected: String;
    FBusy:     Boolean;

    FMeter:     TElement;
    FList:      TElement;
    FLoadInput: TElement;

    // entry
    FClaimText:  TElement;
    FSpeciesSel: TElement;
    FAddBtn:     JW3Button;

    // detail / editor
    FDetail:        TElement;
    FClaimDisp:     TElement;
    FWhy:           TElement;
    FJudge:         TElement;
    FAdvisor:       TElement;
    FSpeciesCur:    TElement;
    FSpeciesAdd:    TElement;
    FSpeciesAddBtn: JW3Button;
    FClaimTypeSel:  TElement;
    FCausalSel:     TElement;
    FRiskSel:       TElement;
    FPredChk:       TElement;
    FHarmChk:       TElement;
    FRegInput:      TElement;
    FSteelman:      TElement;
    FSrcList:       TElement;
    FSrcTier:       TElement;
    FSrcOrigin:     TElement;
    FSrcUrl:        TElement;
    FAddSrcBtn:     JW3Button;
    FPromote:       JW3Button;
    FPublish:       JW3Button;

    procedure BuildEntry(AParent: TElement);
    procedure BuildEditor(AParent: TElement);
    procedure WireStore;
    procedure RenderMeter;
    procedure RenderList;
    procedure RenderDetail;
    procedure RenderSources(AClaim: variant);
    procedure SelectClaim(const AId: String);
    procedure DoAddClaim;
    procedure DoAddSpecies;
    procedure DoAddSource;
    procedure DoPromote;
    procedure DoPublish;
    procedure ConsultAdvisor(const AId: String; ADone: TVoidProc);
    procedure WriteArticle;
    procedure PromptSignoffAndPublish(const AId: String);
    function  StatusColour(const AStatus: String): String;
  protected
    procedure InitializeObject; override;
  end;

implementation

var
  LF = #10;
  PROXY_URL     = 'http://localhost:3030';
  ADVISOR_MODEL = 'claude-opus-4-8';
  SYNTH_MODEL   = 'claude-sonnet-4-6';

type
  TTextProc = procedure(const S: String);
  TJsonProc = procedure(Data: variant);
  TErrProc  = procedure(Status: Integer; Msg: String);

// Read the chosen file from a change event and hand its text to OnText.
// asm touches only parameters — the proven crossing pattern.
procedure ReadFileAsText(e: variant; OnText: TTextProc);
begin
  asm
    var f = (@e) && (@e).target && (@e).target.files && (@e).target.files[0];
    if (f) {
      var rd = new FileReader();
      rd.onload = function (ev) { (@OnText)(String((ev && ev.target && ev.target.result) || '')); };
      rd.readAsText(f);
    }
  end;
end;

// Offer AText as a downloadable file named AName (the round trip back to disk).
procedure DownloadText(const AName, AText: String);
begin
  asm
    var blob = new Blob([@AText], { type: 'application/json' });
    var url  = URL.createObjectURL(blob);
    var a    = document.createElement('a');
    a.href = url;
    a.download = @AName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  end;
end;

// ── rung-2 plumbing — verbatim ports of the runner's proven helpers ─────────

procedure PostJSONWeb(const AUrl, ABody: String; OnResult: TJsonProc; OnError: TErrProc);
begin
  asm
    fetch(@AUrl, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    @ABody,
      signal:  AbortSignal.timeout(90000)
    }).then(function (resp) {
      return resp.text().then(function (t) { return { ok: resp.ok, status: resp.status, text: t }; });
    }).then(function (x) {
      if (x.ok) {
        var d;
        try { d = JSON.parse(x.text); } catch (e) { (@OnError)(x.status, 'bad JSON from proxy'); return; }
        (@OnResult)(d);
      } else {
        (@OnError)(x.status, x.text || 'HTTP error');
      }
    }).catch(function (e) {
      (@OnError)(0, String((e && e.message) || e));
    });
  end;
end;

function ParseJsonLoose(const AText: String): variant;
begin
  asm
    var s = String(@AText || '');
    var a = s.indexOf('['); var o = s.indexOf('{');
    var start = -1;
    if (a === -1) start = o; else if (o === -1) start = a; else start = Math.min(a, o);
    var endA = s.lastIndexOf(']'); var endO = s.lastIndexOf('}');
    var fin = Math.max(endA, endO);
    var r = null;
    if (start !== -1 && fin !== -1 && fin > start) {
      try { r = JSON.parse(s.slice(start, fin + 1)); } catch (e) { r = null; }
    }
    @Result = r;
  end;
end;

function JsonOk(v: variant): Boolean;
begin
  asm @Result = ((@v) !== null && (@v) !== undefined); end;
end;

function ResultText(AData: variant): String;
begin
  asm @Result = String(((@AData) && (@AData).text) || ''); end;
end;

function ResultIn(AData: variant): Integer;
begin
  asm @Result = ((@AData) && (@AData).usage && (@AData).usage.inputTokens) || 0; end;
end;

function ResultOut(AData: variant): Integer;
begin
  asm @Result = ((@AData) && (@AData).usage && (@AData).usage.outputTokens) || 0; end;
end;

// Content hash of claim text + verified source URLs — the advisor cache key.
// Identical to the runner's, so counsel earned on either side is honoured by both.
function ClaimHash(const AText: String; ASources: variant): String;
begin
  asm
    var urls = [];
    var a = (@ASources) || [];
    for (var i = 0; i < a.length; i++) {
      if (a[i] && a[i].verified !== false && a[i].url) urls.push(String(a[i].url));
    }
    urls.sort();
    var s = String(@AText) + '|' + urls.join('|');
    var h = 5381;
    for (var j = 0; j < s.length; j++) { h = ((h * 33) ^ s.charCodeAt(j)) >>> 0; }
    @Result = 'k' + h.toString(36);
  end;
end;

function ClaimSources(AClaim: variant): variant;
begin
  asm @Result = ((@AClaim) && (@AClaim).sources) || []; end;
end;

function SourceLines(ASources: variant): String;
var
  s: String;
begin
  s := '';
  asm
    var a = (@ASources) || [];
    var out = '';
    for (var i = 0; i < a.length; i++) {
      if (a[i] && a[i].verified !== false) {
        out = out + '- Tier ' + String(a[i].tier || 5) + ': ' + String(a[i].origin || '')
            + ' (' + String(a[i].url || '') + ')' + String.fromCharCode(10);
      }
    }
    @s = out;
  end;
  if s = '' then s := '(no verified sources)';
  Result := s;
end;

// ── snapshot readers ─────────────────────────────────────────────────────────

function ClaimsArray(AStore: JW3DataStore): variant;
var
  raw: String;
begin
  raw := String(AStore.Get('ledger.claims'));
  asm @Result = @raw ? JSON.parse(@raw) : []; end;
end;

function FindClaim(AArr: variant; const AId: String): variant;
begin
  asm
    var a = @AArr || []; var r = null;
    for (var i = 0; i < a.length; i++) { if (a[i] && a[i].id === @AId) { r = a[i]; break; } }
    @Result = r;
  end;
end;

// ── small DOM helpers (control value read/write) ─────────────────────────────

function ElValue(El: TElement): String;
var
  h: variant;
begin
  h := El.Handle;
  asm @Result = String(((@h) && (@h).value) || ''); end;
end;

function ElChecked(El: TElement): Boolean;
var
  h: variant;
begin
  h := El.Handle;
  asm @Result = ((@h) && (@h).checked === true); end;
end;

procedure SetElValue(El: TElement; const AValue: String);
var
  h: variant;
begin
  h := El.Handle;
  asm if (@h) { (@h).value = @AValue; } end;
end;

procedure SetElChecked(El: TElement; AValue: Boolean);
var
  h: variant;
begin
  h := El.Handle;
  asm if (@h) { (@h).checked = @AValue; } end;
end;

function MakeSelect(AParent: TElement; const AOptions: String): TElement;
var
  sel: TElement;
  h:   variant;
begin
  sel := TElement.Create('select', AParent);
  sel.SetStyle('font-size', '12px');
  sel.SetStyle('padding',   '2px');
  h := sel.Handle;
  asm
    var opts = (@AOptions).split(',');
    for (var i = 0; i < opts.length; i++) {
      var o = document.createElement('option');
      o.value = opts[i];
      o.textContent = (opts[i] === '') ? '(none)' : opts[i];
      (@h).appendChild(o);
    }
  end;
  Result := sel;
end;

function MakeInput(AParent: TElement; const APlaceholder: String): TElement;
var
  inp: TElement;
  h:   variant;
begin
  inp := TElement.Create('input', AParent);
  h := inp.Handle;
  asm if (@h) { (@h).type = 'text'; (@h).placeholder = @APlaceholder; } end;
  inp.SetStyle('font-size', '12px');
  inp.SetStyle('padding',   '2px 4px');
  Result := inp;
end;

function MakeLabel(AParent: TElement; const AText: String): TElement;
var
  l: TElement;
begin
  l := TElement.Create('span', AParent);
  l.SetStyle('font-size',    '11px');
  l.SetStyle('color',        '#64748b');
  l.SetText(AText);
  Result := l;
end;

function MakeRow(AParent: TElement): TElement;
var
  r: TElement;
begin
  r := TElement.Create('div', AParent);
  r.SetStyle('display',     'flex');
  r.SetStyle('align-items', 'center');
  r.SetStyle('gap',         '6px');
  r.SetStyle('margin-top',  '6px');
  r.SetStyle('flex-wrap',   'wrap');
  Result := r;
end;

// ── construction ─────────────────────────────────────────────────────────────

procedure TFormResearch.InitializeObject;
var
  Body, MeterRow, BtnRow: TElement;
begin
  inherited;

  Body := TElement.Create('div', Self);
  Body.SetStyle('padding',        'var(--space-6, 24px)');
  Body.SetStyle('display',        'flex');
  Body.SetStyle('flex-direction', 'column');
  Body.SetStyle('gap',            'var(--space-3, 12px)');
  Body.SetStyle('width',          '100%');
  Body.SetStyle('max-width',      '860px');
  Body.SetStyle('margin',         '0 auto');

  var Title := TElement.Create('div', Body);
  Title.SetStyle('font-weight', '600');
  Title.SetStyle('font-size',   '18px');
  Title.SetText('Research ledger');

  // meter
  MeterRow := TElement.Create('div', Body);
  MeterRow.SetStyle('display',       'flex');
  MeterRow.SetStyle('align-items',   'center');
  MeterRow.SetStyle('padding',       '6px 10px');
  MeterRow.SetStyle('border',        '1px solid var(--border-color, #e2e8f0)');
  MeterRow.SetStyle('border-radius', '8px');
  MeterRow.SetStyle('font-size',     '13px');
  FMeter := TElement.Create('span', MeterRow);
  FMeter.SetText('meter: 0 tokens');

  // load the runner's checkpoint / download the console's decisions
  MeterRow.SetStyle('gap', '8px');
  var spacer := TElement.Create('span', MeterRow);
  spacer.SetStyle('flex', '1 1 auto');

  var loadLbl := TElement.Create('span', MeterRow);
  loadLbl.SetStyle('font-size', '12px');
  loadLbl.SetStyle('color',     '#64748b');
  loadLbl.SetText('runner checkpoint:');

  FLoadInput := TElement.Create('input', MeterRow);
  FLoadInput.Handle.setAttribute('type', 'file');
  FLoadInput.Handle.setAttribute('accept', '.json,application/json');
  FLoadInput.SetStyle('font-size', '12px');
  FLoadInput.SetStyle('max-width', '220px');
  FLoadInput.Handle.addEventListener('change', procedure (e: variant)
  begin
    ReadFileAsText(e, procedure (const S: String)
    begin
      if Trim(S) = '' then Exit;
      FLedger.LoadJSON(S);     // Sync → store → subscriptions re-render the list
      FSelected := '';
      RenderDetail;
    end);
  end);

  var downBtn := JW3Button.Create(MeterRow);
  downBtn.Caption := 'Download ledger';
  downBtn.OnClick := lambda DownloadText('research-ledger.json', FLedger.ToJSON); end;

  FArticleBtn := JW3Button.Create(MeterRow);
  FArticleBtn.Caption := 'Write article';
  FArticleBtn.OnClick := lambda WriteArticle; end;

  // entry
  BuildEntry(Body);

  // claims list
  FList := TElement.Create('div', Body);
  FList.SetStyle('display',        'flex');
  FList.SetStyle('flex-direction', 'column');
  FList.SetStyle('gap',            '4px');

  // detail panel
  FDetail := TElement.Create('div', Body);
  FDetail.SetStyle('border',        '1px solid var(--border-color, #e2e8f0)');
  FDetail.SetStyle('border-radius', '8px');
  FDetail.SetStyle('padding',       '12px');
  FDetail.SetStyle('display',       'none');

  FClaimDisp := TElement.Create('div', FDetail);
  FClaimDisp.SetStyle('font-size',     '13px');
  FClaimDisp.SetStyle('font-weight',   '600');
  FClaimDisp.SetStyle('margin-bottom', '6px');

  FWhy := TElement.Create('div', FDetail);
  FWhy.SetStyle('color',         '#b91c1c');
  FWhy.SetStyle('white-space',   'pre-wrap');
  FWhy.SetStyle('font-size',     '13px');
  FWhy.SetStyle('margin-bottom', '8px');

  FJudge := TElement.Create('div', FDetail);
  FJudge.SetStyle('font-size',     '13px');
  FJudge.SetStyle('margin-bottom', '8px');
  FJudge.SetStyle('display',       'none');

  FAdvisor := TElement.Create('div', FDetail);
  FAdvisor.SetStyle('font-size',     '13px');
  FAdvisor.SetStyle('margin-bottom', '8px');
  FAdvisor.SetStyle('white-space',   'pre-wrap');
  FAdvisor.SetStyle('display',       'none');

  BuildEditor(FDetail);

  BtnRow := TElement.Create('div', FDetail);
  BtnRow.SetStyle('display',    'flex');
  BtnRow.SetStyle('gap',        '8px');
  BtnRow.SetStyle('margin-top', '10px');

  FPromote := JW3Button.Create(BtnRow);
  FPromote.Caption := 'Promote to finding';
  FPromote.OnClick := lambda DoPromote; end;

  FPublish := JW3Button.Create(BtnRow);
  FPublish.Caption := 'Publish (sign off)';
  FPublish.OnClick := lambda DoPublish; end;

  // engine
  FBusy  := False;
  FStore := JW3DataStore.Create;
  asm
    @FPack = {
      corroborationByGrade:  { LOW: 2, MEDIUM: 2, HIGH: 3 },
      claimTypeRequiresTier: { disease: 1, therapeutic: 1, 'structure-function': 2 }
    };
  end;
  FLedger := TLedger.Create(FStore, FPack, 'operator');
  FBudget := TBudget.Create(FStore, 200000);   // initialises meter.* to 0 / ceiling

  WireStore;
  RenderMeter;
  RenderList;
end;

procedure TFormResearch.BuildEntry(AParent: TElement);
var
  panel, row: TElement;
  h: variant;
begin
  panel := TElement.Create('div', AParent);
  panel.SetStyle('border',         '1px solid var(--border-color, #e2e8f0)');
  panel.SetStyle('border-radius',  '8px');
  panel.SetStyle('padding',        '10px');
  panel.SetStyle('display',        'flex');
  panel.SetStyle('flex-direction', 'column');

  FClaimText := TElement.Create('textarea', panel);
  h := FClaimText.Handle;
  asm if (@h) { (@h).placeholder = 'New claim text...'; (@h).rows = 2; } end;
  FClaimText.SetStyle('width',     '100%');
  FClaimText.SetStyle('font-size', '13px');
  FClaimText.SetStyle('padding',   '6px');
  FClaimText.SetStyle('box-sizing','border-box');

  row := MakeRow(panel);
  MakeLabel(row, 'species');
  FSpeciesSel := MakeSelect(row, 'scientific,marketing,regulatory,forecast');
  FAddBtn := JW3Button.Create(row);
  FAddBtn.Caption := 'Add claim';
  FAddBtn.OnClick := lambda DoAddClaim; end;
end;

procedure TFormResearch.BuildEditor(AParent: TElement);
var
  row: TElement;
  hp, hh: variant;
begin
  // species (set)
  row := MakeRow(AParent);
  MakeLabel(row, 'species:');
  FSpeciesCur := TElement.Create('span', row);
  FSpeciesCur.SetStyle('font-size',   '12px');
  FSpeciesCur.SetStyle('font-weight', '600');
  FSpeciesAdd := MakeSelect(row, 'scientific,marketing,regulatory,forecast');
  FSpeciesAddBtn := JW3Button.Create(row);
  FSpeciesAddBtn.Caption := '+ species';
  FSpeciesAddBtn.OnClick := lambda DoAddSpecies; end;

  // type / causal / risk
  row := MakeRow(AParent);
  MakeLabel(row, 'type');
  FClaimTypeSel := MakeSelect(row, ',disease,therapeutic,structure-function');
  MakeLabel(row, 'causal');
  FCausalSel := MakeSelect(row, 'n/a,observational,interventional,mechanism,none');
  MakeLabel(row, 'risk');
  FRiskSel := MakeSelect(row, 'LOW,MEDIUM,HIGH');

  FClaimTypeSel.Handle.addEventListener('change', procedure (e: variant)
    begin if FSelected <> '' then FLedger.SetField(FSelected, 'claimType', ElValue(FClaimTypeSel)); end);
  FCausalSel.Handle.addEventListener('change', procedure (e: variant)
    begin if FSelected <> '' then FLedger.SetField(FSelected, 'causalBasis', ElValue(FCausalSel)); end);
  FRiskSel.Handle.addEventListener('change', procedure (e: variant)
    begin if FSelected <> '' then FLedger.SetField(FSelected, 'riskGrade', ElValue(FRiskSel)); end);

  // predictions tested / harmful instruction
  row := MakeRow(AParent);
  FPredChk := TElement.Create('input', row);
  hp := FPredChk.Handle;
  asm if (@hp) { (@hp).type = 'checkbox'; } end;
  MakeLabel(row, 'predictions tested');
  FPredChk.Handle.addEventListener('change', procedure (e: variant)
    begin if FSelected <> '' then FLedger.SetField(FSelected, 'predictionsTested', ElChecked(FPredChk)); end);

  FHarmChk := TElement.Create('input', row);
  hh := FHarmChk.Handle;
  asm if (@hh) { (@hh).type = 'checkbox'; } end;
  MakeLabel(row, 'harmful instruction');
  FHarmChk.Handle.addEventListener('change', procedure (e: variant)
    begin if FSelected <> '' then FLedger.SetField(FSelected, 'harmfulInstruction', ElChecked(FHarmChk)); end);

  // regulatory status
  row := MakeRow(AParent);
  MakeLabel(row, 'reg status');
  FRegInput := MakeInput(row, 'e.g. AUST L - listed; not evaluated');
  FRegInput.Handle.addEventListener('change', procedure (e: variant)
    begin if FSelected <> '' then FLedger.SetField(FSelected, 'regulatoryStatus', ElValue(FRegInput)); end);

  // steelman
  MakeLabel(AParent, 'steelman (strongest opposing reading):');
  FSteelman := TElement.Create('textarea', AParent);
  FSteelman.SetStyle('width',      '100%');
  FSteelman.SetStyle('font-size',  '12px');
  FSteelman.SetStyle('margin-top', '4px');
  FSteelman.SetStyle('box-sizing', 'border-box');
  FSteelman.Handle.addEventListener('change', procedure (e: variant)
    begin if FSelected <> '' then FLedger.SetField(FSelected, 'steelman', ElValue(FSteelman)); end);

  // sources
  MakeLabel(AParent, 'sources:');
  FSrcList := TElement.Create('div', AParent);
  FSrcList.SetStyle('display',        'flex');
  FSrcList.SetStyle('flex-direction', 'column');
  FSrcList.SetStyle('gap',            '2px');
  FSrcList.SetStyle('margin',         '4px 0');

  row := MakeRow(AParent);
  MakeLabel(row, 'tier');
  FSrcTier   := MakeSelect(row, '1,2,3,4,5');
  FSrcOrigin := MakeInput(row, 'origin (independence key)');
  FSrcUrl    := MakeInput(row, 'url');
  FAddSrcBtn := JW3Button.Create(row);
  FAddSrcBtn.Caption := '+ source';
  FAddSrcBtn.OnClick := lambda DoAddSource; end;
end;

// ── store wiring — the only engine↔UI coupling ───────────────────────────────

procedure TFormResearch.WireStore;
var
  subClaims, subMeter, subTrip: Integer;
begin
  subClaims := FStore.Subscribe('ledger.claims',
    procedure (const Key: String; Value: variant)
    begin
      RenderList;
      if FSelected <> '' then RenderDetail;
    end);

  subMeter := FStore.Subscribe('meter.total',
    procedure (const Key: String; Value: variant)
    begin
      RenderMeter;
    end);

  subTrip := FStore.Subscribe('meter.tripped',
    procedure (const Key: String; Value: variant)
    begin
      RenderMeter;
    end);
end;

// ── render ───────────────────────────────────────────────────────────────────

procedure TFormResearch.RenderMeter;
var
  total, ceiling, tripped, s: String;
begin
  total   := String(FStore.Get('meter.total'));
  ceiling := String(FStore.Get('meter.ceiling'));
  tripped := String(FStore.Get('meter.tripped'));
  if (total = '')   or (total = 'undefined')   or (total = 'null')   then total := '0';
  if (ceiling = '') or (ceiling = 'undefined') or (ceiling = 'null') then ceiling := '0';

  s := 'meter: ' + total + ' tokens';
  if ceiling <> '0' then s := s + ' / ' + ceiling + ' ceiling';

  if tripped = 'true' then
  begin
    FMeter.SetText(s + '  — BREAKER TRIPPED');
    FMeter.SetStyle('color', '#b91c1c');
  end
  else
  begin
    FMeter.SetText(s);
    FMeter.SetStyle('color', 'inherit');
  end;
end;

function TFormResearch.StatusColour(const AStatus: String): String;
begin
  if AStatus = 'published'      then Result := '#16a34a'
  else if AStatus = 'finding'   then Result := '#0d9488'
  else if AStatus = 'working'   then Result := '#d97706'
  else if AStatus = 'corrected' then Result := '#9333ea'
  else Result := '#64748b';
end;

procedure TFormResearch.RenderList;
var
  arr: variant;
  n, i: Integer;
begin
  arr := ClaimsArray(FStore);
  FList.Clear;
  asm @n = (@arr).length; end;

  if n = 0 then
  begin
    var empty := TElement.Create('div', FList);
    empty.SetStyle('color',     '#64748b');
    empty.SetStyle('font-size', '13px');
    empty.SetText('No claims yet.');
    Exit;
  end;

  for i := 0 to n - 1 do
  begin
    var c: variant;
    asm @c = (@arr)[@i]; end;

    var id     := ClaimStr(c, 'id');
    var status := ClaimStr(c, 'status');
    var text   := ClaimStr(c, 'text');
    var specs  := SpeciesCSV(c);

    var row := TElement.Create('div', FList);
    row.SetStyle('display',       'flex');
    row.SetStyle('align-items',   'baseline');
    row.SetStyle('gap',           '8px');
    row.SetStyle('padding',       '6px 8px');
    row.SetStyle('border',        '1px solid var(--border-color, #e2e8f0)');
    row.SetStyle('border-radius', '6px');
    row.SetStyle('cursor',        'pointer');
    if id = FSelected then
      row.SetStyle('background', 'var(--accent-soft, #eef2ff)');

    var badge := TElement.Create('span', row);
    badge.SetStyle('font-size',   '11px');
    badge.SetStyle('font-weight', '600');
    badge.SetStyle('color',       StatusColour(status));
    badge.SetStyle('white-space', 'nowrap');
    badge.SetText(status.ToUpper);

    var body := TElement.Create('span', row);
    body.SetStyle('flex',      '1 1 auto');
    body.SetStyle('font-size', '13px');
    body.SetText(text);

    var sp := TElement.Create('span', row);
    sp.SetStyle('font-size',   '11px');
    sp.SetStyle('color',       '#64748b');
    sp.SetStyle('white-space', 'nowrap');
    sp.SetText(specs);

    var jnote := ClaimStr(c, 'judgeNote');
    if jnote <> '' then
    begin
      var jb := TElement.Create('span', row);
      jb.SetStyle('font-size',   '11px');
      jb.SetStyle('font-weight', '600');
      jb.SetStyle('white-space', 'nowrap');
      if ClaimBool(c, 'judgeSupported') then
      begin
        jb.SetStyle('color', '#15803d');
        jb.SetText('judge: OK');
      end
      else
      begin
        jb.SetStyle('color', '#b45309');
        jb.SetText('judge: DOUBT');
      end;
      jb.Handle.setAttribute('title', jnote);
    end;

    var anote := ClaimStr(c, 'advisorNote');
    if anote <> '' then
    begin
      var ab := TElement.Create('span', row);
      ab.SetStyle('font-size',   '11px');
      ab.SetStyle('font-weight', '600');
      ab.SetStyle('white-space', 'nowrap');
      if ClaimBool(c, 'advisorSupported') and ClaimBool(c, 'advisorPublishable') then
      begin
        ab.SetStyle('color', '#15803d');
        ab.SetText('advisor: OK');
      end
      else
      begin
        ab.SetStyle('color', '#b45309');
        ab.SetText('advisor: CONCERN');
      end;
      ab.Handle.setAttribute('title', anote);
    end;

    var rid := id;
    row.Handle.setAttribute('data-claim-id', rid);
    row.Handle.addEventListener('click', procedure (e: variant)
    var
      cid: String;
    begin
      asm
        var t = (@e) && (@e).currentTarget;
        @cid = (t && t.getAttribute) ? String(t.getAttribute('data-claim-id') || '') : '';
      end;
      if cid <> '' then SelectClaim(cid);
    end);
  end;
end;

procedure TFormResearch.RenderSources(AClaim: variant);
var
  n, i, tier: Integer;
  origin: String;
begin
  FSrcList.Clear;
  asm @n = ((@AClaim).sources ? (@AClaim).sources.length : 0); end;
  for i := 0 to n - 1 do
  begin
    asm
      @tier   = (@AClaim).sources[@i].tier;
      @origin = String((@AClaim).sources[@i].origin || '');
    end;
    var r := TElement.Create('div', FSrcList);
    r.SetStyle('font-size', '11px');
    r.SetStyle('color',     '#475569');
    r.SetText('Tier ' + IntToStr(tier) + '  ·  ' + origin);
  end;
end;

procedure TFormResearch.SelectClaim(const AId: String);
begin
  FSelected := AId;
  FWhy.SetText('');
  RenderList;
  RenderDetail;
end;

procedure TFormResearch.RenderDetail;
var
  arr, c: variant;
  status: String;
begin
  arr := ClaimsArray(FStore);
  c   := FindClaim(arr, FSelected);
  if ClaimStr(c, 'id') = '' then
  begin
    FDetail.SetStyle('display', 'none');
    Exit;
  end;
  FDetail.SetStyle('display', 'block');

  FClaimDisp.SetText(ClaimStr(c, 'text'));

  var jn := ClaimStr(c, 'judgeNote');
  if jn = '' then
    FJudge.SetStyle('display', 'none')
  else
  begin
    var jline := '';
    if ClaimBool(c, 'judgeSupported') then
    begin
      FJudge.SetStyle('color', '#15803d');
      jline := 'Judge: supported — ' + jn;
      if not ClaimBool(c, 'judgeWording') then
        jline := jline + '  ·  wording mismatch';
    end
    else
    begin
      FJudge.SetStyle('color', '#b45309');
      jline := 'Judge: DOUBT — ' + jn;
    end;
    FJudge.SetStyle('display', 'block');
    FJudge.SetText(jline);
  end;

  var an := ClaimStr(c, 'advisorNote');
  if an = '' then
    FAdvisor.SetStyle('display', 'none')
  else
  begin
    var aline := '';
    if ClaimBool(c, 'advisorSupported') and ClaimBool(c, 'advisorPublishable') then
    begin
      FAdvisor.SetStyle('color', '#15803d');
      aline := 'Advisor: supported — ' + an;
    end
    else
    begin
      FAdvisor.SetStyle('color', '#b45309');
      aline := 'Advisor: CONCERN — ' + an;
    end;
    var aw := ClaimStr(c, 'advisorWording');
    if aw <> '' then aline := aline + LF + 'suggested wording: ' + aw;
    FAdvisor.SetStyle('display', 'block');
    FAdvisor.SetText(aline);
  end;

  FSpeciesCur.SetText(SpeciesCSV(c));
  SetElValue(FClaimTypeSel, ClaimStr(c, 'claimType'));
  SetElValue(FCausalSel,    ClaimStr(c, 'causalBasis'));
  SetElValue(FRiskSel,      ClaimStr(c, 'riskGrade'));
  SetElChecked(FPredChk,    ClaimBool(c, 'predictionsTested'));
  SetElChecked(FHarmChk,    ClaimBool(c, 'harmfulInstruction'));
  SetElValue(FRegInput,     ClaimStr(c, 'regulatoryStatus'));
  SetElValue(FSteelman,     ClaimStr(c, 'steelman'));
  RenderSources(c);

  status := ClaimStr(c, 'status');
  FPromote.Enabled := (not FBusy) and (status <> 'finding') and (status <> 'published');
  FPublish.Enabled := (not FBusy) and (status = 'finding');
end;

// ── actions — call the ledger's guarded transitions ──────────────────────────

procedure TFormResearch.DoAddClaim;
var
  txt, sp, id: String;
begin
  txt := Trim(ElValue(FClaimText));
  if txt = '' then Exit;
  sp := ElValue(FSpeciesSel);
  id := FLedger.AddClaim(txt, sp);
  SetElValue(FClaimText, '');
  SelectClaim(id);
end;

procedure TFormResearch.DoAddSpecies;
begin
  if FSelected = '' then Exit;
  FLedger.AddSpecies(FSelected, ElValue(FSpeciesAdd));
end;

procedure TFormResearch.DoAddSource;
var
  origin, url: String;
  tier: Integer;
begin
  if FSelected = '' then Exit;
  origin := Trim(ElValue(FSrcOrigin));
  if origin = '' then Exit;
  tier := StrToInt(ElValue(FSrcTier));
  url  := Trim(ElValue(FSrcUrl));
  FLedger.AddSource(FSelected, tier, origin, '', url);
  SetElValue(FSrcOrigin, '');
  SetElValue(FSrcUrl, '');
end;

procedure TFormResearch.DoPromote;
var
  v: TGateVerdict;
begin
  if FBusy or (FSelected = '') then Exit;
  v := FLedger.Promote(FSelected);
  if v.Pass then
    FWhy.SetText('')
  else
    FWhy.SetText('Blocked — gates not satisfied:' + LF + v.Reasons);
end;

procedure TFormResearch.DoPublish;
var
  arr, c: variant;
  cid, key: String;
begin
  if FBusy or (FSelected = '') then Exit;
  cid := FSelected;
  arr := ClaimsArray(FStore);
  c   := FindClaim(arr, cid);
  if ClaimStr(c, 'status') <> 'finding' then
  begin
    FWhy.SetText('Publish refused — the claim must be a finding first.');
    Exit;
  end;

  // Heading-to-publish → consult the advisor first, cached on content: if the
  // claim and its sources are unchanged since counsel was last given (here or
  // in the runner), there is no new spend and we go straight to sign-off.
  key := ClaimHash(ClaimStr(c, 'text'), ClaimSources(c));
  if ClaimStr(c, 'advisorKey') = key then
    PromptSignoffAndPublish(cid)
  else
    ConsultAdvisor(cid, lambda PromptSignoffAndPublish(cid); end);
end;

procedure TFormResearch.PromptSignoffAndPublish(const AId: String);
var
  who: String;
  ok:  Boolean;
begin
  if FSelected <> AId then Exit;   // selection moved during the consult; counsel is saved
  who := '';
  asm @who = (window.prompt('Sign-off name to publish:', '') || ''); end;
  if Trim(who) = '' then
  begin
    FWhy.SetText('Publish cancelled — a sign-off name is required.');
    Exit;
  end;
  ok := FLedger.Publish(AId, who);
  if ok then
    FWhy.SetText('')
  else
    FWhy.SetText('Publish refused — the claim must be a finding first.');
end;

procedure TFormResearch.ConsultAdvisor(const AId: String; ADone: TVoidProc);
var
  arr, c: variant;
  sys, usr, body, key, mdl, jn: String;
begin
  arr := ClaimsArray(FStore);
  c   := FindClaim(arr, AId);
  key := ClaimHash(ClaimStr(c, 'text'), ClaimSources(c));
  mdl := ADVISOR_MODEL;   // copied to a var: consts must not cross into asm

  sys := 'You are a senior research advisor, consulted rarely and only where it matters: a claim '
       + 'that passed deterministic gates but drew reviewer doubt, or a claim about to be published. '
       + 'You see the claim and its verified sources; adjudicate independently and strictly. Reply '
       + 'with ONLY a JSON object {"supported": boolean (the sources genuinely support the claim as '
       + 'worded), "publishable": boolean (fit to publish as written), "betterWording": string (an '
       + 'improved wording if needed, else ""), "note": one or two short sentences}. No prose, no fences.';
  usr := 'Claim: ' + ClaimStr(c, 'text') + LF + 'Sources:' + LF + SourceLines(ClaimSources(c))
       + LF + 'This claim is about to be published; give final counsel.';
  jn := ClaimStr(c, 'judgeNote');
  if jn <> '' then usr := usr + LF + 'First reviewer note: ' + jn;

  FBusy := True;
  RenderDetail;                       // disables the buttons while consulting
  FWhy.SetText('Consulting advisor (' + mdl + ')...');

  asm
    @body = JSON.stringify({
      provider:          'claude',
      transport:         'api',
      model:             @mdl,
      system:            @sys,
      messages:          [{ role: 'user', content: @usr }],
      maxTokens:         1500,
      temperature:       0.2,
      stream:            false,
      webSearch:         false,
      budgetId:          'research',
      providerSessionId: ''
    });
  end;

  PostJSONWeb(PROXY_URL + '/v1/chat', body,
    procedure (Data: variant)
    var
      j: variant;
      note: String;
    begin
      FBudget.RecordUsage(ResultIn(Data), ResultOut(Data));
      j := ParseJsonLoose(ResultText(Data));
      if JsonOk(j) then
      begin
        FLedger.SetField(AId, 'advisorSupported',   ClaimBool(j, 'supported'));
        FLedger.SetField(AId, 'advisorPublishable', ClaimBool(j, 'publishable'));
        FLedger.SetField(AId, 'advisorWording',     Trim(ClaimStr(j, 'betterWording')));
        note := Trim(ClaimStr(j, 'note'));
        if note = '' then note := '(no note)';
        FLedger.SetField(AId, 'advisorNote',  note);
        FLedger.SetField(AId, 'advisorModel', mdl);
        FLedger.SetField(AId, 'advisorKey',   key);   // cache mark — only on success
      end
      else
        FLedger.SetField(AId, 'advisorNote', '(advisor returned no parseable verdict)');
      FBusy := False;
      FWhy.SetText('');
      RenderDetail;
      ADone();
    end,
    procedure (Status: Integer; Msg: String)
    begin
      FLedger.SetField(AId, 'advisorNote', 'advisor unavailable (' + IntToStr(Status) + ')');
      FBusy := False;
      FWhy.SetText('');
      RenderDetail;
      ADone();                        // advisory: failure never blocks the human
    end);
end;

// Write a one-page article from the session's decided claims — a third synth
// pass, but over what the HUMAN signed off (published), falling back to findings
// if nothing is published yet. The article is grounded only in claims that
// cleared the gates; blocked/working claims are deliberately excluded. Reuses
// the proxy call and the download helper. Advisory in spirit: a failure just
// reports and never disturbs the ledger.
procedure TFormResearch.WriteArticle;
var
  arr, c: variant;
  n, i, used: Integer;
  body, sys, usr: String;
begin
  if FBusy then Exit;
  arr := ClaimsArray(FStore);
  asm @n = (@arr) ? (@arr).length : 0; end;

  // prefer published; if none signed off yet, fall back to findings
  body := '';
  used := 0;
  for i := 0 to n - 1 do
  begin
    asm @c = (@arr)[@i]; end;
    if ClaimStr(c, 'status') = 'published' then
    begin
      body := body + '- ' + ClaimStr(c, 'text') + LF;
      used := used + 1;
    end;
  end;
  if used = 0 then
    for i := 0 to n - 1 do
    begin
      asm @c = (@arr)[@i]; end;
      if ClaimStr(c, 'status') = 'finding' then
      begin
        body := body + '- ' + ClaimStr(c, 'text') + LF;
        used := used + 1;
      end;
    end;

  if used = 0 then
  begin
    FWhy.SetText('No published findings to write from. Publish or promote a claim first.');
    Exit;
  end;

  sys := 'You are a careful research writer. Given a set of verified findings, write a single-page '
       + 'article (about 400 to 550 words) in plain prose with a short title on the first line. '
       + 'Use ONLY the findings provided; add no facts of your own. Keep every claim calibrated to '
       + 'the strength of its wording - associational stays associational, do not imply causation. '
       + 'Where findings disagree or leave a question open, present it as open debate, not a '
       + 'conclusion. End with a one-paragraph provenance note stating the article was produced from '
       + 'a gated research ledger whose claims passed deterministic evidence gates and independent '
       + 'review. No markdown headings beyond the title line.';
  usr := 'Verified findings:' + LF + body
       + LF + 'Infer the subject from these findings and title the article accordingly.';

  FBusy := True;
  RenderDetail;
  FWhy.SetText('Writing article (' + SYNTH_MODEL + ')...');

  asm
    @body = JSON.stringify({
      provider:          'claude',
      transport:         'api',
      model:             @SYNTH_MODEL,
      system:            @sys,
      messages:          [{ role: 'user', content: @usr }],
      maxTokens:         1500,
      temperature:       0.3,
      stream:            false,
      webSearch:         false,
      budgetId:          'research',
      providerSessionId: ''
    });
  end;

  PostJSONWeb(PROXY_URL + '/v1/chat', body,
    procedure (Data: variant)
    var
      art: String;
    begin
      FBudget.RecordUsage(ResultIn(Data), ResultOut(Data));
      art := Trim(ResultText(Data));
      FBusy := False;
      RenderDetail;
      if art = '' then
      begin
        FWhy.SetText('Article: the writer returned nothing.');
        Exit;
      end;
      FWhy.SetText('Article ready - downloading research-article.md');
      DownloadText('research-article.md', art);
    end,
    procedure (Status: Integer; Msg: String)
    begin
      FBusy := False;
      RenderDetail;
      FWhy.SetText('Article writer unavailable (' + IntToStr(Status) + ').');
    end);
end;

end.
