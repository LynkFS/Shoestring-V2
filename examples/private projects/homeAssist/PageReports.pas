unit PageReports;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PageReports — Read-only summary statistics
//
//  Roles: Administrator, Assessor
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPageReports = class(JW3Panel)
  private
    procedure BuildHeader;
    procedure BuildKPIs;
    procedure BuildQuotePipeline;
    procedure BuildBudgetUtilization;
    procedure BuildContractorActivity;
    procedure AddKpiCard(Parent: TElement; const Value, Label_: String);
    function  SectionCard(const Title: String): TElement;
  public
    constructor Create(Parent: TElement); override;
  end;

implementation

uses Globals, HASData, HASTypes, HASStyles;

{ TPageReports }

constructor TPageReports.Create(Parent: TElement);
begin
  inherited(Parent);
  SetStyle('gap', 'var(--space-4, 16px)');
  BuildHeader;
  BuildKPIs;
  BuildQuotePipeline;
  BuildBudgetUtilization;
  BuildContractorActivity;
end;

// ── Page header ───────────────────────────────────────────────────────────

procedure TPageReports.BuildHeader;
var Header, Title: TElement;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  Title.SetText('Reports');

  var Sub := TElement.Create('div', Header);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetText('Read-only summary statistics');
end;

// ── Helpers ───────────────────────────────────────────────────────────────

procedure TPageReports.AddKpiCard(Parent: TElement; const Value, Label_: String);
var Card, V, L: TElement;
begin
  Card := TElement.Create('div', Parent);
  Card.AddClass(csHasKpiCard);
  V := TElement.Create('div', Card);
  V.AddClass(csHasKpiValue);
  V.SetText(Value);
  L := TElement.Create('div', Card);
  L.AddClass(csHasKpiLabel);
  L.SetText(Label_);
end;

function TPageReports.SectionCard(const Title: String): TElement;
var TitleEl: TElement;
begin
  Result := TElement.Create('div', Self);
  Result.AddClass(csHasCard);
  TitleEl := TElement.Create('div', Result);
  TitleEl.AddClass('has-card-title');
  TitleEl.SetText(Title);
end;

// ── KPI row ───────────────────────────────────────────────────────────────

procedure TPageReports.BuildKPIs;
var Row: TElement;
    I, PaidCount, PendingCount: Integer;
    PaidAmt, PendingAmt: Float;
begin
  Row := TElement.Create('div', Self);
  Row.AddClass(csHasKpiRow);

  AddKpiCard(Row, IntToStr(HAS_Customers.Count),   'Customers');
  AddKpiCard(Row, IntToStr(HAS_Enrollments.Count), 'Enrollments');
  AddKpiCard(Row, IntToStr(HAS_Quotes.Count),      'Quotes');
  AddKpiCard(Row, IntToStr(HAS_Activities.Count),  'Activities');

  PaidCount := 0; PendingCount := 0;
  PaidAmt   := 0; PendingAmt   := 0;
  for I := 0 to HAS_Payments.Count - 1 do
  begin
    if HAS_Payments[I].Status = psPaid then
    begin
      Inc(PaidCount);
      PaidAmt := PaidAmt + HAS_Payments[I].Amount;
    end
    else
    begin
      Inc(PendingCount);
      PendingAmt := PendingAmt + HAS_Payments[I].Amount;
    end;
  end;

  AddKpiCard(Row, FmtCur(PaidAmt),     'Paid (' + IntToStr(PaidCount) + ')');
  AddKpiCard(Row, FmtCur(PendingAmt),  'Pending (' + IntToStr(PendingCount) + ')');
end;

// ── Quote Pipeline ────────────────────────────────────────────────────────

procedure TPageReports.BuildQuotePipeline;
var Card, Wrap: TElement;
    I: Integer;
    Counts: array of Integer;
    Statuses: array of String;
    HTML: String;
begin
  Card := SectionCard('Quote Pipeline');
  Wrap := TElement.Create('div', Card);
  Wrap.AddClass(csHasTableWrap);

  // Build status list in workflow order
  Statuses.SetLength(0);
  Statuses.Add(stRequested);
  Statuses.Add(stSubmitted);
  Statuses.Add(stAcceptedByCustomer);
  Statuses.Add(stAssessed);
  Statuses.Add(stReadyForBatch);
  Statuses.Add(stWorkCommenced);
  Statuses.Add(stCompleted);
  Statuses.Add(stVerified);
  Statuses.Add(stDisputed);
  Statuses.Add(stCancelled);

  Counts.SetLength(Statuses.Count);
  for I := 0 to Statuses.Count - 1 do
    Counts[I] := 0;

  for I := 0 to HAS_Quotes.Count - 1 do
  begin
    var J: Integer;
    for J := 0 to Statuses.Count - 1 do
      if HAS_Quotes[I].Status = Statuses[J] then
      begin
        Inc(Counts[J]);
        break;
      end;
  end;

  HTML :=
    '<table class="has-table">' +
    '<thead><tr><th>Status</th><th style="text-align:right">Count</th></tr></thead>' +
    '<tbody>';

  for I := 0 to Statuses.Count - 1 do
    if Counts[I] > 0 then
      HTML := HTML +
        '<tr><td>' + StatusBadge(Statuses[I]) + '</td>' +
        '<td style="text-align:right;font-weight:600">' + IntToStr(Counts[I]) + '</td></tr>';

  if HAS_Quotes.Count = 0 then
    HTML := HTML +
      '<tr><td colspan="2" style="text-align:center;color:var(--text-light);padding:16px">' +
      'No quotes yet.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Wrap.SetHTML(HTML);
