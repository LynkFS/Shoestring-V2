unit FormClientList;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormClientList -- client management
//
//  Split layout. Left: scrollable client list. Right: detail / edit panel.
//  Add, edit, and delete clients inline.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JForm, JPanel;

type
  TFormClientList = class(TW3Form)
  private
    FSelectedID:  Integer;
    FListPanel:   JW3Panel;
    FDetailPanel: JW3Panel;

    procedure BuildLayout;
    procedure RefreshList;
    procedure SelectClient(ID: Integer);
    procedure ShowDetailView(ID: Integer);
    procedure ShowEditView(ID: Integer);
    procedure ShowNewView;
    procedure ClearDetail;
  protected
    procedure InitializeObject; override;
  end;

implementation

uses
  Globals,
  ThemeStyles, TypographyStyles, InvoiceStyles,
  JPanel, JLabel, JButton, JInput, JModal,
  JToast,
  InvoiceData;

procedure TFormClientList.InitializeObject;
begin
  inherited;
  FSelectedID := 0;
  BuildLayout;
end;

procedure TFormClientList.BuildLayout;
var
  Bar, Body: JW3Panel;
begin
  // ── Top bar ───────────────────────────────────────────────────────

  Bar := JW3Panel.Create(Self);
  Bar.SetStyle('flex-direction', 'row');
  Bar.SetStyle('align-items', 'center');
  Bar.SetStyle('gap', '8px');
  Bar.SetStyle('padding', '12px 24px');
  Bar.SetStyle('background', 'var(--surface-color, #fff)');
  Bar.SetStyle('border-bottom', '1px solid var(--border-color, #e2e8f0)');
  Bar.SetStyle('flex-shrink', '0');

  var BtnBack := JW3Button.Create(Bar);
  BtnBack.Caption := '<< Invoices';
  BtnBack.AddClass(csBtnGhost);
  BtnBack.AddClass(csBtnSmall);
  BtnBack.OnClick := procedure(Sender: TObject)
  begin
    Application.GoToForm('InvoiceList');
  end;

  var Title := JW3Label.Create(Bar);
  Title.SetText('Clients');
  Title.AddClass(csFontBold);
  Title.SetStyle('font-size', '1rem');
  Title.SetStyle('margin-left', '8px');

  var Spacer := TElement.Create('div', Bar);
  Spacer.SetStyle('flex-grow', '1');

  var BtnNew := JW3Button.Create(Bar);
  BtnNew.Caption := '+ New Client';
  BtnNew.AddClass(csBtnPrimary);
  BtnNew.AddClass(csBtnSmall);
  BtnNew.OnClick := procedure(Sender: TObject)
  begin
    ShowNewView;
  end;

  // ── Split body ────────────────────────────────────────────────────

  Body := JW3Panel.Create(Self);
  Body.SetGrow(1);
  Body.SetStyle('flex-direction', 'row');
  Body.SetStyle('overflow', 'hidden');

  // List (left)
  FListPanel := JW3Panel.Create(Body);
  FListPanel.SetStyle('width', '300px');
  FListPanel.SetStyle('flex-shrink', '0');
  FListPanel.SetStyle('border-right', '1px solid var(--border-color, #e2e8f0)');
  FListPanel.SetStyle('overflow', 'auto');
  FListPanel.SetStyle('background', 'var(--surface-color, #fff)');

  // Detail (right)
  FDetailPanel := JW3Panel.Create(Body);
  FDetailPanel.SetGrow(1);
  FDetailPanel.SetStyle('overflow', 'auto');
  FDetailPanel.SetStyle('padding', '24px');
  FDetailPanel.SetStyle('background', 'var(--bg-color, #f8fafc)');

  RefreshList;

  // Show placeholder
  var PH := JW3Label.Create(FDetailPanel);
  PH.SetText('Select a client to view details, or create a new one.');
  PH.SetStyle('color', 'var(--text-light)');
end;

procedure TFormClientList.RefreshList;
var
  I:  Integer;
  C:  TClient;
  Row, Avatar, Info, Name, Email: TElement;
  CID: Integer;
begin
  FListPanel.Clear;

  for I := 0 to Store.ClientCount - 1 do
  begin
    C := Store.GetClient(I);
    CID := C.ID;

    Row := TElement.Create('div', FListPanel);
    Row.AddClass('inv-client-row');
    if C.ID = FSelectedID then
      Row.SetStyle('background', 'var(--hover-color)');

    // Avatar initials
    Avatar := TElement.Create('div', Row);
    Avatar.AddClass('inv-client-avatar');
    var Init: String;
    if Length(C.Name) > 0 then Init := Copy(C.Name, 1, 1);
    Avatar.SetText(Init);

    // Info
    Info := TElement.Create('div', Row);
    Info.AddClass('inv-client-info');
    Name := TElement.Create('div', Info);
    Name.AddClass('inv-client-name');
    Name.SetText(C.Name);
    Email := TElement.Create('div', Info);
    Email.AddClass('inv-client-email');
    Email.SetText(C.Email);

    Row.Handle.setAttribute('data-cid', IntToStr(CID));
    Row.Handle.addEventListener('click', procedure(E: variant)
    begin
      var Val: String;
      asm @Val = (@E).currentTarget.getAttribute('data-cid'); end;
      SelectClient(StrToInt(Val));
    end);
  end;
