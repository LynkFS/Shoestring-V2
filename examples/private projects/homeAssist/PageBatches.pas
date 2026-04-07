unit PageBatches;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PageBatches — Payment batch list with create and send actions
//
//  Roles: Administrator, PaymentOfficer (CanCreateBatch, CanSendBatch)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPageBatches = class(JW3Panel)
  private
    FListWrap:   TElement;
    FNewCard:    TElement;   // Create batch form
    FActionCard: TElement;   // Batch detail panel
    FSelectedID: String;

    // Create-batch form
    FContractorEl: TElement;

    procedure BuildHeader;
    procedure BuildNewCard;
    procedure BuildList;
    procedure RefreshList;
    function  ListHTML: String;
    procedure ShowAction(const BatchID: String);
    procedure HideAction;
    procedure ShowNewCard;
    procedure HideNewCard;
    procedure DoCreateBatch;
    procedure DoSendBatch;
  public
    constructor Create(Parent: TElement); override;
  end;

implementation

uses Globals, HASData, HASPermissions, HASTypes, HASStyles, ThemeStyles;

{ TPageBatches }

constructor TPageBatches.Create(Parent: TElement);
begin
  inherited(Parent);
  FSelectedID := '';
  SetStyle('gap', 'var(--space-4, 16px)');
  BuildHeader;
  BuildNewCard;
  BuildList;
  FActionCard := TElement.Create('div', Self);
  FActionCard.AddClass(csHasCard);
  FActionCard.SetStyle('display', 'none');
end;

// ── Page header ───────────────────────────────────────────────────────────

procedure TPageBatches.BuildHeader;
var Header, Title: TElement;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  Title.SetText('Payment Batches');

  var Sub := TElement.Create('div', Header);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetText(IntToStr(HAS_Batches.Count) + ' total');

  var P := GetPermissions(CurrentRole);
  if P.CanCreateBatch then
  begin
    // Count how many quotes are ready for batching
    var ReadyCount := 0;
    var I: Integer;
    for I := 0 to HAS_Quotes.Count - 1 do
      if HAS_Quotes[I].Status = stReadyForBatch then Inc(ReadyCount);

    var BtnNew := TElement.Create('button', Header);
    BtnNew.AddClass(csHasBtnPrimary);
    BtnNew.SetText('Create Batch (' + IntToStr(ReadyCount) + ' ready)');
    BtnNew.OnClick := lambda ShowNewCard; end;
  end;
end;

// ── Create Batch card ─────────────────────────────────────────────────────

procedure TPageBatches.BuildNewCard;
var Opt: TElement;
    I: Integer;
    P: TPermissions;
begin
  P := GetPermissions(CurrentRole);

  FNewCard := TElement.Create('div', Self);
  FNewCard.AddClass(csHasCard);
  FNewCard.SetStyle('display', 'none');

  if not P.CanCreateBatch then exit;

  var TitleEl := TElement.Create('div', FNewCard);
  TitleEl.AddClass('has-card-title');
  TitleEl.SetText('Create Payment Batch');

  var Sub := TElement.Create('div', FNewCard);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetStyle('margin-bottom', '12px');
  Sub.SetText('All "Ready for Batch" quotes for the selected contractor will be grouped into a new batch.');

  var Row := TElement.Create('div', FNewCard);
  Row.AddClass(csFieldGroup);
  var Lbl := TElement.Create('label', Row);
  Lbl.AddClass(csFieldLabel);
  Lbl.SetText('Contractor');
  FContractorEl := TElement.Create('select', Row);
  FContractorEl.AddClass(csField);

  // Only show contractors that have ReadyForBatch quotes
  for I := 0 to HAS_Contractors.Count - 1 do
  begin
    var HasReady := false;
    var J: Integer;
    for J := 0 to HAS_Quotes.Count - 1 do
      if (HAS_Quotes[J].Status = stReadyForBatch) and
         (HAS_Quotes[J].ContractorID = HAS_Contractors[I].ID) then
      begin
        HasReady := true;
        break;
      end;
    if HasReady then
    begin
      Opt := TElement.Create('option', FContractorEl);
      Opt.SetAttribute('value', HAS_Contractors[I].ID);
      Opt.SetText(HAS_Contractors[I].BusinessName);
    end;
  end;

  var BtnRow := TElement.Create('div', FNewCard);
  BtnRow.SetStyle('display', 'flex');
  BtnRow.SetStyle('gap', '8px');
  BtnRow.SetStyle('margin-top', '12px');

  var BtnCreate := TElement.Create('button', BtnRow);
  BtnCreate.AddClass(csHasBtnPrimary);
  BtnCreate.SetText('Create Batch');
  BtnCreate.OnClick := lambda DoCreateBatch; end;

  var BtnCancel := TElement.Create('button', BtnRow);
  BtnCancel.AddClass(csHasBtn);
  BtnCancel.SetText('Cancel');
  BtnCancel.OnClick := lambda HideNewCard; end;
end;

procedure TPageBatches.ShowNewCard;
begin
  FNewCard.SetStyle('display', 'block');
end;

procedure TPageBatches.HideNewCard;
begin
  FNewCard.SetStyle('display', 'none');
end;

// ── Table ─────────────────────────────────────────────────────────────────

procedure TPageBatches.BuildList;
begin
  FListWrap := TElement.Create('div', Self);
  FListWrap.AddClass(csHasTableWrap);
  FListWrap.SetHTML(ListHTML);

  FListWrap.Handle.addEventListener('click', procedure(E: variant)
  begin
    var bid: String;
    asm
      var tr = (@E).target.closest('tr[data-id]');
      @bid = tr ? tr.getAttribute('data-id') : '';
    end;
    if bid <> '' then ShowAction(bid);
  end);
