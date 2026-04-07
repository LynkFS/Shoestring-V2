unit FormNoise;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Noise Filter - ShoeString2 Frontend
//
//  Signal-to-noise controller for RSS/information streams.
//  Connects to the local Express API (http://localhost:3000) and displays
//  items in three tiers - Focus / Ambient / Hidden - controlled by a
//  tuning dial. Light theme only.
//
//  API surface used:
//    GET  /api.php?action=items&dial=0.50  -> partitioned feed items
//    POST /api.php?action=refresh          -> re-score all items
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  JElement, JForm, JPanel, JLabel, JButton;

type
  TFormNoise = class(TW3Form)
  private
    FDialValue:      Float;    // 0.0 - 1.0
    FDialEl:         variant;  // JS <input type="range"> DOM reference

    // Header
    FHeader:         JW3Panel;
    FLastRefresh:    JW3Label;
    FRefreshBtn:     JW3Button;

    // Dial section
    FDialSection:    JW3Panel;
    FDialReadout:    JW3Label;   // shows "0.50"
    FDialDescLabel:  JW3Label;   // describes current threshold

    // Counts bar
    FCountsBar:      JW3Panel;
    FFocusCount:     JW3Label;
    FAmbientCount:   JW3Label;
    FHiddenCount:    JW3Label;

    // Scrollable content - rebuilt on each data load
    FContent:        JW3Panel;
    FFocusSection:   JW3Panel;
    FAmbientSection: JW3Panel;
    FHiddenSection:  JW3Panel;

    // Assessment overlay
    FDetailOverlay:  JW3Panel;
    FDetailTitle:    JW3Label;
    FDetailMeta:     JW3Label;
    FDetailBody:     JW3Panel;
    FDetailUrlBtn:   JW3Button;
    FAssessToken:    String;

    procedure BuildHeader;
    procedure BuildDialSection;
    procedure BuildCountsBar;
    procedure BuildContent;
    procedure BuildDetailOverlay;
    procedure UpdateDialDisplay;
    procedure LoadItems;
    procedure RenderData(Data: variant);
    procedure RenderFocus(Items: variant; Count: Integer);
    procedure RenderAmbient(Items: variant; Count: Integer);
    procedure RenderHidden(Count: Integer);
    procedure HandleRefresh(Sender: TObject);
    procedure ShowAssessment(const Title, Source, Category, Url: String);
    procedure CloseDetail;
    procedure RunAssessment(const Title, Source, Category, Token: String);
    function  DialDescription: String;

  protected
    procedure InitializeObject; override;
    procedure Show; override;
  end;

implementation

uses
  Globals, HttpClient, ThemeStyles, JToast;


// ═══════════════════════════════════════════════════════════════════════════
//  Local styles - registered once, light theme baked in
// ═══════════════════════════════════════════════════════════════════════════

var GNoiseStyled: Boolean = false;

