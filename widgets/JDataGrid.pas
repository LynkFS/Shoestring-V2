unit JDataGrid;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3DataGrid — Simple Data Grid
//
//  All rows live in the DOM. The browser handles scrolling natively.
//  No sentinel, no row map, no virtual viewport — just a real <table>.
//
//  Features:
//    Column definitions with optional width, alignment, sortable, editable
//    Header click sort (asc / desc / clear)
//    Row selection with OnSelectRow event
//    Cell-level focus with arrow/tab keyboard navigation
//    Column resize via drag handle on header edge
//    Inline cell editing (double-click or F2), OnCellEdit event
//    Ctrl+C / Cmd+C copies focused cell
//    ARIA roles for accessibility
//    Event delegation — one listener per event type, not per cell
//
//  Remaining asm blocks (5):
//    - SafeStr helper (JS undefined/null check)
//    - Sort comparator (inline function with typeof/localeCompare)
//    - Dynamic field read on data objects (3x bracket notation)
//    - navigator.clipboard API
//    - setTimeout in edit blur handler
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, Types;

const
  csDataGrid       = 'datagrid';
  csDgHeaderWrap   = 'dg-header-wrap';
  csDgBodyWrap     = 'dg-body-wrap';
  csDgTable        = 'dg-table';
  csDgTh           = 'dg-th';
  csDgRow          = 'dg-row';
  csDgTd           = 'dg-td';
  csDgRowSelected  = 'dg-row-selected';
  csDgCellFocused  = 'dg-cell-focused';
  csDgSortAsc      = 'dg-sort-asc';
  csDgSortDesc     = 'dg-sort-desc';
  csDgResizeHandle = 'dg-resize-handle';
  csDgEditing      = 'dg-editing';

type
  TGridSortDir = (sdNone, sdAsc, sdDesc);

  TGridColumn = record
    Field:    String;
    Caption:  String;
    Width:    Integer;
    MinWidth: Integer;
    Align:    String;
    Sortable: Boolean;
    Editable: Boolean;
  end;

  TGridSelectRowEvent = procedure(Sender: TObject; RowIndex: Integer;
    RowData: variant);

  TGridCellEditEvent = procedure(Sender: TObject; DataIndex: Integer;
    const Field: String; OldValue, NewValue: variant);

  JW3DataGrid = class(TElement)
  private
    FColumns:     array of TGridColumn;
    FData:        array of variant;
    FView:        array of Integer;
    FSortCol:     Integer;
    FSortDir:     TGridSortDir;

    FSelectedRow: Integer;
    FFocusRow:    Integer;
    FFocusCol:    Integer;
    FRowHeight:   Integer;

    FHeaderWrap:  variant;
    FBodyWrap:    variant;
    FHeaderTable: variant;
    FBodyTable:   variant;
    FTHead:       variant;
    FTBody:       variant;

    FEditing:     Boolean;
    FEditInput:   variant;
    FEditViewRow: Integer;
    FEditCol:     Integer;

    FResizing:    Boolean;
    FResizeCol:   Integer;
    FResizeStartX: Integer;
    FResizeStartW: Integer;

    FOnSelectRow: TGridSelectRowEvent;
    FOnCellEdit:  TGridCellEditEvent;

    procedure BuildStructure;
    procedure BuildColGroup(Table: variant);
    procedure RenderHeader;
    procedure RenderBody;

    procedure HandleHeaderClick(ColIndex: Integer);
    procedure ApplySort(ColIndex: Integer);
    procedure SortView;
    procedure ClearSort;
    procedure UpdateSortIndicators;

    procedure SelectRow(ViewIdx: Integer);
    procedure FocusCellDOM;
    procedure ClearCellFocusDOM;
    function  GetRowElement(ViewIdx: Integer): variant;
    function  GetCellElement(ViewIdx, ColIdx: Integer): variant;
    function  GetHeaderCell(ColIdx: Integer): variant;
    procedure ScrollToRow(ViewIdx: Integer);

    procedure HandleCellClick(ViewIdx, ColIdx: Integer);
    procedure HandleCellDblClick(ViewIdx, ColIdx: Integer);
    procedure BeginEdit(ViewIdx, ColIdx: Integer);
    procedure CommitEdit;
    procedure CancelEdit;

    procedure BeginResize(ColIdx, ScreenX: Integer);
    procedure DoResize(ScreenX: Integer);
    procedure EndResize;

    procedure HandleKeyDown(EventObj: JEvent);
    procedure CopyFocusedCell;

  public
    constructor Create(Parent: TElement); virtual;

    procedure AddColumn(const Field, Caption: String;
      Width: Integer = 0; Align: String = 'left';
      Sortable: Boolean = true; Editable: Boolean = false);

    procedure SetData(const Data: array of variant);
    procedure Refresh;
    function  RowCount: Integer;
    function  GetRowData(ViewIdx: Integer): variant;

    property RowHeight: Integer read FRowHeight write FRowHeight;
    property SelectedRow: Integer read FSelectedRow;
    property OnSelectRow: TGridSelectRowEvent read FOnSelectRow write FOnSelectRow;
    property OnCellEdit: TGridCellEditEvent read FOnCellEdit write FOnCellEdit;
  end;

