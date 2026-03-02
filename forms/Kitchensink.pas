unit Kitchensink;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Kitchen Sink
//
//  Toolbar with a "Components" button. Clicking it toggles a listbox
//  on the left. Selecting a component from the listbox displays a live
//  instance on the main panel. Only one component is shown at a time —
//  the panel is cleared and rebuilt on each selection.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  JElement, JForm, JPanel, JToolbar, JListBox;

type
  TKitchensink = class(TW3Form)
  private
    FToolbar:   JW3Toolbar;
    FBody:      JW3Panel;
    FListBox:   JW3ListBox;
    FDisplay:   JW3Panel;

    procedure HandleComponentsClick(Sender: TObject);
    procedure HandleLayoutsClick(Sender: TObject);
    procedure HandleNonVisualClick(Sender: TObject);
    procedure HandleListSelect(Sender: TObject);
    procedure HandleInvoiceDemoClick(Sender: TObject);
    procedure ShowComponent(const Name: String);

    // Individual component builders
    procedure ShowButton;
    procedure ShowLabel;
    procedure ShowInput;
    procedure ShowTextArea;
    procedure ShowSelect;
    procedure ShowCheckbox;
    procedure ShowListBox;
    procedure ShowBadge;
    procedure ShowCard;
    procedure ShowImage;
    procedure ShowTabs;
    procedure ShowToolbar;
    procedure ShowModal;
    procedure ShowToast;
    procedure ShowTreeView;
    procedure ShowDataGrid;
    procedure ShowProductCard;

  protected
    procedure InitializeObject; override;
  end;

implementation

uses
  Globals,
  ThemeStyles, TypographyStyles,
  JButton, JLabel, JInput, JTextArea, JSelect, JCheckbox,
  JBadge, JCard, JImage, JTabs, JModal, JToast,
  JTreeView, JDataGrid, JProductCard,
  FormLayoutDemo;


procedure TKitchensink.InitializeObject;
begin
  inherited;

  // ── Toolbar ────────────────────────────────────────────────────────

  FToolbar := JW3Toolbar.Create(Self);
  FToolBar.SetStyle('flex-wrap', 'nowrap');
  var BtnComp := FToolbar.AddItem('Components');
  var BtnLayouts := FToolbar.AddItem('Layouts');
  var BtnNonVisual := FToolbar.AddItem('Non-visual');
  var BtnInvoiceDemo := FToolbar.AddItem('InvoiceApp');
  BtnComp.OnClick := HandleComponentsClick;
  BtnLayouts.OnClick := HandleLayoutsClick;
  BtnNonVisual.OnClick := HandleNonVisualClick;
  BtnInvoiceDemo.OnClick := HandleInvoiceDemoClick;

  // ── Body: listbox (left) + display panel (right) ───────────────────

  FBody := JW3Panel.Create(Self);
  FBody.SetGrow(1);
  FBody.SetStyle('flex-direction', 'row');

  // ── Listbox — hidden by default ────────────────────────────────────

  FListBox := JW3ListBox.Create(FBody);
  FListBox.SetStyle('width', '200px');
  FListBox.SetStyle('flex-shrink', '0');
  FListBox.SetStyle('border-right', '1px solid var(--border-color, #e2e8f0)');
  FListBox.Visible := true;

  FListBox.AddItem('button',     'Button');
  FListBox.AddItem('label',      'Label');
  FListBox.AddItem('input',      'Input');
  FListBox.AddItem('textarea',   'TextArea');
  FListBox.AddItem('select',     'Select');
  FListBox.AddItem('checkbox',   'Checkbox');
  FListBox.AddItem('listbox',    'ListBox');
  FListBox.AddItem('badge',      'Badge');
  FListBox.AddItem('card',       'Card');
  FListBox.AddItem('image',      'Image');
  FListBox.AddItem('tabs',       'Tabs');
  FListBox.AddItem('toolbar',    'Toolbar');
  FListBox.AddItem('modal',      'Modal');
  FListBox.AddItem('toast',      'Toast');
  FListBox.AddItem('treeview',   'TreeView');
  FListBox.AddItem('datagrid',   'DataGrid');
  FListBox.AddItem('productcard','Product Card');

  FListBox.OnClick := HandleListSelect;

  // ── Display panel — where the selected component appears ───────────

  FDisplay := JW3Panel.Create(FBody);
  FDisplay.SetGrow(1);
  FDisplay.SetStyle('padding', 'var(--space-6, 24px)');
  FDisplay.SetStyle('overflow', 'auto');
  FDisplay.SetStyle('align-items', 'flex-start');
  FDisplay.SetStyle('gap', 'var(--space-4, 16px)');

  // Show a welcome message
  var Lbl := JW3Label.Create(FDisplay);
  Lbl.SetText('Select a component from the list to preview it.');
  Lbl.SetStyle('color', 'var(--text-light, #64748b)');
