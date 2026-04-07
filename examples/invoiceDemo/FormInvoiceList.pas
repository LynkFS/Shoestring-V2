unit FormInvoiceList;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormInvoiceList — main dashboard
//
//  Dashboard layout. Left sidebar navigation, stat cards, invoice grid.
//
//  Pattern follows FormLayoutDemo exactly:
//    - All helper params typed as TElement (never JW3Panel)
//    - No nested procedures with method-reference parameters
//    - Click handlers are inline lambdas or class methods via OnClick
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JForm, JPanel, JBadge;

type
  TFormInvoiceList = class(TW3Form)
  private
    FFilterStatus: String;
    FStatsRow:     TElement;
    FCountBadge:   JW3Badge;

    procedure BuildLayout;
    procedure AddStatCard(Parent: TElement;
      const Caption, Value, Sub: String);
    procedure RefreshStats;
    procedure RefreshGrid;

    procedure NavNewInvoice(Sender: TObject);

  protected
    procedure InitializeObject; override;
    procedure Show; override;
  end;

  procedure SetActiveInvoiceID(ID: Integer);
  function  ActiveInvoiceID: Integer;
  procedure RefreshInvoiceList;

implementation

uses
  Globals,
  ThemeStyles, TypographyStyles, InvoiceStyles,
  LayoutDashboard,
  JLabel, JButton, JBadge, JDataGrid,
  JToast,
  InvoiceData;

// ── Navigation state ──────────────────────────────────────────────────────

var GActiveInvoiceID: Integer = 0;

procedure SetActiveInvoiceID(ID: Integer);
begin GActiveInvoiceID := ID; end;

function ActiveInvoiceID: Integer;
begin Result := GActiveInvoiceID; end;


// ── Module-level grid ref (needed by RefreshGrid) ─────────────────────────

var GGrid: JW3DataGrid = nil;

procedure RefreshInvoiceList;
var Rows: array of variant;
begin
  if GGrid = nil then exit;
  Rows.Clear;
  for var i := 0 to Store.InvoiceCount - 1 do
  begin
    var Inv       := Store.GetInvoice(i);
    var StatusTxt := Store.StatusLabel(Inv.Status);
    var Client    := Store.FindClient(Inv.ClientID);
    var TotalFmt  := Store.FormatMoney(Store.InvoiceTotal(Inv));
    var InvID     := Inv.ID;
    var InvNum    := Inv.Number;
    var ClientNm  := Client.Name;
    var InvIssued := Inv.IssueDate;
    var InvDue    := Inv.DueDate;
    var Row: variant;
    asm
      @Row = {
        _id:    @InvID,
        number: @InvNum,
        client: @ClientNm,
        issued: @InvIssued,
        due:    @InvDue,
        total:  @TotalFmt,
        status: @StatusTxt
      };
    end;
    Rows.Add(Row);
  end;
  GGrid.SetData(Rows);
end;

// ── TFormInvoiceList ──────────────────────────────────────────────────────

procedure TFormInvoiceList.InitializeObject;
begin
  inherited;
  FFilterStatus := '';
  BuildLayout;
end;

// ── Helper: stat card ─────────────────────────────────────────────────────

procedure TFormInvoiceList.AddStatCard(Parent: TElement;
  const Caption, Value, Sub: String);
var Card: TElement;
begin
  Card := TElement.Create('div', Parent);
  Card.AddClass(csStatCard);
  var L := TElement.Create('div', Card);
  L.AddClass(csStatLabel);
  L.SetText(Caption);
  var V := TElement.Create('div', Card);
  V.AddClass(csStatValue);
  V.SetText(Value);
  var S := TElement.Create('div', Card);
  S.AddClass(csStatSub);
  S.SetText(Sub);
end;

// ── Build ─────────────────────────────────────────────────────────────────

procedure TFormInvoiceList.BuildLayout;
var
  Shell, Nav, Side, Main: JW3Panel;
