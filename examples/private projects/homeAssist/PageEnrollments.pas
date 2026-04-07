unit PageEnrollments;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PageEnrollments — read-only enrollment list with program filter
//
//  Roles: Administrator, Assessor (CanEnroll)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPageEnrollments = class(JW3Panel)
  private
    FProgramEl: TElement;   // plain <select>
    FTableWrap: TElement;

    procedure BuildHeader;
    procedure BuildFilters;
    procedure BuildTable;
    procedure RefreshTable;
    function  TableHTML(const ProgFilter: String): String;
    function  CustomerName(const ID: String): String;
  public
    constructor Create(Parent: TElement); override;
  end;

implementation

uses Globals, HASData, HASTypes, HASStyles, ThemeStyles;

{ TPageEnrollments }

constructor TPageEnrollments.Create(Parent: TElement);
begin
  inherited(Parent);
  SetStyle('gap', 'var(--space-4, 16px)');
  BuildHeader;
  BuildFilters;
  BuildTable;
end;

// ── Lookup helper ─────────────────────────────────────────────────────────

function TPageEnrollments.CustomerName(const ID: String): String;
var I: Integer;
begin
  Result := ID;
  for I := 0 to HAS_Customers.Count - 1 do
    if HAS_Customers[I].ID = ID then
    begin
      Result := HAS_Customers[I].FirstName + ' ' + HAS_Customers[I].LastName;
      exit;
    end;
end;

// ── Page header ───────────────────────────────────────────────────────────

procedure TPageEnrollments.BuildHeader;
var Header, Title: TElement;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  Title.SetText('Enrollments');

  var Sub := TElement.Create('div', Header);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetText(IntToStr(HAS_Enrollments.Count) + ' total');
end;

// ── Filter row ────────────────────────────────────────────────────────────

procedure TPageEnrollments.BuildFilters;
var Row, Opt: TElement;
begin
  Row := TElement.Create('div', Self);
  Row.SetStyle('display', 'flex');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('align-items', 'center');

  var Lbl := TElement.Create('label', Row);
  Lbl.AddClass(csFieldLabel);
  Lbl.SetStyle('margin', '0');
  Lbl.SetText('Program:');

  FProgramEl := TElement.Create('select', Row);
  FProgramEl.AddClass(csField);
  FProgramEl.SetStyle('width', 'auto');
  FProgramEl.SetStyle('height', 'auto');
  FProgramEl.SetStyle('padding', '8px 12px');

  Opt := TElement.Create('option', FProgramEl); Opt.SetAttribute('value', '');        Opt.SetText('All programs');
  Opt := TElement.Create('option', FProgramEl); Opt.SetAttribute('value', progHAS);   Opt.SetText(progHASLabel);
  Opt := TElement.Create('option', FProgramEl); Opt.SetAttribute('value', progHSSH);  Opt.SetText(progHSSHLabel);

  FProgramEl.Handle.addEventListener('change', procedure(E: variant) begin RefreshTable; end);
end;

// ── Table ─────────────────────────────────────────────────────────────────

procedure TPageEnrollments.BuildTable;
begin
  FTableWrap := TElement.Create('div', Self);
  FTableWrap.AddClass(csHasTableWrap);
  FTableWrap.SetHTML(TableHTML(''));
end;

procedure TPageEnrollments.RefreshTable;
begin
  FTableWrap.SetHTML(TableHTML(FProgramEl.Handle.value));
end;

// ── HTML generation ───────────────────────────────────────────────────────

function TPageEnrollments.TableHTML(const ProgFilter: String): String;
var HTML: String;
    I, Count: Integer;
    E: TEnrollment;
    Remaining: Float;
begin
  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>Customer</th><th>Program</th>' +
    '<th style="text-align:right">Budget</th>' +
    '<th style="text-align:right">Spent</th>' +
    '<th style="text-align:right">Remaining</th>' +
    '<th>Status</th><th>Enrolled</th>' +
    '</tr></thead><tbody>';

  Count := 0;
  for I := 0 to HAS_Enrollments.Count - 1 do
  begin
    E := HAS_Enrollments[I];
    if (ProgFilter <> '') and (E.Program <> ProgFilter) then continue;

    Remaining := E.BudgetAllocated - E.BudgetSpent;

    HTML := HTML +
      '<tr>' +
      '<td><strong>' + CustomerName(E.CustomerID) + '</strong></td>' +
      '<td>' +
        '<span class="has-status has-status-blue">' + E.Program + '</span>' +
      '</td>' +
      '<td style="text-align:right;font-size:0.875rem">' + FmtCur(E.BudgetAllocated) + '</td>' +
      '<td style="text-align:right;font-size:0.875rem">' + FmtCur(E.BudgetSpent) + '</td>' +
      '<td style="text-align:right;font-size:0.875rem;color:var(--color-success)">' +
        FmtCur(Remaining) + '</td>' +
      '<td>' + StatusBadge(E.Status) + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + FmtDate(E.EnrolledAt) + '</td>' +
      '</tr>';
    Inc(Count);
  end;

  if Count = 0 then
    HTML := HTML +
      '<tr><td colspan="7" style="text-align:center;color:var(--text-light);padding:24px">' +
      'No enrollments found.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Result := HTML;
end;

end.
