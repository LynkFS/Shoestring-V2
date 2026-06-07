unit JChart;

// =============================================================================
//
//  JChart  --  SVG chart widget for the ShoeString-V2 framework
//
//  Provides professional, theme-aware, animated SVG charts:
//
//    ctBar    Grouped bar chart  -- multiple series, grid, value labels
//    ctLine   Multi-series line  -- smooth Catmull-Rom curves + area fill
//    ctPie    Pie chart          -- series-per-slice with % labels
//    ctDonut  Donut ring chart   -- like pie with centre total label
//
//  Quick start:
//
//    var C := JW3Chart.Create(Parent);
//    C.ChartType := ctBar;
//    C.Title     := 'Quarterly Revenue';
//    C.Animated  := true;
//    C.SetCategories(['Q1','Q2','Q3','Q4']);
//
//    var S1 := C.NewSeries('Product A');
//    S1.AddValue(120); S1.AddValue(190);
//    S1.AddValue(300); S1.AddValue(500);
//
//    var S2 := C.NewSeries('Product B');
//    S2.AddValue(80);  S2.AddValue(150);
//    S2.AddValue(200); S2.AddValue(350);
//
//    C.Refresh;
//
//  For pie / donut each TJChartSeries represents one slice.
//  Only the first AddValue call matters (slice magnitude).
//
//    C.ChartType := ctDonut;
//    C.NewSeries('Apple').AddValue(42);
//    C.NewSeries('Mango').AddValue(28);
//    C.NewSeries('Berry').AddValue(30);
//    C.Refresh;
//
//  Call Refresh after any data or property change to re-render.
//
//  Theme integration
//
//    All colours reference the ShoeString CSS custom properties, so the
//    chart automatically adapts to light / dark mode and any theme swap.
//    Override per-chart by targeting the .jchart class or an ancestor:
//
//    --chart-bg            Chart background       default: transparent
//    --chart-title-color   Title text             default: var(--text-color)
//    --chart-text          Axis / label text      default: var(--text-light)
//    --chart-grid          Grid line colour       default: var(--border-color)
//
// =============================================================================

interface

uses JElement;

type

  // -- Chart type -------------------------------------------------------------

  TJChartType = (ctBar, ctLine, ctPie, ctDonut);

  // -- TJChartSeries ----------------------------------------------------------
  //
  //  Holds one series (for bar/line: a group of values per category;
  //  for pie/donut: a single slice value).
  //  Obtain instances via JW3Chart.NewSeries() -- do not construct directly.

  TJChartSeries = class
  private
    FName:   String;
    FColor:  String;
    FValues: array of Float;
  public
    constructor Create(const AName, AColor: String);
    procedure   AddValue(V: Float);
    function    Count:    Integer;
    function    Value(I:  Integer): Float;
    function    MaxValue: Float;
    function    Total:    Float;
    property Name:  String read FName;
    property Color: String read FColor write FColor;
  end;

  // -- JW3Chart ---------------------------------------------------------------

  JW3Chart = class(TElement)
  private
    FType:       TJChartType;
    FTitle:      String;
    FSubtitle:   String;
    FSeries:     array of TJChartSeries;
    FCategories: array of String;
    FShowLegend: Boolean;
    FShowGrid:   Boolean;
    FAnimated:   Boolean;

    // SVG builders
    function  BuildSVG:          String;
    function  SvgHeader(VW: Integer): String;
    function  SvgEmptyState(VW, VH: Integer): String;
    function  SvgAxesAndGrid(PX, PY, PW, PH: Integer; MaxV: Float): String;
    function  SvgBars(PX, PY, PW, PH: Integer; MaxV: Float):  String;
    function  SvgLines(PX, PY, PW, PH: Integer; MaxV: Float): String;
    function  SvgPie(CX, CY, R, IR: Float): String;
    function  SvgLegendRow(LY, VW: Integer): String;
    function  SvgLegendPie(LX, LY: Integer): String;

    // Helpers
    function  MaxAllSeries: Float;
    function  TotalAll:     Float;
    function  NiceMax(Raw:  Float): Float;

  public
    constructor Create(Parent: TElement); virtual;
    destructor  Destroy; override;

    function  NewSeries(const Name: String; Color: String = ''): TJChartSeries;
    procedure AddCategory(const Cat: String);
    procedure SetCategories(Cats: variant);
    procedure ClearData;
    procedure Refresh;

    property ChartType:  TJChartType read FType       write FType;
    property Title:      String      read FTitle       write FTitle;
    property Subtitle:   String      read FSubtitle    write FSubtitle;
    property ShowLegend: Boolean     read FShowLegend  write FShowLegend;
    property ShowGrid:   Boolean     read FShowGrid    write FShowGrid;
    property Animated:   Boolean     read FAnimated    write FAnimated;
  end;

procedure RegisterChartStyles;


implementation

uses Globals;

// =============================================================================
//  Module-level helpers  (no class context required)
// =============================================================================

