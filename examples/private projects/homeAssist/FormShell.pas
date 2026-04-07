unit FormShell;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormShell — Home Assist Secure main application shell
//
//  Follows the same pattern as FormInvoiceList:
//    • Form (TW3Form) hosts a single full-viewport JW3Panel shell
//    • Shell uses csDashShell grid layout
//    • Nav, Side, Main are JW3Panel children of Shell
//
//  Pages are JW3Panel subclasses embedded in FMain, swapped on NavigateTo.
//  Sidebar is rebuilt on each Show call to reflect the current role.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JForm, JElement, JPanel, JButton;

type
  // Lightweight record to track sidebar nav items for active-state highlighting
  TNavEntry = record
    PageID: String;
    El:     TElement;
  end;

  TFormShell = class(TW3Form)
  private
    // Layout panels (created once in InitializeObject)
    FShell: JW3Panel;  // dash-shell
    FNav:   JW3Panel;  // dash-nav
    FSide:  JW3Panel;  // dash-side
    FMain:  JW3Panel;  // dash-main

    // Nav bar identity elements (updated on Show)
    FRoleBadge: TElement;

    // Current page panel (nil when none)
    FCurrentPage: TElement;

    // Sidebar nav item tracking (rebuilt on each Show)
    FNavItems: array of TNavEntry;

    procedure BuildSidebar;
    procedure UpdateNavHighlight(const PageID: String);
    procedure DoLogout;

  public
    procedure NavigateTo(const PageID: String);
    procedure Show; override;
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals, HASData, HASPermissions, HASStyles, HASTypes,
     LayoutDashboard,
     PageDashboard, PageCustomers, PageContractors, PageEnrollments,
     PageQuotes, PageBatches, PagePayments,
     PageCatalogue, PageReports, PageAuditLog;

{ TFormShell }

procedure TFormShell.InitializeObject;
var NavTitleBlock, NavTitle, NavSub: TElement;
    BtnLogout: TElement;
begin
  inherited;
  AddClass(csHasApp);

  // ── Shell grid ───────────────────────────────────────────────────────────
  FShell := JW3Panel.Create(Self);
  FShell.AddClass(csDashShell);
  FShell.SetGrow(1);

  // ── Nav bar ──────────────────────────────────────────────────────────────
  FNav := JW3Panel.Create(FShell);
  FNav.AddClass(csDashNav);

  NavTitleBlock := TElement.Create('div', FNav);
  NavTitleBlock.SetStyle('display',        'flex');
  NavTitleBlock.SetStyle('flex-direction', 'column');
  NavTitleBlock.SetStyle('flex',           '1');

  NavTitle := TElement.Create('div', NavTitleBlock);
  NavTitle.AddClass('dash-nav-title');
  NavTitle.SetText('Home Assist Secure');

  NavSub := TElement.Create('div', NavTitleBlock);
  NavSub.AddClass('dash-nav-sub');
  NavSub.SetText('Queensland Department of Communities');

  FRoleBadge := TElement.Create('div', FNav);
  FRoleBadge.AddClass(csHasRoleBadge);

  BtnLogout := TElement.Create('button', FNav);
  BtnLogout.AddClass(csHasBtnLogout);
  BtnLogout.SetText('Sign Out');
  BtnLogout.OnClick := lambda DoLogout; end;

  // ── Sidebar ──────────────────────────────────────────────────────────────
  FSide := JW3Panel.Create(FShell);
  FSide.AddClass(csDashSide);

  // ── Main content area ─────────────────────────────────────────────────────
  FMain := JW3Panel.Create(FShell);
  FMain.AddClass(csDashMain);

  FCurrentPage := nil;
end;

// ── Called every time the shell form is navigated to ─────────────────────

procedure TFormShell.Show;
begin
  inherited;
  FRoleBadge.SetText(CurrentRole);
  BuildSidebar;
  NavigateTo('Dashboard');
end;

// ── Sidebar construction ──────────────────────────────────────────────────

procedure TFormShell.BuildSidebar;

  procedure AddGroup(const Label_: String);
  var Lbl: TElement;
  begin
    Lbl := TElement.Create('div', FSide);
    Lbl.AddClass('has-nav-group-label');
    Lbl.SetText(Label_);
  end;

  procedure AddNavItem(const PageID, Caption: String);
  var Item:  TElement;
      Entry: TNavEntry;
  begin
    Item := TElement.Create('div', FSide);
    Item.AddClass(csHasNavItem);
    Item.SetText(Caption);

    var CapturedID := PageID;
    Item.OnClick := lambda NavigateTo(CapturedID); end;

    Entry.PageID := PageID;
    Entry.El     := Item;
    FNavItems.Add(Entry);
  end;

