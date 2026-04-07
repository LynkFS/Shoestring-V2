unit PageDashboard;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PageDashboard — role-aware landing page
//
//  Shows KPI cards relevant to the current user's role, then a table of
//  the 10 most recent audit log events.
//
//  Extends JW3Panel so FormShell can embed it directly in FMain.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPageDashboard = class(JW3Panel)
  private
    procedure BuildHeader;
    procedure BuildKPIs;
    procedure BuildRecentActivity;
    procedure AddKpiCard(Parent: TElement; const Value, Label_: String);
    function  StatusBadgeHTML(const Status: String): String;
  public
    constructor Create(Parent: TElement); override;
  end;

implementation

uses Globals, HASData, HASPermissions, HASTypes, HASStyles;

{ TPageDashboard }

constructor TPageDashboard.Create(Parent: TElement);
begin
  inherited(Parent);
  SetStyle('gap', 'var(--space-4, 16px)');
  BuildHeader;
  BuildKPIs;
  BuildRecentActivity;
end;

// ── Page title ────────────────────────────────────────────────────────────

procedure TPageDashboard.BuildHeader;
var Header, Title: TElement;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  Title.SetText('Dashboard');

  var Sub := TElement.Create('div', Header);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetText('Welcome, ' + CurrentUser + ' · ' + CurrentRole);
end;

// ── KPI cards ─────────────────────────────────────────────────────────────

procedure TPageDashboard.AddKpiCard(Parent: TElement; const Value, Label_: String);
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

procedure TPageDashboard.BuildKPIs;
var P: TPermissions;
    Row: TElement;
    I, N: Integer;
    Pending, Active, Completed, Disputed: Integer;
begin
  P   := GetPermissions(CurrentRole);
  Row := TElement.Create('div', Self);
  Row.AddClass(csHasKpiRow);

  // ── Count metrics from global arrays ──────────────────────────────────

  // Customers
  if P.CanRegisterCustomer then
    AddKpiCard(Row, IntToStr(HAS_Customers.Count), 'Total Customers');

  // Contractors
  if P.CanManageContractors then
  begin
    Active := 0;
    for I := 0 to HAS_Contractors.Count - 1 do
      if HAS_Contractors[I].Status = stActive then Inc(Active);
    AddKpiCard(Row, IntToStr(Active), 'Active Contractors');
  end;

  // Enrollments
  if P.CanEnroll then
    AddKpiCard(Row, IntToStr(HAS_Enrollments.Count), 'Enrollments');

  // Quotes
  if P.CanRequestQuote or P.CanSubmitQuote or P.CanAssessQuote or P.CanAcceptQuote then
  begin
    Pending   := 0;
    Active    := 0;
    Completed := 0;
    Disputed  := 0;
    for I := 0 to HAS_Quotes.Count - 1 do
    begin
      if HAS_Quotes[I].Status = stRequested  then Inc(Pending);
      if HAS_Quotes[I].Status = stSubmitted  then Inc(Active);
      if HAS_Quotes[I].Status = stCompleted  then Inc(Completed);
      if HAS_Quotes[I].Status = stDisputed   then Inc(Disputed);
    end;
    AddKpiCard(Row, IntToStr(Pending),   'Pending Quotes');
    AddKpiCard(Row, IntToStr(Active),    'Submitted Quotes');
    AddKpiCard(Row, IntToStr(Completed), 'Completed');
    if P.CanResolveDispute then
      AddKpiCard(Row, IntToStr(Disputed), 'Disputes');
  end;

  // Payments
  if P.CanMakePayment then
  begin
    N := 0;
    for I := 0 to HAS_Payments.Count - 1 do
      if HAS_Payments[I].Status = psPending then Inc(N);
    AddKpiCard(Row, IntToStr(N), 'Pending Payments');
  end;

  // Batches
  if P.CanCreateBatch then
  begin
    N := 0;
    for I := 0 to HAS_Batches.Count - 1 do
      if HAS_Batches[I].Status = bsPending then Inc(N);
    AddKpiCard(Row, IntToStr(N), 'Pending Batches');
  end;

  // Contractor: my quotes
  if CurrentRole = roleContractor then
  begin
    N := 0;
    for I := 0 to HAS_Quotes.Count - 1 do
      if HAS_Quotes[I].ContractorID = CurrentContractorID then Inc(N);
    AddKpiCard(Row, IntToStr(N), 'My Quotes');
  end;

  // Customer: my enrollments
  if CurrentRole = roleCustomer then
  begin
    N := 0;
    for I := 0 to HAS_Enrollments.Count - 1 do
      if HAS_Enrollments[I].CustomerID = CurrentCustomerID then Inc(N);
    AddKpiCard(Row, IntToStr(N), 'My Enrollments');
  end;