function ChPI: Float;
var V: Float;
begin
  asm @V = Math.PI; end;
  Result := V;
end;

function ChSin(A: Float): Float;
var V: Float;
begin
  asm @V = Math.sin(@A); end; // Added @ to A
  Result := V;
end;

function ChCos(A: Float): Float;
var V: Float;
begin
  asm @V = Math.cos(@A); end; // Added @ to A
  Result := V;
end;

// Float -> tight SVG coordinate string (3 dp, trailing zeros stripped)
function N(V: Float): String;
var Tmp: String;
begin
  // Use @V to tell the compiler to use the correctly mangled JS variable name
  asm @Tmp = parseFloat((@V).toFixed(3)).toString(); end;
  Result := Tmp;
end;

// Human-readable value label  e.g. 1 234 567 -> "1.2M"
function FmtLabel(V: Float): String;
var Tmp: String;
begin
  asm
    if      (@V >= 1e6) @Tmp = parseFloat(((@V)/1e6).toFixed(1)) + 'M';
    else if (@V >= 1e3) @Tmp = parseFloat(((@V)/1e3).toFixed(1)) + 'K';
    else if (@V % 1 === 0) @Tmp = '' + parseInt(@V);
    else   @Tmp = parseFloat((@V).toFixed(2)).toString();
  end;
  Result := Tmp;
end;

// Float (0-1) -> percent string  e.g. 0.4286 -> "42.9%"
function FmtPct(V: Float): String;
var Tmp: String;
begin
  asm @Tmp = parseFloat((@V * 100).toFixed(1)) + '%'; end;
  Result := Tmp;
end;

// XML-escape for SVG text / title content
// Uses split/join to avoid regex literals which DWScript misparses
function XE(const S: String): String;
var Tmp: String;
begin
  Tmp := S;
  asm
    var v = @Tmp;
    v = v.split('&').join('&amp;');
    v = v.split('<').join('&lt;');
    v = v.split('>').join('&gt;');
    @Tmp = v;
  end;
  Result := Tmp;
end;

// -- Default oklch palette (8 perceptual colours matching ShoeString theme) ---

function PaletteColor(Idx: Integer): String;
begin
  case (Idx mod 8) of
    0: Result := 'oklch(55% 0.24 275)';   // violet  -- primary
    1: Result := 'oklch(55% 0.18 145)';   // green   -- success
    2: Result := 'oklch(57% 0.18 250)';   // blue    -- info
    3: Result := 'oklch(68% 0.18  75)';   // amber   -- warning
    4: Result := 'oklch(52% 0.22  25)';   // red     -- danger
    5: Result := 'oklch(55% 0.22 320)';   // magenta
    6: Result := 'oklch(60% 0.20 195)';   // teal
    else Result := 'oklch(62% 0.18 40)';  // orange
  end;
end;


// =============================================================================
//  CSS registration -- called once from initialization
// =============================================================================

var FRegistered: Boolean := false;