procedure RegisterDataGridStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;


// ─── Helper: variant to String (handles JS undefined / null) ─────────────

function SafeStr(v: variant): String;
begin
  asm @Result = ((@v) !== undefined && (@v) !== null) ? String(@v) : ''; end;
end;


// ═════════════════════════════════════════════════════════════════════════
// Constructor
// ═════════════════════════════════════════════════════════════════════════

constructor JW3DataGrid.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csDataGrid);
  SetAttribute('role', 'grid');
  SetAttribute('tabindex', '0');

  FSortCol     := -1;
  FSortDir     := sdNone;
  FFocusRow    := -1;
  FFocusCol    := -1;
  FSelectedRow := -1;
  FRowHeight   := 40;
  FEditing     := false;
  FResizing    := false;

  BuildStructure;

  Handle.addEventListener('keydown', @HandleKeyDown, false);
end;


// ═════════════════════════════════════════════════════════════════════════
// DOM structure + event delegation
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.BuildStructure;
var
  el: variant;
  hdiv, htbl, thead: variant;
  bdiv, btbl, tbody: variant;
begin
  el := Self.Handle;

  // Header
  hdiv := document.createElement('div');
  hdiv.className := 'dg-header-wrap';
  hdiv.style.display := 'block';
  el.appendChild(hdiv);
  FHeaderWrap := hdiv;

  htbl := document.createElement('table');
  htbl.className := 'dg-table';
  hdiv.appendChild(htbl);
  FHeaderTable := htbl;

  thead := document.createElement('thead');
  htbl.appendChild(thead);
  FTHead := thead;

  // Body
  bdiv := document.createElement('div');
  bdiv.className := 'dg-body-wrap';
  bdiv.style.display := 'block';
  bdiv.style.flexGrow := '1';
  bdiv.style.overflowY := 'auto';
  el.appendChild(bdiv);
  FBodyWrap := bdiv;

  btbl := document.createElement('table');
  btbl.className := 'dg-table';
  bdiv.appendChild(btbl);
  FBodyTable := btbl;

  tbody := document.createElement('tbody');
  btbl.appendChild(tbody);
  FTBody := tbody;

  // ── Event delegation ─────────────────────────────────────────────
  // All using Pascal anonymous procedures + variant event properties.
  // These survive re-renders because listeners are on persistent
  // parent elements, not on individual cells.

  // Header: sort click (skip resize handles)
  thead.onclick := procedure(e: variant)
  begin
    var b: boolean := e.target.classList.contains('dg-resize-handle');
    if b = true then exit;
    HandleHeaderClick(e.target.cellIndex);
  end;

  // Header: resize handle mousedown
  thead.onmousedown := procedure(e: variant)
  begin
    var b: boolean := e.target.classList.contains('dg-resize-handle');
    if b = false then exit;
    e.preventDefault;
    e.stopPropagation;
    BeginResize(e.target.parentElement.cellIndex, e.clientX);
  end;

  // Body: cell click
  tbody.onclick := procedure(e: variant)
  begin
    var editing := e.target.closest('.dg-editing');
    if editing <> nil then exit;
    var td := e.target.closest('.dg-td');
    if td = nil then exit;
    var tr := td.parentElement;
    HandleCellClick(tr.sectionRowIndex, td.cellIndex);
  end;

  // Body: cell double-click
  tbody.ondblclick := procedure(e: variant)
  begin
    var editing := e.target.closest('.dg-editing');
    if editing <> nil then exit;
    var td := e.target.closest('.dg-td');
    if td = nil then exit;
    var tr := td.parentElement;
    HandleCellDblClick(tr.sectionRowIndex, td.cellIndex);
  end;

  // Scroll sync: header follows body horizontal scroll
  bdiv.onscroll := procedure
  begin
    FHeaderWrap.scrollLeft := bdiv.scrollLeft;
  end;
