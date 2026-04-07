unit PageQuotes;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PageQuotes — Quote list with per-row workflow action panel
//
//  constructor Create(Parent, InitFilter) — NOT override (extra parameter)
//  InitFilter = '' shows all quotes; stDisputed shows disputes only
//
//  Roles: All (filtered by permission)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPageQuotes = class(JW3Panel)
  private
    FInitFilter:  String;
    FStatusEl:    TElement;   // status filter <select> (nil on Disputes page)
    FListWrap:    TElement;   // table container
    FNewCard:     TElement;   // New Quote Request form card
    FActionCard:  TElement;   // action panel (per-row click)
    FSelectedID:  String;

    // New Quote form fields
    FReqCustEl:   TElement;
    FReqCtrEl:    TElement;
    FReqActEl:    TElement;
    FReqNotesEl:  TElement;

    // Action form fields (assigned by ShowAction)
    FDescEl:      TElement;
    FQtyEl:       TElement;
    FPriceEl:     TElement;
    FSubsidyEl:   TElement;
    FAssessNotes: TElement;
    FDisputeEl:   TElement;
    FResolveEl:   TElement;

    procedure BuildHeader;
    procedure BuildFilters;
    procedure BuildNewCard;
    procedure BuildList;
    procedure RefreshList;
    function  ListHTML(const StatusFilter: String): String;
    procedure ShowNewCard;
    procedure HideNewCard;
    procedure ShowAction(const QuoteID: String);
    procedure HideAction;
    function  AddInputRow(Parent: TElement; const LabelText, InputType: String): TElement;
    function  AddTextareaRow(Parent: TElement; const LabelText: String): TElement;
    procedure DoRequestQuote;
    procedure DoSubmitQuote;
    procedure DoAcceptQuote;
    procedure DoAssessQuote;
    procedure DoMarkReady;
    procedure DoComplete;
    procedure DoVerify;
    procedure DoDispute;
    procedure DoResolveDispute;
  public
    constructor Create(Parent: TElement); override;
    procedure Build(const Filter: String);
  end;

implementation

uses Globals, HASData, HASPermissions, HASTypes, HASStyles, ThemeStyles;

{ TPageQuotes }

constructor TPageQuotes.Create(Parent: TElement);
begin
  inherited(Parent);
  FSelectedID := '';
  SetStyle('gap', 'var(--space-4, 16px)');
end;

procedure TPageQuotes.Build(const Filter: String);
begin
  FInitFilter := Filter;
  BuildHeader;
  BuildFilters;
  BuildNewCard;
  BuildList;
  FActionCard := TElement.Create('div', Self);
  FActionCard.AddClass(csHasCard);
  FActionCard.SetStyle('display', 'none');
end;

// ── Page header ───────────────────────────────────────────────────────────

procedure TPageQuotes.BuildHeader;
var Header, Title: TElement;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  if FInitFilter = stDisputed then
    Title.SetText('Disputes')
  else
    Title.SetText('Quotes');

  var Sub := TElement.Create('div', Header);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetText(IntToStr(HAS_Quotes.Count) + ' total');
end;

// ── Filter row ────────────────────────────────────────────────────────────

procedure TPageQuotes.BuildFilters;
var Row, Opt: TElement;
    P: TPermissions;
begin
  P := GetPermissions(CurrentRole);

  Row := TElement.Create('div', Self);
  Row.SetStyle('display', 'flex');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('align-items', 'center');

  if FInitFilter <> stDisputed then
  begin
    var Lbl := TElement.Create('label', Row);
    Lbl.AddClass(csFieldLabel);
    Lbl.SetStyle('margin', '0');
    Lbl.SetText('Status:');

    FStatusEl := TElement.Create('select', Row);
    FStatusEl.AddClass(csField);
    FStatusEl.SetStyle('width', 'auto');
    FStatusEl.SetStyle('height', 'auto');
    FStatusEl.SetStyle('padding', '8px 12px');

    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', '');                   Opt.SetText('All');
    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stRequested);           Opt.SetText('Requested');
    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stSubmitted);           Opt.SetText('Submitted');
    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stAcceptedByCustomer);  Opt.SetText('Accepted');
    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stAssessed);            Opt.SetText('Assessed');
    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stReadyForBatch);       Opt.SetText('Ready for Batch');
    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stWorkCommenced);       Opt.SetText('Work Commenced');
    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stCompleted);           Opt.SetText('Completed');
    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stVerified);            Opt.SetText('Verified');
    Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stDisputed);            Opt.SetText('Disputed');

    FStatusEl.Handle.addEventListener('change', procedure(E: variant) begin RefreshList; end);
  end
  else
    FStatusEl := nil;

  if P.CanRequestQuote then
  begin
    var Spacer := TElement.Create('div', Row);
    Spacer.SetStyle('flex', '1');
    var BtnNew := TElement.Create('button', Row);
    BtnNew.AddClass(csHasBtnPrimary);
    BtnNew.SetText('+ New Quote Request');
    BtnNew.OnClick := lambda ShowNewCard; end;
  end;
