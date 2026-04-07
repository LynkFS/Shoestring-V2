unit PagePayments;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PagePayments — Payment list with mark-paid action
//
//  Roles: Administrator, PaymentOfficer (CanMakePayment)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPagePayments = class(JW3Panel)
  private
    FStatusEl:   TElement;   // status filter <select>
    FListWrap:   TElement;
    FActionCard: TElement;
    FSelectedID: String;

    // Mark Paid form
    FRefEl: TElement;

    procedure BuildHeader;
    procedure BuildFilters;
    procedure BuildList;
    procedure RefreshList;
    function  ListHTML(const StatusFilter: String): String;
    procedure ShowAction(const PaymentID: String);
    procedure HideAction;
    procedure DoMarkPaid;
  public
    constructor Create(Parent: TElement); override;
  end;

implementation

uses Globals, HASData, HASPermissions, HASTypes, HASStyles, ThemeStyles;

{ TPagePayments }

constructor TPagePayments.Create(Parent: TElement);
begin
  inherited(Parent);
  FSelectedID := '';
  SetStyle('gap', 'var(--space-4, 16px)');
  BuildHeader;
  BuildFilters;
  BuildList;
  FActionCard := TElement.Create('div', Self);
  FActionCard.AddClass(csHasCard);
  FActionCard.SetStyle('display', 'none');
end;

// ── Page header ───────────────────────────────────────────────────────────

procedure TPagePayments.BuildHeader;
var Header, Title: TElement;
    Pending, I: Integer;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  Title.SetText('Payments');

  Pending := 0;
  for I := 0 to HAS_Payments.Count - 1 do
    if HAS_Payments[I].Status = psPending then Inc(Pending);

  var Sub := TElement.Create('div', Header);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetText(IntToStr(HAS_Payments.Count) + ' total · ' +
              IntToStr(Pending) + ' pending');
end;

// ── Filter row ────────────────────────────────────────────────────────────

procedure TPagePayments.BuildFilters;
var Row, Opt: TElement;
begin
  Row := TElement.Create('div', Self);
  Row.SetStyle('display', 'flex');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('align-items', 'center');

  var Lbl := TElement.Create('label', Row);
  Lbl.AddClass(csFieldLabel);
  Lbl.SetStyle('margin', '0');
  Lbl.SetText('Status:');

  FStatusEl := TElement.Create('select', Row);
  FStatusEl.AddClass(csField);
  FStatusEl.SetStyle('width', 'auto');
  FStatusEl.SetStyle('height', 'auto');
  FStatusEl.SetStyle('padding', '8px 12px');

  Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', '');        Opt.SetText('All');
  Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', psPending); Opt.SetText('Pending');
  Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', psPaid);    Opt.SetText('Paid');

  FStatusEl.Handle.addEventListener('change', procedure(E: variant) begin RefreshList; end);
end;

// ── Table ─────────────────────────────────────────────────────────────────

procedure TPagePayments.BuildList;
begin
  FListWrap := TElement.Create('div', Self);
  FListWrap.AddClass(csHasTableWrap);
  FListWrap.SetHTML(ListHTML(''));

  FListWrap.Handle.addEventListener('click', procedure(E: variant)
  begin
    var pid: String;
    asm
      var tr = (@E).target.closest('tr[data-id]');
      @pid = tr ? tr.getAttribute('data-id') : '';
    end;
    if pid <> '' then ShowAction(pid);
  end);
end;

procedure TPagePayments.RefreshList;
begin
  FListWrap.SetHTML(ListHTML(FStatusEl.Handle.value));
  HideAction;
end;

// ── HTML generation ───────────────────────────────────────────────────────

function TPagePayments.ListHTML(const StatusFilter: String): String;
var HTML: String;
    I, Count: Integer;
    P: TPayment;
begin
  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>ID</th><th>Quote</th><th>Batch</th><th>Type</th>' +
    '<th style="text-align:right">Amount</th>' +
    '<th>Status</th><th>Paid</th><th>Reference</th>' +
    '</tr></thead><tbody>';

  Count := 0;
  for I := 0 to HAS_Payments.Count - 1 do
  begin
    P := HAS_Payments[I];
    if (StatusFilter <> '') and (P.Status <> StatusFilter) then continue;

    var TypeLabel: String;
    if P.PayType = ptSubsidy then
      TypeLabel := '<span class="has-status has-status-blue">Subsidy</span>'
    else
      TypeLabel := '<span class="has-status has-status-grey">Cust. Excess</span>';

    HTML := HTML +
      '<tr data-id="' + P.ID + '" style="cursor:pointer">' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + P.ID + '</td>' +
      '<td style="font-size:0.875rem">' + P.QuoteID + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + P.BatchID + '</td>' +
      '<td>' + TypeLabel + '</td>' +
      '<td style="text-align:right;font-size:0.875rem">' + FmtCur(P.Amount) + '</td>' +
      '<td>' + StatusBadge(P.Status) + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + FmtDate(P.PaidAt) + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + P.PaymentRef + '</td>' +
      '</tr>';
    Inc(Count);
  end;

  if Count = 0 then
    HTML := HTML +
      '<tr><td colspan="8" style="text-align:center;color:var(--text-light);padding:24px">' +
      'No payments found.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Result := HTML;