var P: TPermissions;
begin
  FSide.Clear;
  FNavItems := [];

  P := GetPermissions(CurrentRole);

  // Dashboard always visible
  AddNavItem('Dashboard', 'Dashboard');

  // Clients
  if P.CanRegisterCustomer or P.CanAssess or P.CanEnroll then
  begin
    AddGroup('Clients');
    if P.CanRegisterCustomer then AddNavItem('Customers',   'Customers');
    if P.CanEnroll           then AddNavItem('Enrollments', 'Enrollments');
  end;

  // Quotes
  if P.CanRequestQuote or P.CanSubmitQuote or P.CanAcceptQuote or P.CanAssessQuote then
  begin
    AddGroup('Quotes & Jobs');
    AddNavItem('Quotes', 'Quotes');
    if P.CanVerifyWork or P.CanDisputeWork then
      AddNavItem('Disputes', 'Disputes');
  end;

  // Administration
  if P.CanManageContractors or P.CanManageCatalogue then
  begin
    AddGroup('Administration');
    if P.CanManageContractors then AddNavItem('Contractors', 'Contractors');
    if P.CanManageCatalogue   then AddNavItem('Catalogue',   'Services Catalogue');
  end;

  // Finance
  if P.CanCreateBatch or P.CanMakePayment then
  begin
    AddGroup('Finance');
    AddNavItem('Batches',  'Payment Batches');
    AddNavItem('Payments', 'Payments');
  end;

  // Reporting
  if (CurrentRole = roleAdministrator) or (CurrentRole = roleAssessor) then
  begin
    AddGroup('Reporting');
    AddNavItem('Reports',  'Reports');
    AddNavItem('AuditLog', 'Audit Log');
  end;
end;

// ── Highlight active nav item ─────────────────────────────────────────────

procedure TFormShell.UpdateNavHighlight(const PageID: String);
var I: Integer;
begin
  for I := 0 to FNavItems.Count - 1 do
  begin
    if FNavItems[I].PageID = PageID then
      FNavItems[I].El.AddClass(csHasNavActive)
    else
      FNavItems[I].El.RemoveClass(csHasNavActive);
  end;
end;

// ── Page swap ─────────────────────────────────────────────────────────────

procedure TFormShell.NavigateTo(const PageID: String);
var Page: TElement;
begin
  if FCurrentPage <> nil then
  begin
    FCurrentPage.Free;
    FCurrentPage := nil;
  end;

  case PageID of
    'Dashboard':   Page := TPageDashboard.Create(FMain);
    'Customers':   Page := TPageCustomers.Create(FMain);
    'Contractors': Page := TPageContractors.Create(FMain);
    'Enrollments': Page := TPageEnrollments.Create(FMain);
    'Quotes':
    begin
      Page := TPageQuotes.Create(FMain);
      TPageQuotes(Page).Build('');
    end;
    'Disputes':
    begin
      Page := TPageQuotes.Create(FMain);
      TPageQuotes(Page).Build(stDisputed);
    end;
    'Batches':     Page := TPageBatches.Create(FMain);
    'Payments':    Page := TPagePayments.Create(FMain);
    'Catalogue':   Page := TPageCatalogue.Create(FMain);
    'Reports':     Page := TPageReports.Create(FMain);
    'AuditLog':    Page := TPageAuditLog.Create(FMain);
  else
    Page := JW3Panel.Create(FMain);
    Page.SetStyle('padding', '24px');
    var Msg := TElement.Create('div', Page);
    Msg.SetStyle('color', 'var(--text-light)');
    Msg.SetText(PageID + ' — coming soon');
  end;

  FCurrentPage := Page;
  UpdateNavHighlight(PageID);
end;

// ── Logout ────────────────────────────────────────────────────────────────

procedure TFormShell.DoLogout;
begin
  LogEvent('Logout', 'Session', '', CurrentUser + ' signed out');
  CurrentRole         := '';
  CurrentUser         := '';
  CurrentContractorID := '';
  CurrentCustomerID   := '';

  if FCurrentPage <> nil then
  begin
    FCurrentPage.Free;
    FCurrentPage := nil;
  end;

  Application.GoToForm('HASLogin');
end;

end.