end;

// ── Budget Utilization ────────────────────────────────────────────────────

procedure TPageReports.BuildBudgetUtilization;
var Card, Wrap: TElement;
    I: Integer;
    E: TEnrollment;
    Remaining: Float;
    HTML: String;
begin
  Card := SectionCard('Budget Utilization');
  Wrap := TElement.Create('div', Card);
  Wrap.AddClass(csHasTableWrap);

  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>Customer</th><th>Program</th>' +
    '<th style="text-align:right">Allocated</th>' +
    '<th style="text-align:right">Spent</th>' +
    '<th style="text-align:right">Remaining</th>' +
    '</tr></thead><tbody>';

  for I := 0 to HAS_Enrollments.Count - 1 do
  begin
    E := HAS_Enrollments[I];
    Remaining := E.BudgetAllocated - E.BudgetSpent;

    var RemStyle: String;
    if Remaining < 0 then
      RemStyle := 'color:var(--color-danger)'
    else
      RemStyle := 'color:var(--color-success)';

    HTML := HTML +
      '<tr>' +
      '<td><strong>' + CustomerFullName(E.CustomerID) + '</strong></td>' +
      '<td><span class="has-status has-status-blue">' + E.Program + '</span></td>' +
      '<td style="text-align:right;font-size:0.875rem">' + FmtCur(E.BudgetAllocated) + '</td>' +
      '<td style="text-align:right;font-size:0.875rem">' + FmtCur(E.BudgetSpent) + '</td>' +
      '<td style="text-align:right;font-size:0.875rem;' + RemStyle + '">' + FmtCur(Remaining) + '</td>' +
      '</tr>';
  end;

  if HAS_Enrollments.Count = 0 then
    HTML := HTML +
      '<tr><td colspan="5" style="text-align:center;color:var(--text-light);padding:16px">' +
      'No enrollments yet.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Wrap.SetHTML(HTML);
end;

// ── Contractor Activity ───────────────────────────────────────────────────

procedure TPageReports.BuildContractorActivity;
var Card, Wrap: TElement;
    I, J, TotalQ, DoneQ: Integer;
    TotalVal: Float;
    HTML: String;
begin
  Card := SectionCard('Contractor Activity');
  Wrap := TElement.Create('div', Card);
  Wrap.AddClass(csHasTableWrap);

  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>Contractor</th><th>Status</th>' +
    '<th style="text-align:right">Total Quotes</th>' +
    '<th style="text-align:right">Completed</th>' +
    '<th style="text-align:right">Total Value</th>' +
    '</tr></thead><tbody>';

  var Count := 0;
  for I := 0 to HAS_Contractors.Count - 1 do
  begin
    TotalQ   := 0;
    DoneQ    := 0;
    TotalVal := 0;

    for J := 0 to HAS_Quotes.Count - 1 do
      if HAS_Quotes[J].ContractorID = HAS_Contractors[I].ID then
      begin
        Inc(TotalQ);
        TotalVal := TotalVal + HAS_Quotes[J].Total;
        if (HAS_Quotes[J].Status = stCompleted) or (HAS_Quotes[J].Status = stVerified) then
          Inc(DoneQ);
      end;

    if TotalQ > 0 then
    begin
      HTML := HTML +
        '<tr>' +
        '<td><strong>' + HAS_Contractors[I].BusinessName + '</strong></td>' +
        '<td>' + StatusBadge(HAS_Contractors[I].Status) + '</td>' +
        '<td style="text-align:right">' + IntToStr(TotalQ) + '</td>' +
        '<td style="text-align:right">' + IntToStr(DoneQ) + '</td>' +
        '<td style="text-align:right;font-size:0.875rem">' + FmtCur(TotalVal) + '</td>' +
        '</tr>';
      Inc(Count);
    end;
  end;

  if Count = 0 then
    HTML := HTML +
      '<tr><td colspan="5" style="text-align:center;color:var(--text-light);padding:16px">' +
      'No contractor activity yet.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Wrap.SetHTML(HTML);
end;

end.
