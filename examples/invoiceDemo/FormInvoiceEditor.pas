unit FormInvoiceEditor;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormInvoiceEditor -- create or edit an invoice
//
//  Shows a form with: client select, issue/due date, dynamic line items
//  (add/remove rows inline), notes. Save writes to the store and returns
//  to the list. Cancel discards changes.
//
//  When ActiveInvoiceID = 0, creates a new invoice.
//  When ActiveInvoiceID > 0, loads and edits the existing one.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JForm, JSelect, JInput, JTextArea, JPanel, JLabel,
  InvoiceData;

type
  TFormInvoiceEditor = class(TW3Form)
  private
    FInvoice:      TInvoice;     // working copy -- from InvoiceData
    FClientSelect: JW3Select;    // from JSelect (inline uses)
    FIssueDateInp: JW3Input;
    FDueDateInp:   JW3Input;
    FNotesTA:      JW3TextArea;
    FLinesArea:    JW3Panel;     // dynamic line rows go here

    procedure BuildForm;
    procedure BuildLinesHeader(Parent: TElement);
    procedure AddLineRow(const Line: TLineItem);
    //procedure RebuildLinesArea;
    procedure HandleSave;
    procedure HandleCancel;
    function  CollectInvoice: TInvoice;
    function  CollectLines: array of TLineItem;
    procedure UpdateRunningTotal;

    // Running total label
    FTotalLabel: JW3Label;
  protected
    procedure InitializeObject; override;
    procedure Show; override;
  end;

implementation

uses
  Globals,
  ThemeStyles, TypographyStyles, InvoiceStyles,
  JLabel, JToast, JButton,
  FormInvoiceList;

// ── Line row collection helper ────────────────────────────────────────────
// Each line row stores its three inputs on a js object attached to the row

procedure TFormInvoiceEditor.InitializeObject;
begin
  inherited;
end;

procedure TFormInvoiceEditor.Show;
begin
  Self.Clear;
  if ActiveInvoiceID > 0 then
    FInvoice := Store.FindInvoice(ActiveInvoiceID)
  else
    FInvoice := Store.NewBlankInvoice;
  BuildForm;
end;

procedure TFormInvoiceEditor.BuildForm;
var
  Bar, Content: JW3Panel;
