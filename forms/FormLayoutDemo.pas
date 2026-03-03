unit FormLayoutDemo;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Layout Gallery
//
//  Demonstrates all six Shoestring layouts with realistic content.
//  A layout picker select in each layout's header lets you switch
//  between them. Each layout is rebuilt from scratch on selection.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JForm, JPanel;

type
  TFormLayoutDemo = class(TW3Form)
  private
    FCurrent: String;

    function  AddPicker(Parent: TElement): TElement;
    procedure ShowLayout(const Name: String);

    // ── One builder per layout ──

    procedure ShowDashboard;
    procedure ShowDocument;
    procedure ShowHolyGrail;
    procedure ShowKanban;
    procedure ShowSplit;
    procedure ShowStacked;

    // ── Content helpers ──

    procedure AddStatCard(Parent: TElement;
      const Title, Value, Subtitle: String);
    procedure AddNavItem(Parent: TElement;
      const Text: String; Active: Boolean);
    procedure AddKanbanCard(Parent: TElement;
      const Title, Tag: String);
    procedure AddParagraph(Parent: TElement;
      const Text: String);

  protected
    procedure InitializeObject; override;
  end;

implementation

uses
  Globals, JLabel, JButton, JBadge,
  ThemeStyles, TypographyStyles,
  LayoutDashboard, LayoutDocument, LayoutHolyGrail,
  LayoutKanban, LayoutSplit, LayoutStacked;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  Local demo styles                                                         }
{ ═══════════════════════════════════════════════════════════════════════════ }

var GDemoStyled: Boolean = false;