end;


// ═════════════════════════════════════════════════════════════════════════
// Toolbar click — toggle the listbox
// ═════════════════════════════════════════════════════════════════════════

procedure TKitchensink.HandleComponentsClick(Sender: TObject);
begin
  FListBox.Visible := not FListBox.Visible;
end;

procedure TKitchensink.HandleLayoutsClick(Sender: TObject);
begin
  Application.GoToForm('FormLayoutDemo');
end;

procedure TKitchensink.HandleNonVisualClick(Sender: TObject);
begin
  Application.GoToForm('FormNonVisual');
end;

procedure TKitchensink.HandleInvoiceDemoClick(Sender: TObject);
begin
  Application.GoToForm('InvoiceList');
end;

// ═════════════════════════════════════════════════════════════════════════
// Listbox selection — display the chosen component
// ═════════════════════════════════════════════════════════════════════════

procedure TKitchensink.HandleListSelect(Sender: TObject);
begin
  ShowComponent(FListBox.SelectedValue);
end;

procedure TKitchensink.ShowComponent(const Name: String);
begin
  FDisplay.Clear;

  // Title
  var Title := JW3Label.Create(FDisplay);
  Title.SetText(Name);
  Title.AddClass('text-xl');
  Title.AddClass('font-bold');

  if Name = 'button'           then ShowButton
  else if Name = 'label'       then ShowLabel
  else if Name = 'input'       then ShowInput
  else if Name = 'textarea'    then ShowTextArea
  else if Name = 'select'      then ShowSelect
  else if Name = 'checkbox'    then ShowCheckbox
  else if Name = 'listbox'     then ShowListBox
  else if Name = 'badge'       then ShowBadge
  else if Name = 'card'        then ShowCard
  else if Name = 'image'       then ShowImage
  else if Name = 'tabs'        then ShowTabs
  else if Name = 'toolbar'     then ShowToolbar
  else if Name = 'modal'       then ShowModal
  else if Name = 'toast'       then ShowToast
  else if Name = 'treeview'    then ShowTreeView
  else if Name = 'datagrid'    then ShowDataGrid
  else if Name = 'productcard' then ShowProductCard;
end;


// ═════════════════════════════════════════════════════════════════════════
// Component builders
// ═════════════════════════════════════════════════════════════════════════

procedure TKitchensink.ShowButton;
begin
  var Row := JW3Panel.Create(FDisplay);
  Row.SetStyle('flex-direction', 'row');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('flex-wrap', 'wrap');

  var B1 := JW3Button.Create(Row);
  B1.SetText('Default');

  var B2 := JW3Button.Create(Row);
  B2.SetText('Primary');
  B2.AddClass(csBtnPrimary);

  var B3 := JW3Button.Create(Row);
  B3.SetText('Danger');
  B3.AddClass(csBtnDanger);

  var B4 := JW3Button.Create(Row);
  B4.SetText('Ghost');
  B4.AddClass(csBtnGhost);

  var B5 := JW3Button.Create(Row);
  B5.SetText('Small');
  B5.AddClass(csBtnSmall);

  var B6 := JW3Button.Create(Row);
  B6.SetText('Disabled');
  B6.Enabled := false;