begin
  // ── Action bar ────────────────────────────────────────────────────

  Bar := JW3Panel.Create(Self);
  Bar.SetStyle('flex-direction', 'row');
  Bar.SetStyle('align-items', 'center');
  Bar.SetStyle('gap', '8px');
  Bar.SetStyle('padding', '12px 24px');
  Bar.SetStyle('background', 'var(--surface-color, #fff)');
  Bar.SetStyle('border-bottom', '1px solid var(--border-color, #e2e8f0)');
  Bar.SetStyle('flex-shrink', '0');

  var TitleLbl := JW3Label.Create(Bar);
  if FInvoice.ID = 0 then
    TitleLbl.SetText('New Invoice')
  else
    TitleLbl.SetText('Edit ' + FInvoice.Number);
  TitleLbl.AddClass(csFontBold);
  TitleLbl.SetStyle('font-size', '1rem');

  var Sp := TElement.Create('div', Bar);
  Sp.SetStyle('flex-grow', '1');

  FTotalLabel := JW3Label.Create(Bar);
  FTotalLabel.SetText('Total: ' + Store.FormatMoney(Store.InvoiceTotal(FInvoice)));
  FTotalLabel.AddClass(csFontBold);
  FTotalLabel.SetStyle('font-size', '0.95rem');

  var BtnCancel := JW3Button.Create(Bar);
  BtnCancel.Caption := 'Cancel';
  BtnCancel.AddClass(csBtnGhost);
  BtnCancel.AddClass(csBtnSmall);
  BtnCancel.OnClick := procedure(Sender: TObject)
  begin
    HandleCancel;
  end;

  var BtnSave := JW3Button.Create(Bar);
  BtnSave.Caption := 'Save Invoice';
  BtnSave.AddClass(csBtnPrimary);
  BtnSave.AddClass(csBtnSmall);
  BtnSave.OnClick := procedure(Sender: TObject)
  begin
    HandleSave;
  end;

  // ── Content ───────────────────────────────────────────────────────

  Content := JW3Panel.Create(Self);
  Content.SetGrow(1);
  Content.SetStyle('overflow', 'auto');
  Content.SetStyle('padding', '24px');
  Content.SetStyle('gap', '20px');
  Content.SetStyle('align-items', 'stretch');
  Content.SetStyle('max-width', '860px');
  Content.SetStyle('margin', '0 auto');
  Content.SetStyle('width', '100%');
  Content.SetStyle('box-sizing', 'border-box');

  // ── Client & Dates section ────────────────────────────────────────

  var HeaderSec := TElement.Create('div', Content);
  HeaderSec.AddClass('inv-section');

  var HST := TElement.Create('div', HeaderSec);
  HST.AddClass('inv-section-title');
  HST.SetText('Invoice details');

  var Row1 := TElement.Create('div', HeaderSec);
  Row1.AddClass('inv-form-row');

  // Client select
  var GClient := TElement.Create('div', Row1);
  GClient.AddClass('inv-form-group');
  GClient.SetStyle('flex', '2');
  var LClient := TElement.Create('label', GClient);
  LClient.AddClass('inv-form-label');
  LClient.SetText('Client');

  FClientSelect := JW3Select.Create(GClient);
  FClientSelect.AddOption('0', '-- select client --');
  for var i := 0 to Store.ClientCount - 1 do
  begin
    var C := Store.GetClient(i);
    FClientSelect.AddOption(IntToStr(C.ID), C.Name);
  end;
  if FInvoice.ClientID > 0 then
    FClientSelect.Value := IntToStr(FInvoice.ClientID);

  // Issue date
  var GIssue := TElement.Create('div', Row1);
  GIssue.AddClass('inv-form-group');
  var LIssue := TElement.Create('label', GIssue);
  LIssue.AddClass('inv-form-label');
  LIssue.SetText('Issue date');
  FIssueDateInp := JW3Input.Create(GIssue);
  FIssueDateInp.InputType := 'date';
  FIssueDateInp.Value := FInvoice.IssueDate;

  // Due date
  var GDue := TElement.Create('div', Row1);
  GDue.AddClass('inv-form-group');
  var LDue := TElement.Create('label', GDue);
  LDue.AddClass('inv-form-label');
  LDue.SetText('Due date');
  FDueDateInp := JW3Input.Create(GDue);
  FDueDateInp.InputType := 'date';
  FDueDateInp.Value := FInvoice.DueDate;

  // ── Line items section ────────────────────────────────────────────

  var LinesSec := TElement.Create('div', Content);
  LinesSec.AddClass('inv-section');

  var LST := TElement.Create('div', LinesSec);
  LST.AddClass('inv-section-title');
  LST.SetText('Line items');

  BuildLinesHeader(LinesSec);

  FLinesArea := JW3Panel.Create(LinesSec);
  FLinesArea.SetStyle('gap', '6px');

  // Populate from invoice
  if FInvoice.Lines.Count = 0 then
  begin
    // Blank row for new invoice
    var Blank: TLineItem;
    Blank.Description := '';
    Blank.Qty         := 1;
    Blank.UnitPrice   := 0;
    Blank.TaxRate     := 0.10;
    AddLineRow(Blank);
  end
  else
  begin
    for var i := 0 to FInvoice.Lines.Count - 1 do
      AddLineRow(FInvoice.Lines[i]);
  end;

  var BtnAddLine := JW3Button.Create(LinesSec);
  BtnAddLine.Caption := '+ Add line';
  BtnAddLine.AddClass(csBtnGhost);
  BtnAddLine.AddClass(csBtnSmall);
  BtnAddLine.SetStyle('align-self', 'flex-start');
  BtnAddLine.OnClick := procedure(Sender: TObject)
  begin
    var Blank: TLineItem;
    Blank.Description := '';
    Blank.Qty         := 1;
    Blank.UnitPrice   := 0;
    Blank.TaxRate     := 0.10;
    AddLineRow(Blank);
  end;

  // Running total display
  var TotRow := TElement.Create('div', LinesSec);
  TotRow.SetStyle('display', 'flex');
  TotRow.SetStyle('justify-content', 'flex-end');
  TotRow.SetStyle('padding-top', '8px');
  TotRow.SetStyle('border-top', '1px solid var(--border-color, #e2e8f0)');

  var TotInner := TElement.Create('div', TotRow);
  TotInner.SetStyle('display', 'flex');
  TotInner.SetStyle('flex-direction', 'column');
  TotInner.SetStyle('gap', '4px');
  TotInner.SetStyle('min-width', '200px');

  // ── Notes section ─────────────────────────────────────────────────

  var NotesSec := TElement.Create('div', Content);
  NotesSec.AddClass('inv-section');

  var NST := TElement.Create('div', NotesSec);
  NST.AddClass('inv-section-title');
  NST.SetText('Notes');

  FNotesTA := JW3TextArea.Create(NotesSec);
  FNotesTA.SetAttribute('placeholder', 'Payment terms, thank-you message, etc.');
  FNotesTA.SetAttribute('rows', '3');
  FNotesTA.Value := FInvoice.Notes;