end;


// ═════════════════════════════════════════════════════════════════════════
// AddColumn
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.AddColumn(const Field, Caption: String;
  Width: Integer = 0; Align: String = 'left';
  Sortable: Boolean = true; Editable: Boolean = false);
var
  Col: TGridColumn;
begin
  Col.Field    := Field;
  Col.Caption  := Caption;
  Col.Width    := Width;
  Col.MinWidth := 50;
  Col.Align    := Align;
  Col.Sortable := Sortable;
  Col.Editable := Editable;
  FColumns.Add(Col);
end;


// ═════════════════════════════════════════════════════════════════════════
// ColGroup
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.BuildColGroup(Table: variant);
begin
  var old := Table.querySelector('colgroup');
  if old <> nil then old.remove;

  var cg := document.createElement('colgroup');
  for var i := 0 to FColumns.length - 1 do
  begin
    var col := document.createElement('col');
    var w := FColumns[i].Width;
    if w > 0 then col.style.width := IntToStr(w) + 'px';
    cg.appendChild(col);
  end;
  Table.insertBefore(cg, Table.firstChild);
end;


// ═════════════════════════════════════════════════════════════════════════
// Render header
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.RenderHeader;
var
  tr, th, handle: variant;
begin
  BuildColGroup(FHeaderTable);

  FTHead.innerHTML := '';
  tr := document.createElement('tr');
  FTHead.appendChild(tr);

  for var i := 0 to FColumns.length - 1 do
  begin
    th := document.createElement('th');
    th.className := 'dg-th';
    th.textContent := FColumns[i].Caption;
    th.setAttribute('role', 'columnheader');
    th.setAttribute('aria-sort', 'none');

    var align := FColumns[i].Align;
    if align <> 'left' then th.style.textAlign := align;

    handle := document.createElement('div');
    handle.className := 'dg-resize-handle';
    th.appendChild(handle);

    tr.appendChild(th);
  end;
end;


// ═════════════════════════════════════════════════════════════════════════
// Render body — all rows, browser handles scrolling
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.RenderBody;
var
  tr, td: variant;
  row: variant;
begin
  FTBody.innerHTML := '';
  BuildColGroup(FBodyTable);

  for var vi := 0 to FView.Count - 1 do
  begin
    var dataIdx := FView[vi];
    row := FData[dataIdx];

    tr := document.createElement('tr');
    tr.className := 'dg-row';
    tr.setAttribute('role', 'row');

    for var ci := 0 to FColumns.length - 1 do
    begin
      td := document.createElement('td');
      td.className := 'dg-td';
      td.setAttribute('role', 'gridcell');

      var field := FColumns[ci].Field;
      td.textContent := SafeStr(row[field]);

      var align := FColumns[ci].Align;
      if align <> 'left' then td.style.textAlign := align;

      tr.appendChild(td);
    end;

    FTBody.appendChild(tr);
  end;

  // Re-apply visual states after re-render
  if (FSelectedRow >= 0) and (FSelectedRow < FView.Count) then
  begin
    tr := FTBody.rows[FSelectedRow];
    if tr then tr.classList.add('dg-row-selected');
  end;
  FocusCellDOM;
end;


// ═════════════════════════════════════════════════════════════════════════
// SetData / Refresh / helpers
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.SetData(const Data: array of variant);
begin
  FData := Data;

  FView.Clear;
  for var i := 0 to FData.Count - 1 do
    FView.Add(i);

  FSortCol     := -1;
  FSortDir     := sdNone;
  FFocusRow    := -1;
  FFocusCol    := -1;
  FSelectedRow := -1;
  FEditing     := false;

  Refresh;
end;

function JW3DataGrid.RowCount: Integer;
begin
  Result := FView.Count;
end;

function JW3DataGrid.GetRowData(ViewIdx: Integer): variant;
begin
  if (ViewIdx >= 0) and (ViewIdx < FView.Count) then
    Result := FData[FView[ViewIdx]]
  else
    Result := nil;
end;

procedure JW3DataGrid.Refresh;
var
  el: variant;
begin
  el := Self.Handle;
  el.style.setProperty('--dg-row-height', IntToStr(FRowHeight) + 'px');

  RenderHeader;
  RenderBody;
  UpdateSortIndicators;
end;


// ═════════════════════════════════════════════════════════════════════════
// Element access — no row map, just table.rows / row.cells
// ═════════════════════════════════════════════════════════════════════════

