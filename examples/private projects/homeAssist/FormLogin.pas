unit FormLogin;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormLogin — Home Assist Secure login screen
//
//  Centered card on a teal-tinted background.
//  User selects their role, enters their name, then clicks Sign In.
//  On success: seeds data (if first run), logs the event, navigates to shell.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JForm, JElement, JPanel, JSelect, JInput, JButton;

type
  TFormLogin = class(TW3Form)
  private
    FCard:      TElement;    // .has-login-card
    FRoleLabel: TElement;
    FRole:      JW3Select;
    FNameLabel: TElement;
    FName:      JW3Input;
    FError:     TElement;
    FSignIn:    JW3Button;
    procedure DoSignIn;
  protected
    procedure InitializeObject; override;
  end;

implementation

uses Globals, HASData, HASPermissions, HASStyles, HASTypes, ThemeStyles;

{ TFormLogin }

procedure TFormLogin.InitializeObject;
var Wrap: TElement;
begin
  inherited;
  AddClass(csHasApp);

  // Full-viewport centring wrapper
  SetStyle('display',         'flex');
  SetStyle('align-items',     'center');
  SetStyle('justify-content', 'center');
  SetStyle('background',      'linear-gradient(135deg, #0f766e 0%, #134e4a 100%)');

  // ── Login card ──────────────────────────────────────────────────────────
  FCard := TElement.Create('div', Self);
  FCard.AddClass(csHasLoginCard);

  // Logo block
  Wrap := TElement.Create('div', FCard);
  Wrap.AddClass(csHasLoginLogo);

  var LogoMark := TElement.Create('div', Wrap);
  LogoMark.AddClass('has-login-logo-mark');
  LogoMark.SetHTML('&#127968;');   // 🏠 house emoji

  var Title := TElement.Create('div', Wrap);
  Title.AddClass('has-login-logo-title');
  Title.SetText('Home Assist Secure');

  var Sub := TElement.Create('div', Wrap);
  Sub.AddClass('has-login-logo-sub');
  Sub.SetText('Queensland Department of Communities');

  // Role selector
  var RoleGroup := TElement.Create('div', FCard);
  RoleGroup.AddClass(csFieldGroup);

  FRoleLabel := TElement.Create('label', RoleGroup);
  FRoleLabel.AddClass(csFieldLabel);
  FRoleLabel.SetText('Role');

  FRole := JW3Select.Create(RoleGroup);
  FRole.AddOption('', '— Select your role —');
  FRole.AddOption(roleAdministrator,  'Administrator');
  FRole.AddOption(roleAssessor,       'Assessor');
  FRole.AddOption(roleCSO,            'Customer Service Officer');
  FRole.AddOption(rolePaymentOfficer, 'Payment Officer');
  FRole.AddOption(roleContractor,     'Contractor');
  FRole.AddOption(roleCustomer,       'Customer');

  // Name field
  var NameGroup := TElement.Create('div', FCard);
  NameGroup.AddClass(csFieldGroup);

  FNameLabel := TElement.Create('label', NameGroup);
  FNameLabel.AddClass(csFieldLabel);
  FNameLabel.SetText('Your name');

  FName := JW3Input.Create(NameGroup);
  FName.Placeholder := 'Enter your name';
  FName.InputType   := 'text';

  // Error line
  FError := TElement.Create('div', FCard);
  FError.AddClass(csFieldError);
  FError.SetText('');

  // Sign in button
  FSignIn := JW3Button.Create(FCard);
  FSignIn.Caption  := 'Sign In';
  FSignIn.AddClass(csBtnPrimary);
  FSignIn.SetStyle('width', '100%');
  FSignIn.SetStyle('margin-top', '8px');
  FSignIn.OnClick := lambda DoSignIn; end;
end;

procedure TFormLogin.DoSignIn;
var Role, Name: String;
begin
  Role := FRole.Value;
  Name := Trim(FName.Value);

  if Role = '' then
  begin
    FError.SetText('Please select a role.');
    exit;
  end;

  if Name = '' then
  begin
    FError.SetText('Please enter your name.');
    exit;
  end;

  FError.SetText('');

  // Store session
  CurrentRole := Role;
  CurrentUser := Name;

  // Seed data on first run (idempotent guard is inside SeedData)
  SeedData;

  // For contractor role, link to first contractor for demo purposes
  if Role = roleContractor then
  begin
    if HAS_Contractors.Count > 0 then
      CurrentContractorID := HAS_Contractors[0].ID;
  end;

  // For customer role, link to first customer
  if Role = roleCustomer then
  begin
    if HAS_Customers.Count > 0 then
      CurrentCustomerID := HAS_Customers[0].ID;
  end;

  LogEvent('Login', 'Session', '', Name + ' signed in as ' + Role);

  Application.GoToForm('HASShell');
end;

end.
