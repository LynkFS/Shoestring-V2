unit PageCustomers;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PageCustomers — read-only customer list with live name search
//
//  Roles: Administrator, Assessor, CSO (CanRegisterCustomer or CanAssess)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPageCustomers = class(JW3Panel)
  private
    FSearchEl:  TElement;   // plain <input> — value read via Handle.value
    FTableWrap: TElement;   // div hosting the rendered HTML table

    procedure BuildHeader;
    procedure BuildFilters;
    procedure BuildTable;
    procedure RefreshTable;
    function  TableHTML(const Filter: String): String;
  public
    constructor Create(Parent: TElement); override;
  end;

implementation

uses Globals, HASData, HASTypes, HASStyles, ThemeStyles;

{ TPageCustomers }

constructor TPageCustomers.Create(Parent: TElement);
begin
  inherited(Parent);
  SetStyle('gap', 'var(--space-4, 16px)');
  BuildHeader;
  BuildFilters;
  BuildTable;
end;

// ── Page header ───────────────────────────────────────────────────────────

procedure TPageCustomers.BuildHeader;
var Header, Title: TElement;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  Title.SetText('Customers');

  var Count := TElement.Create('div', Header);
  Count.SetStyle('font-size', '0.875rem');
  Count.SetStyle('color', 'var(--text-light)');
  Count.SetText(IntToStr(HAS_Customers.Count) + ' total');
end;

// ── Filter row ────────────────────────────────────────────────────────────

procedure TPageCustomers.BuildFilters;
var Row: TElement;
begin
  Row := TElement.Create('div', Self);
  Row.SetStyle('display', 'flex');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('align-items', 'center');

  FSearchEl := TElement.Create('input', Row);
  FSearchEl.AddClass(csField);
  FSearchEl.SetAttribute('placeholder', 'Search by name or ID…');
  FSearchEl.SetStyle('max-width', '320px');
  FSearchEl.Handle.addEventListener('input', procedure(E: variant) begin RefreshTable; end);
end;

// ── Table (initial build) ─────────────────────────────────────────────────

procedure TPageCustomers.BuildTable;
begin
  FTableWrap := TElement.Create('div', Self);
  FTableWrap.AddClass(csHasTableWrap);
  FTableWrap.SetHTML(TableHTML(''));
end;

procedure TPageCustomers.RefreshTable;
var Filter: String;
begin
  Filter := FSearchEl.Handle.value;
  FTableWrap.SetHTML(TableHTML(Filter));
end;

// ── HTML generation ───────────────────────────────────────────────────────

function TPageCustomers.TableHTML(const Filter: String): String;
var HTML, FLow: String;
    I: Integer;
    C: TCustomer;
    Name: String;
begin
  FLow := LowerCase(Filter);

  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>ID</th><th>Name</th><th>DOB</th><th>Suburb</th>' +
    '<th>Phone</th><th>Status</th><th>Enrolled</th>' +
    '</tr></thead><tbody>';

  var Count := 0;
  for I := 0 to HAS_Customers.Count - 1 do
  begin
    C    := HAS_Customers[I];
    Name := C.FirstName + ' ' + C.LastName;

    // Filter: match ID or full name (case-insensitive)
    if (FLow <> '') and
       (Pos(FLow, LowerCase(Name)) = 0) and
       (Pos(FLow, LowerCase(C.ID)) = 0)
    then continue;

    // Check if enrolled
    var Enrolled := '—';
    var J: Integer;
    for J := 0 to HAS_Enrollments.Count - 1 do
      if HAS_Enrollments[J].CustomerID = C.ID then
      begin
        Enrolled := HAS_Enrollments[J].Program;
        break;
      end;

    HTML := HTML +
      '<tr>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + C.ID + '</td>' +
      '<td><strong>' + Name + '</strong></td>' +
      '<td style="font-size:0.875rem">' + FmtDate(C.DOB) + '</td>' +
      '<td style="font-size:0.875rem">' + C.Suburb + '</td>' +
      '<td style="font-size:0.875rem">' + C.Phone + '</td>' +
      '<td>' + StatusBadge(C.Status) + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + Enrolled + '</td>' +
      '</tr>';
    Inc(Count);
  end;

  if Count = 0 then
    HTML := HTML +
      '<tr><td colspan="7" style="text-align:center;color:var(--text-light);padding:24px">' +
      'No customers found.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Result := HTML;
end;

end.