function JW3DataGrid.GetRowElement(ViewIdx: Integer): variant;
begin
  Result := nil;
  if (ViewIdx >= 0) and (ViewIdx < FView.Count) then
    Result := FTBody.rows[ViewIdx];
end;

function JW3DataGrid.GetCellElement(ViewIdx, ColIdx: Integer): variant;
var
  tr: variant;
begin
  Result := nil;
  tr := GetRowElement(ViewIdx);
  if tr then
    if (ColIdx >= 0) and (ColIdx < FColumns.length) then
      Result := tr.cells[ColIdx];
end;

function JW3DataGrid.GetHeaderCell(ColIdx: Integer): variant;
var
  headerRow: variant;
begin
  Result := nil;
  headerRow := FTHead.rows[0];
  if headerRow then
    if (ColIdx >= 0) and (ColIdx < FColumns.length) then
      Result := headerRow.cells[ColIdx];
end;


// ═════════════════════════════════════════════════════════════════════════
// Sorting
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.HandleHeaderClick(ColIndex: Integer);
begin
  if (ColIndex < 0) or (ColIndex >= FColumns.Count) then exit;
  if not FColumns[ColIndex].Sortable then exit;
  ApplySort(ColIndex);
end;

procedure JW3DataGrid.ApplySort(ColIndex: Integer);
begin
  if FEditing then CommitEdit;

  if FSortCol = ColIndex then
  begin
    case FSortDir of
      sdAsc:  FSortDir := sdDesc;
      sdDesc: begin FSortDir := sdNone; ClearSort; exit; end;
    else
      FSortDir := sdAsc;
    end;
  end
  else
  begin
    FSortCol := ColIndex;
    FSortDir := sdAsc;
  end;

  SortView;
  Refresh;
end;

procedure JW3DataGrid.SortView;
var
  Field: String;
  Dir: Integer;
begin
  if (FSortCol < 0) or (FSortDir = sdNone) then exit;
  Field := FColumns[FSortCol].Field;
  if FSortDir = sdAsc then Dir := 1 else Dir := -1;

  // Sort comparator needs asm for inline function + typeof + localeCompare
  asm
    var data = @self.FData;
    var field = @Field;
    var dir = @Dir;
    (@FView).sort(function(a, b) {
      var va = data[a][field];
      var vb = data[b][field];
      if (va === vb) return 0;
      if (va === undefined || va === null) return dir;
      if (vb === undefined || vb === null) return -dir;
      if (typeof va === 'number' && typeof vb === 'number')
        return (va - vb) * dir;
      return String(va).localeCompare(String(vb)) * dir;
    });
  end;

  FSelectedRow := -1;
  FFocusRow    := -1;
  FFocusCol    := -1;
end;

procedure JW3DataGrid.ClearSort;
begin
  FSortCol := -1;
  FSortDir := sdNone;
  FView.Clear;
  for var i := 0 to FData.Count - 1 do FView.Add(i);
  FSelectedRow := -1;
  FFocusRow    := -1;
  FFocusCol    := -1;
  Refresh;
end;

procedure JW3DataGrid.UpdateSortIndicators;
var
  headerRow, th: variant;
begin
  headerRow := FTHead.rows[0];
  if not headerRow then exit;

  for var i := 0 to FColumns.length - 1 do
  begin
    th := headerRow.cells[i];
    th.classList.remove('dg-sort-asc');
    th.classList.remove('dg-sort-desc');
    th.setAttribute('aria-sort', 'none');
  end;

  if (FSortCol >= 0) and (FSortCol < FColumns.length) then
  begin
    th := headerRow.cells[FSortCol];
    if FSortDir = sdAsc then
    begin
      th.classList.add('dg-sort-asc');
      th.setAttribute('aria-sort', 'ascending');
    end
    else if FSortDir = sdDesc then
    begin
      th.classList.add('dg-sort-desc');
      th.setAttribute('aria-sort', 'descending');
    end;
  end;
end;


// ═════════════════════════════════════════════════════════════════════════
// Row selection
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.SelectRow(ViewIdx: Integer);
var
  tr: variant;
begin
  if FSelectedRow >= 0 then
  begin
    tr := GetRowElement(FSelectedRow);
    if tr then tr.classList.remove('dg-row-selected');
  end;

  FSelectedRow := ViewIdx;

  if FSelectedRow >= 0 then
  begin
    tr := GetRowElement(FSelectedRow);
    if tr then tr.classList.add('dg-row-selected');
  end;

  if assigned(FOnSelectRow) and (ViewIdx >= 0) and (ViewIdx < FView.Count) then
    FOnSelectRow(Self, FView[ViewIdx], FData[FView[ViewIdx]]);
