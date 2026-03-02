unit FormDocument;

interface

uses JElement, JForm, JPanel, LayoutDocument;

type
  TFormDocument = class(TW3Form)
  private
    Shell:   JW3Panel;
    Header:  JW3Panel;
    Body:    JW3Panel;
    Content: JW3Panel;
    Aside:   JW3Panel;
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals;

{ TFormDocument }

procedure TFormDocument.InitializeObject;
begin
  inherited;

  // ── Structure ──────────────────────────────────────────────────────
  //
  //  Five panels, five classes. The layout CSS does everything else.
  //

  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csDocShell);

  Header := JW3Panel.Create(Shell);
  Header.AddClass(csDocHeader);

  Body := JW3Panel.Create(Shell);
  Body.AddClass(csDocBody);

  Content := JW3Panel.Create(Body);
  Content.AddClass(csDocContent);

  Aside := JW3Panel.Create(Body);
  Aside.AddClass(csDocAside);

  // ── Header content ─────────────────────────────────────────────────

  var Logo := JW3Panel.Create(Header);
  Logo.SetText('Shoestring Docs');
  Logo.SetStyle('font-weight', '600');
  Logo.SetStyle('font-size', '1.1rem');

  // ── Article content ────────────────────────────────────────────────

  var Title := JW3Panel.Create(Content);
  Title.SetText('Getting Started');
  Title.SetStyle('font-size', '1.75rem');
  Title.SetStyle('font-weight', '700');
  Title.SetStyle('color', 'var(--text-color)');
  Title.SetStyle('margin-bottom', '8px');

  var Intro := JW3Panel.Create(Content);
  Intro.SetText(
    'Shoestring is a lightweight Pascal framework that compiles to ' +
    'JavaScript for web applications. It provides typed access to the ' +
    'browser without duplicating what the browser already does.'
  );
  Intro.SetStyle('line-height', '1.6');
  Intro.SetStyle('color', 'var(--text-color)');

  var SubHead := JW3Panel.Create(Content);
  SubHead.SetText('Installation');
  SubHead.SetStyle('font-size', '1.25rem');
  SubHead.SetStyle('font-weight', '600');
  SubHead.SetStyle('color', 'var(--text-color)');
  SubHead.SetStyle('margin-top', '24px');

  var Para := JW3Panel.Create(Content);
  Para.SetText(
    'No package manager required. Copy the framework units into your ' +
    'project and add them to your uses clause. The framework registers ' +
    'its stylesheet and creates the application instance automatically ' +
    'during unit initialization.'
  );
  Para.SetStyle('line-height', '1.6');
  Para.SetStyle('color', 'var(--text-color)');

  // ── Sidebar content ────────────────────────────────────────────────

  var NavTitle := JW3Panel.Create(Aside);
  NavTitle.SetText('On this page');
  NavTitle.SetStyle('font-weight', '600');
  NavTitle.SetStyle('font-size', '0.875rem');
  NavTitle.SetStyle('color', 'var(--text-light)');
  NavTitle.SetStyle('text-transform', 'uppercase');
  NavTitle.SetStyle('letter-spacing', '0.05em');

  var Link1 := JW3Panel.Create(Aside);
  Link1.SetText('Getting Started');
  Link1.SetStyle('cursor', 'pointer');
  Link1.SetStyle('color', 'var(--primary-color)');
  Link1.SetStyle('font-size', '0.875rem');

  var Link2 := JW3Panel.Create(Aside);
  Link2.SetText('Installation');
  Link2.SetStyle('cursor', 'pointer');
  Link2.SetStyle('color', 'var(--text-color)');
  Link2.SetStyle('font-size', '0.875rem');

  // ── Optional: override a variable for this instance ────────────────

  // Wider content column for this particular page:
  // Shell.SetStyle('--doc-content-max-width', '860px');

  // Taller header:
  // Shell.SetStyle('--doc-header-height', '72px');
end;

end.