end;

// ── New Quote Request card ─────────────────────────────────────────────────

procedure TPageQuotes.BuildNewCard;
var Opt: TElement;
    I: Integer;
    P: TPermissions;
begin
  P := GetPermissions(CurrentRole);
  if not P.CanRequestQuote then
  begin
    FNewCard := TElement.Create('div', Self);
    FNewCard.SetStyle('display', 'none');
    exit;
  end;

  FNewCard := TElement.Create('div', Self);
  FNewCard.AddClass(csHasCard);
  FNewCard.SetStyle('display', 'none');

  var TitleEl := TElement.Create('div', FNewCard);
  TitleEl.AddClass('has-card-title');
  TitleEl.SetText('New Quote Request');

  var FormRows := TElement.Create('div', FNewCard);
  FormRows.SetStyle('display', 'flex');
  FormRows.SetStyle('flex-direction', 'column');
  FormRows.SetStyle('gap', '12px');

  // Customer select
  var CustRow := TElement.Create('div', FormRows);
  CustRow.AddClass(csFieldGroup);
  var CustLbl := TElement.Create('label', CustRow);
  CustLbl.AddClass(csFieldLabel);
  CustLbl.SetText('Customer');
  FReqCustEl := TElement.Create('select', CustRow);
  FReqCustEl.AddClass(csField);
  if CurrentRole = roleCustomer then
  begin
    Opt := TElement.Create('option', FReqCustEl);
    Opt.SetAttribute('value', CurrentCustomerID);
    Opt.SetText(CustomerFullName(CurrentCustomerID));
  end
  else
    for I := 0 to HAS_Customers.Count - 1 do
    begin
      Opt := TElement.Create('option', FReqCustEl);
      Opt.SetAttribute('value', HAS_Customers[I].ID);
      Opt.SetText(HAS_Customers[I].FirstName + ' ' + HAS_Customers[I].LastName);
    end;

  // Contractor select (active only)
  var CtrRow := TElement.Create('div', FormRows);
  CtrRow.AddClass(csFieldGroup);
  var CtrLbl := TElement.Create('label', CtrRow);
  CtrLbl.AddClass(csFieldLabel);
  CtrLbl.SetText('Contractor');
  FReqCtrEl := TElement.Create('select', CtrRow);
  FReqCtrEl.AddClass(csField);
  for I := 0 to HAS_Contractors.Count - 1 do
    if HAS_Contractors[I].Status = stActive then
    begin
      Opt := TElement.Create('option', FReqCtrEl);
      Opt.SetAttribute('value', HAS_Contractors[I].ID);
      Opt.SetText(HAS_Contractors[I].BusinessName);
    end;

  // Activity select
  var ActRow := TElement.Create('div', FormRows);
  ActRow.AddClass(csFieldGroup);
  var ActLbl := TElement.Create('label', ActRow);
  ActLbl.AddClass(csFieldLabel);
  ActLbl.SetText('Activity');
  FReqActEl := TElement.Create('select', ActRow);
  FReqActEl.AddClass(csField);
  for I := 0 to HAS_Activities.Count - 1 do
  begin
    Opt := TElement.Create('option', FReqActEl);
    Opt.SetAttribute('value', HAS_Activities[I].ID);
    Opt.SetText(HAS_Activities[I].Name + ' (' + HAS_Activities[I].Program + ')');
  end;

  // Notes
  FReqNotesEl := AddTextareaRow(FormRows, 'Notes');

  // Buttons
  var BtnRow := TElement.Create('div', FNewCard);
  BtnRow.SetStyle('display', 'flex');
  BtnRow.SetStyle('gap', '8px');
  BtnRow.SetStyle('margin-top', '4px');

  var BtnSubmit := TElement.Create('button', BtnRow);
  BtnSubmit.AddClass(csHasBtnPrimary);
  BtnSubmit.SetText('Request Quote');
  BtnSubmit.OnClick := lambda DoRequestQuote; end;

  var BtnCancel := TElement.Create('button', BtnRow);
  BtnCancel.AddClass(csHasBtn);
  BtnCancel.SetText('Cancel');
  BtnCancel.OnClick := lambda HideNewCard; end;