end;


// ═════════════════════════════════════════════════════════════════════════
// Cell focus
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.HandleCellClick(ViewIdx, ColIdx: Integer);
begin
  if FEditing then CommitEdit;
  ClearCellFocusDOM;
  FFocusRow := ViewIdx;
  FFocusCol := ColIdx;
  SelectRow(ViewIdx);
  FocusCellDOM;
end;

procedure JW3DataGrid.FocusCellDOM;
var
  td: variant;
begin
  if (FFocusRow < 0) or (FFocusCol < 0) then exit;
  td := GetCellElement(FFocusRow, FFocusCol);
  if td then td.classList.add('dg-cell-focused');
end;

procedure JW3DataGrid.ClearCellFocusDOM;
var
  td: variant;
begin
  if (FFocusRow < 0) or (FFocusCol < 0) then exit;
  td := GetCellElement(FFocusRow, FFocusCol);
  if td then td.classList.remove('dg-cell-focused');
end;

procedure JW3DataGrid.ScrollToRow(ViewIdx: Integer);
var
  tr: variant;
  rowTop, rowBottom, scrollTop, viewHeight: Integer;
begin
  tr := GetRowElement(ViewIdx);
  if not tr then exit;

  rowTop     := tr.offsetTop;
  rowBottom  := rowTop + tr.offsetHeight;
  scrollTop  := FBodyWrap.scrollTop;
  viewHeight := FBodyWrap.clientHeight;

  if rowTop < scrollTop then
    FBodyWrap.scrollTop := rowTop
  else if rowBottom > scrollTop + viewHeight then
    FBodyWrap.scrollTop := rowBottom - viewHeight;
end;


// ═════════════════════════════════════════════════════════════════════════
// Inline editing
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.HandleCellDblClick(ViewIdx, ColIdx: Integer);
begin
  if (ColIdx < 0) or (ColIdx >= FColumns.Count) then exit;
  if not FColumns[ColIdx].Editable then exit;

  ClearCellFocusDOM;
  FFocusRow := ViewIdx;
  FFocusCol := ColIdx;
  SelectRow(ViewIdx);
  BeginEdit(ViewIdx, ColIdx);
end;

procedure JW3DataGrid.BeginEdit(ViewIdx, ColIdx: Integer);
var
  td, input: variant;
  currentVal: String;
  dataIdx: Integer;
  field: String;
begin
  if FEditing then CommitEdit;
  if (ColIdx < 0) or (ColIdx >= FColumns.Count) then exit;
  if not FColumns[ColIdx].Editable then exit;

  td := GetCellElement(ViewIdx, ColIdx);
  if not td then exit;

  dataIdx := FView[ViewIdx];
  field   := FColumns[ColIdx].Field;
  //asm @currentVal = String((@self.FData[@dataIdx])[@field] || ''); end;
  currentVal := FData[dataIdx][field];

  FEditing     := true;
  FEditViewRow := ViewIdx;
  FEditCol     := ColIdx;

  td.classList.add('dg-editing');
  td.classList.remove('dg-cell-focused');
  td.textContent := '';

  input := document.createElement('input');
  input.&type := 'text';
  input.className := 'dg-edit-input';
  input.value := currentVal;
  td.appendChild(input);
  FEditInput := input;

  input.focus;
  input.select;

  // Keyboard handler on the edit input
  input.onkeydown := procedure(e: variant)
  begin
    if e.key = 'Enter' then
    begin
      e.preventDefault;
      e.stopPropagation;
      CommitEdit;
    end
    else if e.key = 'Escape' then
    begin
      e.preventDefault;
      e.stopPropagation;
      CancelEdit;
    end
    else if e.key = 'Tab' then
    begin
      e.preventDefault;
      e.stopPropagation;
      CommitEdit;
      var dir: Integer;
      if e.shiftKey then dir := -1 else dir := 1;
      var nextCol := FEditCol + dir;
      while (nextCol >= 0) and (nextCol < FColumns.length) do
      begin
        if FColumns[nextCol].Editable then
        begin
          HandleCellClick(FEditViewRow, nextCol);
          BeginEdit(FEditViewRow, nextCol);
          break;
        end;
        nextCol := nextCol + dir;
      end;
    end
    else
    begin
      e.stopPropagation;
    end;
  end;

  // Blur: commit on focus loss (setTimeout lets Tab handler fire first)
  input.onblur := procedure
  begin
    if FEditing then
      //asm setTimeout(function() { @self.CommitEdit(); }, 0); end;
      asm setTimeout(function() { @CommitEdit(); }, 0); end;
  end;
