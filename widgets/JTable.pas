unit JTable;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3Table — Lightweight data table
//
//  Renders a styled HTML table from a variant row array (e.g. from a DB
//  callback). Columns are declared once; SetRows rebuilds the table body.
//  Optional delete button column via OnDelete event.
//
//  Usage:
//
//    var T := JW3Table.Create(Self);
//    T.AddColumn('ID',     'id');
//    T.AddColumn('Title',  'title');
//    T.AddColumn('Author', 'author');
//    T.OnDelete := procedure(ID: String)
//    begin
//      DeleteBook(ID);
//    end;
//
//    // In a DB callback:
//    T.SetRows(Data.rows);
//
//    // Switch to a different result set:
//    T.SetRows(OtherData.rows);
//
//    // Show empty state explicitly:
//    T.Clear;
//
//  Notes:
//    - IDField defaults to 'id'. Change it if your primary key has another name.
//    - Cell values are rendered as strings. Format values (dates, currency etc.)
//      in the data before calling SetRows, or post-process the variant array.
//    - NULL / undefined values render as an em-dash (—).
//    - The wrapper div handles overflow-x, so wide tables scroll horizontally.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csJTable = 'jtbl-wrap';

type
  TTableColumn = record
    Header: String;
    Field:  String;
  end;

  TTableDeleteEvent = procedure(ID: String);

  JW3Table = class(TElement)
  private
    FColumns:  array of TTableColumn;
    FOnDelete: TTableDeleteEvent;
    FIDField:  String;

  public
    constructor Create(Parent: TElement); virtual;

    procedure AddColumn(const Header, Field: String);
    procedure SetRows(Rows: variant);
    procedure Clear;

    property IDField:  String             read FIDField  write FIDField;
    property OnDelete: TTableDeleteEvent  read FOnDelete write FOnDelete;
  end;

procedure RegisterTableStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterTableStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Table wrapper ────────────────────────────────────────────── */

    .jtbl-wrap {
      overflow-x: auto;
    }

    /* ── Table ────────────────────────────────────────────────────── */

    .jtbl {
      width: 100%;
      border-collapse: collapse;
      font-size: var(--text-sm);
    }

    .jtbl th {
      text-align: left;
      padding: 8px 12px;
      background: var(--surface-2);
      border-bottom: 2px solid var(--border-strong);
      font-weight: var(--weight-semi);
      white-space: nowrap;
    }

    .jtbl td {
      padding: 8px 12px;
      border-bottom: 1px solid var(--border-color);
    }

    .jtbl tr:hover td {
      background: var(--hover-color);
    }

    /* ── Cell states ──────────────────────────────────────────────── */

    .jtbl-null {
      color: var(--text-xlight);
      font-style: italic;
    }

    .jtbl-empty {
      padding: 8px;
      color: var(--text-light);
    }

    /* ── Delete button ────────────────────────────────────────────── */

    .jtbl-del {
      cursor: pointer;
      color: var(--color-danger);
      font-size: var(--text-xs);
      padding: 2px 8px;
      border: 1px solid var(--color-danger);
      border-radius: var(--radius-sm);
      background: transparent;
      line-height: 1.6;
    }

    .jtbl-del:hover {
      background: var(--color-danger);
      color: #fff;
    }

  ');
end;

{ JW3Table }

constructor JW3Table.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  RegisterTableStyles;
  AddClass(csJTable);
  FIDField := 'id';

  // Event delegation — one listener handles all delete buttons,
  // even after SetRows replaces the table HTML.
  Handle.addEventListener('click', procedure(E: variant)
  begin
    var id: String;
    asm
      var el = (@E).target.closest('[data-id]');
      if (el) {
        (@E).preventDefault();
        @id = el.getAttribute('data-id') || '';
      }
    end;
    if (id <> '') and assigned(FOnDelete) then
      FOnDelete(id);
  end);
end;


procedure JW3Table.AddColumn(const Header, Field: String);
var Col: TTableColumn;
begin
  Col.Header := Header;
  Col.Field  := Field;
  FColumns.Add(Col);
end;


procedure JW3Table.Clear;
begin
  SetHTML('<p class="jtbl-empty">No data.</p>');
end;


procedure JW3Table.SetRows(Rows: variant);
var cols: variant;
    hasDelete: Boolean;
    idField: String;
    html: String;
begin
  if FColumns.Count = 0 then exit;

  // Build a JS array from FColumns so the asm block can iterate it.
  asm @cols = []; end;
  for var i := 0 to FColumns.Count - 1 do
  begin
    var h := FColumns[i].Header;
    var f := FColumns[i].Field;
    asm (@cols).push({ header: @h, field: @f }); end;
  end;

  hasDelete := assigned(FOnDelete);
  idField   := FIDField;

  // Build HTML in the asm block and assign to a Pascal variable,
  // then use SetHTML — avoids (@Self).Handle which doesn't resolve
  // Pascal property getters from inside raw JS.
  asm
    var rows      = @Rows;
    var cols      = @cols;
    var hasDelete = @hasDelete;
    var idField   = @idField;

    if (!rows || rows.length === 0) {
      @html = '<p class="jtbl-empty">No data.</p>';
    } else {
      var h = '<table class="jtbl"><thead><tr>';
      cols.forEach(function(c) { h += '<th>' + c.header + '</th>'; });
      if (hasDelete) h += '<th></th>';
      h += '</tr></thead><tbody>';

      rows.forEach(function(row) {
        h += '<tr>';
        cols.forEach(function(c) {
          var v = row[c.field];
          h += (v === null || v === undefined)
            ? '<td><span class="jtbl-null">—</span></td>'
            : '<td>' + String(v).replace(/</g, '&lt;') + '</td>';
        });
        if (hasDelete) {
          h += '<td><button class="jtbl-del" data-id="' +
            row[idField] + '">delete</button></td>';
        }
        h += '</tr>';
      });

      h += '</tbody></table>';
      @html = h;
    }
  end;

  SetHTML(html);
end;


initialization
  RegisterTableStyles;
end.