end;

procedure TPageQuotes.ShowNewCard;
begin
  FNewCard.SetStyle('display', 'block');
end;

procedure TPageQuotes.HideNewCard;
begin
  FNewCard.SetStyle('display', 'none');
end;

// ── Table ─────────────────────────────────────────────────────────────────

procedure TPageQuotes.BuildList;
begin
  FListWrap := TElement.Create('div', Self);
  FListWrap.AddClass(csHasTableWrap);
  FListWrap.SetHTML(ListHTML(FInitFilter));

  FListWrap.Handle.addEventListener('click', procedure(E: variant)
  begin
    var qid: String;
    asm
      var tr = (@E).target.closest('tr[data-id]');
      @qid = tr ? tr.getAttribute('data-id') : '';
    end;
    if qid <> '' then ShowAction(qid);
  end);
end;

procedure TPageQuotes.RefreshList;
var Filter: String;
begin
  if FInitFilter = stDisputed then
    Filter := stDisputed
  else if FStatusEl <> nil then
    Filter := FStatusEl.Handle.value
  else
    Filter := '';
  FListWrap.SetHTML(ListHTML(Filter));
  HideAction;
end;

// ── HTML generation ───────────────────────────────────────────────────────

function TPageQuotes.ListHTML(const StatusFilter: String): String;
var HTML: String;
    I, Count: Integer;
    Q: TQuote;
begin
  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>ID</th><th>Customer</th><th>Contractor</th><th>Activity</th>' +
    '<th style="text-align:right">Total</th><th>Status</th><th>Requested</th>' +
    '</tr></thead><tbody>';

  Count := 0;
  for I := 0 to HAS_Quotes.Count - 1 do
  begin
    Q := HAS_Quotes[I];
    if (StatusFilter <> '') and (Q.Status <> StatusFilter) then continue;
    // Contractor sees only their quotes
    if (CurrentRole = roleContractor) and (Q.ContractorID <> CurrentContractorID) then continue;
    // Customer sees only their quotes
    if (CurrentRole = roleCustomer) and (Q.CustomerID <> CurrentCustomerID) then continue;

    HTML := HTML +
      '<tr data-id="' + Q.ID + '" style="cursor:pointer">' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + Q.ID + '</td>' +
      '<td><strong>' + CustomerFullName(Q.CustomerID) + '</strong></td>' +
      '<td style="font-size:0.875rem">' + ContractorBizName(Q.ContractorID) + '</td>' +
      '<td style="font-size:0.875rem">' + ActivityName(Q.ActivityID) + '</td>' +
      '<td style="text-align:right;font-size:0.875rem">' + FmtCur(Q.Total) + '</td>' +
      '<td>' + StatusBadge(Q.Status) + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + FmtDate(Q.RequestedAt) + '</td>' +
      '</tr>';
    Inc(Count);
  end;

  if Count = 0 then
    HTML := HTML +
      '<tr><td colspan="7" style="text-align:center;color:var(--text-light);padding:24px">' +
      'No quotes found.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Result := HTML;
end;

// ── Field helpers ─────────────────────────────────────────────────────────

function TPageQuotes.AddInputRow(Parent: TElement; const LabelText, InputType: String): TElement;
var Row, Lbl: TElement;
begin
  Row := TElement.Create('div', Parent);
  Row.AddClass(csFieldGroup);
  Lbl := TElement.Create('label', Row);
  Lbl.AddClass(csFieldLabel);
  Lbl.SetText(LabelText);
  Result := TElement.Create('input', Row);
  Result.AddClass(csField);
  if InputType <> '' then
    Result.SetAttribute('type', InputType);