end;

procedure JW3DataGrid.CommitEdit;
var
  newVal: String;
  dataIdx: Integer;
  field: String;
  oldVal: variant;
  td: variant;
begin
  if not FEditing then exit;
  FEditing := false;

  if FEditInput then
    newVal := FEditInput.value
  else
    newVal := '';

  dataIdx := FView[FEditViewRow];
  field   := FColumns[FEditCol].Field;

  // Dynamic field read/write on JS object
//  asm
//    @oldVal = (@self.FData[@dataIdx])[@field];
//    (@self.FData[@dataIdx])[@field] = @newVal;
//  end;

  oldVal := FData[dataIdx][field];
  FData[dataIdx][field] := newVal;

  td := GetCellElement(FEditViewRow, FEditCol);
  if td then
  begin
    td.classList.remove('dg-editing');
    td.innerHTML := '';
    td.textContent := newVal;
  end;

  FEditInput := nil;
  FocusCellDOM;

  if assigned(FOnCellEdit) then
    FOnCellEdit(Self, dataIdx, field, oldVal, newVal);
end;

procedure JW3DataGrid.CancelEdit;
var
  td: variant;
  dataIdx: Integer;
  field: String;
  originalVal: String;
begin
  if not FEditing then exit;
  FEditing := false;

  dataIdx := FView[FEditViewRow];
  field   := FColumns[FEditCol].Field;

  // Dynamic field read on JS object
  //asm @originalVal = String((@self.FData[@dataIdx])[@field] || ''); end;
  originalVal := FData[dataIdx][field];

  td := GetCellElement(FEditViewRow, FEditCol);
  if td then
  begin
    td.classList.remove('dg-editing');
    td.innerHTML := '';
    td.textContent := originalVal;
  end;

  FEditInput := nil;
  FocusCellDOM;
end;


// ═════════════════════════════════════════════════════════════════════════
// Column resize
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.BeginResize(ColIdx, ScreenX: Integer);
var
  th: variant;
  body: variant;
begin
  FResizing     := true;
  FResizeCol    := ColIdx;
  FResizeStartX := ScreenX;

  if FColumns[ColIdx].Width > 0 then
    FResizeStartW := FColumns[ColIdx].Width
  else
  begin
    th := GetHeaderCell(ColIdx);
    if th then
      FResizeStartW := th.offsetWidth
    else
      FResizeStartW := 100;
  end;

  body := document.body;
  body.classList.add('dg-col-resizing');

  document.onmousemove := procedure(e: variant)
  begin
    DoResize(e.clientX);
  end;

  document.onmouseup := procedure(e: variant)
  begin
    document.onmousemove := procedure begin end;
    EndResize;
    document.onmouseup := procedure begin end;
  end;
end;

procedure JW3DataGrid.DoResize(ScreenX: Integer);
var
  delta, newWidth: Integer;
begin
  delta    := ScreenX - FResizeStartX;
  newWidth := FResizeStartW + delta;

  if newWidth < FColumns[FResizeCol].MinWidth then
    newWidth := FColumns[FResizeCol].MinWidth;

  FColumns[FResizeCol].Width := newWidth;
  BuildColGroup(FHeaderTable);
  BuildColGroup(FBodyTable);
end;

procedure JW3DataGrid.EndResize;
var
  body: variant;
begin
  FResizing := false;
  body := document.body;
  body.classList.remove('dg-col-resizing');
end;


// ═════════════════════════════════════════════════════════════════════════
// Clipboard
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.CopyFocusedCell;
var
  td: variant;
  text: String;
begin
  if (FFocusRow < 0) or (FFocusCol < 0) then exit;
  td := GetCellElement(FFocusRow, FFocusCol);
  if not td then exit;

  text := td.textContent;

  // navigator.clipboard is browser-specific API
  asm
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(@text);
    }
  end;
end;


// ═════════════════════════════════════════════════════════════════════════
// Keyboard
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataGrid.HandleKeyDown(EventObj: JEvent);
var
  Key: String;
  CtrlOrMeta: Boolean;
  pageSize: Integer;
