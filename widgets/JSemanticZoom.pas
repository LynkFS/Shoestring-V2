unit JSemanticZoom;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JSemanticZoom — Zoomable knowledge surface
//
//  A full-viewport reading surface where prose content has depth. Phrases
//  wrapped with <span class="zoom-phrase" data-zoom="key"> are portals to
//  deeper content. Click to zoom in; Escape or click the surface background
//  to zoom out one level.
//
//  There is no menu, no toolbar, no navigation bar. The surface IS the
//  document. The depth indicator (right edge) and values bar (bottom) are
//  the only persistent chrome. Everything else is content.
//
//  Structure:
//    TZoomSurface  — full-viewport scrollable surface (the world)
//      ├ FCard          — centred white document card
//      │   ├ FCardHeader — project ID (left) + version (right)
//      │   ├ FTitleInput — editable project heading
//      │   ├ FActionRow  — Examine button + breadcrumb trail
//      │   ├ FBody       — prose content, swapped with animation on zoom
//      │   └ [widget slots] — pre-built TElement slots, hidden until active
//      ├ FDepthBar    — fixed right-edge vertical zoom-level indicator
//      └ FValuesBar   — fixed bottom strip with named value zones
//
//  Node types:
//    AddLevel(key, html, depth)           Raw HTML string (original behaviour)
//    AddText(key, html, depth)            Prose HTML wrapped in .text-prose
//    AddCode(key, code, depth)            Code string in pre.zoom-code.text-mono
//    AddForm(key, depth, fields)          Rendered input form; fires OnFormSubmit
//    AddWidget(key, depth): TElement      Returns an empty slot in FCard for
//                                         the caller to populate with components
//
//  JSON loading:
//    LoadFromObject(data)  — load from an already-parsed JS object
//    FetchAndLoad(url)     — async HTTP GET + parse + load
//
//    JSON schema:
//      {
//        "project": { "name": "...", "id": "...", "version": "..." },
//        "values":  ["Safety", "Privacy"],
//        "nodes": [
//          { "key": "root",    "depth": 0, "type": "text", "content": "<p>...</p>" },
//          { "key": "snippet", "depth": 1, "type": "code", "content": "x := 1;" },
//          { "key": "contact", "depth": 2, "type": "form", "fields": [
//              { "name": "email", "label": "Email", "type": "email", "required": true },
//              { "name": "msg",   "label": "Message", "type": "textarea" }
//          ]}
//        ]
//      }
//    Note: "widget" nodes cannot be loaded from JSON (they require live TElement refs).
//
//  OnFormSubmit:
//    Fires when the user submits a rendered form node. Receives the node key
//    and a plain JS object with name → value pairs for every named input.
//      Surface.OnFormSubmit := procedure(Sender: TObject; Key: String; Values: variant)
//      begin
//        var email := String(Values.email);
//        Toast('Submitted: ' + Key, ttSuccess, 3000);
//      end;
//
//  Zoom navigation:
//    ZoomTo(key)   — push key on the nav stack, animate in (going deeper)
//    ZoomOut       — pop the stack, animate out (going shallower)
//    Escape key    — calls ZoomOut
//    Surface click — calls ZoomOut (click outside the card)
//
//  Values bar:
//    AddValue('Safety') — adds a labelled zone
//    PulseValue('Safety') — triggers a brief colour pulse on that zone
//
//  Animation:
//    Zoom in:  exit = scale down + slide down, enter = scale up from below
//    Zoom out: exit = scale up + slide up,    enter = scale down from above
//    Duration: 280 ms exit, 420 ms enter (spring easing)
//    Widget nodes are shown/hidden immediately (no animation).
//
//  asm block rule:
//    Never use (@FField).Something inside asm — DWScript field mangling
//    produces unreliable references when methods are called through closures.
//    Always capture Pascal method results into local variants first.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  // Node type identifiers — used by the Add* methods and stored in TZoomLevel
  szltText   = 'text';     // prose HTML, body wrapped in .text-prose
  szltCode   = 'code';     // code string, body wrapped in pre.zoom-code.text-mono
  szltHTML   = 'html';     // raw HTML string (original AddLevel behaviour)
  szltForm   = 'form';     // rendered input form; fires OnFormSubmit on submit
  szltWidget = 'widget';   // pre-built TElement slot (code-only, not JSON-loadable)

  csZoomPhrase   = 'zoom-phrase';
  csZoomSurface  = 'zoom-surface';
  csZoomCard     = 'zoom-card';
  csZoomCardHdr  = 'zoom-card-hdr';
  csZoomProjId   = 'zoom-proj-id';
  csZoomVersion  = 'zoom-version';
  csZoomTitleInput = 'zoom-title-input';
  csZoomActionRow  = 'zoom-action-row';
  csZoomExamine    = 'zoom-examine';
  csZoomBreadcrumb = 'zoom-breadcrumb';
  csZoomBody     = 'zoom-body';
  csZoomDepth    = 'zoom-depth';
  csZoomDot      = 'zoom-dot';
  csZoomDotAct   = 'zoom-dot-active';
  csZoomValBar   = 'zoom-val-bar';
  csZoomValZone  = 'zoom-val-zone';
  csZoomValPulse = 'zoom-val-pulse';