end;

procedure TFormInvoiceEditor.BuildLinesHeader(Parent: TElement);
var HDR: TElement;
begin
  HDR := TElement.Create('div', Parent);
  HDR.AddClass('inv-editor-lines-header');
  HDR.SetStyle('padding', '0 4px');

  var D := TElement.Create('div', HDR);
  D.SetStyle('flex-grow', '1');
  D.SetText('Description');

  var Q := TElement.Create('div', HDR);
  Q.SetStyle('width', '80px');
  Q.SetText('Qty');

  var P := TElement.Create('div', HDR);
  P.SetStyle('width', '100px');
  P.SetText('Unit price');

  var T := TElement.Create('div', HDR);
  T.SetStyle('width', '70px');
  T.SetText('Tax %');

  var R := TElement.Create('div', HDR);
  R.SetStyle('width', '28px');
  R.SetText('');
end;

procedure TFormInvoiceEditor.AddLineRow(const Line: TLineItem);
var
  Row:   TElement;
  IDesc: JW3Input;
  IQty:  JW3Input;
  IPrc:  JW3Input;
  ITax:  JW3Input;
  BtnRm: JW3Button;
begin
  Row := TElement.Create('div', FLinesArea);
  Row.AddClass('inv-editor-line');

  IDesc := JW3Input.Create(Row);
  IDesc.AddClass('desc');
  IDesc.Placeholder := 'Service or product description';
  IDesc.Value := Line.Description;
  IDesc.OnChange := procedure(Sender: TObject; Value: String)
  begin
    UpdateRunningTotal;
  end;

  IQty := JW3Input.Create(Row);
  IQty.AddClass('num');
  IQty.InputType := 'number';
  IQty.SetAttribute('min', '0');
  IQty.SetAttribute('step', '0.5');
  IQty.Value := FloatToStr(Line.Qty);
  IQty.OnChange := procedure(Sender: TObject; Value: String)
  begin
    UpdateRunningTotal;
  end;

  IPrc := JW3Input.Create(Row);
  IPrc.AddClass('num');
  IPrc.InputType := 'number';
  IPrc.SetAttribute('min', '0');
  IPrc.SetAttribute('step', '0.01');
  IPrc.Value := FloatToStr(Line.UnitPrice);
  IPrc.OnChange := procedure(Sender: TObject; Value: String)
  begin
    UpdateRunningTotal;
  end;

  ITax := JW3Input.Create(Row);
  ITax.AddClass('tax');
  ITax.InputType := 'number';
  ITax.SetAttribute('min', '0');
  ITax.SetAttribute('max', '100');
  ITax.SetAttribute('step', '1');
  // Tax displayed as percentage integer, e.g. 10 for 10%
  ITax.Value := IntToStr(Round(Line.TaxRate * 100));
  ITax.OnChange := procedure(Sender: TObject; Value: String)
  begin
    UpdateRunningTotal;
  end;

  BtnRm := JW3Button.Create(Row);
  BtnRm.AddClass('remove');
  BtnRm.Caption := '×';
  BtnRm.AddClass(csBtnGhost);
  BtnRm.AddClass(csBtnSmall);
  BtnRm.SetStyle('width', '28px');
  BtnRm.SetStyle('padding', '0');
  BtnRm.SetStyle('font-size', '1rem');
  BtnRm.OnClick := procedure(Sender: TObject)
  begin
    Row.Handle.remove;
    UpdateRunningTotal;
  end;

  // Store input refs on row element for CollectLines to read
  Row.handle._invDesc := IDesc.Handle;
  Row.Handle._invQty  := IQty.Handle;
  Row.Handle._invPrc  := IPrc.Handle;
  Row.Handle._invTax  := ITax.Handle;
