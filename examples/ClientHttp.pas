unit ClientHttp;

// ═══════════════════════════════════════════════════════════════════════════
//
//  ClientHttp
//
//  Browser-side client for NodeHttpServer.pas.
//  Start the Node server first: node index.js  (default port 3000)
//
//  Lets the user set the server base URL, then fire any of the four routes:
//
//    GET /       welcome message
//    GET /time   server clock (UTC, ISO, epoch)
//    GET /info   OS and process info
//    GET /echo   echoes query params — enter params in the field shown
//
//  Each response is pretty-printed as JSON in the response card.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  JElement, JForm, JPanel, JToolbar, JInput, JLabel, JBadge;

type
  TFormClientHttp = class(TW3Form)
  private
    FToolbar:     JW3Toolbar;
    FBody:        JW3Panel;
    FUrlInput:    JW3Input;
    FEchoRow:     JW3Panel;
    FEchoInput:   JW3Input;
    FPathLabel:   JW3Label;
    FStatusBadge: JW3Badge;
    FOutput:      JW3Label;

    function  CurrentURL: String;
    function  CurrentEchoParams: String;
    procedure FetchRoute(const Path: String);
  protected
    procedure InitializeObject; override;
  end;

implementation

uses
  Globals, ThemeStyles, JButton, HttpClient, JToast;


var GStyled: Boolean = false;