end;

procedure TKitchensink.ShowLabel;
begin
  var L1 := JW3Label.Create(FDisplay);
  L1.SetText('A simple label');

  var L2 := JW3Label.Create(FDisplay);
  L2.SetText('Bold label');
  L2.AddClass('font-bold');

  var L3 := JW3Label.Create(FDisplay);
  L3.SetText('Large coloured label');
  L3.AddClass('text-2xl');
  L3.SetStyle('color', 'var(--primary-color, #6366f1)');
end;

procedure TKitchensink.ShowInput;
begin
  var I1 := JW3Input.Create(FDisplay);
  I1.SetAttribute('placeholder', 'Type something...');
  I1.SetStyle('max-width', '300px');

  var I2 := JW3Input.Create(FDisplay);
  I2.SetAttribute('placeholder', 'Disabled input');
  I2.Enabled := false;
  I2.SetStyle('max-width', '300px');
end;

procedure TKitchensink.ShowTextArea;
begin
  var TA := JW3TextArea.Create(FDisplay);
  TA.SetAttribute('placeholder', 'Enter multiple lines...');
  TA.SetAttribute('rows', '5');
  TA.SetStyle('max-width', '400px');
  TA.SetStyle('width', '100%');
end;

procedure TKitchensink.ShowSelect;
begin
  var Sel := JW3Select.Create(FDisplay);
  Sel.AddOption('', '-- Choose --');
  Sel.AddOption('red', 'Red');
  Sel.AddOption('green', 'Green');
  Sel.AddOption('blue', 'Blue');
  Sel.AddOption('yellow', 'Yellow');
  Sel.SetStyle('max-width', '200px');
end;

procedure TKitchensink.ShowCheckbox;
begin
  var C1 := JW3Checkbox.Create(FDisplay);
  C1.Caption := 'Accept terms';

  var C2 := JW3Checkbox.Create(FDisplay);
  C2.Caption := 'Subscribe to newsletter';

  var C3 := JW3Checkbox.Create(FDisplay);
  C3.Caption := 'Disabled option';
  C3.Enabled := false;
end;

procedure TKitchensink.ShowListBox;
begin
  var LB := JW3ListBox.Create(FDisplay);
  LB.SetStyle('width', '200px');
  LB.SetStyle('height', '180px');
  LB.AddItem('pascal', 'Object Pascal');
  LB.AddItem('js', 'JavaScript');
  LB.AddItem('rust', 'Rust');
  LB.AddItem('go', 'Go');
  LB.AddItem('python', 'Python');
  LB.AddItem('csharp', 'C#');
end;

procedure TKitchensink.ShowBadge;
begin
  var Row := JW3Panel.Create(FDisplay);
  Row.SetStyle('flex-direction', 'row');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('flex-wrap', 'wrap');
  Row.SetStyle('align-items', 'center');

  var B1 := JW3Badge.Create(Row);
  B1.SetText('Default');

  var B2 := JW3Badge.Create(Row);
  B2.SetText('Success');
  B2.AddClass(csBadgeSuccess);

  var B3 := JW3Badge.Create(Row);
  B3.SetText('Warning');
  B3.AddClass(csBadgeWarning);

  var B4 := JW3Badge.Create(Row);
  B4.SetText('Danger');
  B4.AddClass(csBadgeDanger);

  var B5 := JW3Badge.Create(Row);
  B5.SetText('Info');
  B5.AddClass(csBadgeInfo);

  var B6 := JW3Badge.Create(Row);
  B6.SetText('Primary');
  B6.AddClass(csBadgePrimary);
end;

procedure TKitchensink.ShowCard;
begin
  var Card := JW3Card.Create(FDisplay);
  Card.Title := 'Example Card';
  Card.SetStyle('max-width', '360px');
  Card.SetStyle('width', '100%');

  var Lbl := JW3Label.Create(Card.Body);
  Lbl.SetText('This is the card body. Cards have a header, body, and footer panel.');

  var Btn := JW3Button.Create(Card.Footer);
  Btn.SetText('Action');
  Btn.AddClass(csBtnPrimary);
