unit FormInvoiceDetail;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormInvoiceDetail — read-only invoice view
//
//  Document layout. Shows full invoice: header meta, client card,
//  line items table, totals, notes. Action toolbar: back, edit,
//  mark as sent/paid, delete.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JForm;

type
  TFormInvoiceDetail = class(TW3Form)
  protected
    procedure InitializeObject; override;
    procedure Show; override;
  end;

implementation

uses
  Globals,
  ThemeStyles, TypographyStyles, InvoiceStyles,
  JPanel, JLabel, JButton, JBadge, JModal,
  JToast,
  InvoiceData, FormInvoiceList;

procedure TFormInvoiceDetail.InitializeObject;
begin
  inherited;
end;

procedure TFormInvoiceDetail.Show;
var
  Inv:    TInvoice;
  Client: TClient;
  Tbl:    TElement;

  procedure AddTotalRow(const Key, Val: String; IsTotal: Boolean = false);
  var Row: TElement;
  begin
    Row := TElement.Create('div', Tbl);
    Row.AddClass('inv-totals-row');
    if IsTotal then Row.AddClass('total');
    var K := TElement.Create('div', Row);
    K.AddClass('key');
    K.SetText(Key);
    var V := TElement.Create('div', Row);
    V.AddClass('val');
    V.SetText(Val);
  end;