begin
  if FEditing then exit;

  Key := EventObj.key;
  CtrlOrMeta := EventObj.ctrlKey or EventObj.metaKey;

  if FView.Count = 0 then exit;

  if FFocusRow < 0 then FFocusRow := 0;
  if FFocusCol < 0 then FFocusCol := 0;

  // Clipboard
  if CtrlOrMeta and ((Key = 'c') or (Key = 'C')) then
  begin
    CopyFocusedCell;
    exit;
  end;

  if Key = 'ArrowDown' then
  begin
    EventObj.preventDefault;
    if FFocusRow < FView.Count - 1 then
    begin
      ClearCellFocusDOM;
      FFocusRow := FFocusRow + 1;
      ScrollToRow(FFocusRow);
      SelectRow(FFocusRow);
      FocusCellDOM;
    end;
  end

  else if Key = 'ArrowUp' then
  begin
    EventObj.preventDefault;
    if FFocusRow > 0 then
    begin
      ClearCellFocusDOM;
      FFocusRow := FFocusRow - 1;
      ScrollToRow(FFocusRow);
      SelectRow(FFocusRow);
      FocusCellDOM;
    end;
  end

  else if Key = 'ArrowRight' then
  begin
    EventObj.preventDefault;
    if FFocusCol < FColumns.Count - 1 then
    begin
      ClearCellFocusDOM;
      FFocusCol := FFocusCol + 1;
      FocusCellDOM;
    end;
  end

  else if Key = 'ArrowLeft' then
  begin
    EventObj.preventDefault;
    if FFocusCol > 0 then
    begin
      ClearCellFocusDOM;
      FFocusCol := FFocusCol - 1;
      FocusCellDOM;
    end;
  end

  else if Key = 'Tab' then
  begin
    EventObj.preventDefault;
    ClearCellFocusDOM;
    if EventObj.shiftKey then
    begin
      FFocusCol := FFocusCol - 1;
      if FFocusCol < 0 then
      begin
        FFocusCol := FColumns.Count - 1;
        if FFocusRow > 0 then
        begin
          FFocusRow := FFocusRow - 1;
          ScrollToRow(FFocusRow);
          SelectRow(FFocusRow);
        end;
      end;
    end
    else
    begin
      FFocusCol := FFocusCol + 1;
      if FFocusCol >= FColumns.Count then
      begin
        FFocusCol := 0;
        if FFocusRow < FView.Count - 1 then
        begin
          FFocusRow := FFocusRow + 1;
          ScrollToRow(FFocusRow);
          SelectRow(FFocusRow);
        end;
      end;
    end;
    FocusCellDOM;
  end

  else if Key = 'Home' then
  begin
    EventObj.preventDefault;
    ClearCellFocusDOM;
    FFocusRow := 0;
    FFocusCol := 0;
    ScrollToRow(0);
    SelectRow(0);
    FocusCellDOM;
  end

  else if Key = 'End' then
  begin
    EventObj.preventDefault;
    ClearCellFocusDOM;
    FFocusRow := FView.Count - 1;
    FFocusCol := FColumns.Count - 1;
    ScrollToRow(FFocusRow);
    SelectRow(FFocusRow);
    FocusCellDOM;
  end

  else if Key = 'PageDown' then
  begin
    EventObj.preventDefault;
    ClearCellFocusDOM;
    pageSize := FBodyWrap.clientHeight div FRowHeight;
    if pageSize < 1 then pageSize := 1;
    FFocusRow := FFocusRow + pageSize;
    if FFocusRow >= FView.Count then FFocusRow := FView.Count - 1;
    ScrollToRow(FFocusRow);
    SelectRow(FFocusRow);
    FocusCellDOM;
  end

  else if Key = 'PageUp' then
  begin
    EventObj.preventDefault;
    ClearCellFocusDOM;
    pageSize := FBodyWrap.clientHeight div FRowHeight;
    if pageSize < 1 then pageSize := 1;
    FFocusRow := FFocusRow - pageSize;
    if FFocusRow < 0 then FFocusRow := 0;
    ScrollToRow(FFocusRow);
    SelectRow(FFocusRow);
    FocusCellDOM;
  end

  else if Key = 'Enter' then
  begin
    EventObj.preventDefault;
    SelectRow(FFocusRow);
    if (FFocusCol >= 0) and (FFocusCol < FColumns.Count) then
      if FColumns[FFocusCol].Editable then
        BeginEdit(FFocusRow, FFocusCol);
  end

  else if Key = 'F2' then
  begin
    EventObj.preventDefault;
    if (FFocusCol >= 0) and (FFocusCol < FColumns.Count) then
      if FColumns[FFocusCol].Editable then
        BeginEdit(FFocusRow, FFocusCol);
  end

  else if Key = 'Escape' then
  begin
    if FEditing then CancelEdit;
  end;