end;

procedure TKitchensink.ShowImage;
begin
  var Img := JW3Image.Create(FDisplay);
  Img.Src := 'https://picsum.photos/300/200';
  Img.Alt := 'Random placeholder image';
  Img.SetStyle('border-radius', 'var(--radius-lg, 8px)');
  Img.SetStyle('max-width', '300px');
end;

procedure TKitchensink.ShowTabs;
begin
  var Tabs := JW3TabControl.Create(FDisplay);
  Tabs.SetStyle('max-width', '500px');
  Tabs.SetStyle('width', '100%');

  var Page1 := Tabs.AddTab('General');
  var L1 := JW3Label.Create(Page1);
  L1.SetText('This is the General tab content.');
  L1.SetStyle('padding', 'var(--space-4, 16px)');

  var Page2 := Tabs.AddTab('Advanced');
  var L2 := JW3Label.Create(Page2);
  L2.SetText('Advanced settings would go here.');
  L2.SetStyle('padding', 'var(--space-4, 16px)');

  var Page3 := Tabs.AddTab('About');
  var L3 := JW3Label.Create(Page3);
  L3.SetText('Shoestring Framework — Kitchen Sink Demo');
  L3.SetStyle('padding', 'var(--space-4, 16px)');
end;

procedure TKitchensink.ShowToolbar;
begin
  var TB := JW3Toolbar.Create(FDisplay);
  TB.SetStyle('width', '100%');
  TB.SetStyle('max-width', '500px');

  var B1 := TB.AddItem('New');
  var B2 := TB.AddItem('Open');
  var B3 := TB.AddItem('Save');
  TB.AddSeparator;
  var B4 := TB.AddItem('Settings');
  TB.AddSpacer;
  var B5 := TB.AddItem('Help');
end;

procedure TKitchensink.ShowModal;
begin
  var Info := JW3Label.Create(FDisplay);
  Info.SetText('Click the button to open a modal dialog.');

  var Btn := JW3Button.Create(FDisplay);
  Btn.SetText('Open Modal');
  Btn.AddClass(csBtnPrimary);

  Btn.OnClick := procedure(Sender: TObject)
  begin
    var Dlg := JW3Modal.Create(Self);
    Dlg.Title := 'Example Modal';

    var Lbl := JW3Label.Create(Dlg.Body);
    Lbl.SetText('This is a modal dialog. Click the backdrop or close button to dismiss.');
    Lbl.SetStyle('padding', 'var(--space-4, 16px)');

    var CloseBtn := JW3Button.Create(Dlg.Footer);
    CloseBtn.SetText('Close');
    CloseBtn.AddClass(csBtnPrimary);
    CloseBtn.OnClick := procedure(Sender: TObject)
    begin
      Dlg.Hide;;
    end;

    Dlg.Show;
  end;
end;

procedure TKitchensink.ShowToast;
begin
  var Info := JW3Label.Create(FDisplay);
  Info.SetText('Click a button to fire a toast notification.');

  var Row := JW3Panel.Create(FDisplay);
  Row.SetStyle('flex-direction', 'row');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('flex-wrap', 'wrap');

  var B1 := JW3Button.Create(Row);
  B1.SetText('Info Toast');
  B1.OnClick := procedure(Sender: TObject)
  begin
    Toast('This is an info message.', ttInfo);
  end;

  var B2 := JW3Button.Create(Row);
  B2.SetText('Success Toast');
  B2.AddClass(csBtnPrimary);
  B2.OnClick := procedure(Sender: TObject)
  begin
    Toast('Operation completed!', ttSuccess);
  end;

  var B3 := JW3Button.Create(Row);
  B3.SetText('Error Toast');
  B3.AddClass(csBtnDanger);
  B3.OnClick := procedure(Sender: TObject)
  begin
    Toast('Something went wrong.', ttDanger);
  end;
end;