begin
  Self.Clear;
  if ActiveInvoiceID = 0 then exit;

  Inv := Store.FindInvoice(ActiveInvoiceID);
  if Inv.ID = 0 then exit;

  Client := Store.FindClient(Inv.ClientID);

  // ── Top action bar ────────────────────────────────────────────────

  var Bar := JW3Panel.Create(Self);
  Bar.SetStyle('flex-direction', 'row');
  Bar.SetStyle('align-items', 'center');
  Bar.SetStyle('gap', '8px');
  Bar.SetStyle('padding', '12px 24px');
  Bar.SetStyle('background', 'var(--surface-color, #fff)');
  Bar.SetStyle('border-bottom', '1px solid var(--border-color, #e2e8f0)');
  Bar.SetStyle('flex-shrink', '0');

  var BtnBack := JW3Button.Create(Bar);
  BtnBack.Caption := '<< Back';
  BtnBack.AddClass(csBtnGhost);
  BtnBack.AddClass(csBtnSmall);
  BtnBack.OnClick := procedure(Sender: TObject)
  begin
    Application.GoToForm('InvoiceList');
  end;

  var InvTitle := JW3Label.Create(Bar);
  InvTitle.SetText(Inv.Number);
  InvTitle.AddClass(csFontBold);
  InvTitle.SetStyle('font-size', '1rem');
  InvTitle.SetStyle('margin-left', '8px');

  var StatusBadge := JW3Badge.Create(Bar);
  StatusBadge.SetText(Store.StatusLabel(Inv.Status));
  StatusBadge.AddClass(Store.StatusBadgeClass(Inv.Status));

  var Spacer := TElement.Create('div', Bar);
  Spacer.SetStyle('flex-grow', '1');

  // Context action buttons depending on status
  if Inv.Status = isDraft then
  begin
    var BtnSend := JW3Button.Create(Bar);
    BtnSend.Caption := 'Mark as Sent';
    BtnSend.AddClass(csBtnSecondary);
    BtnSend.AddClass(csBtnSmall);
    BtnSend.OnClick := procedure(Sender: TObject)
    begin
      Store.SetStatus(Inv.ID, isSent);
      Toast('Invoice marked as Sent.', ttSuccess);
      Application.GoToForm('InvoiceList');
    end;
  end;

  if Inv.Status in [isSent, isOverdue] then
  begin
    var BtnPay := JW3Button.Create(Bar);
    BtnPay.Caption := 'Record Payment';
    BtnPay.AddClass(csBtnPrimary);
    BtnPay.AddClass(csBtnSmall);
    BtnPay.OnClick := procedure(Sender: TObject)
    begin
      Store.SetStatus(Inv.ID, isPaid);
      Toast('Payment recorded. Invoice marked Paid.', ttSuccess);
      Application.GoToForm('InvoiceList');
    end;
  end;

  if Inv.Status in [isDraft, isSent] then
  begin
    var BtnEdit := JW3Button.Create(Bar);
    BtnEdit.Caption := 'Edit';
    BtnEdit.AddClass(csBtnGhost);
    BtnEdit.AddClass(csBtnSmall);
    BtnEdit.OnClick := procedure(Sender: TObject)
    begin
      SetActiveInvoiceID(Inv.ID);
      Application.GoToForm('InvoiceEditor');
    end;
  end;

  var BtnDel := JW3Button.Create(Bar);
  BtnDel.Caption := 'Delete';
  BtnDel.AddClass(csBtnDanger);
  BtnDel.AddClass(csBtnSmall);
  BtnDel.OnClick := procedure(Sender: TObject)
  begin
    var Dlg := JW3Modal.Create(Self);
    Dlg.Title := 'Delete ' + Inv.Number + '?';

    var Msg := JW3Label.Create(Dlg.Body);
    Msg.SetText(
      'This will permanently delete ' + Inv.Number +
      ' for ' + Client.Name + '. This cannot be undone.');
    Msg.SetStyle('padding', 'var(--space-4, 16px)');

    var BtnCancel := JW3Button.Create(Dlg.Footer);
    BtnCancel.Caption := 'Cancel';
    BtnCancel.AddClass(csBtnGhost);
    BtnCancel.OnClick := procedure(Sender: TObject)
    begin
      Dlg.Hide;
    end;

    var BtnConfirm := JW3Button.Create(Dlg.Footer);
    BtnConfirm.Caption := 'Delete';
    BtnConfirm.AddClass(csBtnDanger);
    BtnConfirm.OnClick := procedure(Sender: TObject)
    begin
      Store.DeleteInvoice(Inv.ID);
      Dlg.Hide;
      Toast(Inv.Number + ' deleted.', ttWarning);
      Application.GoToForm('InvoiceList');
    end;

    Dlg.Show;
  end;

  // ── Scrollable content area ───────────────────────────────────────

  var Content := JW3Panel.Create(Self);
  Content.SetGrow(1);
  Content.SetStyle('overflow', 'auto');
  Content.SetStyle('padding', '24px');
  Content.SetStyle('gap', '20px');
  Content.SetStyle('align-items', 'stretch');
  Content.SetStyle('max-width', '860px');
  Content.SetStyle('margin', '0 auto');
  Content.SetStyle('width', '100%');
  Content.SetStyle('box-sizing', 'border-box');

  // ── Invoice header card ───────────────────────────────────────────

  var Header := TElement.Create('div', Content);
  Header.AddClass('inv-header');

  // Left: invoice number + meta
  var Left := TElement.Create('div', Header);
  Left.AddClass('inv-meta');

  var NumEl := JW3Label.Create(Left);
  NumEl.SetText(Inv.Number);
  NumEl.AddClass(csText2xl);
  NumEl.AddClass(csFontBold);

  procedure MetaRow(const Key, Val: String);
  var Row: TElement;
  begin
    Row := TElement.Create('div', Left);
    Row.AddClass('inv-meta-row');
    var K := TElement.Create('span', Row);
    K.AddClass('inv-meta-key');
    K.SetText(Key);
    var V := TElement.Create('span', Row);
    V.AddClass('inv-meta-val');
    V.SetText(Val);
  end;

  MetaRow('Issued',  Inv.IssueDate);
  MetaRow('Due',     Inv.DueDate);
  MetaRow('Status',  Store.StatusLabel(Inv.Status));

  // Right: status badge + total
  var Right := TElement.Create('div', Header);
  Right.SetStyle('text-align', 'right');
  Right.SetStyle('display', 'flex');
  Right.SetStyle('flex-direction', 'column');
  Right.SetStyle('align-items', 'flex-end');
  Right.SetStyle('gap', '8px');

  var TotalLbl := JW3Label.Create(Right);
  TotalLbl.SetText(Store.FormatMoney(Store.InvoiceTotal(Inv)));
  TotalLbl.AddClass(csText3xl);
  TotalLbl.AddClass(csFontBold);

  var SB := JW3Badge.Create(Right);
  SB.SetText(Store.StatusLabel(Inv.Status));
  SB.AddClass(Store.StatusBadgeClass(Inv.Status));

  // ── Client card ───────────────────────────────────────────────────

  var ClientSec := TElement.Create('div', Content);
  ClientSec.AddClass('inv-section');

  var CST := TElement.Create('div', ClientSec);
  CST.AddClass('inv-section-title');
  CST.SetText('Bill to');

  var CC := TElement.Create('div', ClientSec);
  CC.AddClass('inv-client-card');

  var CName := TElement.Create('div', CC);
  CName.AddClass('name');
  CName.SetText(Client.Name);

  var CEm := TElement.Create('div', CC);
  CEm.AddClass('detail');
  CEm.SetText(Client.Email);

  if Client.Phone <> '' then
  begin
    var CPh := TElement.Create('div', CC);
    CPh.AddClass('detail');
    CPh.SetText(Client.Phone);
  end;

  if Client.Address <> '' then
  begin
    var CAd := TElement.Create('div', CC);
    CAd.AddClass('detail');
    CAd.SetText(Client.Address + ', ' + Client.City + ', ' + Client.Country);
  end;

  // ── Line items ────────────────────────────────────────────────────

  var LinesSec := TElement.Create('div', Content);
  LinesSec.AddClass('inv-section');

  var LST := TElement.Create('div', LinesSec);
  LST.AddClass('inv-section-title');
  LST.SetText('Line items');

  var TableWrap := TElement.Create('div', LinesSec);
  TableWrap.SetStyle('overflow', 'auto');

  var Table := TElement.Create('table', TableWrap);
  Table.AddClass('inv-lines');

  // thead
  var Head := TElement.Create('thead', Table);
  var HR := TElement.Create('tr', Head);

    procedure TD(Row: TElement; const T: String; Right: Boolean = false);
    begin
      var El := TElement.Create('td', Row);
      if Right then El.AddClass('right');
      El.SetText(T);
    end;

  procedure TH(const T: String; Right: Boolean = false);
  begin
    var El := TElement.Create('th', HR);
    if Right then El.AddClass('right');
    El.SetText(T);
  end;
  TH('Description');
  TH('Qty',        true);
  TH('Unit price', true);
  TH('Tax',        true);
  TH('Amount',     true);

  // tbody
  var Body := TElement.Create('tbody', Table);
  for var i := 0 to Inv.Lines.Count - 1 do
  begin
    var L   := Inv.Lines[i];
    var Amt := L.Qty * L.UnitPrice;
    var Row := TElement.Create('tr', Body);