type
  TZoomField = record
    Name:        String;   // HTML name attribute — becomes the key in Values object
    Label_:      String;   // Visible label text
    FieldType:   String;   // 'text' | 'email' | 'number' | 'textarea' | 'select' | 'checkbox'
    Placeholder: String;
    Options:     String;   // Comma-separated option values for 'select'
    Required:    Boolean;
  end;

  TZoomLevel = record
    Key:       String;
    Depth:     Integer;
    LevelType: String;
    Content:   String;             // rendered HTML for text/code/html/form types
    Fields:    array of TZoomField; // original field specs (form type only)
    Widget:    TElement;            // pre-built slot element (widget type only)
  end;

  TOnFormSubmit = procedure(Sender: TObject; Key: String; Values: variant);

  TZoomSurface = class(TElement)
  private
    FCard:         TElement;
    FCardHeader:   TElement;
    FProjectId:    TElement;
    FVersionEl:    TElement;
    FTitleInput:   TElement;
    FActionRow:    TElement;
    FExamineBtn:   TElement;
    FBreadcrumb:   TElement;
    FBody:         TElement;
    FDepthBar:     TElement;
    FValuesBar:    TElement;

    FLevels:       array of TZoomLevel;
    FNavStack:     array of String;
    FNavLabels:    array of String;
    FValueZones:   array of TElement;
    FCurrentKey:   String;
    FMaxDepth:     Integer;

    FOnZoomChange: TNotifyEvent;
    FOnExamine:    TNotifyEvent;
    FOnFormSubmit: TOnFormSubmit;

    function  FindLevel(const Key: String): Integer;
    function  LevelDepth(const Key: String): Integer;
    function  IsAnimating: Boolean;
    procedure RenderContent(const Key: String; GoingDeeper: Boolean);
    procedure UpdateDepthBar;
    procedure UpdateBreadcrumb;
    procedure NavigateTo(const Idx: Integer);
    procedure ClearNavStack;
    procedure HideAllWidgets;
    procedure RegisterLevel(const Key: String; Depth: Integer;
                            const LType, Content: String);

  public
    constructor Create(Parent: TElement); virtual;

    // ── Content registration ───────────────────────────────────────────────
    procedure SetProject(const Name, ID, Version: String);
    procedure AddLevel(const Key, HTML: String; Depth: Integer);
    procedure AddText(const Key, HTML: String; Depth: Integer);
    procedure AddCode(const Key, Code: String; Depth: Integer);
    procedure AddForm(const Key: String; Depth: Integer;
                      const Fields: array of TZoomField);
    function  AddWidget(const Key: String; Depth: Integer): TElement;
    procedure AddValue(const Name: String);

    // ── JSON loading ───────────────────────────────────────────────────────
    procedure LoadFromObject(const Data: variant);
    procedure FetchAndLoad(const URL: String);

    // ── Navigation ────────────────────────────────────────────────────────
    procedure ZoomTo(const Key: String);
    procedure ZoomToLabelled(const Key, Label: String);
    procedure ZoomOut;

    // ── Values layer ──────────────────────────────────────────────────────
    procedure PulseValue(const Name: String);

    // ── Reload ────────────────────────────────────────────────────────────
    // Clears all registered nodes, nav stack, and value zones so the surface
    // can be reloaded with LoadFromObject / FetchAndLoad. Widget slots are
    // removed from FCard; callers must re-add them via AddWidget.
    procedure Reset;

    // ── State ─────────────────────────────────────────────────────────────
    function  CurrentDepth: Integer;
    function  CurrentKey: String;
    function  ProjectName: String;

    property OnZoomChange:  TNotifyEvent  read FOnZoomChange  write FOnZoomChange;
    property OnExamine:     TNotifyEvent  read FOnExamine     write FOnExamine;
    property OnFormSubmit:  TOnFormSubmit read FOnFormSubmit  write FOnFormSubmit;
  end;

procedure RegisterZoomStyles;

implementation

uses Globals, HttpClient;

var FRegistered: Boolean := false;


// ── HtmlEscape: escape special chars before embedding text inside HTML ────────
// Use for any user-supplied string that goes into an attribute or text node.

function HtmlEscape(const s: String): String;
begin
  asm
    @Result = String(@s)
      .replace(/&/g,  '&amp;')
      .replace(/</g,  '&lt;')
      .replace(/>/g,  '&gt;');
//      .replace(/"/g,  '&quot;')
//      .replace(/'/g,  '&#x27;');
  end;
end;

// ── SafeFieldType: validate input type against the allowed whitelist ──────────
// Prevents attribute injection via malformed FieldType strings from JSON.

function SafeFieldType(const t: String): String;
begin
  if (t = 'text')     or (t = 'email')  or (t = 'number') or
     (t = 'password') or (t = 'tel')    or (t = 'url')    or
     (t = 'date')     or (t = 'time')   or (t = 'search') then
    Result := t
  else
    Result := 'text';
end;


//=============================================================================
// BuildFormHTML — generates the HTML string for a form node
//=============================================================================

function BuildFormHTML(const Key: String; const Fields: array of TZoomField): String;
var
  i, j:     Integer;
  F:        TZoomField;
  html:     String;
  t:        String;
  optStr:   String;
  optArr:   variant;
  optCount: Integer;
  optVal:   String;