procedure RegisterStyles;
begin
  if GStyled then exit;
  GStyled := true;
  AddStyleBlock(#'

    .hc-card {
      display: flex;
      flex-direction: column;
      gap: 12px;
      padding: 20px;
      background: var(--surface-color, #fff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-lg, 8px);
      width: 100%;
      max-width: 680px;
    }

    .hc-section-label {
      font-size: 0.75rem;
      font-weight: 600;
      color: var(--text-light, #64748b);
      text-transform: uppercase;
      letter-spacing: 0.06em;
    }

    .hc-row {
      display: flex;
      flex-direction: row;
      gap: 8px;
      align-items: center;
      flex-wrap: wrap;
    }

    .hc-response-meta {
      display: flex;
      flex-direction: row;
      gap: 8px;
      align-items: center;
      padding-bottom: 8px;
      border-bottom: 1px solid var(--border-color, #e2e8f0);
    }

    .hc-path {
      font-family: var(--font-family-mono, monospace);
      font-size: 0.9rem;
      font-weight: 600;
    }

    .hc-output {
      font-family: var(--font-family-mono, monospace);
      font-size: 0.85rem;
      padding: 14px;
      background: var(--hover-color, #f1f5f9);
      border-radius: var(--radius-md, 6px);
      color: var(--text-color, #334155);
      white-space: pre;
      min-height: 60px;
    }

  ');
end;


// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function TFormClientHttp.CurrentURL: String;
var
  h: variant;
begin
  h := FUrlInput.Handle;
  Result := String(h.value);
  while (Result <> '') and (Result[Length(Result)] = '/') do
    Result := Copy(Result, 1, Length(Result) - 1);
end;

function TFormClientHttp.CurrentEchoParams: String;
var
  h: variant;
begin
  h := FEchoInput.Handle;
  Result := String(h.value);
end;

procedure TFormClientHttp.FetchRoute(const Path: String);
var
  url: String;
begin
  url := CurrentURL + Path;

  FPathLabel.SetText(Path);
  FStatusBadge.SetText('…');
  FStatusBadge.RemoveClass(csBadgeSuccess);
  FStatusBadge.RemoveClass(csBadgeDanger);
  FOutput.SetText('GET ' + url + #13 + 'Waiting for response…');

  FetchJSON(url,

    procedure(Data: variant)
    begin
      FStatusBadge.SetText('200 OK');
      FStatusBadge.RemoveClass(csBadgeDanger);
      FStatusBadge.AddClass(csBadgeSuccess);
      var pretty: String;
      asm @pretty = JSON.stringify(@Data, null, 2); end;
      FOutput.SetText(pretty);
    end,

    procedure(Status: Integer; Msg: String)
    begin
      FStatusBadge.SetText(IntToStr(Status) + ' ' + Msg);
      FStatusBadge.RemoveClass(csBadgeSuccess);
      FStatusBadge.AddClass(csBadgeDanger);
      FOutput.SetText('Error ' + IntToStr(Status) + ': ' + Msg + #13#13 +
        'Is the Node server running?' + #13 +
        'node index.js');
      Toast('Request failed: ' + Msg, ttDanger);
    end
  );
end;


// ─────────────────────────────────────────────────────────────────────────────
// InitializeObject
// ─────────────────────────────────────────────────────────────────────────────

procedure TFormClientHttp.InitializeObject;
begin
  inherited;

  // ── Toolbar ───────────────────────────────────────────────────────────────

  FToolbar := JW3Toolbar.Create(Self);

  var BtnBack := FToolbar.AddItem('<< Back');
  BtnBack.OnClick := procedure(Sender: TObject)
  begin
    Application.GoToForm('Kitchensink');
  end;

  var TitleLbl := JW3Label.Create(FToolbar);
  TitleLbl.SetText('HTTP Client — NodeHttpServer');
  TitleLbl.SetStyle('font-weight', '600');
  TitleLbl.SetStyle('font-size', '0.9rem');
  TitleLbl.SetStyle('padding-left', '8px');

  // ── Scrollable body ───────────────────────────────────────────────────────

  FBody := JW3Panel.Create(Self);
  FBody.SetGrow(1);
  FBody.SetStyle('overflow', 'auto');
  FBody.SetStyle('padding', 'var(--space-6, 24px)');
  FBody.SetStyle('align-items', 'flex-start');
  FBody.SetStyle('gap', 'var(--space-5, 20px)');

  // ── Server URL card ───────────────────────────────────────────────────────

  var UrlCard := JW3Panel.Create(FBody);
  UrlCard.AddClass('hc-card');

  var UrlLabel := TElement.Create('div', UrlCard);
  UrlLabel.AddClass('hc-section-label');
  UrlLabel.SetText('Server URL');

  var UrlRow := TElement.Create('div', UrlCard);
  UrlRow.AddClass('hc-row');
  UrlRow.SetStyle('flex-wrap', 'nowrap');

  FUrlInput := JW3Input.Create(UrlRow);
  FUrlInput.SetStyle('flex', '1');
  FUrlInput.Value := 'http://localhost:3000';

  var UrlHint := JW3Label.Create(UrlCard);
  UrlHint.SetText('Start the Node server:  node index.js');
  UrlHint.SetStyle('font-size', '0.8rem');
  UrlHint.SetStyle('color', 'var(--text-light, #64748b)');
  UrlHint.SetStyle('font-family', 'var(--font-family-mono, monospace)');

  // ── Endpoints card ────────────────────────────────────────────────────────

  var EndCard := JW3Panel.Create(FBody);
  EndCard.AddClass('hc-card');

  var EndLabel := TElement.Create('div', EndCard);
  EndLabel.AddClass('hc-section-label');
  EndLabel.SetText('Endpoints');

  var BtnRow := TElement.Create('div', EndCard);
  BtnRow.AddClass('hc-row');

  var BtnRoot := JW3Button.Create(BtnRow);
  BtnRoot.SetText('GET /');
  BtnRoot.OnClick := procedure(Sender: TObject)
  begin
    FEchoRow.Visible := false;
    FetchRoute('/');
  end;

  var BtnTime := JW3Button.Create(BtnRow);
  BtnTime.SetText('GET /time');
  BtnTime.AddClass(csBtnSecondary);
  BtnTime.OnClick := procedure(Sender: TObject)
  begin
    FEchoRow.Visible := false;
    FetchRoute('/time');
  end;

  var BtnInfo := JW3Button.Create(BtnRow);
  BtnInfo.SetText('GET /info');
  BtnInfo.AddClass(csBtnSecondary);
  BtnInfo.OnClick := procedure(Sender: TObject)
  begin
    FEchoRow.Visible := false;
    FetchRoute('/info');
  end;

  var BtnEcho := JW3Button.Create(BtnRow);
  BtnEcho.SetText('GET /echo');
  BtnEcho.AddClass(csBtnGhost);
  BtnEcho.OnClick := procedure(Sender: TObject)
  begin
    FEchoRow.Visible := true;
    var params := CurrentEchoParams;
    if params = '' then
      FetchRoute('/echo')
    else
      FetchRoute('/echo?' + params);
  end;

  // ── Echo params (shown only when /echo is clicked) ────────────────────────

  FEchoRow := JW3Panel.Create(EndCard);
  FEchoRow.AddClass('hc-row');
  FEchoRow.SetStyle('flex-wrap', 'nowrap');
  FEchoRow.Visible := false;

  var EchoParamLbl := JW3Label.Create(FEchoRow);
  EchoParamLbl.SetText('Query params:');
  EchoParamLbl.SetStyle('font-size', '0.85rem');
  EchoParamLbl.SetStyle('color', 'var(--text-light, #64748b)');
  EchoParamLbl.SetStyle('white-space', 'nowrap');

  FEchoInput := JW3Input.Create(FEchoRow);
  FEchoInput.SetStyle('flex', '1');
  FEchoInput.Placeholder := 'name=Alice&lang=pascal';

  // ── Response card ─────────────────────────────────────────────────────────

  var RespCard := JW3Panel.Create(FBody);
  RespCard.AddClass('hc-card');

  var RespMeta := TElement.Create('div', RespCard);
  RespMeta.AddClass('hc-response-meta');

  var MethodBadge := JW3Badge.Create(RespMeta);
  MethodBadge.SetText('GET');
  MethodBadge.AddClass(csBadgePrimary);

  FPathLabel := JW3Label.Create(RespMeta);
  FPathLabel.SetText('/');
  FPathLabel.AddClass('hc-path');
  FPathLabel.SetGrow(1);

  FStatusBadge := JW3Badge.Create(RespMeta);
  FStatusBadge.SetText('—');

  FOutput := JW3Label.Create(RespCard);
  FOutput.AddClass('hc-output');
  FOutput.SetText('Press an endpoint button above to send a request.');
end;


initialization
  RegisterStyles;
end.