procedure RegisterNoiseStyles;
begin
  if GNoiseStyled then exit;
  GNoiseStyled := true;

  AddStyleBlock(#'

    /* ── Root: force light theme regardless of system preference ─── */
    .noise-root {
      background: #f0f4f8;
      color: #1a202c;
      display: flex;
      flex-direction: column;
      --primary-color:   #6366f1;
      --primary-light:   #e0e7ff;
      --text-color:      #1a202c;
      --text-light:      #64748b;
      --bg-color:        #f0f4f8;
      --surface-color:   #ffffff;
      --border-color:    #e2e8f0;
      --hover-color:     #f8fafc;
    }

    /* ── Header bar ─────────────────────────────────────────────── */
    .noise-header {
      background: #ffffff;
      border-bottom: 2px solid #e2e8f0;
      padding: 12px 20px;
      flex-shrink: 0;
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .noise-title {
      font-size: 18px;
      font-weight: 700;
      color: #1a202c;
      letter-spacing: -0.3px;
      flex: 1;
    }

    .noise-last-refresh {
      font-size: 11px;
      color: #94a3b8;
    }

    /* ── Dial section ───────────────────────────────────────────── */
    .noise-dial-section {
      background: #ffffff;
      border-bottom: 1px solid #e2e8f0;
      padding: 14px 20px 12px;
      flex-shrink: 0;
    }

    .noise-dial-row {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .noise-dial-end-label {
      font-size: 11px;
      font-weight: 600;
      color: #94a3b8;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      min-width: 44px;
    }

    .noise-dial-end-label.right { text-align: right; }

    .noise-dial-input {
      flex: 1;
      -webkit-appearance: none;
      appearance: none;
      height: 6px;
      border-radius: 3px;
      background: linear-gradient(to right, #6366f1 var(--dial-pct, 0%), #e2e8f0 var(--dial-pct, 0%));
      outline: none;
      cursor: pointer;
    }

    .noise-dial-input::-webkit-slider-thumb {
      -webkit-appearance: none;
      width: 22px;
      height: 22px;
      border-radius: 50%;
      background: #6366f1;
      cursor: pointer;
      box-shadow: 0 2px 8px rgba(99, 102, 241, 0.40);
      border: 3px solid #ffffff;
    }

    .noise-dial-input::-moz-range-thumb {
      width: 22px;
      height: 22px;
      border-radius: 50%;
      background: #6366f1;
      cursor: pointer;
      border: 3px solid #ffffff;
      box-shadow: 0 2px 8px rgba(99, 102, 241, 0.40);
    }

    .noise-dial-readout {
      font-size: 22px;
      font-weight: 800;
      color: #6366f1;
      min-width: 52px;
      text-align: center;
      letter-spacing: -0.5px;
    }

    .noise-dial-desc {
      font-size: 12px;
      color: #64748b;
      margin-top: 8px;
    }

    /* ── Counts bar ─────────────────────────────────────────────── */
    .noise-counts-bar {
      background: #f8fafc;
      border-bottom: 1px solid #e2e8f0;
      padding: 7px 20px;
      flex-shrink: 0;
      display: flex;
      align-items: center;
      gap: 20px;
      font-size: 12px;
    }

    .noise-count-chip {
      display: flex;
      align-items: center;
      gap: 6px;
      color: #475569;
    }

    .noise-count-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      flex-shrink: 0;
    }

    .dot-focus   { background: #10b981; }
    .dot-ambient { background: #f59e0b; }
    .dot-hidden  { background: #cbd5e1; }

    /* ── Scrollable content ─────────────────────────────────────── */
    .noise-content {
      flex: 1;
      overflow-y: auto;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 24px;
    }

    /* ── Section header ─────────────────────────────────────────── */
    .noise-section-hdr {
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 1.2px;
      text-transform: uppercase;
      color: #94a3b8;
      padding-bottom: 8px;
      border-bottom: 1px solid #e2e8f0;
      margin-bottom: 10px;
    }

    /* ── Focus card grid ────────────────────────────────────────── */
    .noise-focus-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
      gap: 12px;
    }

    .noise-card {
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 10px;
      padding: 14px 16px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      cursor: pointer;
      transition: box-shadow 0.15s ease, border-color 0.15s ease;
    }

    .noise-card:hover {
      border-color: #6366f1;
      box-shadow: 0 4px 14px rgba(99, 102, 241, 0.14);
    }

    .noise-card-title {
      font-size: 14px;
      font-weight: 600;
      color: #1a202c;
      line-height: 1.4;
    }

    .noise-card-source {
      font-size: 12px;
      color: #64748b;
    }

    .noise-card-score {
      font-size: 11px;
      font-weight: 600;
      padding: 2px 8px;
      border-radius: 9999px;
      background: #e0e7ff;
      color: #6366f1;
      align-self: flex-start;
    }

    /* ── Ambient list ───────────────────────────────────────────── */
    .noise-ambient-list {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .noise-ambient-row {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 12px;
      border-radius: 6px;
      background: #ffffff;
      border: 1px solid #f1f5f9;
      cursor: pointer;
      transition: background 0.1s;
    }

    .noise-ambient-row:hover { background: #f8fafc; border-color: #e2e8f0; }

    .noise-ambient-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      flex-shrink: 0;
    }

    .noise-ambient-title {
      flex: 1;
      font-size: 13px;
      color: #374151;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .noise-ambient-source {
      font-size: 11px;
      color: #94a3b8;
      flex-shrink: 0;
    }

    .noise-ambient-score {
      font-size: 11px;
      color: #cbd5e1;
      flex-shrink: 0;
      min-width: 32px;
      text-align: right;
    }

    /* ── Hidden section ─────────────────────────────────────────── */
    .noise-hidden-box {
      text-align: center;
      font-size: 13px;
      color: #94a3b8;
      padding: 16px;
      background: #f8fafc;
      border-radius: 8px;
      border: 1px dashed #e2e8f0;
    }

    /* ── Refresh button ─────────────────────────────────────────── */
    .noise-refresh-btn {
      background: #6366f1 !important;
      color: #ffffff !important;
      border: none !important;
      border-radius: 6px !important;
      padding: 6px 14px !important;
      font-size: 13px !important;
      font-weight: 500 !important;
      cursor: pointer !important;
      box-shadow: none !important;
    }

    .noise-refresh-btn:hover {
      background: #4f46e5 !important;
    }

    /* ── Empty / loading states ─────────────────────────────────── */
    .noise-empty {
      font-size: 13px;
      color: #94a3b8;
      text-align: center;
      padding: 20px;
    }

    /* ── Card footer (score + assess button) ────────────────────── */
    .noise-card-footer {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-top: 4px;
    }

    .noise-card-assess-btn {
      font-size: 11px;
      font-weight: 600;
      color: #6366f1;
      background: #eef2ff;
      border: 1px solid #c7d2fe;
      border-radius: 5px;
      padding: 3px 8px;
      cursor: pointer;
      transition: background 0.1s;
    }

    .noise-card-assess-btn:hover { background: #e0e7ff; }

    /* ── Assessment overlay ──────────────────────────────────────── */
    .noise-overlay {
      position: fixed;
      inset: 0;
      background: rgba(15, 23, 42, 0.60);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 1000;
      padding: 20px;
      box-sizing: border-box;
    }

    .noise-detail-card {
      background: #ffffff;
      border-radius: 14px;
      width: 100%;
      max-width: 760px;
      max-height: 85vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 24px 64px rgba(0,0,0,0.30);
      overflow: hidden;
    }

    .noise-detail-hdr {
      padding: 20px 24px 14px;
      border-bottom: 1px solid #e2e8f0;
      flex-shrink: 0;
      display: flex;
      gap: 12px;
      align-items: flex-start;
    }

    .noise-detail-hdr-text { flex: 1; }

    .noise-detail-title {
      font-size: 17px;
      font-weight: 700;
      color: #1a202c;
      line-height: 1.4;
      margin-bottom: 4px;
    }

    .noise-detail-meta { font-size: 12px; color: #64748b; }

    .noise-detail-close {
      background: none !important;
      border: none !important;
      font-size: 20px !important;
      color: #94a3b8 !important;
      cursor: pointer !important;
      padding: 0 4px !important;
      line-height: 1 !important;
      box-shadow: none !important;
      flex-shrink: 0;
    }

    .noise-detail-close:hover { color: #475569 !important; }

    .noise-detail-body {
      flex: 1;
      overflow-y: auto;
      padding: 20px 24px;
      user-select: text;
      -webkit-user-select: text;
    }

    .noise-assess-para {
      font-size: 15px;
      line-height: 1.75;
      color: #374151;
      margin-bottom: 18px;
    }

    .noise-assess-loading {
      font-size: 14px;
      color: #94a3b8;
      font-style: italic;
      text-align: center;
      padding: 40px 0;
    }

    .noise-assess-heading {
      font-size: 13px;
      font-weight: 700;
      color: #1a202c;
      margin-top: 20px;
      margin-bottom: 2px;
    }

    .noise-assess-error { font-size: 14px; color: #ef4444; }

    .noise-detail-footer {
      padding: 12px 24px;
      border-top: 1px solid #e2e8f0;
      display: flex;
      justify-content: flex-end;
      gap: 10px;
      flex-shrink: 0;
    }

    .noise-detail-url-btn {
      background: #6366f1 !important;
      color: #ffffff !important;
      border: none !important;
      border-radius: 6px !important;
      padding: 6px 14px !important;
      font-size: 13px !important;
      font-weight: 500 !important;
      cursor: pointer !important;
      box-shadow: none !important;
    }

    .noise-detail-url-btn:hover { background: #4f46e5 !important; }

    .noise-detail-dismiss-btn {
      background: #f1f5f9 !important;
      color: #475569 !important;
      border: 1px solid #e2e8f0 !important;
      border-radius: 6px !important;
      padding: 6px 14px !important;
      font-size: 13px !important;
      cursor: pointer !important;
      box-shadow: none !important;
    }

    .noise-detail-dismiss-btn:hover { background: #e2e8f0 !important; }

  ');
end;


// ═══════════════════════════════════════════════════════════════════════════
//  TFormNoise
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormNoise.InitializeObject;
begin
  inherited;
  AddClass('noise-root');
  FDialValue := 0.0;
  RegisterNoiseStyles;
  BuildHeader;
  BuildDialSection;
  BuildCountsBar;
  BuildContent;
  BuildDetailOverlay;
end;

procedure TFormNoise.Show;
begin
  inherited;
  LoadItems;
end;


// ─── Header ──────────────────────────────────────────────────────────────

procedure TFormNoise.BuildHeader;
begin
  FHeader := JW3Panel.Create(Self);
  FHeader.AddClass('noise-header');

  var TitleLbl := JW3Label.Create(FHeader);
  TitleLbl.SetText('Noise Filter');
  TitleLbl.AddClass('noise-title');

  FLastRefresh := JW3Label.Create(FHeader);
  FLastRefresh.SetText('');
  FLastRefresh.AddClass('noise-last-refresh');

  FRefreshBtn := JW3Button.Create(FHeader);
  FRefreshBtn.SetText('Refresh');
  FRefreshBtn.AddClass('noise-refresh-btn');
  FRefreshBtn.OnClick := HandleRefresh;
end;


// ─── Dial section ────────────────────────────────────────────────────────

procedure TFormNoise.BuildDialSection;
begin
  FDialSection := JW3Panel.Create(Self);
  FDialSection.AddClass('noise-dial-section');

  // Row: Chaos label - range input - value readout - Signal label
  var Row := JW3Panel.Create(FDialSection);
  Row.AddClass('noise-dial-row');

  var LblChaos := JW3Label.Create(Row);
  LblChaos.SetText('Chaos');
  LblChaos.AddClass('noise-dial-end-label');

  // Container for the range input (injected via asm)
  var SliderWrap := JW3Panel.Create(Row);
  SliderWrap.SetStyle('flex', '1');

  asm
    var inp = document.createElement('input');
    inp.type  = 'range';
    inp.min   = '0';
    inp.max   = '100';
    inp.value = '0';
    inp.step  = '1';
    inp.className = 'noise-dial-input';
    (@SliderWrap).FHandle.appendChild(inp);
    @FDialEl = inp;
  end;

  FDialEl.addEventListener('input', procedure(E: variant)
  begin
    var pct: Float;
    asm @pct = parseFloat((@FDialEl).value); end;
    FDialValue := pct / 100.0;
    // Update gradient fill via CSS custom property
    var pctStr: String;
    asm @pctStr = pct.toFixed(0) + '%'; end;
    FDialEl.style.setProperty('--dial-pct', pctStr);
    UpdateDialDisplay;
    LoadItems;
  end);

  FDialReadout := JW3Label.Create(Row);
  FDialReadout.SetText('0.00');
  FDialReadout.AddClass('noise-dial-readout');

  var LblSignal := JW3Label.Create(Row);
  LblSignal.SetText('Signal');
  LblSignal.AddClass('noise-dial-end-label');
  LblSignal.AddClass('right');

  // Description line below the slider
  FDialDescLabel := JW3Label.Create(FDialSection);
  FDialDescLabel.SetText(DialDescription);
  FDialDescLabel.AddClass('noise-dial-desc');
end;


// ─── Counts bar ──────────────────────────────────────────────────────────

procedure TFormNoise.BuildCountsBar;
begin
  FCountsBar := JW3Panel.Create(Self);
  FCountsBar.AddClass('noise-counts-bar');
  FCountsBar.SetStyle('flex-direction', 'row');
  FCountsBar.SetStyle('justify-content', 'center');

  // Focus chip
  var FocusChip := JW3Panel.Create(FCountsBar);
  FocusChip.AddClass('noise-count-chip');
  var FocusDot := JW3Panel.Create(FocusChip);
  FocusDot.AddClass('noise-count-dot');
  FocusDot.AddClass('dot-focus');
  FFocusCount := JW3Label.Create(FocusChip);
  FFocusCount.SetText('Focus: -');

  // Ambient chip
  var AmbientChip := JW3Panel.Create(FCountsBar);
  AmbientChip.AddClass('noise-count-chip');
  var AmbientDot := JW3Panel.Create(AmbientChip);
  AmbientDot.AddClass('noise-count-dot');
  AmbientDot.AddClass('dot-ambient');
  FAmbientCount := JW3Label.Create(AmbientChip);
  FAmbientCount.SetText('Ambient: -');

  // Hidden chip
  var HiddenChip := JW3Panel.Create(FCountsBar);
  HiddenChip.AddClass('noise-count-chip');
  var HiddenDot := JW3Panel.Create(HiddenChip);
  HiddenDot.AddClass('noise-count-dot');
  HiddenDot.AddClass('dot-hidden');
  FHiddenCount := JW3Label.Create(HiddenChip);
  FHiddenCount.SetText('Hidden: -');
end;


// ─── Content area ────────────────────────────────────────────────────────

procedure TFormNoise.BuildContent;
begin
  FContent := JW3Panel.Create(Self);
  FContent.AddClass('noise-content');
  FContent.SetStyle('flex', '1');

  FFocusSection   := JW3Panel.Create(FContent);
  FAmbientSection := JW3Panel.Create(FContent);
  FHiddenSection  := JW3Panel.Create(FContent);
end;


// ═══════════════════════════════════════════════════════════════════════════
//  Data loading
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormNoise.LoadItems;
var
  dialStr: String;
begin
  asm @dialStr = (@FDialValue).toFixed(2); end;

  FetchJSON('api.php?action=items&dial=' + dialStr,
    procedure(Data: variant)
    begin
      RenderData(Data);
    end,
    procedure(Status: Integer; Msg: String)
    begin
      Toast('Noise Filter: could not load items (' + Msg + ')', ttDanger, 4000);
    end
  );
end;

procedure TFormNoise.HandleRefresh(Sender: TObject);
begin
  PostJSON('api.php?action=refresh', '{}',
    procedure(Data: variant)
    begin
      Toast('Items re-scored', ttSuccess, 2000);
      LoadItems;
    end,
    procedure(Status: Integer; Msg: String)
    begin
      Toast('Refresh failed: ' + Msg, ttDanger, 4000);
    end
  );
end;


// ═══════════════════════════════════════════════════════════════════════════
//  Rendering
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormNoise.RenderData(Data: variant);
var
  fc, ac, hc: Integer;
  tsStr: String;
begin
  // Extract counts
  asm
    @fc = (@Data).counts.focus;
    @ac = (@Data).counts.ambient;
    @hc = (@Data).counts.hidden;
    @tsStr = (@Data).lastRefresh || '';
  end;

  // Update counts bar
  FFocusCount.SetText('Focus: '   + IntToStr(fc));
  FAmbientCount.SetText('Ambient: ' + IntToStr(ac));
  FHiddenCount.SetText('Hidden: '  + IntToStr(hc));

  // Update last-refresh label (trim to time portion)
  if tsStr <> '' then
  begin
    var tPart: String;
    asm @tPart = (@tsStr).replace('T', ' ').substring(0, 19); end;
    FLastRefresh.SetText('Updated ' + tPart + ' UTC');
  end;

  // Render each tier
  RenderFocus(Data.focus, fc);
  RenderAmbient(Data.ambient, ac);
  RenderHidden(hc);
end;

// ─── Focus cards ─────────────────────────────────────────────────────────

procedure TFormNoise.RenderFocus(Items: variant; Count: Integer);
var
  i, Limit: Integer;
begin
  FFocusSection.Clear;

  var Hdr := JW3Label.Create(FFocusSection);
  Hdr.SetText('Focus  ·  ' + IntToStr(Count) + ' items');
  Hdr.AddClass('noise-section-hdr');

  if Count = 0 then
  begin
    var Empty := JW3Label.Create(FFocusSection);
    Empty.SetText('No items at this dial position.');
    Empty.AddClass('noise-empty');
    exit;
  end;

  var Grid := JW3Panel.Create(FFocusSection);
  Grid.AddClass('noise-focus-grid');

  // Show up to 9 focus cards
  Limit := Count;
  //if Limit > 9 then Limit := 9;

  for i := 0 to Limit - 1 do
  begin
    var title, sourceName, category, url, scoreStr: String;
    asm
      var item    = (@Items)[@i];
      @title      = item.title           || '(no title)';
      @sourceName = item.sourceName      || '';
      @category   = item.sourceCategory  || '';
      @url        = item.url             || '';
      @scoreStr   = (item.relevanceScore || 0).toFixed(2);
    end;

    var Card := JW3Panel.Create(Grid);
    Card.AddClass('noise-card');
    Card.SetAttribute('data-url', url);

    var TitleLbl := JW3Label.Create(Card);
    TitleLbl.SetText(title);
    TitleLbl.AddClass('noise-card-title');

    var SrcLbl := JW3Label.Create(Card);
    SrcLbl.SetText(sourceName + '  ·  ' + category);
    SrcLbl.AddClass('noise-card-source');

    // Footer: score + optional assess button
    var CardFooter := JW3Panel.Create(Card);
    CardFooter.AddClass('noise-card-footer');

    var ScoreLbl := JW3Label.Create(CardFooter);
    ScoreLbl.SetText(scoreStr);
    ScoreLbl.AddClass('noise-card-score');

    var AssessBtn := JW3Panel.Create(CardFooter);
    AssessBtn.SetText('Assess');
    AssessBtn.AddClass('noise-card-assess-btn');
    AssessBtn.SetAttribute('data-title',    title);
    AssessBtn.SetAttribute('data-source',   sourceName);
    AssessBtn.SetAttribute('data-category', category);
    AssessBtn.SetAttribute('data-url',      url);
    AssessBtn.Handle.addEventListener('click', procedure(E: variant)
    begin
      asm (@E).stopPropagation(); end;
      var t, src, cat, u: String;
      asm
        var el = (@E).currentTarget;
        @t   = el.getAttribute('data-title')    || '';
        @src = el.getAttribute('data-source')   || '';
        @cat = el.getAttribute('data-category') || '';
        @u   = el.getAttribute('data-url')      || '';
      end;
      ShowAssessment(t, src, cat, u);
    end);

    Card.Handle.addEventListener('click', procedure(E: variant)
    begin
      var u: String;
      asm @u = (@E).currentTarget.getAttribute('data-url'); end;
      if u <> '' then
        asm window.open(@u, '_blank'); end;
    end);
  end;

  // Overflow note
  if Count > 9 then
  begin
    var More := JW3Label.Create(FFocusSection);
    More.SetText('+ ' + IntToStr(Count - 9) + ' more focus items (raise dial to filter)');
    More.AddClass('noise-empty');
  end;
end;

// ─── Ambient rows ─────────────────────────────────────────────────────────

procedure TFormNoise.RenderAmbient(Items: variant; Count: Integer);
var
  i, Limit: Integer;
begin
  FAmbientSection.Clear;

  var Hdr := JW3Label.Create(FAmbientSection);
  Hdr.SetText('Ambient  ·  ' + IntToStr(Count) + ' items');
  Hdr.AddClass('noise-section-hdr');

  if Count = 0 then
  begin
    var Empty := JW3Label.Create(FAmbientSection);
    Empty.SetText('No ambient items.');
    Empty.AddClass('noise-empty');
    exit;
  end;

  var List := JW3Panel.Create(FAmbientSection);
  List.AddClass('noise-ambient-list');

  Limit := Count;
  if Limit > 15 then Limit := 15;

  for i := 0 to Limit - 1 do
  begin
    var title, source, url, scoreStr, color: String;
    asm
      var item  = (@Items)[@i];
      @title    = item.title       || '(no title)';
      @source   = item.sourceName  || '';
      @url      = item.url         || '';
      @scoreStr = (item.relevanceScore || 0).toFixed(2);
      @color    = item.sourceColor || '#94a3b8';
    end;

    var Row := JW3Panel.Create(List);
    Row.AddClass('noise-ambient-row');
    Row.SetAttribute('data-url', url);

    var Dot := JW3Panel.Create(Row);
    Dot.AddClass('noise-ambient-dot');
    Dot.SetStyle('background', color);

    var TitleLbl := JW3Label.Create(Row);
    TitleLbl.SetText(title);
    TitleLbl.AddClass('noise-ambient-title');

    var SrcLbl := JW3Label.Create(Row);
    SrcLbl.SetText(source);
    SrcLbl.AddClass('noise-ambient-source');

    var ScoreLbl := JW3Label.Create(Row);
    ScoreLbl.SetText(scoreStr);
    ScoreLbl.AddClass('noise-ambient-score');

    Row.Handle.addEventListener('click', procedure(E: variant)
    begin
      var u: String;
      asm @u = (@E).currentTarget.getAttribute('data-url'); end;
      if u <> '' then
        asm window.open(@u, '_blank'); end;
    end);
  end;

  if Count > 15 then
  begin
    var More := JW3Label.Create(FAmbientSection);
    More.SetText('+ ' + IntToStr(Count - 15) + ' more ambient items');
    More.AddClass('noise-empty');
  end;
end;

// ─── Hidden count ─────────────────────────────────────────────────────────

procedure TFormNoise.RenderHidden(Count: Integer);
begin
  FHiddenSection.Clear;

  var Hdr := JW3Label.Create(FHiddenSection);
  Hdr.SetText('Hidden');
  Hdr.AddClass('noise-section-hdr');

  var Box := JW3Panel.Create(FHiddenSection);
  Box.AddClass('noise-hidden-box');

  if Count = 0 then
    Box.SetText('Everything is visible at this dial setting.')
  else
    Box.SetText(IntToStr(Count) + ' items filtered out - lower the dial to reveal them.');
end;


// ═══════════════════════════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormNoise.UpdateDialDisplay;
var
  valStr: String;
begin
  asm @valStr = (@FDialValue).toFixed(2); end;
  FDialReadout.SetText(valStr);
  FDialDescLabel.SetText(DialDescription);
end;

// ═══════════════════════════════════════════════════════════════════════════
//  Assessment overlay
// ═══════════════════════════════════════════════════════════════════════════

procedure TFormNoise.BuildDetailOverlay;
begin
  FDetailOverlay := JW3Panel.Create(Self);
  FDetailOverlay.AddClass('noise-overlay');

  var Card := JW3Panel.Create(FDetailOverlay);
  Card.AddClass('noise-detail-card');

  // Header
  var Hdr := JW3Panel.Create(Card);
  Hdr.AddClass('noise-detail-hdr');

  var HdrText := JW3Panel.Create(Hdr);
  HdrText.AddClass('noise-detail-hdr-text');

  FDetailTitle := JW3Label.Create(HdrText);
  FDetailTitle.AddClass('noise-detail-title');

  FDetailMeta := JW3Label.Create(HdrText);
  FDetailMeta.AddClass('noise-detail-meta');

  var CloseBtn := JW3Button.Create(Hdr);
  CloseBtn.SetText('x');
  CloseBtn.AddClass('noise-detail-close');
  CloseBtn.OnClick := lambda CloseDetail; end;

  // Scrollable body
  FDetailBody := JW3Panel.Create(Card);
  FDetailBody.AddClass('noise-detail-body');
  FDetailBody.SetStyle('user-select', 'text');
  FDetailBody.SetStyle('-webkit-user-select', 'text');

  // Footer
  var Footer := JW3Panel.Create(Card);
  Footer.AddClass('noise-detail-footer');

  var DismissBtn := JW3Button.Create(Footer);
  DismissBtn.SetText('Close');
  DismissBtn.AddClass('noise-detail-dismiss-btn');
  DismissBtn.OnClick := lambda CloseDetail; end;

  FDetailUrlBtn := JW3Button.Create(Footer);
  FDetailUrlBtn.SetText('Open article ->');
  FDetailUrlBtn.AddClass('noise-detail-url-btn');
  FDetailUrlBtn.Handle.addEventListener('click', procedure(E: variant)
  begin
    var u: String;
    asm @u = (@E).currentTarget.getAttribute('data-url') || ''; end;
    if u <> '' then
      asm window.open(@u, '_blank'); end;
  end);

  // Close on backdrop click
  FDetailOverlay.Handle.addEventListener('click', procedure(E: variant)
  begin
    var isBackdrop: Boolean;
    asm @isBackdrop = (@E).target === (@FDetailOverlay).FHandle; end;
    if isBackdrop then CloseDetail;
  end);
end;

procedure TFormNoise.ShowAssessment(const Title, Source, Category, Url: String);
begin
  FDetailOverlay.SetStyle('display', 'flex');
  FDetailTitle.SetText(Title);
  FDetailMeta.SetText(Source + '  ·  ' + Category);
  FDetailBody.SetHTML('<p class="noise-assess-loading">Consulting Opus - takes 10-20 s...</p>');
  FDetailUrlBtn.SetAttribute('data-url', Url);

  if FAssessToken <> '' then
  begin
    RunAssessment(Title, Source, Category, FAssessToken);
    exit;
  end;

  PostJSON('/api/claude/auth/token', '{}',
    procedure(D: variant)
    begin
      asm @FAssessToken = (@D).token || ''; end;
      if FAssessToken = '' then
      begin
        FDetailBody.SetHTML('<p class="noise-assess-error">Could not obtain auth token.</p>');
        exit;
      end;
      RunAssessment(Title, Source, Category, FAssessToken);
    end,
    procedure(Status: Integer; Msg: String)
    begin
      FDetailBody.SetHTML('<p class="noise-assess-error">Auth error: ' + Msg + '</p>');
    end
  );
end;

procedure TFormNoise.CloseDetail;
begin
  FDetailOverlay.SetStyle('display', 'none');
  FDetailBody.SetHTML('');
end;

procedure TFormNoise.RunAssessment(const Title, Source, Category, Token: String);
var
  xhr:    variant;
  prompt: String;
begin

/*
  prompt :=
    'Analyse this news headline. Be direct and factual - no filler, no hedging.' + #10 +
    'Headline: "' + Title + '"' + #10 +
    'Source: ' + Source + ' (' + Category + ')' + #10#10 +
    'Structure your response with these exact headings, each followed by 4-6 tight sentences:' + #10 +
    '## What is happening' + #10 +
    '## Background' + #10 +
    '## Key actors' + #10 +
    '## Why it matters' + #10 +
    '## Different angles' + #10 +
    '## Economic / practical impact' + #10 +
    '## What happens next' + #10 +
    '## Risks' + #10 +
    '## Opportunities' + #10 +
    '## Bottom line' + #10 +
    '## Best way to resolve the issue' + #10#10 +
    'Keep each section sharp. Avoid generic observations.';

*/

prompt :=
  'You are briefing someone who makes decisions based on what you tell them. ' +
  'They need to understand HOW things work, not just WHAT is happening. ' +
  'Explain cause-and-effect chains. Name specific mechanisms, institutions, and precedents.' + #10#10 +

  'Headline: "' + Title + '"' + #10 +
  'Source: ' + Source + ' (' + Category + ')' + #10#10 +

  '## What is actually happening' + #10 +
  'State the concrete action, decision, or event. Who did what, when, and under what authority. No scene-setting.' + #10#10 +

  '## Why now' + #10 +
  'What changed that made this happen at this moment? What was the trigger - a deadline, an election, a market move, a prior decision that created pressure?' + #10#10 +

  '## The mechanism' + #10 +
  'How does this work technically, legally, or economically? Trace the causal chain: if X happens, then Y follows because Z. Name the specific law, protocol, market dynamic, or institutional process involved.' + #10#10 +

  '## Who gains, who loses' + #10 +
  'Be specific about which actors benefit and which are disadvantaged. Include second-order effects - who gets hurt indirectly.' + #10#10 +

  '## What the opposing view says' + #10 +
  'Steel-man the strongest counterargument. What would an informed critic say is wrong with the prevailing narrative?' + #10#10 +

  '## Practical impact' + #10 +
  'For a self-employed developer and IT consultant in regional Australia running self-hosted infrastructure with off-grid solar: what specifically changes? Name concrete actions, costs, timelines, or regulatory exposures.' + #10#10 +

  '## What happens next' + #10 +
  'What are the next decision points, deadlines, or events that will determine the outcome? Give dates or timeframes where possible.' + #10#10 +

  '## How this should be resolved' + #10 +
  'This is the most important section - take as much space as you need. ' +
  'Draw on historical precedents, cross-domain analogies, and unconventional approaches. ' +
  'Don''t just say what should happen - explain a specific strategy or mechanism that would work, why it would work, and what makes it better than the obvious alternatives. ' +
  'If there is no clean resolution, say so and explain what an intelligent adaptation looks like instead.' + #10#10 +

  'Be concrete throughout. Replace every adjective with a fact.';

//////

  asm @xhr = new XMLHttpRequest(); end;
  xhr.open('POST', '/api/claude/stream');
  asm
    (@xhr).setRequestHeader('Content-Type', 'application/json');
    (@xhr).setRequestHeader('Authorization', 'Bearer ' + @Token);
    (@xhr).timeout = 300000;

    (@FDetailBody).FHandle.dataset.accum = '';
    var lastPos = 0;
    (@xhr).onprogress = function() {
      var raw = (@xhr).responseText.slice(lastPos);
      lastPos = (@xhr).responseText.length;
      var el = (@FDetailBody).FHandle;
      var lines = raw.split('\n');
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line.startsWith('data: ')) continue;
        try {
          var chunk = JSON.parse(line.slice(6));
          if (chunk.type === 'content_block_delta' &&
              chunk.delta && chunk.delta.type === 'text_delta') {
            el.dataset.accum = (el.dataset.accum || '') + chunk.delta.text;
            el.innerText = el.dataset.accum;
          }
        } catch(e) {}
      }
    };
  end;

  xhr.onreadystatechange := procedure()
  begin
    if xhr.readyState <> 4 then exit;
    if xhr.status = 0 then
    begin
      FDetailBody.SetHTML('<p class="noise-assess-error">Request timed out or was aborted.</p>');
      exit;
    end;
    // Read text accumulated by onprogress from the DOM element
    var text: String;
    asm @text = (@FDetailBody).FHandle.dataset.accum || ''; end;
    if text = '' then
    begin
      FDetailBody.SetHTML('<p class="noise-assess-error">Empty response from Claude.</p>');
      exit;
    end;
    // Final markdown render
    var html: String;
    asm
      var paras = (@text).split('\n\n').filter(function(p){ return p.trim().length > 0; });
      if (paras.length === 0) paras = [@text];
      @html = paras.map(function(p){
        p = p.trim();
        var lines = p.split('\n');
        var first = lines[0].trim();
        if (first.startsWith('## ')) {
          var heading = first.slice(3);
          var body = lines.slice(1).join(' ').trim();
          body = body.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
          var out = '<p class="noise-assess-heading">' + heading + '</p>';
          if (body) out += '<p class="noise-assess-para">' + body + '</p>';
          return out;
        }
        p = p.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        return '<p class="noise-assess-para">' + p + '</p>';
      }).join('');
    end;
    FDetailBody.SetHTML(html);
  end;

  var body: String;
  asm
    @body = JSON.stringify({
      model: 'claude-opus-4-6',
      max_tokens: 8192,
      tools: [{type: 'web_search_20250305', name: 'web_search'}],
      messages: [{role: 'user', content: @prompt}]
    });
  end;
  xhr.send(body);
end;

function TFormNoise.DialDescription: String;
begin
  if      FDialValue < 0.15 then Result := 'Everything visible - full information stream'
  else if FDialValue < 0.30 then Result := 'Noise starting to fade - low-relevance items dimming'
  else if FDialValue < 0.45 then Result := 'Mixed signal - focus and ambient blending'
  else if FDialValue < 0.60 then Result := 'Infrastructure and high-priority sources dominating'
  else if FDialValue < 0.75 then Result := 'Survival feeds + high-impact items only'
  else if FDialValue < 0.90 then Result := 'Critical signals - only the most important items'
  else                           Result := 'Emergency mode - maximum filtration active';
end;

end.