begin
  html := '<form class="zoom-form" data-key="' + HtmlEscape(Key) + '">';

  for i := 0 to Fields.Count - 1 do
  begin
    F := Fields[i];
    html := html + '<div class="zoom-field">';
    html := html + '<label class="zoom-field-label">' + HtmlEscape(F.Label_) + '</label>';

    if F.FieldType = 'textarea' then
    begin
      html := html + '<textarea class="zoom-field-input" name="' + HtmlEscape(F.Name) + '"';
      if F.Placeholder <> '' then
        html := html + ' placeholder="' + HtmlEscape(F.Placeholder) + '"';
      if F.Required then html := html + ' required';
      html := html + '></textarea>';
    end

    else if F.FieldType = 'select' then
    begin
      html := html + '<select class="zoom-field-input" name="' + HtmlEscape(F.Name) + '">';
      optStr := F.Options;
      asm
        @optArr   = (@optStr).split(',');
        @optCount = (@optArr).length;
      end;
      for j := 0 to optCount - 1 do
      begin
        asm @optVal = @optArr[@j].trim(); end;
        html := html + '<option value="' + HtmlEscape(optVal) + '">' + HtmlEscape(optVal) + '</option>';
      end;
      html := html + '</select>';
    end

    else if F.FieldType = 'checkbox' then
    begin
      html := html + '<label class="zoom-field-check-wrap">';
      html := html + '<input type="checkbox" name="' + HtmlEscape(F.Name) + '">';
      if F.Placeholder <> '' then
        html := html + '<span>' + HtmlEscape(F.Placeholder) + '</span>';
      html := html + '</label>';
    end

    else
    begin
      t := SafeFieldType(F.FieldType);
      html := html + '<input class="zoom-field-input" type="' + t +
                     '" name="' + HtmlEscape(F.Name) + '"';
      if F.Placeholder <> '' then
        html := html + ' placeholder="' + HtmlEscape(F.Placeholder) + '"';
      if F.Required then html := html + ' required';
      html := html + '>';
    end;

    html := html + '</div>';
  end;

  html := html + '<button class="zoom-field-submit" type="submit">Submit</button>';
  html := html + '</form>';
  Result := html;
end;


//=============================================================================
// RegisterZoomStyles
//=============================================================================

