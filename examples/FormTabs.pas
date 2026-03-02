unit FormTabs;

interface

uses JElement, JForm, JPanel, JTabs, JToolbar, JButton;

type
  TFormTabs = class(TW3Form)
  private
    Tabs: JW3TabControl;
    procedure TabChanged(Sender: TObject; Index: Integer);
    procedure HandleBack(Sender: TObject);
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals;

{ TFormTabs }

procedure TFormTabs.InitializeObject;
begin
  inherited;

  // ── Toolbar with Back button ───────────────────────────────────────

  var TB := JW3Toolbar.Create(Self);
  var BtnBack := TB.AddItem('< Back');
  BtnBack.OnClick := HandleBack;

  Tabs := JW3TabControl.Create(Self);

  // ── General tab ────────────────────────────────────────────────────

  var General := Tabs.AddTab('General');

  var Title := JW3Panel.Create(General);
  Title.SetText('General Settings');
  Title.AddClass('text-xl');
  Title.AddClass('font-semibold');

  var Desc := JW3Panel.Create(General);
  Desc.SetText('Configure the basic application settings here.');
  Desc.AddClass('text-muted');

  // ── Advanced tab ───────────────────────────────────────────────────

  var Advanced := Tabs.AddTab('Advanced');

  var Title2 := JW3Panel.Create(Advanced);
  Title2.SetText('Advanced Settings');
  Title2.AddClass('text-xl');
  Title2.AddClass('font-semibold');

  var Desc2 := JW3Panel.Create(Advanced);
  Desc2.SetText('These settings are for experienced users.');
  Desc2.AddClass('text-muted');

  // ── About tab ──────────────────────────────────────────────────────

  var About := Tabs.AddTab('About');

  var Title3 := JW3Panel.Create(About);
  Title3.SetText('Shoestring Framework');
  Title3.AddClass('text-xl');
  Title3.AddClass('font-semibold');

  var Ver := JW3Panel.Create(About);
  Ver.SetText('Version 1.0');
  Ver.AddClass('text-sm');
  Ver.AddClass('text-muted');

  // ── Tab change event (optional) ────────────────────────────────────

  Tabs.OnTabChanged := TabChanged;
end;

procedure TFormTabs.TabChanged(Sender: TObject; Index: Integer);
begin
  console.log('Tab switched to index ' + IntToStr(Index));
end;

procedure TFormTabs.HandleBack(Sender: TObject);
begin
  Application.GoToForm('Kitchensink');
end;

end.