//  asm
//    (@Row).Handle._invDesc = @IDesc.Handle;
//    (@Row).Handle._invQty  = @IQty.Handle;
//    (@Row).Handle._invPrc  = @IPrc.Handle;
//    (@Row).Handle._invTax  = @ITax.Handle;
//  end;

  UpdateRunningTotal;
end;

function TFormInvoiceEditor.CollectLines: array of TLineItem;
begin
  Result.Clear;
  var Rows: variant;

  Rows := FLinesArea.Handle.querySelectorAll('.inv-editor-line');
//  asm
//    @Rows = (@FLinesArea).Handle.querySelectorAll('.inv-editor-line');
//  end;

  var Count: Integer;
  Count := Rows.length;
//  asm @Count = (@Rows).length; end;
  for var i := 0 to Count - 1 do
  begin
    var Row: variant;
    Row := Rows[i];
    //asm @Row = @Rows[@i]; end;
    var L: TLineItem;

    asm
      @L.Description = (@Row)._invDesc.value;
      @L.Qty         = parseFloat((@Row)._invQty.value) || 0;
      @L.UnitPrice   = parseFloat((@Row)._invPrc.value) || 0;
      @L.TaxRate     = (parseFloat((@Row)._invTax.value) || 0) / 100;
    end;
    if L.Description <> '' then
      Result.Add(L);
  end;
end;

procedure TFormInvoiceEditor.UpdateRunningTotal;
var
  Lines: array of TLineItem;
  Sub, Tax: Float;
begin
  Lines := CollectLines;
  Sub   := 0;
  Tax   := 0;
  for var i := 0 to Lines.Count - 1 do
  begin
    Sub := Sub + Lines[i].Qty * Lines[i].UnitPrice;
    Tax := Tax + Lines[i].Qty * Lines[i].UnitPrice * Lines[i].TaxRate;
  end;
  FTotalLabel.SetText('Total: ' + Store.FormatMoney(Sub + Tax));
end;

function TFormInvoiceEditor.CollectInvoice: TInvoice;
begin
  Result         := FInvoice;
  var CIDStr     := FClientSelect.Value;
  Result.ClientID := StrToInt(CIDStr);
  Result.IssueDate := FIssueDateInp.Value;
  Result.DueDate   := FDueDateInp.Value;
  Result.Notes     := FNotesTA.Value;
  Result.Lines     := CollectLines;
end;

procedure TFormInvoiceEditor.HandleSave;
var
  Inv: TInvoice;
begin
  Inv := CollectInvoice;

  if Inv.ClientID = 0 then
  begin
    Toast('Please select a client.', ttWarning);
    exit;
  end;
  if Inv.Lines.Count = 0 then
  begin
    Toast('Add at least one line item.', ttWarning);
    exit;
  end;

  Store.SaveInvoice(Inv);

  if FInvoice.ID = 0 then
    Toast('Invoice ' + Inv.Number + ' created.', ttSuccess)
  else
    Toast('Invoice ' + Inv.Number + ' updated.', ttSuccess);

  SetActiveInvoiceID(Inv.ID);
  RefreshInvoiceList;
  Application.GoToForm('InvoiceDetail');
end;

procedure TFormInvoiceEditor.HandleCancel;
begin
  if FInvoice.ID = 0 then
    Application.GoToForm('InvoiceList')
  else
  begin
    SetActiveInvoiceID(FInvoice.ID);
    Application.GoToForm('InvoiceDetail');
  end;
end;

end.