begin
  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csDashShell);

  // ── Nav bar ───────────────────────────────────────────────────────

  Nav := JW3Panel.Create(Shell);
  Nav.AddClass(csDashNav);

  var Logo := JW3Label.Create(Nav);
  Logo.SetText('⬡  InvoiceApp');
  Logo.AddClass(csFontBold);
  Logo.SetStyle('font-size', '1rem');
  Logo.SetStyle('letter-spacing', '-0.01em');

  var NavSpacer := TElement.Create('div', Nav);
  NavSpacer.SetStyle('flex-grow', '1');

  var BtnNew := JW3Button.Create(Nav);
  BtnNew.Caption := '+ New Invoice';
  BtnNew.AddClass(csBtnPrimary);
  BtnNew.AddClass(csBtnSmall);
  BtnNew.OnClick := NavNewInvoice;

  // ── Sidebar ───────────────────────────────────────────────────────

  Side := JW3Panel.Create(Shell);
  Side.AddClass(csDashSide);

  // Nav items — inline lambdas for click, no method-ref parameter
  var ItemInv := TElement.Create('div', Side);
  ItemInv.AddClass('inv-nav-item');
  ItemInv.AddClass('active');
  TElement.Create('span', ItemInv).SetText('🗒');
  TElement.Create('span', ItemInv).SetText(' Invoices');

  var ItemCli := TElement.Create('div', Side);
  ItemCli.AddClass('inv-nav-item');
  TElement.Create('span', ItemCli).SetText('👥');
  TElement.Create('span', ItemCli).SetText(' Clients');
  ItemCli.Handle.addEventListener('click', procedure(E: variant)
  begin
    Application.GoToForm('ClientList');
  end);

  // Spacer
  var SideSpacer := TElement.Create('div', Side);
  SideSpacer.SetStyle('flex-grow', '1');

  // Filter header
  var FiltHead := TElement.Create('div', Side);
  FiltHead.SetStyle('font-size', '0.7rem');
  FiltHead.SetStyle('font-weight', '600');
  FiltHead.SetStyle('text-transform', 'uppercase');
  FiltHead.SetStyle('letter-spacing', '0.07em');
  FiltHead.SetStyle('color', 'var(--text-light, #64748b)');
  FiltHead.SetStyle('padding', '8px 14px 4px');
  FiltHead.SetText('Filter by status');

  // Filter items — each captures a local StatusValue string
  procedure AddFilter(const FilterCaption, StatusValue: String);
  var FItem: TElement;
  begin
    FItem := TElement.Create('div', Side);
    FItem.AddClass('inv-nav-item');
    TElement.Create('span', FItem).SetText(FilterCaption);
    FItem.Handle.addEventListener('click', procedure(E: variant)
    begin
      FFilterStatus := StatusValue;
      RefreshGrid;
    end);
  end;

  AddFilter('All',     '');
  AddFilter('Draft',   'Draft');
  AddFilter('Sent',    'Sent');
  AddFilter('Paid',    'Paid');
  AddFilter('Overdue', 'Overdue');

  // ── Main ──────────────────────────────────────────────────────────

  Main := JW3Panel.Create(Shell);
  Main.AddClass(csDashMain);

  // Title row
  var TitleRow := TElement.Create('div', Main);
  TitleRow.SetStyle('display', 'flex');
  TitleRow.SetStyle('flex-direction', 'row');
  TitleRow.SetStyle('align-items', 'center');
  TitleRow.SetStyle('gap', '12px');

  var TitleLbl := JW3Label.Create(TitleRow);
  TitleLbl.SetText('Invoices');
  TitleLbl.AddClass(csText2xl);
  TitleLbl.AddClass(csFontBold);

  FCountBadge := JW3Badge.Create(TitleRow);

  // Stat cards row — populated via RefreshStats on each Show
  FStatsRow := TElement.Create('div', Main);
  FStatsRow.AddClass('inv-stats-row');

  // DataGrid wrapper
  var GridWrap := JW3Panel.Create(Main);
  GridWrap.SetStyle('background', 'var(--surface-color, #fff)');
  GridWrap.SetStyle('border', '1px solid var(--border-color, #e2e8f0)');
  GridWrap.SetStyle('border-radius', 'var(--radius-lg, 8px)');
  GridWrap.SetStyle('overflow', 'hidden');
  GridWrap.SetGrow(1);

  GGrid := JW3DataGrid.Create(GridWrap);
  GGrid.SetStyle('width',  '100%');
  GGrid.SetStyle('height', '100%');

  GGrid.AddColumn('number',  'Invoice',  110);
  GGrid.AddColumn('client',  'Client',   180);
  GGrid.AddColumn('issued',  'Issued',   100);
  GGrid.AddColumn('due',     'Due',      100);
  GGrid.AddColumn('total',   'Total',    110, 'right');
  GGrid.AddColumn('status',  'Status',    90, 'center', false);

  GGrid.OnSelectRow := procedure(Sender: TObject; RowIdx: Integer; Data: variant)
  begin
    var InvID: Integer;
    InvID := Data._id;