end;

// ── Recent audit log table ────────────────────────────────────────────────

function TPageDashboard.StatusBadgeHTML(const Status: String): String;
var Cls: String;
begin
  // Map status string → colour variant
  if (Status = 'Login')    or (Status = stActive)   or (Status = stVerified)
  or (Status = stCompleted) or (Status = bsCompleted) or (Status = psPaid)
  then Cls := 'has-status-green'
  else if (Status = stRequested) or (Status = stSubmitted) or (Status = bsPending)
       or (Status = psPending)   or (Status = 'Create')    or (Status = 'Enroll')
       or (Status = stEnrolled)
  then Cls := 'has-status-blue'
  else if (Status = stDisputed)  or (Status = stSuspended)
  then Cls := 'has-status-red'
  else if (Status = stAssessed)  or (Status = stReadyForBatch) or (Status = bsSent)
  then Cls := 'has-status-yellow'
  else Cls := 'has-status-grey';

  Result := '<span class="has-status ' + Cls + '">' + Status + '</span>';
end;

procedure TPageDashboard.BuildRecentActivity;
var Card, CardTitle, Wrap: TElement;
    TableHTML: String;
    I, Start: Integer;
begin
  // Only admins / assessors see full audit log; others see their last 10 events
  Card := TElement.Create('div', Self);
  Card.AddClass(csHasCard);

  CardTitle := TElement.Create('div', Card);
  CardTitle.AddClass('has-card-title');
  CardTitle.SetText('Recent Activity');

  if HAS_AuditLog.Count = 0 then
  begin
    var Empty := TElement.Create('div', Card);
    Empty.SetStyle('color', 'var(--text-light)');
    Empty.SetStyle('font-size', '0.875rem');
    Empty.SetStyle('padding', '8px 0');
    Empty.SetText('No activity recorded yet.');
    exit;
  end;

  Wrap := TElement.Create('div', Card);
  Wrap.AddClass(csHasTableWrap);

  // Show last 10 entries (most recent first)
  Start := HAS_AuditLog.Count - 1;

  TableHTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>Time</th><th>Event</th><th>Entity</th><th>Actor</th><th>Details</th>' +
    '</tr></thead><tbody>';

  I := Start;
  var Shown := 0;
  while (I >= 0) and (Shown < 10) do
  begin
    var Ev := HAS_AuditLog[I];
    TableHTML := TableHTML +
      '<tr>' +
      '<td style="white-space:nowrap;font-size:0.8rem;color:var(--text-light)">' +
        FmtDate(Ev.LoggedAt) + '</td>' +
      '<td>' + StatusBadgeHTML(Ev.EventType) + '</td>' +
      '<td style="font-size:0.8rem">' + Ev.EntityType + '</td>' +
      '<td style="font-size:0.875rem">' + Ev.Actor + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + Ev.Details + '</td>' +
      '</tr>';
    Dec(I);
    Inc(Shown);
  end;

  TableHTML := TableHTML + '</tbody></table>';
  Wrap.SetHTML(TableHTML);
end;

end.