end;

procedure TFormClientList.SelectClient(ID: Integer);
begin
  FSelectedID := ID;
  RefreshList;
  ShowDetailView(ID);
end;

procedure TFormClientList.ClearDetail;
begin
  FDetailPanel.Clear;
end;

procedure TFormClientList.ShowDetailView(ID: Integer);
var
  C: TClient;
begin
  ClearDetail;
  C := Store.FindClient(ID);
  if C.ID = 0 then exit;

  // Count their invoices
  var InvCount := 0;
  var InvTotal: Float := 0;
  for var i := 0 to Store.InvoiceCount - 1 do
  begin
    var Inv := Store.GetInvoice(i);
    if Inv.ClientID = ID then
    begin
      InvCount := InvCount + 1;
      InvTotal := InvTotal + Store.InvoiceTotal(Inv);
    end;
  end;

  // Header row
  var HRow := TElement.Create('div', FDetailPanel);
  HRow.SetStyle('display', 'flex');
  HRow.SetStyle('flex-direction', 'row');
  HRow.SetStyle('align-items', 'center');
  HRow.SetStyle('gap', '12px');
  HRow.SetStyle('margin-bottom', '20px');

  var BigAvatar := TElement.Create('div', HRow);
  BigAvatar.SetStyle('width', '52px');
  BigAvatar.SetStyle('height', '52px');
  BigAvatar.SetStyle('border-radius', '50%');
  BigAvatar.SetStyle('background', 'var(--primary-color, #6366f1)');
  BigAvatar.SetStyle('color', '#fff');
  BigAvatar.SetStyle('font-weight', '700');
  BigAvatar.SetStyle('font-size', '1.3rem');
  BigAvatar.SetStyle('display', 'flex');
  BigAvatar.SetStyle('align-items', 'center');
  BigAvatar.SetStyle('justify-content', 'center');
  var Init: String;
  if Length(C.Name) > 0 then Init := Copy(C.Name, 1, 1);
  BigAvatar.SetText(Init);

  var HInfo := TElement.Create('div', HRow);
  HInfo.SetStyle('display', 'flex');
  HInfo.SetStyle('flex-direction', 'column');
  HInfo.SetStyle('gap', '2px');
  HInfo.SetStyle('flex-grow', '1');
  var HName := TElement.Create('div', HInfo);
  HName.SetStyle('font-size', '1.1rem');
  HName.SetStyle('font-weight', '700');
  HName.SetStyle('color', 'var(--text-color)');
  HName.SetText(C.Name);
  var HCity := TElement.Create('div', HInfo);
  HCity.SetStyle('font-size', '0.8rem');
  HCity.SetStyle('color', 'var(--text-light)');
  HCity.SetText(C.City + ', ' + C.Country);

  var BtnEdit := JW3Button.Create(HRow);
  BtnEdit.Caption := 'Edit';
  BtnEdit.AddClass(csBtnGhost);
  BtnEdit.AddClass(csBtnSmall);
  BtnEdit.OnClick := procedure(Sender: TObject)
  begin
    ShowEditView(ID);
  end;

  var BtnDel := JW3Button.Create(HRow);
  BtnDel.Caption := 'Delete';
  BtnDel.AddClass(csBtnDanger);
  BtnDel.AddClass(csBtnSmall);
  BtnDel.OnClick := procedure(Sender: TObject)
  begin
    if InvCount > 0 then
    begin
      Toast('Cannot delete -- client has ' + IntToStr(InvCount) + ' invoices.', ttWarning);
      exit;
    end;
    Store.DeleteClient(ID);
    FSelectedID := 0;
    RefreshList;
    ClearDetail;
    Toast(C.Name + ' deleted.', ttSuccess);
  end;

  // Detail card
  var Sec := TElement.Create('div', FDetailPanel);
  Sec.AddClass('inv-section');

  var ST := TElement.Create('div', Sec);
  ST.AddClass('inv-section-title');
  ST.SetText('Contact details');

  procedure DetailRow(const Key, Val: String);
  var Row: TElement;
  begin
    if Val = '' then exit;
    Row := TElement.Create('div', Sec);
    Row.AddClass('inv-meta-row');
    var K := TElement.Create('div', Row);
    K.AddClass('inv-meta-key');
    K.SetText(Key);
    var V := TElement.Create('div', Row);
    V.AddClass('inv-meta-val');
    V.SetText(Val);
  end;

  DetailRow('Email',   C.Email);
  DetailRow('Phone',   C.Phone);
  DetailRow('Address', C.Address);
  DetailRow('City',    C.City);
  DetailRow('Country', C.Country);

  // Invoice summary
  var InvSec := TElement.Create('div', FDetailPanel);
  InvSec.AddClass('inv-section');
  InvSec.SetStyle('margin-top', '16px');

  var IST := TElement.Create('div', InvSec);
  IST.AddClass('inv-section-title');
  IST.SetText('Invoices');

  var IRow := TElement.Create('div', InvSec);
  IRow.AddClass('inv-meta-row');
  var IK := TElement.Create('div', IRow);
  IK.AddClass('inv-meta-key');
  IK.SetText('Count');
  var IV := TElement.Create('div', IRow);
  IV.AddClass('inv-meta-val');
  IV.SetText(IntToStr(InvCount) + ' invoices');

  var TRow := TElement.Create('div', InvSec);
  TRow.AddClass('inv-meta-row');
  var TK := TElement.Create('div', TRow);
  TK.AddClass('inv-meta-key');
  TK.SetText('Total billed');
  var TV := TElement.Create('div', TRow);
  TV.AddClass('inv-meta-val');
  TV.SetText(Store.FormatMoney(InvTotal));