end;

procedure TPageBatches.RefreshList;
begin
  FListWrap.SetHTML(ListHTML);
  HideAction;
end;

// ── HTML generation ───────────────────────────────────────────────────────

function TPageBatches.ListHTML: String;
var HTML: String;
    I, Count: Integer;
    B: TBatch;
begin
  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>ID</th><th>Contractor</th><th>Quotes</th>' +
    '<th>Status</th><th>Created</th><th>Sent</th>' +
    '</tr></thead><tbody>';

  Count := 0;
  for I := 0 to HAS_Batches.Count - 1 do
  begin
    B := HAS_Batches[I];
    HTML := HTML +
      '<tr data-id="' + B.ID + '" style="cursor:pointer">' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + B.ID + '</td>' +
      '<td><strong>' + ContractorBizName(B.ContractorID) + '</strong></td>' +
      '<td style="text-align:center">' + IntToStr(B.QuoteIDs.Count) + '</td>' +
      '<td>' + StatusBadge(B.Status) + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + FmtDate(B.CreatedAt) + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + FmtDate(B.SentAt) + '</td>' +
      '</tr>';
    Inc(Count);
  end;

  if Count = 0 then
    HTML := HTML +
      '<tr><td colspan="6" style="text-align:center;color:var(--text-light);padding:24px">' +
      'No batches found.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Result := HTML;
end;

// ── Action panel ─────────────────────────────────────────────────────────

procedure TPageBatches.HideAction;
begin
  FSelectedID := '';
  FActionCard.SetStyle('display', 'none');
  FActionCard.Clear;
end;

procedure TPageBatches.ShowAction(const BatchID: String);
var B: TBatch;
    Idx: Integer;
    P: TPermissions;
    QuotesHTML: String;
    I: Integer;
begin
  Idx := FindBatchIdx(BatchID);
  if Idx < 0 then exit;
  B := HAS_Batches[Idx];
  P := GetPermissions(CurrentRole);
  FSelectedID := BatchID;

  FActionCard.Clear;
  FActionCard.SetStyle('display', 'block');

  var TitleEl := TElement.Create('div', FActionCard);
  TitleEl.AddClass('has-card-title');
  TitleEl.SetText('Batch ' + B.ID);

  // Summary
  var SummaryDiv := TElement.Create('div', FActionCard);
  SummaryDiv.SetHTML(
    '<div style="display:grid;grid-template-columns:120px 1fr;gap:6px 16px;' +
    'font-size:0.875rem;margin-bottom:16px">' +
    '<span style="color:var(--text-light)">Contractor:</span>' +
      '<span>' + ContractorBizName(B.ContractorID) + '</span>' +
    '<span style="color:var(--text-light)">Status:</span>' +
      '<span>' + StatusBadge(B.Status) + '</span>' +
    '<span style="color:var(--text-light)">Created:</span>' +
      '<span>' + FmtDate(B.CreatedAt) + '</span>' +
    '<span style="color:var(--text-light)">Sent:</span>' +
      '<span>' + FmtDate(B.SentAt) + '</span>' +
    '</div>'
  );

  // Quotes in this batch
  var QuotesTitle := TElement.Create('div', FActionCard);
  QuotesTitle.SetStyle('font-weight', '600');
  QuotesTitle.SetStyle('font-size', '0.875rem');
  QuotesTitle.SetStyle('margin-bottom', '8px');
  QuotesTitle.SetText('Quotes in this batch (' + IntToStr(B.QuoteIDs.Count) + ')');

  QuotesHTML := '<ul style="margin:0;padding:0 0 0 16px;font-size:0.875rem;' +
                'color:var(--text-color)">';
  for I := 0 to B.QuoteIDs.Count - 1 do
  begin
    var QIdx := FindQuoteIdx(B.QuoteIDs[I]);
    if QIdx >= 0 then
      QuotesHTML := QuotesHTML +
        '<li>' + B.QuoteIDs[I] + ' — ' +
        CustomerFullName(HAS_Quotes[QIdx].CustomerID) + ' · ' +
        ActivityName(HAS_Quotes[QIdx].ActivityID) + ' · ' +
        FmtCur(HAS_Quotes[QIdx].Total) + '</li>'
    else
      QuotesHTML := QuotesHTML + '<li>' + B.QuoteIDs[I] + '</li>';
  end;
  QuotesHTML := QuotesHTML + '</ul>';

  var QuotesList := TElement.Create('div', FActionCard);
  QuotesList.SetHTML(QuotesHTML);
  QuotesList.SetStyle('margin-bottom', '16px');

  // Send button
  if (B.Status = bsPending) and P.CanSendBatch then
  begin
    var BtnSend := TElement.Create('button', FActionCard);
    BtnSend.AddClass(csHasBtnPrimary);
    BtnSend.SetText('Send Batch to Contractor');
    BtnSend.OnClick := lambda DoSendBatch; end;
  end;

  // Close button
  var CloseBtn := TElement.Create('button', FActionCard);
  CloseBtn.AddClass(csHasBtn);
  CloseBtn.SetStyle('margin-top', '8px');
  CloseBtn.SetText('Close');
  CloseBtn.OnClick := lambda HideAction; end;
end;

// ── Action handlers ───────────────────────────────────────────────────────

procedure TPageBatches.DoCreateBatch;
var ContractorID: String;
begin
  ContractorID := FContractorEl.Handle.value;
  if ContractorID = '' then exit;
  BatchCreate(ContractorID);
  HideNewCard;
  RefreshList;
end;

procedure TPageBatches.DoSendBatch;
begin
  BatchSend(FSelectedID);
  HideAction;
  RefreshList;
end;

end.