//    procedure TD(const T: String; Right: Boolean = false);
//    begin
//      var El := TElement.Create('td', Row);
//      if Right then El.AddClass('right');
//      El.SetText(T);
//    end;
    TD(Row, L.Description);
    TD(Row, FloatToStr(L.Qty), true);
    TD(Row, Store.FormatMoney(L.UnitPrice), true);
    var TaxPct: String;
    if L.TaxRate > 0 then
      TaxPct := IntToStr(Round(L.TaxRate * 100)) + '%'
    else
      TaxPct := '—';
    TD(Row, TaxPct, true);
    TD(Row, Store.FormatMoney(Amt), true);
  end;

  // totals
  Tbl := TElement.Create('div', LinesSec);
  Tbl.AddClass('inv-totals');

  AddTotalRow('Subtotal', Store.FormatMoney(Store.InvoiceSubtotal(Inv)));
  AddTotalRow('Tax',      Store.FormatMoney(Store.InvoiceTax(Inv)));
  AddTotalRow('Total',    Store.FormatMoney(Store.InvoiceTotal(Inv)), true);

  // ── Notes ─────────────────────────────────────────────────────────

  if Inv.Notes <> '' then
  begin
    var NotesSec := TElement.Create('div', Content);
    NotesSec.AddClass('inv-section');

    var NST := TElement.Create('div', NotesSec);
    NST.AddClass('inv-section-title');
    NST.SetText('Notes');

    var NText := TElement.Create('div', NotesSec);
    NText.SetText(Inv.Notes);
    NText.SetStyle('font-size', '0.875rem');
    NText.SetStyle('color', 'var(--text-color, #1e293b)');
    NText.SetStyle('line-height', '1.6');
  end;
end;

end.