end;

procedure TFormClientList.ShowEditView(ID: Integer);
var
  C:    TClient;
  IsNew: Boolean;

  FNameInp, FEmailInp, FPhoneInp, FAddrInp, FCityInp, FCountryInp: JW3Input;
begin
  ClearDetail;
  IsNew := (ID = 0);

  if IsNew then
  begin
    C.ID      := 0;
    C.Name    := '';
    C.Email   := '';
    C.Phone   := '';
    C.Address := '';
    C.City    := '';
    C.Country := 'Australia';
  end
  else
    C := Store.FindClient(ID);

  var FTitle := JW3Label.Create(FDetailPanel);
  if IsNew then FTitle.SetText('New Client')
  else FTitle.SetText('Edit ' + C.Name);
  FTitle.AddClass(csText2xl);
  FTitle.AddClass(csFontBold);
  FTitle.SetStyle('margin-bottom', '16px');

  var Sec := TElement.Create('div', FDetailPanel);
  Sec.AddClass('inv-section');

  procedure MakeField(const Label, PlaceHolder, Value: String;
    Inp: JW3Input);
  begin
    var G := TElement.Create('div', Sec);
    G.AddClass('inv-form-group');
    var L := TElement.Create('label', G);
    L.AddClass('inv-form-label');
    L.SetText(Label);
    Inp := JW3Input.Create(G);
    Inp.Placeholder := PlaceHolder;
    Inp.Value := Value;
  end;

  MakeField('Name',    'Full company name',    C.Name,    FNameInp);
  MakeField('Email',   'billing@company.com',  C.Email,   FEmailInp);
  MakeField('Phone',   '+61 7 4000 0000',      C.Phone,   FPhoneInp);
  MakeField('Address', 'Street address',       C.Address, FAddrInp);

  var Row := TElement.Create('div', Sec);
  Row.AddClass('inv-form-row');

  var GCity := TElement.Create('div', Row);
  GCity.AddClass('inv-form-group');
  var LCity := TElement.Create('label', GCity);
  LCity.AddClass('inv-form-label');
  LCity.SetText('City');
  FCityInp := JW3Input.Create(GCity);
  FCityInp.Placeholder := 'City';
  FCityInp.Value := C.City;

  var GCountry := TElement.Create('div', Row);
  GCountry.AddClass('inv-form-group');
  var LCountry := TElement.Create('label', GCountry);
  LCountry.AddClass('inv-form-label');
  LCountry.SetText('Country');
  FCountryInp := JW3Input.Create(GCountry);
  FCountryInp.Placeholder := 'Country';
  FCountryInp.Value := C.Country;

  // Buttons
  var BtnRow := TElement.Create('div', Sec);
  BtnRow.SetStyle('display', 'flex');
  BtnRow.SetStyle('flex-direction', 'row');
  BtnRow.SetStyle('gap', '8px');
  BtnRow.SetStyle('padding-top', '8px');

  var BtnCancel := JW3Button.Create(BtnRow);
  BtnCancel.Caption := 'Cancel';
  BtnCancel.AddClass(csBtnGhost);
  BtnCancel.OnClick := procedure(Sender: TObject)
  begin
    if IsNew then
    begin
      ClearDetail;
      var PH := JW3Label.Create(FDetailPanel);
      PH.SetText('Select a client or create a new one.');
      PH.SetStyle('color', 'var(--text-light)');
    end
    else
      ShowDetailView(ID);
  end;

  var BtnSave := JW3Button.Create(BtnRow);
  BtnSave.Caption := 'Save';
  BtnSave.AddClass(csBtnPrimary);
  BtnSave.OnClick := procedure(Sender: TObject)
  begin
    C.Name    := FNameInp.Value;
    C.Email   := FEmailInp.Value;
    C.Phone   := FPhoneInp.Value;
    C.Address := FAddrInp.Value;
    C.City    := FCityInp.Value;
    C.Country := FCountryInp.Value;

    if Trim(C.Name) = '' then
    begin
      Toast('Name is required.', ttWarning);
      exit;
    end;

    Store.SaveClient(C);
    FSelectedID := C.ID;
    RefreshList;
    ShowDetailView(C.ID);
    Toast(C.Name + ' saved.', ttSuccess);
  end;
end;

procedure TFormClientList.ShowNewView;
begin
  ShowEditView(0);
end;

end.