procedure RegisterZoomStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Surface ───────────────────────────────────────────────────────── */

    .zoom-surface {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      overflow-y: auto;
      overflow-x: hidden;
      overscroll-behavior: contain;

      background-color: #eeede9;
      background-image: radial-gradient(circle, rgba(0,0,0,0.055) 1px, transparent 1px);
      background-size: 26px 26px;

      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 60px 80px 100px;
      box-sizing: border-box;
    }

    /* ── Card ───────────────────────────────────────────────────────────── */

    .zoom-card {
      width: 100%;
      max-width: 660px;
      background: #ffffff;
      border-radius: 20px;
      padding: 40px 48px 52px;
      box-sizing: border-box;
      flex-shrink: 0;

      box-shadow:
        0 1px 2px  rgba(0,0,0,0.04),
        0 6px 20px rgba(0,0,0,0.06),
        0 20px 56px rgba(0,0,0,0.09);
    }

    /* ── Card header row ────────────────────────────────────────────────── */

    .zoom-card-hdr {
      display: flex;
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 24px;
    }

    .zoom-proj-id {
      font-family: "SF Mono", "Fira Code", "Cascadia Code", monospace;
      font-size: 10px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: #9ca3af;
      font-weight: 500;
    }

    .zoom-version {
      font-family: "SF Mono", "Fira Code", "Cascadia Code", monospace;
      font-size: 10px;
      letter-spacing: 0.08em;
      color: #9ca3af;
    }

    /* ── Title input ─────────────────────────────────────────────────────── */

    .zoom-title-input {
      width: 100%;
      font-size: 26px;
      font-weight: 600;
      color: #2563eb;
      line-height: 1.25;
      letter-spacing: -0.01em;
      margin-bottom: 14px;
      padding: 0 0 5px 0;
      box-sizing: border-box;
      border: none;
      border-bottom: 2px solid rgba(37,99,235,0.18);
      outline: none;
      background: transparent;
      font-family: inherit;
    }

    .zoom-title-input:focus {
      border-bottom-color: rgba(37,99,235,0.55);
    }

    .zoom-title-input::placeholder {
      color: #93c5fd;
    }

    /* ── Action row: examine button + breadcrumb ────────────────────────── */

    .zoom-action-row {
      display: flex;
      flex-direction: row;
      align-items: center;
      gap: 16px;
      margin-bottom: 28px;
    }

    /* ── Examine button ──────────────────────────────────────────────────── */

    .zoom-examine {
      display: inline-block;
      flex-shrink: 0;
      padding: 7px 20px;
      background: #2563eb;
      color: #ffffff;
      border: none;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 0.03em;
      cursor: pointer;
      font-family: inherit;
      transition: background 0.14s ease, transform 0.1s ease;
    }

    .zoom-examine:hover  { background: #1d4ed8; }
    .zoom-examine:active { transform: scale(0.97); }

    /* ── Breadcrumb trail ────────────────────────────────────────────────── */

    .zoom-breadcrumb {
      font-size: 12px;
      color: #9ca3af;
      font-family: "SF Mono", "Fira Code", monospace;
      letter-spacing: 0.04em;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .zoom-crumb {
      cursor: pointer;
      color: #6b7280;
      transition: color 0.12s ease;
    }

    .zoom-crumb:hover { color: #2563eb; }

    .zoom-crumb-sep {
      color: #d1d5db;
      margin: 0 3px;
    }

    /* ── Body prose ─────────────────────────────────────────────────────── */

    .zoom-body {
      font-size: 15px;
      line-height: 1.82;
      color: #374151;
      transition: opacity 0.28s ease, transform 0.28s ease;
    }

    .zoom-body p        { margin: 0 0 1.3em; }
    .zoom-body p:last-child { margin-bottom: 0; }

    .zoom-body strong,
    .zoom-body b        { color: #1f2937; font-weight: 600; }

    /* ── Zoom phrases — the portals ─────────────────────────────────────── */

    .zoom-phrase {
      color: #2563eb;
      cursor: zoom-in;
      border-bottom: 1px solid rgba(37,99,235,0.28);
      transition: color 0.12s ease, border-color 0.12s ease;
    }

    .zoom-phrase:hover {
      color: #1d4ed8;
      border-bottom-color: rgba(29,78,216,0.65);
    }

    /* ── Code nodes ──────────────────────────────────────────────────────── */

    .zoom-code {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 10px;
      padding: 18px 22px;
      overflow-x: auto;
      margin: 0;
      line-height: 1.65;
      font-size: 0.82rem;
      color: #334155;
      white-space: pre;
    }

    /* ── Form nodes ──────────────────────────────────────────────────────── */

    .zoom-form {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .zoom-field {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }

    .zoom-field-label {
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: #9ca3af;
    }

    .zoom-field-input {
      padding: 9px 12px;
      border: 1.5px solid #e5e7eb;
      border-radius: 8px;
      font-size: 14px;
      font-family: inherit;
      color: #374151;
      background: #fafafa;
      outline: none;
      box-sizing: border-box;
      width: 100%;
      transition: border-color 0.15s ease, box-shadow 0.15s ease;
    }

    .zoom-field-input:focus {
      border-color: #2563eb;
      background: #ffffff;
      box-shadow: 0 0 0 3px rgba(37,99,235,0.10);
    }

    textarea.zoom-field-input {
      resize: vertical;
      min-height: 88px;
      line-height: 1.55;
    }

    .zoom-field-check-wrap {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 14px;
      color: #374151;
      cursor: pointer;
      user-select: none;
    }

    .zoom-field-submit {
      align-self: flex-start;
      padding: 9px 22px;
      background: #2563eb;
      color: #ffffff;
      border: none;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 0.02em;
      cursor: pointer;
      font-family: inherit;
      transition: background 0.14s ease, transform 0.1s ease;
    }

    .zoom-field-submit:hover  { background: #1d4ed8; }
    .zoom-field-submit:active { transform: scale(0.97); }

    /* ── Widget slot ─────────────────────────────────────────────────────── */

    .zoom-widget {
      width: 100%;
    }

    /* ── Body animation: exit going deeper ──────────────────────────────── */

    .zoom-exit-deep {
      opacity: 0 !important;
      transform: scale(0.965) translateY(8px) !important;
      pointer-events: none !important;
    }

    /* ── Body animation: exit going shallower ───────────────────────────── */

    .zoom-exit-up {
      opacity: 0 !important;
      transform: scale(1.025) translateY(-8px) !important;
      pointer-events: none !important;
    }

    /* ── Body animation: enter going deeper ─────────────────────────────── */

    @keyframes zoomEnterDeep {
      from { opacity: 0; transform: scale(0.97) translateY(-10px); }
      to   { opacity: 1; transform: scale(1)    translateY(0);     }
    }

    /* ── Body animation: enter going shallower ──────────────────────────── */

    @keyframes zoomEnterUp {
      from { opacity: 0; transform: scale(1.02) translateY(10px); }
      to   { opacity: 1; transform: scale(1)    translateY(0);    }
    }

    .zoom-enter-deep {
      animation: zoomEnterDeep 0.38s cubic-bezier(0.16, 1, 0.3, 1) forwards;
      pointer-events: none;
    }

    .zoom-enter-up {
      animation: zoomEnterUp 0.38s cubic-bezier(0.16, 1, 0.3, 1) forwards;
      pointer-events: none;
    }

    /* ── Depth indicator — right edge, fixed ────────────────────────────── */

    .zoom-depth {
      position: fixed;
      right: 26px;
      top: 50%;
      transform: translateY(-50%);
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 11px;
      z-index: 100;
    }

    .zoom-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: #d1d5db;
      flex-shrink: 0;
      transition: background 0.35s ease, transform 0.35s ease, opacity 0.35s ease;
    }

    .zoom-depth::before {
      content: "";
      position: absolute;
      top: 3px;
      bottom: 3px;
      left: 50%;
      transform: translateX(-50%);
      width: 1px;
      background: linear-gradient(to bottom, transparent, #d1d5db 20%, #d1d5db 80%, transparent);
      z-index: -1;
    }

    .zoom-dot-active {
      background: #2563eb !important;
      transform: scale(1.45);
    }

    /* ── Values bar — bottom edge, fixed ────────────────────────────────── */

    .zoom-val-bar {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      height: 29px;
      display: flex;
      flex-direction: row;
      align-items: stretch;
      background: rgba(235,234,230,0.88);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      border-top: 1px solid rgba(0,0,0,0.08);
      z-index: 100;
    }

    .zoom-val-zone {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 9px;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: #a0aec0;
      font-weight: 700;
      font-family: "SF Mono", "Fira Code", monospace;
      border-right: 1px solid rgba(0,0,0,0.06);
      transition: color 0.5s ease, background 0.5s ease;
      user-select: none;
    }

    .zoom-val-zone:last-child { border-right: none; }

    @keyframes zoomValPulse {
      0%   { background: transparent;          color: #a0aec0; }
      15%  { background: rgba(37,99,235,0.11); color: #2563eb; }
      70%  { background: rgba(37,99,235,0.07); color: #3b82f6; }
      100% { background: transparent;          color: #a0aec0; }
    }

    .zoom-val-pulse {
      animation: zoomValPulse 2.2s ease forwards;
    }

    /* ── Load error ─────────────────────────────────────────────────────── */

    .zoom-load-error {
      color: #dc2626;
      font-size: 14px;
      line-height: 1.6;
      padding: 20px 0 0;
    }

  ');
end;


{ TZoomSurface }

constructor TZoomSurface.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csZoomSurface);

  FMaxDepth   := 0;
  FCurrentKey := '';

  // ── Card ─────────────────────────────────────────────────────────────────
  FCard := TElement.Create('div', Self);
  FCard.AddClass(csZoomCard);

  // Header row: project ID left, version right
  FCardHeader := TElement.Create('div', FCard);
  FCardHeader.AddClass(csZoomCardHdr);

  FProjectId := TElement.Create('div', FCardHeader);
  FProjectId.AddClass(csZoomProjId);

  FVersionEl := TElement.Create('div', FCardHeader);
  FVersionEl.AddClass(csZoomVersion);

  // Title — editable input
  FTitleInput := TElement.Create('input', FCard);
  FTitleInput.AddClass(csZoomTitleInput);
  FTitleInput.SetAttribute('type', 'text');
  FTitleInput.SetAttribute('spellcheck', 'false');

  // Action row: Examine button + breadcrumb trail
  FActionRow := TElement.Create('div', FCard);
  FActionRow.AddClass(csZoomActionRow);

  FExamineBtn := TElement.Create('button', FActionRow);
  FExamineBtn.AddClass(csZoomExamine);
  FExamineBtn.SetText('Examine');
  FExamineBtn.Handle.addEventListener('click', procedure(E: variant)
  begin
    ClearNavStack;
    if assigned(FOnExamine) then
      FOnExamine(Self);
  end);

  FBreadcrumb := TElement.Create('div', FActionRow);
  FBreadcrumb.AddClass(csZoomBreadcrumb);
  FBreadcrumb.Handle.addEventListener('click', procedure(E: variant)
  var el: variant;
  var idx: Integer;
  begin
    el := E.target.closest('[data-crumb]');
    if el then
    begin
      idx := el.getAttribute('data-crumb');
      NavigateTo(idx);
    end;
  end);

  // Body — animated content area for text/code/html/form nodes
  FBody := TElement.Create('div', FCard);
  FBody.AddClass(csZoomBody);

  // ── Event delegation: zoom phrase clicks ─────────────────────────────────
  FBody.Handle.addEventListener('click', procedure(E: variant)
  var el: variant;
  var key, lbl: String;
  begin
    el := E.target.closest('[data-zoom]');
    if el then
    begin
      key := el.getAttribute('data-zoom');
      lbl := el.textContent;
      ZoomToLabelled(key, lbl);
    end;
  end);

  // ── Event delegation: form submissions ───────────────────────────────────
  FBody.Handle.addEventListener('submit', procedure(E: variant)
  var form: variant;
  var formOk: Boolean;
  var key: String;
  var vals: variant;
  begin
    E.preventDefault;
    form := E.target.closest('.zoom-form');
    asm @formOk = !!@form; end;
    if not formOk then exit;

    key := form.getAttribute('data-key');
    asm
      @vals = {};
      var inputs = (@form).querySelectorAll('[name]');
      for (var i = 0; i < inputs.length; i++) {
        var el = inputs[i];
        @vals[el.name] = (el.tagName === 'INPUT' && el.type === 'checkbox')
          ? el.checked
          : el.value;
      }
    end;

    if assigned(FOnFormSubmit) then
      FOnFormSubmit(Self, key, vals);
  end);

  // ── Depth indicator — fixed right edge ───────────────────────────────────
  FDepthBar := TElement.Create('div', Self);
  FDepthBar.AddClass(csZoomDepth);

  // ── Values bar — fixed bottom edge ───────────────────────────────────────
  FValuesBar := TElement.Create('div', Self);
  FValuesBar.AddClass(csZoomValBar);

  // ── Surface background click: zoom out ───────────────────────────────────
  Handle.addEventListener('click', procedure(E: variant)
  begin
    if not E.target.closest('.zoom-card') then
      ZoomOut;
  end);

  // ── Escape key: zoom out one level ───────────────────────────────────────
  document.addEventListener('keydown', procedure(E: variant)
  begin
    if E.key = 'Escape' then ZoomOut;
  end);
end;


// ── Private helpers ──────────────────────────────────────────────────────────

function TZoomSurface.FindLevel(const Key: String): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to FLevels.Count - 1 do
    if FLevels[i].Key = Key then
    begin
      Result := i;
      exit;
    end;
end;

function TZoomSurface.LevelDepth(const Key: String): Integer;
var
  idx: Integer;
begin
  idx := FindLevel(Key);
  if idx >= 0 then
    Result := FLevels[idx].Depth
  else
    Result := -1;
end;

procedure TZoomSurface.HideAllWidgets;
var
  i: Integer;
begin
  for i := 0 to FLevels.Count - 1 do
    if (FLevels[i].LevelType = szltWidget) and (FLevels[i].Widget <> nil) then
      FLevels[i].Widget.SetStyle('display', 'none');
end;

// True during both the exit phase (280 ms) and the enter phase (420 ms).
// Navigation calls that arrive while animating are dropped to prevent
// overlapping timeouts from clobbering each other's innerHTML.
function TZoomSurface.IsAnimating: Boolean;
begin
  Result := FBody.HasClass('zoom-exit-deep') or FBody.HasClass('zoom-exit-up') or
            FBody.HasClass('zoom-enter-deep') or FBody.HasClass('zoom-enter-up');
end;

procedure TZoomSurface.UpdateBreadcrumb;
var
  i:     Integer;
  parts: String;
  lbl:   String;
begin
  parts := '';
  for i := 0 to FNavStack.Count - 1 do
  begin
    lbl := FNavLabels[i];
    if (lbl <> '') and (LevelDepth(FNavStack[i]) >= 2) then
    begin
      if parts <> '' then
        parts := parts + '<span class="zoom-crumb-sep">&rsaquo;</span>';
      parts := parts +
        '<span class="zoom-crumb" data-crumb="' + IntToStr(i) + '">' + HtmlEscape(lbl) + '</span>';
    end;
  end;
  FBreadcrumb.SetHTML(parts);
end;

procedure TZoomSurface.NavigateTo(const Idx: Integer);
begin
  if IsAnimating then exit;
  if (Idx < 0) or (Idx >= FNavStack.Count) then exit;

  while FNavStack.Count > Idx + 1 do
    FNavStack.Delete(FNavStack.Count - 1);
  while FNavLabels.Count > Idx + 1 do
    FNavLabels.Delete(FNavLabels.Count - 1);

  RenderContent(FNavStack[Idx], false);
  UpdateBreadcrumb;

  if assigned(FOnZoomChange) then
    FOnZoomChange(Self);
end;

procedure TZoomSurface.ClearNavStack;
begin
  FNavStack.Clear;
  FNavLabels.Clear;
  FCurrentKey := '';
  FBreadcrumb.SetHTML('');
end;

procedure TZoomSurface.UpdateDepthBar;
var
  i, curDepth: Integer;
  Dot: TElement;
begin
  curDepth := LevelDepth(FCurrentKey);

  FDepthBar.Clear;
  for i := 0 to FMaxDepth do
  begin
    Dot := TElement.Create('div', FDepthBar);
    Dot.AddClass(csZoomDot);
    if i = curDepth then
      Dot.AddClass(csZoomDotAct);
  end;
end;

procedure TZoomSurface.RenderContent(const Key: String; GoingDeeper: Boolean);
var
  idx:           Integer;
  ltype:         String;
  html:          String;
  deeper:        Boolean;
  prevIdx:       Integer;
  prevWasWidget: Boolean;
  bodyHandle:    variant;
  surfHandle:    variant;
begin
  idx := FindLevel(Key);
  if idx < 0 then exit;

  ltype  := FLevels[idx].LevelType;
  html   := FLevels[idx].Content;
  deeper := GoingDeeper;

  // Wrap code content in a mono block; text and html render identically into .zoom-body
  if ltype = szltCode then
    html := '<pre class="zoom-code text-mono"><code>' + html + '</code></pre>';

  // Always hide all widget slots first
  HideAllWidgets;

  // ── Widget node: swap FBody for the pre-built slot ───────────────────────
  if ltype = szltWidget then
  begin
    FBody.SetStyle('display', 'none');
    if FLevels[idx].Widget <> nil then
      FLevels[idx].Widget.SetStyle('display', '');
    FCurrentKey := Key;
    UpdateDepthBar;
    exit;
  end;

  // ── Non-widget node ──────────────────────────────────────────────────────
  FBody.SetStyle('display', '');  // restore if previously hidden by a widget

  // Check whether the previous render was a widget (no animation needed)
  prevIdx       := FindLevel(FCurrentKey);
  prevWasWidget := (FCurrentKey <> '') and (prevIdx >= 0) and
                   (FLevels[prevIdx].LevelType = szltWidget);

  // First render or returning from a widget — no animation
  if (FCurrentKey = '') or prevWasWidget then
  begin
    FBody.SetHTML(html);
    FCurrentKey := Key;
    UpdateDepthBar;
    exit;
  end;

  FCurrentKey := Key;
  UpdateDepthBar;

  // Animated content swap
  bodyHandle := FBody.Handle;
  surfHandle := Handle;

  if deeper then
    FBody.AddClass('zoom-exit-deep')
  else
    FBody.AddClass('zoom-exit-up');

  asm
    var bodyEl  = @bodyHandle;
    var surfEl  = @surfHandle;
    var newHTML = @html;
    var goDeep  = @deeper;

    setTimeout(function() {
      bodyEl.innerHTML = newHTML;
      bodyEl.classList.remove('zoom-exit-deep', 'zoom-exit-up');
      bodyEl.classList.add(goDeep ? 'zoom-enter-deep' : 'zoom-enter-up');
      surfEl.scrollTop = 0;

      setTimeout(function() {
        bodyEl.classList.remove('zoom-enter-deep', 'zoom-enter-up');
      }, 420);

    }, 280);
  end;
end;


// ── Private: shared level registration ───────────────────────────────────────

procedure TZoomSurface.RegisterLevel(const Key: String; Depth: Integer;
                                     const LType, Content: String);
var
  L: TZoomLevel;
begin
  if FindLevel(Key) >= 0 then exit;  // duplicate key — ignore

  L.Key       := Key;
  L.Depth     := Depth;
  L.LevelType := LType;
  L.Content   := Content;
  L.Widget    := nil;
  FLevels.Add(L);

  if Depth > FMaxDepth then
  begin
    FMaxDepth := Depth;
    if FCurrentKey <> '' then
      UpdateDepthBar;
  end;
end;


// ── Public API ───────────────────────────────────────────────────────────────

procedure TZoomSurface.SetProject(const Name, ID, Version: String);
var h: variant;
begin
  h := FTitleInput.Handle;
  asm (@h).value = @Name; end;
  FProjectId.SetText(ID);
  FVersionEl.SetText(Version);
end;

function TZoomSurface.ProjectName: String;
var h: variant;
begin
  h := FTitleInput.Handle;
  asm @Result = (@h).value; end;
end;

function TZoomSurface.CurrentKey: String;
begin
  Result := FCurrentKey;
end;

procedure TZoomSurface.AddLevel(const Key, HTML: String; Depth: Integer);
begin
  RegisterLevel(Key, Depth, szltHTML, HTML);
end;

procedure TZoomSurface.AddText(const Key, HTML: String; Depth: Integer);
begin
  RegisterLevel(Key, Depth, szltText, HTML);
end;

procedure TZoomSurface.AddCode(const Key, Code: String; Depth: Integer);
begin
  RegisterLevel(Key, Depth, szltCode, Code);
end;

procedure TZoomSurface.AddForm(const Key: String; Depth: Integer;
                               const Fields: array of TZoomField);
var
  L: TZoomLevel;
begin
  if FindLevel(Key) >= 0 then exit;  // duplicate key — ignore

  L.Key       := Key;
  L.Depth     := Depth;
  L.LevelType := szltForm;
  L.Content   := BuildFormHTML(Key, Fields);
  L.Widget    := nil;
  FLevels.Add(L);

  if Depth > FMaxDepth then
  begin
    FMaxDepth := Depth;
    if FCurrentKey <> '' then
      UpdateDepthBar;
  end;
end;

function TZoomSurface.AddWidget(const Key: String; Depth: Integer): TElement;
var
  L:       TZoomLevel;
  Slot:    TElement;
  existIdx: Integer;
begin
  existIdx := FindLevel(Key);
  if existIdx >= 0 then
  begin
    Result := FLevels[existIdx].Widget;
    exit;
  end;

  Slot := TElement.Create('div', FCard);
  Slot.AddClass('zoom-widget');
  Slot.SetStyle('display', 'none');

  L.Key       := Key;
  L.Depth     := Depth;
  L.LevelType := szltWidget;
  L.Content   := '';
  L.Widget    := Slot;
  FLevels.Add(L);

  if Depth > FMaxDepth then
  begin
    FMaxDepth := Depth;
    if FCurrentKey <> '' then
      UpdateDepthBar;
  end;

  Result := Slot;
end;

procedure TZoomSurface.AddValue(const Name: String);
var
  Zone: TElement;
begin
  Zone := TElement.Create('div', FValuesBar);
  Zone.AddClass(csZoomValZone);
  Zone.SetText(Name);
  FValueZones.Add(Zone);
end;


//=============================================================================
// JSON loading
//=============================================================================

procedure TZoomSurface.LoadFromObject(const Data: variant);
var
  i, j:         Integer;
  nodeCount:    Integer;
  fieldCount:   Integer;
  nodes:        variant;
  node:         variant;
  flds:         variant;
  fld:          variant;
  fArr:         array of TZoomField;
  f:            TZoomField;
  key:          String;
  ntype:        String;
  content:      String;
  depth:        Integer;
  hasProj:      Boolean;
  projname:     String;
  projid:       String;
  projver:      String;
  vcount:       Integer;
  vname:        String;
  vn:           variant;
  fname:        String;
  flabel:       String;
  ftype:        String;
  fplaceholder: String;
  foptions:     String;
  frequired:    Boolean;
begin
  // ── Project ───────────────────────────────────────────────────────────────
  asm @hasProj = !!((@Data).project); end;
  if hasProj then
  begin
    asm
      @projname = (@Data).project.name    || '';
      @projid   = (@Data).project.id      || '';
      @projver  = (@Data).project.version || '';
    end;
    SetProject(projname, projid, projver);
  end;

  // ── Values bar ────────────────────────────────────────────────────────────
  asm
    @vn     = (@Data).values || [];
    @vcount = (@vn).length;
  end;
  for i := 0 to vcount - 1 do
  begin
    asm @vname = @vn[@i]; end;
    AddValue(vname);
  end;

  // ── Nodes ─────────────────────────────────────────────────────────────────
  asm
    @nodes     = (@Data).nodes || [];
    @nodeCount = (@nodes).length;
  end;

  for i := 0 to nodeCount - 1 do
  begin
    asm
      var n  = @nodes;
      var ix = @i;
      @node  = n[ix];
    end;
    asm
      @key     = (@node).key     || '';
      @depth   = (@node).depth   || 0;
      @content = (@node).content || '';
      @ntype   = (@node).type    || 'html';
    end;

    if key = '' then continue;

    if ntype = szltText then
      AddText(key, content, depth)

    else if ntype = szltCode then
      AddCode(key, content, depth)

    else if ntype = szltForm then
    begin
      asm
        @flds       = (@node).fields || [];
        @fieldCount = (@flds).length;
      end;
      fArr.Clear;
      for j := 0 to fieldCount - 1 do
      begin
        asm
          var fa = @flds;
          var jx = @j;
          @fld = fa[jx];
        end;
        asm
          @fname        = (@fld).name        || '';
          @flabel       = (@fld).label       || '';
          @ftype        = (@fld).type        || 'text';
          @fplaceholder = (@fld).placeholder || '';
          @foptions     = (@fld).options     || '';
          @frequired    = !!(@fld).required;
        end;
        f.Name        := fname;
        f.Label_      := flabel;
        f.FieldType   := ftype;
        f.Placeholder := fplaceholder;
        f.Options     := foptions;
        f.Required    := frequired;
        fArr.Add(f);
      end;
      AddForm(key, depth, fArr);
    end

    // 'widget' nodes are silently skipped — they require live TElement refs
    else if ntype <> szltWidget then
      AddLevel(key, content, depth);
  end;
end;

procedure TZoomSurface.FetchAndLoad(const URL: String);
begin
  FetchJSON(URL,
    procedure(Data: variant)
    begin
      LoadFromObject(Data);
    end,
    procedure(Status: Integer; Msg: String)
    begin
      FBody.SetHTML('<p class="zoom-load-error">Could not load content' +
        ' (' + IntToStr(Status) + '\u2009\u2014\u2009' + HtmlEscape(Msg) + ').</p>');
      FBody.SetStyle('display', '');
    end);
end;


//=============================================================================
// Navigation
//=============================================================================

procedure TZoomSurface.ZoomTo(const Key: String);
begin
  ZoomToLabelled(Key, '');
end;

procedure TZoomSurface.ZoomToLabelled(const Key, Label: String);
var
  idx: Integer;
begin
  if IsAnimating then exit;

  idx := FindLevel(Key);
  if idx < 0 then exit;

  FNavStack.Add(Key);
  FNavLabels.Add(Label);
  RenderContent(Key, true);
  UpdateBreadcrumb;

  if assigned(FOnZoomChange) then
    FOnZoomChange(Self);
end;

procedure TZoomSurface.ZoomOut;
var
  prevKey: String;
begin
  if FNavStack.Count <= 1 then exit;
  if IsAnimating then exit;

  FNavStack.Delete(FNavStack.Count - 1);
  FNavLabels.Delete(FNavLabels.Count - 1);
  prevKey := FNavStack[FNavStack.Count - 1];

  RenderContent(prevKey, false);
  UpdateBreadcrumb;

  if assigned(FOnZoomChange) then
    FOnZoomChange(Self);
end;


//=============================================================================
// Reset — clear all content so the surface can be reloaded
//=============================================================================

procedure TZoomSurface.Reset;
begin
  ClearNavStack;
  FLevels.Clear;
  // Clear value zones: free the DOM children then empty the tracking array
  FValuesBar.Clear;
  FValueZones.Clear;
  FMaxDepth := 0;
  FBody.SetHTML('');
  FBody.SetStyle('display', '');
  UpdateDepthBar;
end;


//=============================================================================
// Values bar
//=============================================================================

procedure TZoomSurface.PulseValue(const Name: String);
var
  i: Integer;
  h: variant;
begin
  for i := 0 to FValueZones.Count - 1 do
    if UpperCase(FValueZones[i].GetText) = UpperCase(Name) then
    begin
      FValueZones[i].RemoveClass(csZoomValPulse);
      h := FValueZones[i].Handle;
      asm void (@h).offsetWidth; end;
      FValueZones[i].AddClass(csZoomValPulse);
      break;
    end;
end;


//=============================================================================
// State
//=============================================================================

function TZoomSurface.CurrentDepth: Integer;
begin
  Result := LevelDepth(FCurrentKey);
end;


initialization
  RegisterZoomStyles;

end.