end;

function TPageQuotes.AddTextareaRow(Parent: TElement; const LabelText: String): TElement;
var Row, Lbl: TElement;
begin
  Row := TElement.Create('div', Parent);
  Row.AddClass(csFieldGroup);
  Lbl := TElement.Create('label', Row);
  Lbl.AddClass(csFieldLabel);
  Lbl.SetText(LabelText);
  Result := TElement.Create('textarea', Row);
  Result.AddClass(csField);
  Result.SetStyle('height', '64px');
end;

// ── Action panel ─────────────────────────────────────────────────────────

procedure TPageQuotes.HideAction;
begin
  FSelectedID := '';
  FActionCard.SetStyle('display', 'none');
  FActionCard.Clear;
end;

procedure TPageQuotes.ShowAction(const QuoteID: String);
var Q: TQuote;
    Idx: Integer;
    P: TPermissions;
    FormSection, BtnEl: TElement;
    SummaryHTML: String;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  Q := HAS_Quotes[Idx];
  P := GetPermissions(CurrentRole);
  FSelectedID := QuoteID;

  FActionCard.Clear;
  FActionCard.SetStyle('display', 'block');

  // ── Title ──────────────────────────────────────────────────────────────
  var TitleEl := TElement.Create('div', FActionCard);
  TitleEl.AddClass('has-card-title');
  TitleEl.SetText('Quote ' + Q.ID);

  // ── Summary ────────────────────────────────────────────────────────────
  SummaryHTML :=
    '<div style="display:grid;grid-template-columns:150px 1fr;gap:6px 16px;' +
    'font-size:0.875rem;margin-bottom:16px">' +
    '<span style="color:var(--text-light)">Customer:</span>' +
      '<span>' + CustomerFullName(Q.CustomerID) + '</span>' +
    '<span style="color:var(--text-light)">Contractor:</span>' +
      '<span>' + ContractorBizName(Q.ContractorID) + '</span>' +
    '<span style="color:var(--text-light)">Activity:</span>' +
      '<span>' + ActivityName(Q.ActivityID) + '</span>' +
    '<span style="color:var(--text-light)">Status:</span>' +
      '<span>' + StatusBadge(Q.Status) + '</span>';

  if Q.Total > 0 then
    SummaryHTML := SummaryHTML +
      '<span style="color:var(--text-light)">Total:</span><span>' + FmtCur(Q.Total) + '</span>' +
      '<span style="color:var(--text-light)">Subsidy:</span><span>' + FmtCur(Q.SubsidyAmount) + '</span>' +
      '<span style="color:var(--text-light)">Customer Excess:</span><span>' + FmtCur(Q.CustomerExcess) + '</span>';

  if Q.AssessmentNotes <> '' then
    SummaryHTML := SummaryHTML +
      '<span style="color:var(--text-light)">Assessment:</span><span>' + Q.AssessmentNotes + '</span>';

  if Q.DisputeReason <> '' then
    SummaryHTML := SummaryHTML +
      '<span style="color:var(--text-light)">Dispute reason:</span><span>' + Q.DisputeReason + '</span>';

  SummaryHTML := SummaryHTML + '</div>';

  var SummaryDiv := TElement.Create('div', FActionCard);
  SummaryDiv.SetHTML(SummaryHTML);

  // ── Separator ──────────────────────────────────────────────────────────
  var Sep := TElement.Create('hr', FActionCard);
  Sep.SetStyle('border', 'none');
  Sep.SetStyle('border-top', '1px solid var(--border-color)');
  Sep.SetStyle('margin', '0 0 16px');

  // ── Action form ────────────────────────────────────────────────────────
  FormSection := TElement.Create('div', FActionCard);
  FormSection.SetStyle('display', 'flex');
  FormSection.SetStyle('flex-direction', 'column');
  FormSection.SetStyle('gap', '12px');

  // Contractor submits quote
  if (Q.Status = stRequested) and P.CanSubmitQuote and
     (CurrentContractorID = Q.ContractorID) then
  begin
    var H := TElement.Create('div', FormSection);
    H.SetStyle('font-weight', '600');
    H.SetText('Submit Quote');

    FDescEl := AddInputRow(FormSection, 'Description', 'text');
    FDescEl.SetAttribute('placeholder', 'Line item description');

    var TwoCol := TElement.Create('div', FormSection);
    TwoCol.SetStyle('display', 'grid');
    TwoCol.SetStyle('grid-template-columns', '1fr 1fr');
    TwoCol.SetStyle('gap', '12px');
    FQtyEl   := AddInputRow(TwoCol, 'Qty', 'number');
    FQtyEl.SetAttribute('value', '1');
    FPriceEl := AddInputRow(TwoCol, 'Price (ex GST)', 'number');
    FPriceEl.SetAttribute('step', '0.01');

    BtnEl := TElement.Create('button', FormSection);
    BtnEl.AddClass(csHasBtnPrimary);
    BtnEl.SetText('Submit Quote');
    BtnEl.OnClick := lambda DoSubmitQuote; end;
  end

  // Customer accepts / Assessor assesses
  else if (Q.Status = stSubmitted) or (Q.Status = stAcceptedByCustomer) then
  begin
    if P.CanAcceptQuote and (Q.Status = stSubmitted) and
       (CurrentCustomerID = Q.CustomerID) then
    begin
      var H := TElement.Create('div', FormSection);
      H.SetText('Total: ' + FmtCur(Q.Total) + '  (subsidy may apply after assessment)');
      H.SetStyle('font-size', '0.875rem');
      H.SetStyle('color', 'var(--text-light)');
      BtnEl := TElement.Create('button', FormSection);
      BtnEl.AddClass(csHasBtnPrimary);
      BtnEl.SetText('Accept Quote');
      BtnEl.OnClick := lambda DoAcceptQuote; end;
    end;

    if P.CanAssessQuote then
    begin
      var H := TElement.Create('div', FormSection);
      H.SetStyle('font-weight', '600');
      H.SetText('Assess Quote');
      FSubsidyEl   := AddInputRow(FormSection, 'Subsidy Amount ($)', 'number');
      FSubsidyEl.SetAttribute('step', '0.01');
      FAssessNotes := AddTextareaRow(FormSection, 'Assessment Notes');
      BtnEl := TElement.Create('button', FormSection);
      BtnEl.AddClass(csHasBtnPrimary);
      BtnEl.SetText('Save Assessment');
      BtnEl.OnClick := lambda DoAssessQuote; end;
    end;
  end

  // Admin marks assessed quote ready for batch
  else if Q.Status = stAssessed then
  begin
    if P.CanCreateBatch then
    begin
      var H := TElement.Create('div', FormSection);
      H.SetStyle('font-size', '0.875rem');
      H.SetStyle('color', 'var(--text-light)');
      H.SetText('Quote assessed. Approve it for inclusion in a payment batch.');
      BtnEl := TElement.Create('button', FormSection);
      BtnEl.AddClass(csHasBtnPrimary);
      BtnEl.SetText('Mark Ready for Batch');
      BtnEl.OnClick := lambda DoMarkReady; end;
    end;
  end

  // Awaiting batch
  else if Q.Status = stReadyForBatch then
  begin
    var H := TElement.Create('div', FormSection);
    H.SetStyle('font-size', '0.875rem');
    H.SetStyle('color', 'var(--text-light)');
    H.SetText('Approved — awaiting inclusion in a payment batch.');
  end

  // Work in progress
  else if Q.Status = stWorkCommenced then
  begin
    if P.CanSubmitQuote and (CurrentContractorID = Q.ContractorID) then
    begin
      BtnEl := TElement.Create('button', FormSection);
      BtnEl.AddClass(csHasBtnPrimary);
      BtnEl.SetText('Mark Work Complete');
      BtnEl.OnClick := lambda DoComplete; end;
    end;
    if P.CanVerifyWork and (CurrentCustomerID = Q.CustomerID) then
    begin
      BtnEl := TElement.Create('button', FormSection);
      BtnEl.AddClass(csHasBtnPrimary);
      BtnEl.SetText('Verify Work Complete');
      BtnEl.OnClick := lambda DoVerify; end;
      FDisputeEl := AddTextareaRow(FormSection, 'Dispute Reason');
      BtnEl := TElement.Create('button', FormSection);
      BtnEl.AddClass(csHasBtnDanger);
      BtnEl.SetText('Raise Dispute');
      BtnEl.OnClick := lambda DoDispute; end;
    end;
  end

  // Work reported complete
  else if Q.Status = stCompleted then
  begin
    if P.CanVerifyWork and (CurrentCustomerID = Q.CustomerID) then
    begin
      BtnEl := TElement.Create('button', FormSection);
      BtnEl.AddClass(csHasBtnPrimary);
      BtnEl.SetText('Verify Work Complete');
      BtnEl.OnClick := lambda DoVerify; end;
      FDisputeEl := AddTextareaRow(FormSection, 'Dispute Reason');
      BtnEl := TElement.Create('button', FormSection);
      BtnEl.AddClass(csHasBtnDanger);
      BtnEl.SetText('Raise Dispute');
      BtnEl.OnClick := lambda DoDispute; end;
    end;
  end

  // Disputed — resolve
  else if Q.Status = stDisputed then
  begin
    if P.CanResolveDispute then
    begin
      var H := TElement.Create('div', FormSection);
      H.SetStyle('font-weight', '600');
      H.SetText('Resolve Dispute');
      FResolveEl := AddTextareaRow(FormSection, 'Outcome / Resolution');
      BtnEl := TElement.Create('button', FormSection);
      BtnEl.AddClass(csHasBtnPrimary);
      BtnEl.SetText('Resolve Dispute');
      BtnEl.OnClick := lambda DoResolveDispute; end;
    end;
  end;

  // Close button
  var CloseBtn := TElement.Create('button', FActionCard);
  CloseBtn.AddClass(csHasBtn);
  CloseBtn.SetStyle('margin-top', '8px');
  CloseBtn.SetText('Close');
  CloseBtn.OnClick := lambda HideAction; end;