//    asm @InvID = @Data._id; end;
    SetActiveInvoiceID(InvID);
    Application.GoToForm('InvoiceDetail');
  end;
end;

// ── RefreshGrid ───────────────────────────────────────────────────────────

procedure TFormInvoiceList.RefreshGrid;
var
  Rows: array of variant;
begin
  if GGrid = nil then exit;

  Rows.Clear;

  for var i := 0 to Store.InvoiceCount - 1 do
  begin
    var Inv       := Store.GetInvoice(i);
    var StatusTxt := Store.StatusLabel(Inv.Status);   // avoid 'label' JS keyword

    if (FFilterStatus <> '') and (StatusTxt <> FFilterStatus) then
      continue;

    var Client       := Store.FindClient(Inv.ClientID);
    var TotalFmt     := Store.FormatMoney(Store.InvoiceTotal(Inv));
    var InvID        := Inv.ID;
    var InvNum       := Inv.Number;
    var ClientName   := Client.Name;
    var InvIssued    := Inv.IssueDate;
    var InvDue       := Inv.DueDate;

    var Row: variant;
    asm
      @Row = {
        _id:    @InvID,
        number: @InvNum,
        client: @ClientName,
        issued: @InvIssued,
        due:    @InvDue,
        total:  @TotalFmt,
        status: @StatusTxt
      };
    end;
    Rows.Add(Row);
  end;

  FCountBadge.SetText(IntToStr(Rows.Count));
  GGrid.SetData(Rows);
end;

// ── RefreshStats ──────────────────────────────────────────────────────────

procedure TFormInvoiceList.RefreshStats;
begin
  FStatsRow.Clear;

  AddStatCard(FStatsRow,
    'Total Invoices',
    IntToStr(Store.InvoiceCount),
    IntToStr(Store.CountByStatus(isDraft)) + ' drafts');

  AddStatCard(FStatsRow,
    'Outstanding',
    Store.FormatMoney(Store.TotalOutstanding),
    IntToStr(Store.CountByStatus(isSent) + Store.CountByStatus(isOverdue)) + ' unpaid');

  AddStatCard(FStatsRow,
    'Paid',
    Store.FormatMoney(Store.TotalPaid),
    IntToStr(Store.CountByStatus(isPaid)) + ' invoices');

  AddStatCard(FStatsRow,
    'Overdue',
    IntToStr(Store.CountByStatus(isOverdue)),
    'require attention');
end;

// ── Show — refresh stats and grid on every navigation visit ───────────────

procedure TFormInvoiceList.Show;
begin
  inherited;
  RefreshStats;
  RefreshGrid;
end;

// ── Nav handlers ──────────────────────────────────────────────────────────

procedure TFormInvoiceList.NavNewInvoice(Sender: TObject);
begin
  SetActiveInvoiceID(0);
  Application.GoToForm('InvoiceEditor');
end;

initialization
  RegisterDashboardLayout;
end.