procedure TKitchensink.ShowTreeView;
begin
  var Tree := JW3TreeView.Create(FDisplay);
  Tree.SetStyle('width', '600px');
  Tree.SetStyle('height', '300px');
  Tree.SetStyle('border', '1px solid var(--border-color, #e2e8f0)');
  Tree.SetStyle('border-radius', 'var(--radius-lg, 8px)');

  var Root := Tree.AddNode(nil, 'Documents');
  var Work := Tree.AddNode(Root, 'Work');
  Tree.AddNode(Work, 'Report.docx');
  Tree.AddNode(Work, 'Budget.xlsx');
  Tree.AddNode(Work, 'Presentation.pptx');
  var Personal := Tree.AddNode(Root, 'Personal');
  Tree.AddNode(Personal, 'Photos');
  Tree.AddNode(Personal, 'Music');
  var Dev := Tree.AddNode(nil, 'Development');
  var Proj := Tree.AddNode(Dev, 'Shoestring');
  Tree.AddNode(Proj, 'JElement.pas');
  Tree.AddNode(Proj, 'Globals.pas');
  Tree.AddNode(Proj, 'Types.pas');
end;

procedure TKitchensink.ShowDataGrid;
begin
  var Grid := JW3DataGrid.Create(FDisplay);
  Grid.SetStyle('width', '100%');
  Grid.SetStyle('max-width', '600px');
  Grid.SetStyle('height', '300px');

  Grid.AddColumn('name',   'Name',   160);
  Grid.AddColumn('email',  'Email',  220, 'left', true, true);
  Grid.AddColumn('role',   'Role',   100);
  Grid.AddColumn('status', 'Status', 80, 'center');

  var Rows: array of variant;

  asm
    function mkRow(n, e, r, s) { return {name:n, email:e, role:r, status:s}; }
    @Rows = [
      mkRow('Alice Johnson',  'alice@example.com',   'Admin',     'Active'),
      mkRow('Bob Smith',      'bob@example.com',     'Editor',    'Active'),
      mkRow('Carol White',    'carol@example.com',   'Viewer',    'Inactive'),
      mkRow('Dave Brown',     'dave@example.com',    'Editor',    'Active'),
      mkRow('Eve Davis',      'eve@example.com',     'Admin',     'Active'),
      mkRow('Frank Miller',   'frank@example.com',   'Viewer',    'Active'),
      mkRow('Grace Wilson',   'grace@example.com',   'Editor',    'Inactive'),
      mkRow('Henry Taylor',   'henry@example.com',   'Viewer',    'Active'),
      mkRow('Irene Clark',    'irene@example.com',   'Admin',     'Active'),
      mkRow('Jack Lewis',     'jack@example.com',    'Editor',    'Active')
    ];
  end;

  Grid.SetData(Rows);
end;

procedure TKitchensink.ShowProductCard;
begin
  // FDisplay is the container — make it a card container
  AddCardContainer(FDisplay);

  var C1 := TProductCard.Create(FDisplay);
  C1.Title := 'Reef Snorkel Set';
  C1.Price := '$49.95';
  C1.Description := 'Full-face snorkel mask with dry-top system and 180° panoramic view.';
  C1.ImageSrc := 'https://picsum.photos/seed/snorkel/400/300';
  C1.AddTag('New');
  C1.AddTag('Sale');

  var C2 := TProductCard.Create(FDisplay);
  C2.Title := 'Hiking Daypack 28L';
  C2.Price := '$79.00';
  C2.Description := 'Lightweight ripstop nylon with hydration sleeve and rain cover.';
  C2.ImageSrc := 'https://picsum.photos/seed/hiking/400/300';
  C2.AddTag('Popular');

  var C3 := TProductCard.Create(FDisplay);
  C3.Title := 'Solar Lantern';
  C3.Price := '$24.50';
  C3.Description := 'Collapsible LED lantern with built-in solar panel. 12-hour runtime.';
  C3.ImageSrc := 'https://picsum.photos/seed/lantern/400/300';
  C3.AddTag('Eco');
  C3.AddTag('Camping');
end;

end.