end;

// ── Action handlers ───────────────────────────────────────────────────────

procedure TPageQuotes.DoRequestQuote;
var CustID, CtrID, ActID, Notes: String;
begin
  CustID := FReqCustEl.Handle.value;
  CtrID  := FReqCtrEl.Handle.value;
  ActID  := FReqActEl.Handle.value;
  Notes  := FReqNotesEl.Handle.value;
  if (CustID = '') or (CtrID = '') or (ActID = '') then exit;
  QuoteRequest(CustID, CtrID, ActID, Notes);
  HideNewCard;
  RefreshList;
end;

procedure TPageQuotes.DoSubmitQuote;
var Desc: String;
    Qty: Integer;
    Price: Float;
begin
  Desc := FDescEl.Handle.value;
  if Desc = '' then exit;
  asm
    @Qty   = Math.max(1, parseInt((@FQtyEl).Handle.value, 10) || 1);
    @Price = parseFloat((@FPriceEl).Handle.value) || 0;
  end;
  if Price <= 0 then exit;
  QuoteSubmit(FSelectedID, Desc, Qty, Price);
  HideAction;
  RefreshList;
end;

procedure TPageQuotes.DoAcceptQuote;
begin
  QuoteAccept(FSelectedID);
  HideAction;
  RefreshList;