end;

// ═════════════════════════════════════════════════════════════════════════
// Styles
// ═════════════════════════════════════════════════════════════════════════

procedure RegisterDataGridStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    .datagrid {
      display: flex;
      flex-direction: column;
      border: var(--dg-border, 1px solid var(--border-color, #e2e8f0));
      border-radius: var(--dg-radius, var(--radius-lg, 8px));
      background: var(--dg-bg, var(--surface-color, #ffffff));
      overflow: hidden;
      outline: none;
    }

    .dg-table {
      width: 100%;
      border-collapse: collapse;
      table-layout: fixed;
    }

    .dg-header-wrap { overflow: hidden; flex-shrink: 0; }

    .dg-body-wrap {
      overflow-y: auto;
      overflow-x: auto;
      flex-grow: 1;
    }

    /* ── Header ───────────────────────────────────────────────────── */

    .dg-th {
      height: var(--dg-header-height, 40px);
      padding: var(--dg-cell-padding, 0 12px);
      background: var(--dg-header-bg, var(--hover-color, #f1f5f9));
      color: var(--dg-header-color, var(--text-color, #334155));
      font-size: var(--dg-font-size, var(--font-size-sm, 0.875rem));
      font-weight: 600;
      text-align: left;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      cursor: pointer;
      user-select: none;
      border-bottom: 2px solid var(--border-color, #e2e8f0);
      position: relative;
    }

    .dg-th:hover { background: var(--border-color, #e2e8f0); }
    .dg-th::after { content: ""; margin-left: 6px; font-size: 0.7em; }

    .dg-sort-asc::after {
      content: " \25B2";
      color: var(--dg-sort-color, var(--primary-color, #6366f1));
    }
    .dg-sort-desc::after {
      content: " \25BC";
      color: var(--dg-sort-color, var(--primary-color, #6366f1));
    }

    /* ── Resize handle ────────────────────────────────────────────── */

    .dg-resize-handle {
      position: absolute;
      top: 0; right: 0;
      width: 5px; height: 100%;
      cursor: col-resize;
      user-select: none;
      z-index: 1;
    }

    .dg-resize-handle:hover,
    .dg-resize-handle.dg-resizing {
      background: var(--primary-color, #6366f1);
      opacity: 0.4;
    }

    /* ── Rows ─────────────────────────────────────────────────────── */

    .dg-row { transition: background-color 0.1s; }
    .dg-row:hover { background: var(--dg-row-hover, var(--hover-color, #f1f5f9)); }

    .dg-row-selected,
    .dg-row-selected:hover {
      background: var(--dg-row-selected, var(--primary-color, #6366f1)) !important;
      color: var(--dg-row-selected-c, #ffffff);
    }

    /* ── Cells ────────────────────────────────────────────────────── */

    .dg-td {
      height: var(--dg-row-height, 40px);
      padding: var(--dg-cell-padding, 0 12px);
      font-size: var(--dg-font-size, var(--font-size-sm, 0.875rem));
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      vertical-align: middle;
      cursor: default;
    }

    /* ── Cell focus ───────────────────────────────────────────────── */

    .dg-cell-focused {
      outline: 2px solid var(--primary-color, #6366f1);
      outline-offset: -2px;
      background: rgba(99, 102, 241, 0.06);
    }

    .dg-row-selected .dg-cell-focused {
      outline-color: #ffffff;
      background: rgba(255, 255, 255, 0.1);
    }

    /* ── Inline editing ───────────────────────────────────────────── */

    .dg-editing { padding: 0 !important; }

    .dg-edit-input {
      width: 100%; height: 100%;
      border: none;
      outline: 2px solid var(--primary-color, #6366f1);
      outline-offset: -2px;
      padding: 0 12px;
      font-size: inherit; font-family: inherit; color: inherit;
      background: var(--surface-color, #ffffff);
      box-sizing: border-box;
    }

    /* ── Empty state ──────────────────────────────────────────────── */

    .dg-empty {
      padding: 32px; text-align: center;
      color: var(--text-light, #64748b);
      font-size: var(--dg-font-size, var(--font-size-sm, 0.875rem));
    }

    /* ── Resize cursor lock ───────────────────────────────────────── */

    body.dg-col-resizing,
    body.dg-col-resizing * {
      cursor: col-resize !important;
      user-select: none !important;
    }
  ');
end;

initialization
  RegisterDataGridStyles;
end.