end;

// ── Action panel ─────────────────────────────────────────────────────────

procedure TPagePayments.HideAction;
begin
  FSelectedID := '';
  FActionCard.SetStyle('display', 'none');
  FActionCard.Clear;
end;

procedure TPagePayments.ShowAction(const PaymentID: String);
var P: TPayment;
    Idx: Integer;
    Perm: TPermissions;
begin
  Idx := FindPaymentIdx(PaymentID);
  if Idx < 0 then exit;
  P    := HAS_Payments[Idx];
  Perm := GetPermissions(CurrentRole);
  FSelectedID := PaymentID;

  FActionCard.Clear;
  FActionCard.SetStyle('display', 'block');

  var TitleEl := TElement.Create('div', FActionCard);
  TitleEl.AddClass('has-card-title');
  TitleEl.SetText('Payment ' + P.ID);

  var TypeLabel: String;
  if P.PayType = ptSubsidy then TypeLabel := 'Subsidy' else TypeLabel := 'Customer Excess';

  var SummaryDiv := TElement.Create('div', FActionCard);
  SummaryDiv.SetHTML(
    '<div style="display:grid;grid-template-columns:120px 1fr;gap:6px 16px;' +
    'font-size:0.875rem;margin-bottom:16px">' +
    '<span style="color:var(--text-light)">Quote:</span><span>' + P.QuoteID + '</span>' +
    '<span style="color:var(--text-light)">Batch:</span><span>' + P.BatchID + '</span>' +
    '<span style="color:var(--text-light)">Type:</span><span>' + TypeLabel + '</span>' +
    '<span style="color:var(--text-light)">Amount:</span><span>' + FmtCur(P.Amount) + '</span>' +
    '<span style="color:var(--text-light)">Status:</span><span>' + StatusBadge(P.Status) + '</span>' +
    '<span style="color:var(--text-light)">Paid At:</span><span>' + FmtDate(P.PaidAt) + '</span>' +
    '<span style="color:var(--text-light)">Reference:</span><span>' + P.PaymentRef + '</span>' +
    '</div>'
  );

  if (P.Status = psPending) and Perm.CanMakePayment then
  begin
    var Sep := TElement.Create('hr', FActionCard);
    Sep.SetStyle('border', 'none');
    Sep.SetStyle('border-top', '1px solid var(--border-color)');
    Sep.SetStyle('margin', '0 0 16px');

    var FormDiv := TElement.Create('div', FActionCard);
    FormDiv.SetStyle('display', 'flex');
    FormDiv.SetStyle('flex-direction', 'column');
    FormDiv.SetStyle('gap', '12px');

    var H := TElement.Create('div', FormDiv);
    H.SetStyle('font-weight', '600');
    H.SetText('Mark as Paid');

    var RefRow := TElement.Create('div', FormDiv);
    RefRow.AddClass(csFieldGroup);
    var Lbl := TElement.Create('label', RefRow);
    Lbl.AddClass(csFieldLabel);
    Lbl.SetText('Payment Reference');
    FRefEl := TElement.Create('input', RefRow);
    FRefEl.AddClass(csField);
    FRefEl.SetAttribute('placeholder', 'e.g. TXN-88221');

    var BtnPaid := TElement.Create('button', FormDiv);
    BtnPaid.AddClass(csHasBtnPrimary);
    BtnPaid.SetText('Mark Paid');
    BtnPaid.OnClick := lambda DoMarkPaid; end;
  end;

  var CloseBtn := TElement.Create('button', FActionCard);
  CloseBtn.AddClass(csHasBtn);
  CloseBtn.SetStyle('margin-top', '8px');
  CloseBtn.SetText('Close');
  CloseBtn.OnClick := lambda HideAction; end;
end;

// ── Action handlers ───────────────────────────────────────────────────────

procedure TPagePayments.DoMarkPaid;
var Ref: String;
begin
  Ref := FRefEl.Handle.value;
  if Ref = '' then exit;
  PaymentMarkPaid(FSelectedID, Ref);
  HideAction;
  RefreshList;
end;

end.