procedure RegisterChartStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* -- Container -------------------------------------------------------- */

    .jchart {
      display: block;
      position: relative;
      width: 100%;
      min-height: 220px;
      background: var(--chart-bg, transparent);
    }

    .jchart svg {
      display: block;
      width: 100%;
      height: 100%;
      overflow: visible;
    }

    /* -- Text classes ------------------------------------------------------ */

    .jc-title {
      fill: var(--chart-title-color, var(--text-color, #1c1b21));
      font-weight: 600;
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    }
    .jc-subtitle {
      fill: var(--chart-text, var(--text-light, #6b6a74));
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    }
    .jc-axislabel {
      fill: var(--chart-text, var(--text-light, #6b6a74));
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    }
    .jc-legend-text {
      fill: var(--chart-text, var(--text-light, #6b6a74));
      font-size: 11px;
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
      dominant-baseline: central;
    }
    .jc-pct-label {
      fill: #fff;
      font-size: 11px;
      font-weight: 600;
      text-anchor: middle;
      dominant-baseline: central;
      pointer-events: none;
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    }
    .jc-donut-label {
      fill: var(--text-color, #1c1b21);
      text-anchor: middle;
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    }

    /* -- Grid & axes ------------------------------------------------------- */

    .jc-axis-line {
      stroke: var(--chart-grid, var(--border-color, #dddde3));
      stroke-width: 1;
      fill: none;
    }
    .jc-grid-line {
      stroke: var(--chart-grid, var(--border-color, #dddde3));
      stroke-width: 0.5;
      stroke-dasharray: 4 3;
      fill: none;
    }

    /* -- Bar --------------------------------------------------------------- */

    .jc-bar {
      transform-box: fill-box;
      transform-origin: 50% 100%;
      transition: opacity 0.15s ease;
    }
    .jc-bar:hover  { opacity: 0.75; cursor: pointer; }

    @keyframes jcBarIn {
      from { transform: scaleY(0); opacity: 0.3; }
      to   { transform: scaleY(1); opacity: 1;   }
    }

    /* -- Line ------------------------------------------------------------- */

    .jc-line-path {
      stroke-dasharray: 8000;
      stroke-dashoffset: 8000;
      fill: none;
      stroke-linecap: round;
      stroke-linejoin: round;
    }

    @keyframes jcLineIn {
      to { stroke-dashoffset: 0; }
    }

    .jc-dot {
      transform-box: fill-box;
      transform-origin: 50% 50%;
      transition: r 0.15s ease;
    }
    .jc-dot:hover { r: 6px; cursor: pointer; }

    @keyframes jcDotIn {
      from { transform: scale(0); opacity: 0; }
      to   { transform: scale(1); opacity: 1; }
    }

    .jc-area-path { stroke: none; }

    @keyframes jcAreaIn {
      from { opacity: 0; }
      to   { opacity: 0.13; }
    }

    /* -- Pie / Donut ------------------------------------------------------- */

    .jc-slice {
      stroke: var(--surface-color, #ffffff);
      stroke-width: 2;
      transform-box: fill-box;
      transform-origin: 50% 50%;
      transition: opacity 0.15s ease, transform 0.2s var(--anim-ease, ease);
    }
    .jc-slice:hover {
      opacity: 0.82;
      transform: scale(1.04);
      cursor: pointer;
    }

    @keyframes jcSliceIn {
      from { opacity: 0; transform: scale(0.85) rotate(-4deg); }
      to   { opacity: 1; transform: scale(1)    rotate(0deg);  }
    }

    /* -- Legend fade ------------------------------------------------------- */

    .jc-legend-group { opacity: 0; }

    @keyframes jcFadeIn {
      to { opacity: 1; }
    }

  ');
end;


// =============================================================================
//  TJChartSeries
// =============================================================================

constructor TJChartSeries.Create(const AName, AColor: String);
begin
  inherited Create;
  FName   := AName;
  FColor  := AColor;
  FValues := [];
end;

procedure TJChartSeries.AddValue(V: Float);
begin
  FValues.Add(V);
end;

function TJChartSeries.Count: Integer;
begin
  Result := FValues.Count;
end;

function TJChartSeries.Value(I: Integer): Float;
begin
  if (I >= 0) and (I < FValues.Count) then
    Result := FValues[I]
  else
    Result := 0;
end;

function TJChartSeries.MaxValue: Float;
var M: Float; i: Integer;
begin
  M := 0;
  for i := 0 to FValues.Count - 1 do
    if FValues[i] > M then M := FValues[i];
  Result := M;
end;

function TJChartSeries.Total: Float;
var T: Float; i: Integer;
begin
  T := 0;
  for i := 0 to FValues.Count - 1 do
    T := T + FValues[i];
  Result := T;
end;


// =============================================================================
//  JW3Chart -- constructor / destructor / public API
// =============================================================================

constructor JW3Chart.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass('jchart');

  FType       := ctBar;
  FShowLegend := true;
  FShowGrid   := true;
  FAnimated   := true;
  FSeries     := [];
  FCategories := [];
  FTitle      := '';
  FSubtitle   := '';
end;

destructor JW3Chart.Destroy;
var i: Integer;
begin
  for i := 0 to FSeries.Count - 1 do
    FSeries[i].Free;
  inherited;
end;

function JW3Chart.NewSeries(const Name: String; Color: String = ''): TJChartSeries;
var C: String;
begin
  if Color <> '' then C := Color
  else C := PaletteColor(FSeries.Count);
  Result := TJChartSeries.Create(Name, C);
  FSeries.Add(Result);
end;

procedure JW3Chart.AddCategory(const Cat: String);
begin
  FCategories.Add(Cat);
end;

procedure JW3Chart.SetCategories(Cats: variant);
var
  i, Len: Integer;
  S: String;
begin
  FCategories := [];
  asm @Len = Cats.length; end;
  for i := 0 to Len - 1 do
  begin
    asm @S = '' + Cats[@i]; end;
    FCategories.Add(S);
  end;
end;

procedure JW3Chart.ClearData;
var i: Integer;
begin
  for i := 0 to FSeries.Count - 1 do
    FSeries[i].Free;
  FSeries     := [];
  FCategories := [];
end;

procedure JW3Chart.Refresh;
begin
  SetHTML(BuildSVG);
end;



// =============================================================================
//  Private helpers
// =============================================================================

function JW3Chart.MaxAllSeries: Float;
var M, V: Float; i, j: Integer;
begin
  M := 0;
  for i := 0 to FSeries.Count - 1 do
    for j := 0 to FSeries[i].Count - 1 do
    begin
      V := FSeries[i].Value(j);
      if V > M then M := V;
    end;
  Result := M;
end;

function JW3Chart.TotalAll: Float;
var T: Float; i: Integer;
begin
  T := 0;
  for i := 0 to FSeries.Count - 1 do
    T := T + FSeries[i].Total;
  Result := T;
end;

// Round up to a "nice" axis maximum
function JW3Chart.NiceMax(Raw: Float): Float;
var V: Float;
begin
  if Raw <= 0 then begin Result := 10; exit; end;
  asm
    var mag  = Math.pow(10, Math.floor(Math.log10(Raw)));
    var norm = Raw / mag;
    var step;
    if      (norm <= 1)  step = 0.1 * mag;
    else if (norm <= 2)  step = 0.2 * mag;
    else if (norm <= 5)  step = 0.5 * mag;
    else                 step = mag;
    @V = Math.ceil(Raw / step) * step;
  end;
  Result := V;
end;
// Round up to a "nice" axis maximum

// =============================================================================
//  BuildSVG -- top-level dispatcher
//  Viewbox is always 600 x 400.  SVG scales to 100% of the container.
// =============================================================================

function JW3Chart.BuildSVG: String;
var
  S:                String;
  MaxV:             Float;
  PX, PY, PW, PH:  Integer;
  CX, CY, R, IR:   Float;
begin
  if FSeries.Count = 0 then
  begin
    Result := SvgEmptyState(600, 400);
    exit;
  end;

  S :=
    '<svg viewBox="0 0 600 400" xmlns="http://www.w3.org/2000/svg"' +
    ' preserveAspectRatio="xMidYMid meet"' +
    ' style="overflow:visible;width:100%;height:100%">';

  S := S + SvgHeader(600);

  case FType of

    ctBar, ctLine:
    begin
      // Plot area: l=60 t=52 w=510 h=260  (leaves 28 px bottom for legend)
      PX := 60;  PY := 52;
      PW := 510; PH := 260;

      MaxV := NiceMax(MaxAllSeries);
      if MaxV <= 0 then MaxV := 10;

      S := S + SvgAxesAndGrid(PX, PY, PW, PH, MaxV);

      if FType = ctBar then
        S := S + SvgBars(PX, PY, PW, PH, MaxV)
      else
        S := S + SvgLines(PX, PY, PW, PH, MaxV);

      if FShowLegend then
        S := S + SvgLegendRow(384, 600);
    end;

    ctPie, ctDonut:
    begin
      if TotalAll > 0 then
      begin
        if FShowLegend then
        begin
          CX := 205; CY := 190; R := 118;
        end else begin
          CX := 300; CY := 200; R := 130;
        end;

        if FType = ctDonut then IR := R * 0.50
        else IR := 0;

        S := S + SvgPie(CX, CY, R, IR);

        if FShowLegend then
          S := S + SvgLegendPie(345, 82);
      end;
    end;

  end;

  S      := S + '</svg>';
  Result := S;
end;


// =============================================================================
//  Shared SVG fragments
// =============================================================================

function JW3Chart.SvgHeader(VW: Integer): String;
var CX: Integer; S: String;
begin
  if (FTitle = '') and (FSubtitle = '') then begin Result := ''; exit; end;
  CX := VW div 2;
  S  := '';
  if FTitle <> '' then
    S := S +
      '<text x="' + IntToStr(CX) + '" y="22" text-anchor="middle"' +
      ' class="jc-title" style="font-size:15px">' + XE(FTitle) + '</text>';
  if FSubtitle <> '' then
    S := S +
      '<text x="' + IntToStr(CX) + '" y="39" text-anchor="middle"' +
      ' class="jc-subtitle" style="font-size:11px">' + XE(FSubtitle) + '</text>';
  Result := S;
end;

function JW3Chart.SvgEmptyState(VW, VH: Integer): String;
var CX, CY: Integer;
begin
  CX := VW div 2;
  CY := VH div 2;
  Result :=
    '<svg viewBox="0 0 ' + IntToStr(VW) + ' ' + IntToStr(VH) + '"' +
    ' xmlns="http://www.w3.org/2000/svg" style="width:100%;height:100%">' +
    '<rect width="' + IntToStr(VW) + '" height="' + IntToStr(VH) + '" rx="8"' +
    ' style="fill:var(--surface-3,#eeeef2)"/>' +
    '<text x="' + IntToStr(CX) + '" y="' + IntToStr(CY - 8) + '"' +
    ' text-anchor="middle" class="jc-subtitle" style="font-size:13px">No data</text>' +
    '<text x="' + IntToStr(CX) + '" y="' + IntToStr(CY + 12) + '"' +
    ' text-anchor="middle" class="jc-subtitle" style="font-size:10px">' +
    'Call NewSeries() then Refresh()</text></svg>';
end;

function JW3Chart.SvgAxesAndGrid(PX, PY, PW, PH: Integer; MaxV: Float): String;
const GridSteps = 5;
var
  S:     String;
  i:     Integer;
  GY:    Float;
  LblV:  Float;
  CatX:  Float;
  nCats: Integer;
begin
  S     := '';
  nCats := FCategories.Count;
  if nCats = 0 then nCats := 1;

  for i := 0 to GridSteps do
  begin
    GY   := PY + PH - (i / GridSteps) * PH;
    LblV := MaxV * (i / GridSteps);

    if FShowGrid and (i > 0) then
      S := S +
        '<line x1="' + N(PX)      + '" y1="' + N(GY) + '"' +
        ' x2="' + N(PX + PW) + '" y2="' + N(GY) + '"' +
        ' class="jc-grid-line"/>';

    S := S +
      '<text x="' + N(PX - 6) + '" y="' + N(GY) + '"' +
      ' text-anchor="end" dominant-baseline="central"' +
      ' class="jc-axislabel" style="font-size:10px">' +
      XE(FmtLabel(LblV)) + '</text>';
  end;

  // Bottom axis
  S := S +
    '<line x1="' + N(PX) + '" y1="' + N(PY + PH) + '"' +
    ' x2="' + N(PX + PW) + '" y2="' + N(PY + PH) + '"' +
    ' class="jc-axis-line"/>';

  // Left axis
  S := S +
    '<line x1="' + N(PX) + '" y1="' + N(PY) + '"' +
    ' x2="' + N(PX) + '" y2="' + N(PY + PH) + '"' +
    ' class="jc-axis-line"/>';

  // Category labels
  for i := 0 to FCategories.Count - 1 do
  begin
    CatX := PX + (i + 0.5) * (PW / nCats);
    S    := S +
      '<text x="' + N(CatX) + '" y="' + N(PY + PH + 18) + '"' +
      ' text-anchor="middle" class="jc-axislabel" style="font-size:10px">' +
      XE(FCategories[i]) + '</text>';
  end;

  Result := S;
end;


// =============================================================================
//  Bar chart
// =============================================================================

function JW3Chart.SvgBars(PX, PY, PW, PH: Integer; MaxV: Float): String;
var
  S:               String;
  nCats, nSeries:  Integer;
  groupW, barW:    Float;
  bx, by, bh:      Float;
  i, j:            Integer;
  animDelay:       Float;
  pctUsed:         Float;
begin
  S       := '';
  nCats   := FCategories.Count;
  nSeries := FSeries.Count;
  if nCats   = 0 then nCats   := 1;
  if nSeries = 0 then begin Result := ''; exit; end;
  if MaxV   <= 0 then begin Result := ''; exit; end;

  pctUsed := 0.72;
  groupW  := PW / nCats;
  barW    := (groupW * pctUsed) / nSeries;

  for i := 0 to nCats - 1 do
  begin
    for j := 0 to nSeries - 1 do
    begin
      if i >= FSeries[j].Count then continue;

      bh := (FSeries[j].Value(i) / MaxV) * PH;
      if bh <= 0 then continue;

      bx := PX + i * groupW + groupW * ((1 - pctUsed) / 2) + j * barW;
      by := PY + PH - bh;

      animDelay := (i * nSeries + j) * 0.04;

      S := S +
        '<rect class="jc-bar" x="' + N(bx) + '" y="' + N(by) + '"' +
        ' width="' + N(barW - 1.5) + '" height="' + N(bh) + '" rx="3"' +
        ' style="fill:' + FSeries[j].Color;

      if FAnimated then
        S := S + '; animation:jcBarIn 0.5s cubic-bezier(0.34,1.56,0.64,1) ' +
                 N(animDelay) + 's both';
      S := S + '">' +
        '<title>' + XE(FSeries[j].Name) + ': ' +
        XE(FmtLabel(FSeries[j].Value(i))) + '</title></rect>';

      // Value label above bar (only when tall enough)
      if bh > 20 then
        S := S +
          '<text x="' + N(bx + (barW - 1.5) / 2) + '" y="' + N(by - 4) + '"' +
          ' text-anchor="middle" class="jc-axislabel"' +
          ' style="font-size:9px;fill:' + FSeries[j].Color + '">' +
          XE(FmtLabel(FSeries[j].Value(i))) + '</text>';
    end;
  end;

  Result := S;
end;


// =============================================================================
//  Line chart -- smooth Catmull-Rom bezier curves
// =============================================================================

function JW3Chart.SvgLines(PX, PY, PW, PH: Integer; MaxV: Float): String;
var
  S:                          String;
  nCats, j, i:                Integer;
  xs, ys:                     array of Float;
  pathD, areaD:               String;
  pm1, pi1, pi2:              Integer;
  cp1x, cp1y, cp2x, cp2y:    Float;
  dotDelay:                   Float;
  xc, yc:                     Float;
begin
  S     := '';
  nCats := FCategories.Count;
  if nCats = 0 then nCats := 1;
  if (FSeries.Count = 0) or (MaxV <= 0) then begin Result := ''; exit; end;

  for j := 0 to FSeries.Count - 1 do
  begin
    if FSeries[j].Count = 0 then continue;

    // -- Plot coordinates ---------------------------------------------------
    xs := [];
    ys := [];
    for i := 0 to nCats - 1 do
    begin
      if nCats > 1 then
        xc := PX + i * (PW / (nCats - 1))
      else
        xc := PX + PW / 2;

      yc := PY + PH - (FSeries[j].Value(i) / MaxV) * PH;
      if yc < PY      then yc := PY;
      if yc > PY + PH then yc := PY + PH;
      xs.Add(xc);
      ys.Add(yc);
    end;

    // -- Catmull-Rom smooth path --------------------------------------------
    pathD := 'M ' + N(xs[0]) + ',' + N(ys[0]);
    for i := 0 to nCats - 2 do
    begin
      if i > 0 then pm1 := i - 1 else pm1 := 0;
      pi1 := i + 1;
      if i + 2 < nCats then pi2 := i + 2 else pi2 := nCats - 1;

      cp1x := xs[i]   + (xs[pi1] - xs[pm1]) / 6;
      cp1y := ys[i]   + (ys[pi1] - ys[pm1]) / 6;
      cp2x := xs[pi1] - (xs[pi2] - xs[i])   / 6;
      cp2y := ys[pi1] - (ys[pi2] - ys[i])   / 6;

      pathD := pathD +
        ' C ' + N(cp1x) + ',' + N(cp1y) + ' ' +
                N(cp2x) + ',' + N(cp2y) + ' ' +
                N(xs[pi1]) + ',' + N(ys[pi1]);
    end;

    // -- Area fill ----------------------------------------------------------
    areaD := pathD +
      ' L ' + N(xs[nCats-1]) + ',' + N(PY + PH) +
      ' L ' + N(xs[0])       + ',' + N(PY + PH) + ' Z';

    S := S +
      '<path d="' + areaD + '" class="jc-area-path"' +
      ' style="fill:' + FSeries[j].Color;
    if FAnimated then
      S := S + '; animation:jcAreaIn 0.8s ease ' + N(j * 0.12) + 's both'
    else
      S := S + '; opacity:0.13';
    S := S + '"/>';

    // -- Line stroke --------------------------------------------------------
    S := S +
      '<path d="' + pathD + '" class="jc-line-path"' +
      ' stroke="' + FSeries[j].Color + '" stroke-width="2.5"';
    if FAnimated then
      S := S +
        ' style="animation:jcLineIn 0.9s cubic-bezier(0.4,0,0.2,1) ' +
        N(j * 0.12) + 's both"';
    S := S + '/>';

    // -- Data-point dots ----------------------------------------------------
    for i := 0 to nCats - 1 do
    begin
      dotDelay := j * 0.12 + i * 0.04 + 0.75;
      S := S +
        '<circle cx="' + N(xs[i]) + '" cy="' + N(ys[i]) + '" r="4"' +
        ' class="jc-dot" fill="' + FSeries[j].Color + '"' +
        ' stroke="var(--surface-color,#fff)" stroke-width="2"';
      if FAnimated then
        S := S + ' style="animation:jcDotIn 0.3s ease ' + N(dotDelay) + 's both"';
      S := S + '><title>' +
        XE(FSeries[j].Name) + ': ' + XE(FmtLabel(FSeries[j].Value(i)));
      if i < FCategories.Count then
        S := S + ' (' + XE(FCategories[i]) + ')';
      S := S + '</title></circle>';
    end;
  end;

  Result := S;
end;


// =============================================================================
//  Pie / Donut chart
// =============================================================================

function JW3Chart.SvgPie(CX, CY, R, IR: Float): String;
var
  S:                      String;
  Total:                  Float;
  StartAngle, EndAngle:   Float;
  i:                      Integer;
  pct, Angle:             Float;
  x1, y1, x2, y2:        Float;
  ix1, iy1, ix2, iy2:    Float;
  largeArc:               Integer;
  pathD:                  String;
  midAngle, labelR:       Float;
  labelX, labelY:         Float;
  animStyle:              String;
  sliceVal:               Float;
begin
  S     := '';
  Total := TotalAll;
  if Total <= 0 then begin Result := ''; exit; end;

  StartAngle := -(ChPI / 2);  // 12 o'clock start

  for i := 0 to FSeries.Count - 1 do
  begin
    if FSeries[i].Count = 0 then continue;
    sliceVal := FSeries[i].Value(0);
    if sliceVal <= 0 then continue;

    pct   := sliceVal / Total;
    Angle := pct * 2 * ChPI;

    EndAngle  := StartAngle + Angle;
    animStyle := '';

    if FAnimated then
      animStyle :=
        'animation:jcSliceIn 0.55s cubic-bezier(0.34,1.56,0.64,1) ' +
        N(i * 0.07) + 's both';

    // -- Full circle (single series) ----------------------------------------
    if pct >= 0.9999 then
    begin
      S := S +
        '<circle cx="' + N(CX) + '" cy="' + N(CY) + '" r="' + N(R) + '"' +
        ' class="jc-slice" style="fill:' + FSeries[i].Color + '; ' + animStyle + '"/>';
      if IR > 0 then
        S := S +
          '<circle cx="' + N(CX) + '" cy="' + N(CY) + '" r="' + N(IR) + '"' +
          ' style="fill:var(--surface-color,#fff);stroke:none"/>';
      StartAngle := EndAngle;
      continue;
    end;

    x1 := CX + R * ChCos(StartAngle);  y1 := CY + R * ChSin(StartAngle);
    x2 := CX + R * ChCos(EndAngle);    y2 := CY + R * ChSin(EndAngle);
    if Angle > ChPI then largeArc := 1 else largeArc := 0;

    if IR > 0 then
    begin
      ix1 := CX + IR * ChCos(EndAngle);   iy1 := CY + IR * ChSin(EndAngle);
      ix2 := CX + IR * ChCos(StartAngle); iy2 := CY + IR * ChSin(StartAngle);
      pathD :=
        'M '  + N(x1)  + ',' + N(y1)  +
        ' A ' + N(R)   + ',' + N(R)   + ' 0 ' + IntToStr(largeArc) + ' 1 ' +
                N(x2)  + ',' + N(y2)  +
        ' L ' + N(ix1) + ',' + N(iy1) +
        ' A ' + N(IR)  + ',' + N(IR)  + ' 0 ' + IntToStr(largeArc) + ' 0 ' +
                N(ix2) + ',' + N(iy2) + ' Z';
    end else begin
      pathD :=
        'M '  + N(CX) + ',' + N(CY) +
        ' L ' + N(x1) + ',' + N(y1) +
        ' A ' + N(R)  + ',' + N(R)  + ' 0 ' + IntToStr(largeArc) + ' 1 ' +
                N(x2) + ',' + N(y2) + ' Z';
    end;

    S := S +
      '<path d="' + pathD + '" class="jc-slice"' +
      ' style="fill:' + FSeries[i].Color + '; ' + animStyle + '">' +
      '<title>' + XE(FSeries[i].Name) + ': ' +
      XE(FmtLabel(sliceVal)) + ' (' + FmtPct(pct) + ')' +
      '</title></path>';

    // -- Percentage label inside slice --------------------------------------
    if pct >= 0.06 then
    begin
      midAngle := StartAngle + Angle * 0.5;
      if IR > 0 then labelR := (R + IR) * 0.5
      else            labelR := R * 0.62;
      labelX := CX + labelR * ChCos(midAngle);
      labelY := CY + labelR * ChSin(midAngle);
      S := S +
        '<text x="' + N(labelX) + '" y="' + N(labelY) + '"' +
        ' class="jc-pct-label" style="font-size:';
      if pct >= 0.15 then S := S + '11' else S := S + '9';
      S := S + 'px">' + FmtPct(pct) + '</text>';
    end;

    StartAngle := EndAngle;
  end;

  // -- Donut: punched hole + centre label ------------------------------------
  if IR > 0 then
  begin
    S := S +
      '<circle cx="' + N(CX) + '" cy="' + N(CY) + '" r="' + N(IR - 1) + '"' +
      ' style="fill:var(--surface-color,#fff);stroke:none;pointer-events:none"/>' +
      '<text x="' + N(CX) + '" y="' + N(CY - 9) + '"' +
      ' class="jc-donut-label" style="font-size:20px;font-weight:700">' +
      XE(FmtLabel(TotalAll)) + '</text>' +
      '<text x="' + N(CX) + '" y="' + N(CY + 12) + '"' +
      ' class="jc-donut-label" style="font-size:10px">Total</text>';
  end;

  Result := S;
end;


// =============================================================================
//  Legends
// =============================================================================

// Horizontal legend row centred under bar / line charts
function JW3Chart.SvgLegendRow(LY, VW: Integer): String;
var
  S:          String;
  itemW:      Float;
  totalW:     Float;
  startX:     Float;
  i:          Integer;
  ix:         Float;
  animAttr:   String;
begin
  if FSeries.Count = 0 then begin Result := ''; exit; end;

  itemW  := 110;
  totalW := FSeries.Count * itemW;
  if totalW > VW - 24 then totalW := VW - 24;
  startX := (VW - totalW) / 2;

  animAttr := '';
  if FAnimated then
    animAttr := ' class="jc-legend-group"' +
                ' style="animation:jcFadeIn 0.4s ease 0.85s both"';

  S := '<g' + animAttr + '>';

  for i := 0 to FSeries.Count - 1 do
  begin
    ix := startX + i * (totalW / FSeries.Count);
    S  := S +
      '<rect x="' + N(ix) + '" y="' + N(LY - 6) + '"' +
      ' width="13" height="13" rx="3"' +
      ' style="fill:' + FSeries[i].Color + '"/>' +
      '<text x="' + N(ix + 18) + '" y="' + N(LY + 1) + '"' +
      ' class="jc-legend-text">' + XE(FSeries[i].Name) + '</text>';
  end;

  S := S + '</g>';
  Result := S;
end;

// Vertical legend column right of pie / donut charts
function JW3Chart.SvgLegendPie(LX, LY: Integer): String;
var
  S:         String;
  i:         Integer;
  iy:        Float;
  Total:     Float;
  pct:       Float;
  animAttr:  String;
begin
  if FSeries.Count = 0 then begin Result := ''; exit; end;

  Total    := TotalAll;
  animAttr := '';
  if FAnimated then
    animAttr := ' class="jc-legend-group"' +
                ' style="animation:jcFadeIn 0.4s ease 0.85s both"';

  S := '<g' + animAttr + '>';

  for i := 0 to FSeries.Count - 1 do
  begin
    iy := LY + i * 26;

    S := S +
      '<circle cx="' + N(LX + 7) + '" cy="' + N(iy) + '" r="7"' +
      ' style="fill:' + FSeries[i].Color + '"/>' +
      '<text x="' + N(LX + 20) + '" y="' + N(iy) + '"' +
      ' class="jc-legend-text">' + XE(FSeries[i].Name) + '</text>';

    if (Total > 0) and (FSeries[i].Count > 0) then
    begin
      pct := FSeries[i].Value(0) / Total;
      S   := S +
        '<text x="590" y="' + N(iy) + '"' +
        ' text-anchor="end" class="jc-legend-text"' +
        ' style="font-weight:500">' + FmtPct(pct) + '</text>';
    end;
  end;

  S := S + '</g>';
  Result := S;
end;


initialization
  RegisterChartStyles;
end.


/*
It is a solid piece of work. For a Pascal-to-JS framework like Shoestring-V2, building the SVG server-side (or in this case, "Pascal-logic-side") and injecting it is often much more performant than trying to manage hundreds of individual DOM elements.Here are a few "architectural" observations and potential refinements to consider as you move from "compiles okay" to "production-ready":1. The "Fixed Viewbox" TrapYou are currently using a hardcoded viewBox="0 0 600 400".The Good: The chart scales perfectly like an image.The Risk: If the container is very wide and short (e.g., a dashboard strip), the text will scale up and look gargantuan, or the chart will have massive pillar-boxing.The Fix: Consider making the height/width ratio a property or dynamically calculating the viewBox based on the Element.ClientWidth.2. Legend CollisionIn SvgLegendRow, you have itemW := 110.If a user has 10 series with long names ("Quarterly Projected Revenue 2024"), the labels will overlap or run off the 600px stage.Wise Thought: In the SVG world, text width is notoriously hard to calculate without a live DOM getBBox() call. You might want to implement a simple "truncate" helper in your XE function or switch to a vertical legend if FSeries.Count > 5.3. Catmull-Rom ComplexityYour SvgLines implementation is quite sophisticated for a "quick widget." Using Catmull-Rom for smoothing makes the data look professional.Note on Math: Your tension is fixed at $1/6$. While it looks great for general data, it can occasionally produce "overshoot" (where the line dips below 0 even if all data points are positive).Constraint: If accuracy is more important than "curviness" for your specific use case, you might want a Smooth: Boolean property to toggle between the Catmull-Rom and simple L (LineTo) commands.4. Interactive EventsCurrently, you have CSS hover effects (.jc-bar:hover), but the Pascal code has no way of knowing which bar was clicked.The Shoestring Way: You could add a data attribute to your SVG elements:DelphiS := S + ' data-series="' + IntToStr(j) + '" data-index="' + IntToStr(i) + '"';
Then, in your JW3Chart constructor, you can hook a single click listener to the container and use event.target.dataset to fire a Pascal event like OnDataClick(SeriesIndex, ValIndex).5. String Building vs. PerformanceYou are doing a lot of string concatenation (S := S + ...).In the JavaScript world, this is actually very fast now (engines optimize it), so don't feel pressured to use a TStringBuilder unless you're rendering thousands of points.However, if you plan on animating updates (e.g., data points sliding from one value to another), SetHTML will destroy the old SVG and create a new one, breaking any CSS transitions. If "live" movement is a future goal, you'll eventually need to target specific <rect> IDs and update their y and height attributes directly.6. Axis "Niceness"Your NiceMax function is clever. One edge case: If all your values are 0.001 and 0.002, Math.floor(Math.log10(Raw)) will handle it, but your FmtLabel might round them both to "0".Thought: You might want to pass the calculated "step" size into FmtLabel so it knows how many decimal places are actually significant for that specific chart.Minor Code Clean-upIn your Destroy, you are looping through FSeries to free them. Since you are using a Pascal-to-JS compiler, check if your framework's array of TObject handles its own memory. In many JS-transpiled dialects, the garbage collector handles the objects, and explicitly calling Free in a loop can occasionally lead to double-free errors if the array itself is managed. (Though for standard DWS compatibility, what you have is the "correct" Pascal way).One last tiny thing: In SvgBars, you have if bh <= 0 then continue;. This means zero-value bars simply don't exist in the DOM. This makes them impossible to hover over or see a tooltip for. Providing a "minimum height" of 1 or 2 pixels often helps the UI feel more responsive.How is the performance looking on mobile browsers? That's usually where the CSS animations show their true colors.
*/