end;

procedure TPageQuotes.DoAssessQuote;
var SubsidyAmt: Float;
    Notes: String;
begin
  asm @SubsidyAmt = parseFloat((@FSubsidyEl).Handle.value) || 0; end;
  Notes := FAssessNotes.Handle.value;
  QuoteAssess(FSelectedID, SubsidyAmt, Notes);
  HideAction;
  RefreshList;
end;

procedure TPageQuotes.DoMarkReady;
begin
  QuoteMarkReady(FSelectedID);
  HideAction;
  RefreshList;
end;

procedure TPageQuotes.DoComplete;
begin
  QuoteComplete(FSelectedID);
  HideAction;
  RefreshList;
end;

procedure TPageQuotes.DoVerify;
begin
  QuoteVerify(FSelectedID);
  HideAction;
  RefreshList;
end;

procedure TPageQuotes.DoDispute;
var Reason: String;
begin
  Reason := FDisputeEl.Handle.value;
  if Reason = '' then exit;
  QuoteDispute(FSelectedID, Reason);
  HideAction;
  RefreshList;
end;

procedure TPageQuotes.DoResolveDispute;
var Outcome: String;
begin
  Outcome := FResolveEl.Handle.value;
  if Outcome = '' then exit;
  QuoteResolveDispute(FSelectedID, Outcome);
  HideAction;
  RefreshList;
end;

end.
