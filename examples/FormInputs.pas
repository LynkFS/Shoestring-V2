unit FormInputs;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Form Inputs Demo
//
//  Demonstrates all form input components in a Stacked layout:
//  JButton, JLabel, JInput, JTextArea, JSelect, JCheckbox.
//
//  Two sections: a contact form (labels + inputs + validation) and
//  a settings panel (checkbox, select, buttons). Shows the field-group
//  pattern, validation on submit, and event handling.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JForm, JPanel;

type
  TFormInputs = class(TW3Form)
  private
    FName:     TElement;
    FEmail:    TElement;
    FCountry:  TElement;
    FNotes:    TElement;
    FAgree:    TElement;
    FStatus:   JW3Panel;

    procedure HandleSubmit(Sender: TObject);
    procedure HandleReset(Sender: TObject);

  protected
    procedure InitializeObject; override;
  end;

implementation

uses
  Globals,
  LayoutStacked,
  ThemeStyles,
  JButton,
  JLabel,
  JInput,
  JTextArea,
  JSelect,
  JCheckbox;


// ── Helper: create a field group (label + field stacked in a div) ────────

function MakeGroup(Parent: TElement; const LabelText: String): JW3Panel;
begin
  Result := JW3Panel.Create(Parent);
  Result.AddClass('field-group');

  var Lbl := JW3Label.Create(Result);
  Lbl.Caption := LabelText;
end;


{ TFormInputs }

procedure TFormInputs.InitializeObject;
var
  Shell, Header, Body, Section, Row, BtnRow: JW3Panel;
  Group: JW3Panel;
begin
  inherited;

  // ── Stacked layout shell ───────────────────────────────────────────

  Shell := JW3Panel.Create(Self);
  Shell.AddClass(csStackShell);

  // Header
  Header := JW3Panel.Create(Shell);
  Header.AddClass(csStackHeader);

  var Title := JW3Panel.Create(Header);
  Title.SetText('Form Components');
  Title.SetStyle('font-weight', '600');
  Title.SetStyle('font-size', '1.05rem');

  // Scrollable body
  Body := JW3Panel.Create(Shell);
  Body.AddClass(csStackBody);

  // ── Contact form section ───────────────────────────────────────────

  Section := JW3Panel.Create(Body);
  Section.AddClass(csStackSection);
  Section.SetStyle('max-width', '480px');

  var SectionTitle := JW3Panel.Create(Section);
  SectionTitle.SetText('Contact Form');
  SectionTitle.SetStyle('font-size', 'var(--font-size-xl, 1.25rem)');
  SectionTitle.SetStyle('font-weight', '600');
  SectionTitle.SetStyle('margin-bottom', 'var(--space-4, 16px)');

  // Name field
  Group := MakeGroup(Section, 'Full name');
  FName := JW3Input.Create(Group);
  JW3Input(FName).Placeholder := 'John Smith';

  // Email field
  Group := MakeGroup(Section, 'Email address');
  FEmail := JW3Input.Create(Group);
  JW3Input(FEmail).Placeholder := 'you@example.com';
  JW3Input(FEmail).InputType := 'email';

  // Country select
  Group := MakeGroup(Section, 'Country');
  FCountry := JW3Select.Create(Group);
  JW3Select(FCountry).AddOption('', 'Choose a country...');
  JW3Select(FCountry).AddOption('AU', 'Australia');
  JW3Select(FCountry).AddOption('NZ', 'New Zealand');
  JW3Select(FCountry).AddOption('GB', 'United Kingdom');
  JW3Select(FCountry).AddOption('US', 'United States');

  // Notes textarea
  Group := MakeGroup(Section, 'Notes');
  FNotes := JW3TextArea.Create(Group);
  JW3TextArea(FNotes).Placeholder := 'Any additional information...';
  JW3TextArea(FNotes).Rows := 4;

  // Agree checkbox
  FAgree := JW3Checkbox.Create(Section);
  JW3Checkbox(FAgree).Caption := 'I agree to the terms and conditions';
  FAgree.SetStyle('margin-bottom', 'var(--space-4, 16px)');

  // Button row
  BtnRow := JW3Panel.Create(Section);
  BtnRow.SetStyle('flex-direction', 'row');
  BtnRow.SetStyle('gap', 'var(--space-3, 12px)');

  var BtnSubmit := JW3Button.Create(BtnRow);
  BtnSubmit.Caption := 'Submit';
  BtnSubmit.AddClass(csBtnPrimary);
  BtnSubmit.OnClick := HandleSubmit;

  var BtnReset := JW3Button.Create(BtnRow);
  BtnReset.Caption := 'Reset';
  BtnReset.AddClass(csBtnSecondary);
  BtnReset.OnClick := HandleReset;

  var BtnDelete := JW3Button.Create(BtnRow);
  BtnDelete.Caption := 'Delete';
  BtnDelete.AddClass(csBtnDanger);
  BtnDelete.AddClass(csBtnSmall);

  // Status line
  FStatus := JW3Panel.Create(Section);
  FStatus.SetStyle('font-size', 'var(--font-size-sm, 0.875rem)');
  FStatus.SetStyle('min-height', '1.5em');
end;


//=============================================================================
// Event handlers
//=============================================================================

procedure TFormInputs.HandleSubmit(Sender: TObject);
var
  Valid: Boolean;
begin
  Valid := true;

  // Validate name
  if JW3Input(FName).Value = '' then
  begin
    FName.AddClass('invalid');
    Valid := false;
  end
  else
    FName.RemoveClass('invalid');

  // Validate email
  if JW3Input(FEmail).Value = '' then
  begin
    FEmail.AddClass('invalid');
    Valid := false;
  end
  else
    FEmail.RemoveClass('invalid');

  // Validate country
  if JW3Select(FCountry).Value = '' then
  begin
    FCountry.AddClass('invalid');
    Valid := false;
  end
  else
    FCountry.RemoveClass('invalid');

  // Validate agreement
  if not JW3Checkbox(FAgree).Checked then
  begin
    FStatus.SetText('Please agree to the terms.');
    FStatus.SetStyle('color', 'var(--color-danger, #ef4444)');
    Valid := false;
  end;

  if Valid then
  begin
    FStatus.SetText('Form submitted successfully.');
    FStatus.SetStyle('color', 'var(--color-success, #22c55e)');
  end;
end;


procedure TFormInputs.HandleReset(Sender: TObject);
begin
  JW3Input(FName).Value := '';
  JW3Input(FEmail).Value := '';
  JW3Select(FCountry).SelectedIndex := 0;
  JW3TextArea(FNotes).Value := '';
  JW3Checkbox(FAgree).Checked := false;

  FName.RemoveClass('invalid');
  FEmail.RemoveClass('invalid');
  FCountry.RemoveClass('invalid');

  FStatus.SetText('');
end;

end.