procedure RegisterDemoStyles;
begin
  if GDemoStyled then exit;
  GDemoStyled := true;
  AddStyleBlock(#'

    /* ── Stat cards ─────────────────────────────────────────────── */

    .demo-stat {
      background: var(--surface-color, #fff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-lg, 8px);
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .demo-stat-value {
      font-size: 1.75rem;
      font-weight: 700;
      color: var(--text-color, #1e293b);
    }
    .demo-stat-title {
      font-size: 0.8rem;
      color: var(--text-light, #64748b);
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }
    .demo-stat-sub {
      font-size: 0.8rem;
      color: var(--primary-color, #6366f1);
    }

    /* ── Nav items ──────────────────────────────────────────────── */

    .demo-nav-item {
      padding: 8px 12px;
      border-radius: var(--radius-md, 6px);
      font-size: 0.875rem;
      cursor: pointer;
      color: var(--text-color, #1e293b);
      transition: background 150ms ease;
    }
    .demo-nav-item:hover {
      background: var(--border-color, #e2e8f0);
    }
    .demo-nav-item.active {
      background: var(--primary-color, #6366f1);
      color: #fff;
    }

    /* ── Kanban cards ───────────────────────────────────────────── */

    .demo-kb-card {
      background: var(--surface-color, #fff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-md, 6px);
      padding: 12px;
      display: flex;
      flex-direction: column;
      gap: 8px;
      cursor: grab;
    }
    .demo-kb-card:hover {
      box-shadow: 0 2px 8px rgba(0,0,0,.08);
    }

    /* ── Stats row ──────────────────────────────────────────────── */

    .demo-stats-row {
      display: flex;
      flex-direction: row;
      gap: 16px;
      flex-wrap: wrap;
    }
    .demo-stats-row > * {
      flex: 1;
      min-width: 160px;
    }

    /* ── Picker ─────────────────────────────────────────────────── */

    .demo-picker {
      appearance: none;
      background: var(--hover-color, #f1f5f9);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-md, 6px);
      padding: 6px 28px 6px 10px;
      font-size: 12px;
      font-weight: 600;
      color: var(--text-color, #1e293b);
      cursor: pointer;
      outline: none;
      background-image: url("data:image/svg+xml,%3Csvg xmlns=''http://www.w3.org/2000/svg'' width=''12'' height=''12'' viewBox=''0 0 12 12''%3E%3Cpath fill=''%2394a3b8'' d=''M2 4l4 4 4-4z''/%3E%3C/svg%3E");
      background-repeat: no-repeat;
      background-position: right 8px center;
    }
    .demo-picker:focus {
      border-color: var(--primary-color, #6366f1);
    }

    /* ── Content block ──────────────────────────────────────────── */

    .demo-content-block {
      background: var(--surface-color, #fff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-lg, 8px);
      padding: 24px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    /* ── List row ───────────────────────────────────────────────── */

    .demo-list-item {
      padding: 12px 16px;
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      display: flex;
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
      font-size: 0.875rem;
    }
    .demo-list-item:last-child { border-bottom: none; }

    /* ── Footer ─────────────────────────────────────────────────── */

    .demo-footer-text {
      font-size: 0.75rem;
      color: var(--text-light, #64748b);
      text-align: center;
    }
  ');
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  Layout picker — shared across all layouts                                 }
{ ═══════════════════════════════════════════════════════════════════════════ }

function TFormLayoutDemo.AddPicker(Parent: TElement): TElement;
var
  Sel, Opt: TElement;
  Items: array[0..6] of String;
  I: Integer;
begin
  Items[0] := 'dashboard';
  Items[1] := 'document';
  Items[2] := 'holygrail';
  Items[3] := 'kanban';
  Items[4] := 'split';
  Items[5] := 'stacked';
  Items[6] := 'back';

  Sel := TElement.Create('select', Parent);
  Sel.AddClass('demo-picker');

  for I := 0 to 6 do
  begin
    Opt := TElement.Create('option', Sel);
    Opt.SetAttribute('value', Items[I]);
    case I of
      0: Opt.SetText('Dashboard');
      1: Opt.SetText('Document');
      2: Opt.SetText('Holy Grail');
      3: Opt.SetText('Kanban');
      4: Opt.SetText('Split');
      5: Opt.SetText('Stacked');
      6: Opt.SetText('Back');
    end;
    if Items[I] = FCurrent then
      Opt.SetAttribute('selected', 'selected');
  end;

  Sel.Handle.addEventListener('change', procedure(Event: variant)
  begin
    ShowLayout(String(Sel.Handle.value));
  end);

  Result := Sel;
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  Content helpers                                                           }
{ ═══════════════════════════════════════════════════════════════════════════ }

procedure TFormLayoutDemo.AddStatCard(Parent: TElement;
  const Title, Value, Subtitle: String);
var
  Card, VLbl, TLbl, SLbl: TElement;
begin
  Card := TElement.Create('div', Parent);
  Card.AddClass('demo-stat');

  TLbl := TElement.Create('div', Card);
  TLbl.AddClass('demo-stat-title');
  TLbl.SetText(Title);

  VLbl := TElement.Create('div', Card);
  VLbl.AddClass('demo-stat-value');
  VLbl.SetText(Value);

  SLbl := TElement.Create('div', Card);
  SLbl.AddClass('demo-stat-sub');
  SLbl.SetText(Subtitle);
end;

procedure TFormLayoutDemo.AddNavItem(Parent: TElement;
  const Text: String; Active: Boolean);
var
  El: TElement;
begin
  El := TElement.Create('div', Parent);
  El.AddClass('demo-nav-item');
  if Active then El.AddClass('active');
  El.SetText(Text);
end;

procedure TFormLayoutDemo.AddKanbanCard(Parent: TElement;
  const Title, Tag: String);
var
  Card, TLbl, Badge: TElement;
begin
  Card := TElement.Create('div', Parent);
  Card.AddClass('demo-kb-card');

  TLbl := JW3Label.Create(Card);
  TLbl.SetText(Title);
  TLbl.SetStyle('font-weight', '500');

  Badge := JW3Badge.Create(Card);
  Badge.SetText(Tag);
  Badge.AddClass(csBadgeInfo);
end;

procedure TFormLayoutDemo.AddParagraph(Parent: TElement;
  const Text: String);
var
  P: TElement;
begin
  P := TElement.Create('div', Parent);
  P.SetText(Text);
  P.SetStyle('line-height', '1.65');
  P.SetStyle('color', 'var(--text-color, #1e293b)');
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  Switch logic                                                              }
{ ═══════════════════════════════════════════════════════════════════════════ }

procedure TFormLayoutDemo.ShowLayout(const Name: String);
begin

  if Name = 'back' then
  begin
    Application.GoToForm('Kitchensink');
    Exit;
  end;
  
  FCurrent := Name;
  Self.Clear;

  if Name = 'dashboard'       then ShowDashboard
  else if Name = 'document'   then ShowDocument
  else if Name = 'holygrail'  then ShowHolyGrail
  else if Name = 'kanban'     then ShowKanban
  else if Name = 'split'      then ShowSplit
  else if Name = 'stacked'    then ShowStacked
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  1. Dashboard                                                              }
{ ═══════════════════════════════════════════════════════════════════════════ }

procedure TFormLayoutDemo.ShowDashboard;
var
  Shell, Nav, Side, Main: JW3Panel;
  Logo, Title: JW3Label;
  Spacer, StatsRow, Block: TElement;
  Item: TElement;
  B: JW3Badge;
begin
  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csDashShell);

  // ── Nav bar ──
  Nav := JW3Panel.Create(Shell);
  Nav.AddClass(csDashNav);

  Logo := JW3Label.Create(Nav);
  Logo.SetText('⬡');
  Logo.SetStyle('font-size', '1.4rem');

  Title := JW3Label.Create(Nav);
  Title.SetText('Dashboard Layout');
  Title.SetStyle('font-weight', '600');

  Spacer := TElement.Create('div', Nav);
  Spacer.SetStyle('flex-grow', '1');

  AddPicker(Nav);

  // ── Sidebar ──
  Side := JW3Panel.Create(Shell);
  Side.AddClass(csDashSide);

  AddNavItem(Side, 'Overview', true);
  AddNavItem(Side, 'Customers', false);
  AddNavItem(Side, 'Invoices', false);
  AddNavItem(Side, 'Products', false);
  AddNavItem(Side, 'Reports', false);
  AddNavItem(Side, 'Settings', false);

  // ── Main ──
  Main := JW3Panel.Create(Shell);
  Main.AddClass(csDashMain);

  var H := JW3Label.Create(Main);
  H.SetText('Overview');
  H.AddClass(csText2xl);
  H.AddClass(csFontBold);

  StatsRow := TElement.Create('div', Main);
  StatsRow.AddClass('demo-stats-row');

  AddStatCard(StatsRow, 'Revenue',   '$48,290', '+12.5% from last month');
  AddStatCard(StatsRow, 'Customers', '1,284',   '+34 this week');
  AddStatCard(StatsRow, 'Orders',    '356',     '23 pending');
  AddStatCard(StatsRow, 'Avg Value', '$135.64',  '-2.1% from last month');

  Block := TElement.Create('div', Main);
  Block.AddClass('demo-content-block');

  var BTitle := JW3Label.Create(Block);
  BTitle.SetText('Recent Orders');
  BTitle.AddClass(csFontSemibold);

  Item := TElement.Create('div', Block); Item.AddClass('demo-list-item');
  TElement.Create('span', Item).SetText('INV-2024-0891 — Alice Johnson');
  B := JW3Badge.Create(Item); B.SetText('Paid');    B.AddClass(csBadgeSuccess);

  Item := TElement.Create('div', Block); Item.AddClass('demo-list-item');
  TElement.Create('span', Item).SetText('INV-2024-0890 — Bob Smith');
  B := JW3Badge.Create(Item); B.SetText('Pending'); B.AddClass(csBadgeWarning);

  Item := TElement.Create('div', Block); Item.AddClass('demo-list-item');
  TElement.Create('span', Item).SetText('INV-2024-0889 — Carol White');
  B := JW3Badge.Create(Item); B.SetText('Shipped'); B.AddClass(csBadgeInfo);

  Item := TElement.Create('div', Block); Item.AddClass('demo-list-item');
  TElement.Create('span', Item).SetText('INV-2024-0888 — Dave Brown');
  B := JW3Badge.Create(Item); B.SetText('Paid');    B.AddClass(csBadgeSuccess);
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  2. Document                                                               }
{ ═══════════════════════════════════════════════════════════════════════════ }

procedure TFormLayoutDemo.ShowDocument;
var
  Shell, Header, Body, Content, Aside: JW3Panel;
  Spacer: TElement;
begin
  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csDocShell);

  Header := JW3Panel.Create(Shell);
  Header.AddClass(csDocHeader);

  var Logo := JW3Label.Create(Header);
  Logo.SetText('Document Layout');
  Logo.SetStyle('font-weight', '600');

  Spacer := TElement.Create('div', Header);
  Spacer.SetStyle('flex-grow', '1');

  AddPicker(Header);

  Body := JW3Panel.Create(Shell);
  Body.AddClass(csDocBody);

  Content := JW3Panel.Create(Body);
  Content.AddClass(csDocContent);
  Content.SetStyle('gap', '16px');

  Aside := JW3Panel.Create(Body);
  Aside.AddClass(csDocAside);

  // ── Article ──

  var T := JW3Label.Create(Content);
  T.SetText('The Container Query Pattern');
  T.AddClass(csText2xl);
  T.AddClass(csFontBold);

  var Sub := JW3Label.Create(Content);
  Sub.SetText('Responsive components that adapt to their container, not the viewport');
  Sub.AddClass(csTextMuted);

  AddParagraph(Content,
    'Media queries respond to the viewport. Container queries respond to the ' +
    'element''s parent. This distinction matters when the same component appears ' +
    'in a narrow sidebar and a wide main panel — media queries cannot ' +
    'distinguish between these contexts.');

  AddParagraph(Content,
    'The pattern requires two elements. The parent declares container-type: ' +
    'inline-size, which tells the browser to track its width. The child uses ' +
    '@container rules to switch its grid-template-columns based on the ' +
    'container''s available width.');

  var H2 := JW3Label.Create(Content);
  H2.SetText('When to Use');
  H2.AddClass(csTextXl);
  H2.AddClass(csFontBold);

  AddParagraph(Content,
    'Container queries are for components that restructure — product cards that ' +
    'flip from vertical to horizontal, dashboards that rearrange their panels, ' +
    'data tables that collapse columns. Simple stacking components that just ' +
    'wrap their children do not need them.');

  AddParagraph(Content,
    'The implementation cost is one container-type declaration on the parent and ' +
    'one @container rule in the stylesheet. No JavaScript. No resize observers. ' +
    'The browser does the work.');

  // ── Sidebar ──

  var NavT := JW3Label.Create(Aside);
  NavT.SetText('On this page');
  NavT.SetStyle('font-weight', '600');
  NavT.SetStyle('font-size', '0.8rem');
  NavT.SetStyle('color', 'var(--text-light, #64748b)');
  NavT.SetStyle('text-transform', 'uppercase');
  NavT.SetStyle('letter-spacing', '0.05em');

  var L1 := JW3Label.Create(Aside);
  L1.SetText('The Container Query Pattern');
  L1.SetStyle('color', 'var(--primary-color, #6366f1)');
  L1.SetStyle('font-size', '0.875rem');

  var L2 := JW3Label.Create(Aside);
  L2.SetText('When to Use');
  L2.SetStyle('color', 'var(--text-color, #1e293b)');
  L2.SetStyle('font-size', '0.875rem');
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  3. Holy Grail                                                             }
{ ═══════════════════════════════════════════════════════════════════════════ }

procedure TFormLayoutDemo.ShowHolyGrail;
var
  Shell, Header, Nav, Center, Aside, Footer: JW3Panel;
  Spacer, Block: TElement;
begin
  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csHgShell);

  // ── Header ──
  Header := JW3Panel.Create(Shell);
  Header.AddClass(csHgHeader);

  var Logo := JW3Label.Create(Header);
  Logo.SetText('Holy Grail Layout');
  Logo.SetStyle('font-weight', '600');

  Spacer := TElement.Create('div', Header);
  Spacer.SetStyle('flex-grow', '1');

  var Btn1 := JW3Button.Create(Header);
  Btn1.Caption := 'Home';
  Btn1.AddClass(csBtnGhost);
  Btn1.AddClass(csBtnSmall);

  var Btn2 := JW3Button.Create(Header);
  Btn2.Caption := 'Features';
  Btn2.AddClass(csBtnGhost);
  Btn2.AddClass(csBtnSmall);

  var Btn3 := JW3Button.Create(Header);
  Btn3.Caption := 'Pricing';
  Btn3.AddClass(csBtnGhost);
  Btn3.AddClass(csBtnSmall);

  AddPicker(Header);

  // ── Left nav ──
  Nav := JW3Panel.Create(Shell);
  Nav.AddClass(csHgNav);

  AddNavItem(Nav, 'Getting Started', true);
  AddNavItem(Nav, 'Installation', false);
  AddNavItem(Nav, 'Configuration', false);
  AddNavItem(Nav, 'API Reference', false);
  AddNavItem(Nav, 'Examples', false);
  AddNavItem(Nav, 'FAQ', false);

  // ── Center content ──
  Center := JW3Panel.Create(Shell);
  Center.AddClass(csHgCenter);
  Center.SetStyle('gap', '16px');

  var T := JW3Label.Create(Center);
  T.SetText('Getting Started');
  T.AddClass(csText2xl);
  T.AddClass(csFontBold);

  AddParagraph(Center,
    'The Holy Grail layout provides a full portal structure with left navigation, ' +
    'right sidebar, and centered content. It collapses to a single column on ' +
    'mobile, with the sidebars stacking below the content.');

  Block := TElement.Create('div', Center);
  Block.AddClass('demo-content-block');
  var BT := JW3Label.Create(Block);
  BT.SetText('Quick Start');
  BT.AddClass(csFontSemibold);
  AddParagraph(Block,
    'Add the LayoutHolyGrail unit to your uses clause. The CSS registers ' +
    'automatically during unit initialization. Create six panels — shell, header, ' +
    'nav, center, aside, footer — assign the class constants, and the browser ' +
    'handles the grid placement.');

  AddParagraph(Center,
    'Override CSS variables on the shell to customise widths, backgrounds, and ' +
    'breakpoints. The layout adapts without changing Pascal code.');

  // ── Right aside ──
  Aside := JW3Panel.Create(Shell);
  Aside.AddClass(csHgAside);

  var AT := JW3Label.Create(Aside);
  AT.SetText('Related');
  AT.SetStyle('font-weight', '600');
  AT.SetStyle('font-size', '0.8rem');
  AT.SetStyle('color', 'var(--text-light, #64748b)');
  AT.SetStyle('text-transform', 'uppercase');

  var R1 := JW3Label.Create(Aside);
  R1.SetText('Dashboard Layout');
  R1.SetStyle('color', 'var(--primary-color, #6366f1)');
  R1.SetStyle('font-size', '0.875rem');

  var R2 := JW3Label.Create(Aside);
  R2.SetText('Document Layout');
  R2.SetStyle('color', 'var(--text-color, #1e293b)');
  R2.SetStyle('font-size', '0.875rem');

  var R3 := JW3Label.Create(Aside);
  R3.SetText('Split Layout');
  R3.SetStyle('color', 'var(--text-color, #1e293b)');
  R3.SetStyle('font-size', '0.875rem');

  // ── Footer ──
  Footer := JW3Panel.Create(Shell);
  Footer.AddClass(csHgFooter);

  var FT := JW3Label.Create(Footer);
  FT.AddClass('demo-footer-text');
  FT.SetText('Shoestring Framework — Holy Grail Layout Demo');
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  4. Kanban                                                                 }
{ ═══════════════════════════════════════════════════════════════════════════ }

procedure TFormLayoutDemo.ShowKanban;
var
  Shell, Header, Board: JW3Panel;
  Col, ColHead, ColBody: TElement;
  Spacer: TElement;
  Badge: JW3Badge;
begin
  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csKbShell);

  // ── Header ──
  Header := JW3Panel.Create(Shell);
  Header.AddClass(csKbHeader);

  var Logo := JW3Label.Create(Header);
  Logo.SetText('Kanban Layout');
  Logo.SetStyle('font-weight', '600');

  Spacer := TElement.Create('div', Header);
  Spacer.SetStyle('flex-grow', '1');

  Badge := JW3Badge.Create(Header);
  Badge.SetText('Sprint 14');
  Badge.AddClass(csBadgePrimary);

  AddPicker(Header);

  // ── Board ──
  Board := JW3Panel.Create(Shell);
  Board.AddClass(csKbBoard);

  // Column: Backlog
  Col := TElement.Create('div', Board);
  Col.AddClass(csKbCol);
  ColHead := TElement.Create('div', Col);
  ColHead.AddClass(csKbColHead);
  ColHead.SetText('Backlog');
  ColBody := TElement.Create('div', Col);
  ColBody.AddClass(csKbColBody);
  AddKanbanCard(ColBody, 'Add CSV export to reports',     'Feature');
  AddKanbanCard(ColBody, 'Review onboarding flow',        'Design');
  AddKanbanCard(ColBody, 'Update API rate limit docs',    'Docs');

  // Column: To Do
  Col := TElement.Create('div', Board);
  Col.AddClass(csKbCol);
  ColHead := TElement.Create('div', Col);
  ColHead.AddClass(csKbColHead);
  ColHead.SetText('To Do');
  ColBody := TElement.Create('div', Col);
  ColBody.AddClass(csKbColBody);
  AddKanbanCard(ColBody, 'Fix pagination on mobile',      'Bug');
  AddKanbanCard(ColBody, 'Implement SSO login',           'Feature');

  // Column: In Progress
  Col := TElement.Create('div', Board);
  Col.AddClass(csKbCol);
  ColHead := TElement.Create('div', Col);
  ColHead.AddClass(csKbColHead);
  ColHead.SetText('In Progress');
  ColBody := TElement.Create('div', Col);
  ColBody.AddClass(csKbColBody);
  AddKanbanCard(ColBody, 'Refactor notification service', 'Tech Debt');
  AddKanbanCard(ColBody, 'Design settings page',          'Design');
  AddKanbanCard(ColBody, 'Write integration tests',       'QA');

  // Column: Done
  Col := TElement.Create('div', Board);
  Col.AddClass(csKbCol);
  ColHead := TElement.Create('div', Col);
  ColHead.AddClass(csKbColHead);
  ColHead.SetText('Done');
  ColBody := TElement.Create('div', Col);
  ColBody.AddClass(csKbColBody);
  AddKanbanCard(ColBody, 'Deploy v2.4.1 hotfix',          'Ops');
  AddKanbanCard(ColBody, 'Customer feedback survey',      'Product');
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  5. Split                                                                  }
{ ═══════════════════════════════════════════════════════════════════════════ }

procedure TFormLayoutDemo.ShowSplit;
var
  Shell, Left, Right: JW3Panel;
  Block, Item: TElement;
begin
  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csSplitShell);
  Shell.AddClass(csSplitWeighted); // 2:3 ratio

  // ── Left panel ──
  Left := JW3Panel.Create(Shell);
  Left.AddClass(csSplitLeft);
  Left.SetStyle('gap', '12px');

  var Header := TElement.Create('div', Left);
  Header.SetStyle('display', 'flex');
  Header.SetStyle('align-items', 'center');
  Header.SetStyle('gap', '12px');

  var T := JW3Label.Create(Header);
  T.SetText('Split Layout');
  T.SetStyle('font-weight', '600');
  T.SetStyle('flex-grow', '1');

  AddPicker(Header);

  var Sub := JW3Label.Create(Left);
  Sub.SetText('Inbox');
  Sub.AddClass(csTextXl);
  Sub.AddClass(csFontBold);

  // Message list
  Block := TElement.Create('div', Left);
  Block.AddClass('demo-content-block');
  Block.SetStyle('padding', '0');

  Item := TElement.Create('div', Block); Item.AddClass('demo-list-item');
  Item.SetStyle('background', 'var(--hover-color, #f1f5f9)');
  TElement.Create('div', Item).SetText('Alice — Project update ready for review');

  Item := TElement.Create('div', Block); Item.AddClass('demo-list-item');
  TElement.Create('div', Item).SetText('Bob — Meeting notes from standup');

  Item := TElement.Create('div', Block); Item.AddClass('demo-list-item');
  TElement.Create('div', Item).SetText('Carol — Deployment schedule confirmed');

  Item := TElement.Create('div', Block); Item.AddClass('demo-list-item');
  TElement.Create('div', Item).SetText('Dave — Budget approval needed');

  Item := TElement.Create('div', Block); Item.AddClass('demo-list-item');
  TElement.Create('div', Item).SetText('Eve — New design mockups attached');

  // ── Right panel ──
  Right := JW3Panel.Create(Shell);
  Right.AddClass(csSplitRight);
  Right.SetStyle('gap', '16px');
  Right.SetStyle('padding', '24px');

  var RT := JW3Label.Create(Right);
  RT.SetText('Project update ready for review');
  RT.AddClass(csTextXl);
  RT.AddClass(csFontBold);

  var From := JW3Label.Create(Right);
  From.SetText('From: Alice Johnson — 10:42 AM');
  From.AddClass(csTextMuted);
  From.SetStyle('font-size', '0.875rem');

  AddParagraph(Right,
    'Hi team, I''ve finished the layout refactoring we discussed last week. ' +
    'The main changes are the switch from absolute positioning to flex-based ' +
    'layout and the addition of container queries for responsive components.');

  AddParagraph(Right,
    'I''ve tested on Chrome, Firefox, and Safari. Mobile works well with the ' +
    'new breakpoints. Let me know if you spot anything before I merge.');

  var BtnRow := TElement.Create('div', Right);
  BtnRow.SetStyle('display', 'flex');
  BtnRow.SetStyle('gap', '8px');

  var Btn1 := JW3Button.Create(BtnRow);
  Btn1.Caption := 'Reply';
  Btn1.AddClass(csBtnPrimary);

  var Btn2 := JW3Button.Create(BtnRow);
  Btn2.Caption := 'Forward';
  Btn2.AddClass(csBtnGhost);
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  6. Stacked                                                                }
{ ═══════════════════════════════════════════════════════════════════════════ }

procedure TFormLayoutDemo.ShowStacked;
var
  Shell, Header, Body, Footer: JW3Panel;
  Section, StatsRow: TElement;
  Spacer: TElement;
begin
  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csStackShell);

  // ── Header ──
  Header := JW3Panel.Create(Shell);
  Header.AddClass(csStackHeader);

  var Logo := JW3Label.Create(Header);
  Logo.SetText('Stacked Layout');
  Logo.SetStyle('font-weight', '600');

  Spacer := TElement.Create('div', Header);
  Spacer.SetStyle('flex-grow', '1');

  var BtnH := JW3Button.Create(Header);
  BtnH.Caption := 'About';
  BtnH.AddClass(csBtnGhost);
  BtnH.AddClass(csBtnSmall);

  var BtnC := JW3Button.Create(Header);
  BtnC.Caption := 'Contact';
  BtnC.AddClass(csBtnGhost);
  BtnC.AddClass(csBtnSmall);

  AddPicker(Header);

  // ── Scrollable body ──
  Body := JW3Panel.Create(Shell);
  Body.AddClass(csStackBody);

  // Section 1: Hero
  Section := TElement.Create('div', Body);
  Section.AddClass(csStackSection);
  Section.SetStyle('text-align', 'center');
  Section.SetStyle('padding-top', '64px');
  Section.SetStyle('padding-bottom', '64px');

  var HeroT := JW3Label.Create(Section);
  HeroT.SetText('Build with Less');
  HeroT.AddClass(csText4xl);
  HeroT.AddClass(csFontBold);
  HeroT.AddClass(csLeadingTight);

  var HeroS := JW3Label.Create(Section);
  HeroS.AddClass(csTextMuted);
  HeroS.SetText(
    'A minimalist Pascal web framework. Typed access to the browser. ' +
    'No abstractions. No magic.');

  var HeroBtn := JW3Button.Create(Section);
  HeroBtn.Caption := 'Get Started';
  HeroBtn.AddClass(csBtnPrimary);
  HeroBtn.AddClass(csBtnLarge);

  // Section 2: Stats
  Section := TElement.Create('div', Body);
  Section.AddClass(csStackSection);

  var StT := JW3Label.Create(Section);
  StT.SetText('By the Numbers');
  StT.AddClass(csTextXl);
  StT.AddClass(csFontBold);
  StT.SetStyle('text-align', 'center');

  StatsRow := TElement.Create('div', Section);
  StatsRow.AddClass('demo-stats-row');

  AddStatCard(StatsRow, 'Core Lines',     '~750',    '4 units');
  AddStatCard(StatsRow, 'Widgets',        '15',      'Zero asm in base');
  AddStatCard(StatsRow, 'Layouts',        '6',       'CSS Grid + Flex');
  AddStatCard(StatsRow, 'Dependencies',   '0',       'Pure browser APIs');

  // Section 3: Text
  Section := TElement.Create('div', Body);
  Section.AddClass(csStackSection);

  var FT := JW3Label.Create(Section);
  FT.SetText('Philosophy');
  FT.AddClass(csTextXl);
  FT.AddClass(csFontBold);

  AddParagraph(Section,
    'If the browser does it, don''t. Shoestring provides typed Pascal access ' +
    'to CSS properties, DOM methods, and browser APIs. It does not reimplement ' +
    'them, wrap them, abstract them, or improve upon them.');

  AddParagraph(Section,
    'Every component descends from TElement, which wraps a single DOM element ' +
    'via a variant field. No typed JHTMLElement. No asm blocks. Every DOM ' +
    'method works through variant dispatch.');

  // ── Footer ──
  Footer := JW3Panel.Create(Shell);
  Footer.AddClass(csStackFooter);

  var FTxt := JW3Label.Create(Footer);
  FTxt.AddClass('demo-footer-text');
  FTxt.SetText('Shoestring Framework — Built in Far North Queensland');
end;


{ ═══════════════════════════════════════════════════════════════════════════ }
{  Init                                                                      }
{ ═══════════════════════════════════════════════════════════════════════════ }

procedure TFormLayoutDemo.InitializeObject;
begin
  inherited;
  ShowLayout('dashboard');
end;


initialization
  RegisterDemoStyles;
end.
