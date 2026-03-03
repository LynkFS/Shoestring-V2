unit FormNonVisual;

// ?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
//
//  Non-Visual Components Gallery
//
//  Demonstrates all five non-visual component categories from Chapter 10:
//  Services, HTTP Client, Validators, DataStore, Models, and Adapters.
//
//  Same shell as the Kitchensink: toolbar + sidebar listbox + display panel.
//  Each entry rebuilds the display panel with a live, interactive example.
//
// ?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????

interface

uses
  JElement, JForm, JPanel, JToolbar, JListBox, JLabel, JDatastore, Types;

type

  // "Session service" demonstrates a long-lived service object

  TSessionService = class
  private
    FUserName: String;
    FLoggedIn: Boolean;
  public
    procedure Login(const UserName: String);
    procedure Logout;
    function  IsLoggedIn: Boolean;
    function  UserName: String;
    function  Role: String;
  end;

  // "Contact model" used by both Models and Adapters demos

  TContact = record
    ID:      Integer;
    Name:    String;
    Email:   String;
    Company: String;
    Active:  Boolean;
  end;

  // "List adapter" bridges a TContact array to a JW3ListBox

  TContactAdapter = class
  private
    FData:    array of TContact;
    FListBox: JW3ListBox;
  public
    constructor Create(ListBox: JW3ListBox);
    procedure   SetData(Data: array of TContact);
    function    ItemAt(Index: Integer): TContact;
  end;

  // The form

  TFormNonVisual = class(TW3Form)
  private
    FToolbar:   JW3Toolbar;
    FBody:      JW3Panel;
    FNav:       JW3ListBox;
    FDisplay:   JW3Panel;
    FSession:   TSessionService;
    FDataStore: JW3DataStore;

    procedure HandleNavSelect(Sender: TObject; Value: String);
    procedure ShowDemo(const Name: String);

    procedure ShowServices;
    procedure ShowHttpClient;
    procedure ShowValidators;
    procedure ShowDataStore;
    procedure ShowModels;
    procedure ShowAdapters;

    // Shared helpers
    function  AddSection(const Title: String): JW3Panel;
    function  AddOutput(Parent: TElement; const Text: String): JW3Label;
    procedure AddCodeHint(Parent: TElement; const Text: String);
  protected
    procedure InitializeObject; override;
    destructor Destroy; override;
  end;

implementation

uses
  Globals, ThemeStyles, TypographyStyles,
  JButton, JLabel, JInput, JBadge,
  HttpClient, Validators;


// Local styles

var GStyled: Boolean = false;

procedure RegisterStyles;
begin
  if GStyled then exit;
  GStyled := true;
  AddStyleBlock(#'

    .nv-section {
      display: flex;
      flex-direction: column;
      gap: 8px;
      padding: 16px;
      background: var(--surface-color, #fff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-lg, 8px);
      max-width: 560px;
      width: 100%;
    }

    .nv-section-title {
      font-size: 0.75rem;
      font-weight: 600;
      color: var(--text-light, #64748b);
      text-transform: uppercase;
      letter-spacing: 0.07em;
      padding-bottom: 4px;
      border-bottom: 1px solid var(--border-color, #e2e8f0);
    }

    .nv-output {
      font-family: var(--font-family-mono);
      font-size: 0.85rem;
      padding: 10px 14px;
      background: var(--hover-color, #f1f5f9);
      border-radius: var(--radius-md, 6px);
      color: var(--text-color, #334155);
      white-space: pre-wrap;
      word-break: break-all;
    }

    .nv-code {
      font-family: var(--font-family-mono);
      font-size: 0.8rem;
      color: var(--text-light, #64748b);
      font-style: italic;
    }

    .nv-row {
      display: flex;
      flex-direction: row;
      gap: 8px;
      align-items: center;
      flex-wrap: wrap;
    }

    .nv-field-row {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .nv-status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      flex-shrink: 0;
    }
    .nv-status-dot.online  { background: var(--color-success, #22c55e); }
    .nv-status-dot.offline { background: var(--color-danger,  #ef4444); }

    .nv-detail-row {
      display: flex;
      flex-direction: row;
      gap: 8px;
      font-size: 0.875rem;
      padding: 6px 0;
      border-bottom: 1px solid var(--border-color, #e2e8f0);
    }
    .nv-detail-row:last-child { border-bottom: none; }
    .nv-detail-key {
      color: var(--text-light, #64748b);
      min-width: 80px;
      flex-shrink: 0;
    }
    .nv-detail-val {
      color: var(--text-color, #334155);
      font-weight: 500;
    }
  ');
end;


// TSessionService

procedure TSessionService.Login(const UserName: String);
begin
  FUserName := UserName;
  FLoggedIn := true;
end;

procedure TSessionService.Logout;
begin
  FUserName := '';
  FLoggedIn := false;
end;

function TSessionService.IsLoggedIn: Boolean;
begin
  Result := FLoggedIn;
end;

function TSessionService.UserName: String;
begin
  Result := FUserName;
end;

function TSessionService.Role: String;
begin
  if FLoggedIn then Result := 'editor' else Result := 'guest';
end;


// TContactAdapter

constructor TContactAdapter.Create(ListBox: JW3ListBox);
begin
  inherited Create;
  FListBox := ListBox;
end;

procedure TContactAdapter.SetData(Data: array of TContact);
begin
  FData := Data;
  FListBox.Clear;
  for var i := 0 to FData.Count - 1 do
    FListBox.AddItem(IntToStr(FData[i].ID), FData[i].Name);
end;

function TContactAdapter.ItemAt(Index: Integer): TContact;
begin
  Result := FData[Index];
end;


// TFormNonVisual

destructor TFormNonVisual.Destroy;
begin
  FDataStore.Free;
  FSession.Free;
  inherited;
end;

procedure TFormNonVisual.InitializeObject;
begin
  inherited;

  FSession := TSessionService.Create;

  // Toolbar
  FToolbar := JW3Toolbar.Create(Self);
  var BtnBack := FToolbar.AddItem('<< Back');
  BtnBack.OnClick := procedure(Sender: TObject)
  begin
    Application.GoToForm('Kitchensink');
  end;
  var Title := JW3Label.Create(FToolbar);
  Title.SetText('Non-Visual Components');
  Title.SetStyle('font-weight', '600');
  Title.SetStyle('font-size', '0.9rem');
  Title.SetStyle('padding-left', '8px');

  // Body
  FBody := JW3Panel.Create(Self);
  FBody.SetGrow(1);
  FBody.SetStyle('flex-direction', 'row');

  // Nav sidebar
  FNav := JW3ListBox.Create(FBody);
  FNav.SetStyle('width', '200px');
  FNav.SetStyle('flex-shrink', '0');
  FNav.SetStyle('border-right', '1px solid var(--border-color, #e2e8f0)');

  FNav.AddItem('services',   'Services');
  FNav.AddItem('http',       'HTTP Client');
  FNav.AddItem('validators', 'Validators');
  FNav.AddItem('datastore',  'DataStore');
  FNav.AddItem('models',     'Models');
  FNav.AddItem('adapters',   'Adapters');

  FNav.OnSelect := HandleNavSelect;

  // Display panel
  FDisplay := JW3Panel.Create(FBody);
  FDisplay.SetGrow(1);
  FDisplay.SetStyle('padding', 'var(--space-6, 24px)');
  FDisplay.SetStyle('overflow', 'auto');
  FDisplay.SetStyle('gap', 'var(--space-4, 16px)');
  FDisplay.SetStyle('align-items', 'flex-start');

  var Hint := JW3Label.Create(FDisplay);
  Hint.SetText('Select a category from the list to see a live example.');
  Hint.SetStyle('color', 'var(--text-light, #64748b)');
end;


procedure TFormNonVisual.HandleNavSelect(Sender: TObject; Value: String);
begin
  ShowDemo(Value);
end;

procedure TFormNonVisual.ShowDemo(const Name: String);
begin
  FDisplay.Clear;

  var Heading := JW3Label.Create(FDisplay);
  Heading.AddClass('text-xl');
  Heading.AddClass('font-bold');

  if Name = 'services'        then begin Heading.SetText('Services');     ShowServices;   end
  else if Name = 'http'       then begin Heading.SetText('HTTP Client');  ShowHttpClient; end
  else if Name = 'validators' then begin Heading.SetText('Validators');   ShowValidators; end
  else if Name = 'datastore'  then begin Heading.SetText('DataStore');    ShowDataStore;  end
  else if Name = 'models'     then begin Heading.SetText('Models');       ShowModels;     end
  else if Name = 'adapters'   then begin Heading.SetText('Adapters');     ShowAdapters;   end;
end;


// Shared helpers
function TFormNonVisual.AddSection(const Title: String): JW3Panel;
begin
  Result := JW3Panel.Create(FDisplay);
  Result.AddClass('nv-section');

  if Title <> '' then
  begin
    var T := TElement.Create('div', Result);
    T.AddClass('nv-section-title');
    T.SetText(Title);
  end;
end;

function TFormNonVisual.AddOutput(Parent: TElement; const Text: String): JW3Label;
begin
  Result := JW3Label.Create(Parent);
  Result.AddClass('nv-output');
  Result.SetText(Text);
end;

procedure TFormNonVisual.AddCodeHint(Parent: TElement; const Text: String);
begin
  var El := TElement.Create('div', Parent);
  El.AddClass('nv-code');
  El.SetText(Text);
end;



// Services

procedure TFormNonVisual.ShowServices;
begin
  var Desc := JW3Label.Create(FDisplay);
  Desc.SetText(
    'Services are long-lived objects created once and used across the application. ' +
    'They hold state, own resources, and expose a typed API. They inherit from TObject ' +
    'and never touch the DOM.');
  Desc.AddClass('text-prose');

  // Session service demo

  var Sec := AddSection('TSessionService -- authentication state');

  // Status row
  var StatusRow := TElement.Create('div', Sec);
  StatusRow.AddClass('nv-row');

  var Dot := TElement.Create('div', StatusRow);
  Dot.AddClass('nv-status-dot');
  Dot.AddClass('offline');

  var StatusLbl := JW3Label.Create(StatusRow);
  StatusLbl.SetText('Not logged in  ?*  Role: guest');

  procedure UpdateStatus;
  begin
    if FSession.IsLoggedIn then
    begin
      Dot.RemoveClass('offline');
      Dot.AddClass('online');
      StatusLbl.SetText('Logged in as ' + FSession.UserName + '  ?*  Role: ' + FSession.Role);
    end
    else
    begin
      Dot.RemoveClass('online');
      Dot.AddClass('offline');
      StatusLbl.SetText('Not logged in  ?*  Role: ' + FSession.Role);
    end;
  end;

  UpdateStatus;

  // Buttons
  var BtnRow := TElement.Create('div', Sec);
  BtnRow.AddClass('nv-row');

  var BtnLogin := JW3Button.Create(BtnRow);
  BtnLogin.SetText('Login as Nico');
  BtnLogin.AddClass(csBtnPrimary);
  BtnLogin.AddClass(csBtnSmall);
  BtnLogin.OnClick := procedure(Sender: TObject)
  begin
    FSession.Login('Nico');
    UpdateStatus;
  end;

  var BtnLogin2 := JW3Button.Create(BtnRow);
  BtnLogin2.SetText('Login as Alice');
  BtnLogin2.AddClass(csBtnSecondary);
  BtnLogin2.AddClass(csBtnSmall);
  BtnLogin2.OnClick := procedure(Sender: TObject)
  begin
    FSession.Login('Alice');
    UpdateStatus;
  end;

  var BtnLogout := JW3Button.Create(BtnRow);
  BtnLogout.SetText('Logout');
  BtnLogout.AddClass(csBtnGhost);
  BtnLogout.AddClass(csBtnSmall);
  BtnLogout.OnClick := procedure(Sender: TObject)
  begin
    FSession.Logout;
    UpdateStatus;
  end;

  AddCodeHint(Sec,
    'FSession := TSessionService.Create;  // created once in InitializeObject' + #13 +
    'FSession.Login(''Nico'');              // survives form switches' + #13 +
    'if FSession.IsLoggedIn then ...');
end;


// HTTP Client

procedure TFormNonVisual.ShowHttpClient;
begin
  var Desc := JW3Label.Create(FDisplay);
  Desc.SetText(
    'HTTP helpers are standalone procedures, not classes. Call the procedure, ' +
    'supply success and error callbacks, and receive the result asynchronously. ' +
    'No object to create or free.');
  Desc.AddClass('text-prose');

  // FetchJSON demo

  var Sec1 := AddSection('FetchJSON -- load users from a public API');

  var Output1 := AddOutput(Sec1, 'Press the button to fetch.');

  var Btn1 := JW3Button.Create(Sec1);
  Btn1.SetText('Fetch /users');
  Btn1.AddClass(csBtnPrimary);
  Btn1.AddClass(csBtnSmall);
  Btn1.OnClick := procedure(Sender: TObject)
  begin
    Output1.SetText('Fetching...');
    Btn1.Enabled := false;

    FetchJSON(
      'https://jsonplaceholder.typicode.com/users',

      procedure(Data: variant)
      begin
        Btn1.Enabled := true;
        var result := '';
        var count: Integer;
        asm @count = Math.min(5, (@Data).length); end;
        for var i := 0 to count - 1 do
        begin
          var item: variant;
          asm @item = @Data[@i]; end;
          result := result + String(item.name) + '  <' + String(item.email) + '>' + #13;
        end;
        Output1.SetText(result);
      end,

      procedure(Status: Integer; Msg: String)
      begin
        Btn1.Enabled := true;
        Output1.SetText('Error ' + IntToStr(Status) + ': ' + Msg);
      end
    );
  end;

  AddCodeHint(Sec1,
    'FetchJSON(url,' + #13 +
    '  procedure(Data: variant) begin ... end,' + #13 +
    '  procedure(Status: Integer; Msg: String) begin ... end);');

  // FetchText demo

  var Sec2 := AddSection('FetchText -- load plain text');

  var Output2 := AddOutput(Sec2, 'Press the button to fetch.');

  var Btn2 := JW3Button.Create(Sec2);
  Btn2.SetText('Fetch /todos/1');
  Btn2.AddClass(csBtnSecondary);
  Btn2.AddClass(csBtnSmall);
  Btn2.OnClick := procedure(Sender: TObject)
  begin
    Output2.SetText('Fetching...');
    Btn2.Enabled := false;

    FetchText(
      'https://jsonplaceholder.typicode.com/todos/1',
      procedure(Text: String)
      begin
        Btn2.Enabled := true;
        Output2.SetText(Text);
      end,
      procedure(Status: Integer; Msg: String)
      begin
        Btn2.Enabled := true;
        Output2.SetText('Error ' + IntToStr(Status) + ': ' + Msg);
      end
    );
  end;

  // PostJSON demo

  var Sec3 := AddSection('PostJSON -- send JSON to an endpoint');

  var Output3 := AddOutput(Sec3, 'Press the button to post.');

  var Btn3 := JW3Button.Create(Sec3);
  Btn3.SetText('POST /posts');
  Btn3.AddClass(csBtnSecondary);
  Btn3.AddClass(csBtnSmall);
  Btn3.OnClick := procedure(Sender: TObject)
  begin
    Output3.SetText('Posting...');
    Btn3.Enabled := false;

    var body: variant := new JObject;
    body.title  := 'Hello from ShoeString2';
    body.body   := 'Posted via PostJSON';
    body.userId := 1;

    PostJSON(
      'https://jsonplaceholder.typicode.com/posts',
      JSON.Stringify(body),
      procedure(Data: variant)
      begin
        Btn3.Enabled := true;
        Output3.SetText(
          'id:    ' + String(Data.id)    + #13 +
          'title: ' + String(Data.title) + #13 +
          'body:  ' + String(Data.body));
      end,
      procedure(Status: Integer; Msg: String)
      begin
        Btn3.Enabled := true;
        Output3.SetText('Error ' + IntToStr(Status) + ': ' + Msg);
      end
    );
  end;

  AddCodeHint(Sec3,
    'PostJSON(url, JSON.Stringify(payload),' + #13 +
    '  procedure(Data: variant) begin ... end,' + #13 +
    '  procedure(Status: Integer; Msg: String) begin ... end);');
end;


type
  TValidatorFn = function(const S: String): Boolean;

// Validators

procedure TFormNonVisual.ShowValidators;
begin
  var Desc := JW3Label.Create(FDisplay);
  Desc.SetText(
    'Validators are pure functions. They take a string, return a boolean. ' +
    'No DOM dependency, no side effects. Apply the result to the field''s CSS class ' +
    'and let the browser render the state.');
  Desc.AddClass('text-prose');

  // Live validation demo

  var Sec := AddSection('Live field validation');

  function MakeField(const Label, Placeholder: String;
    ValidFn: TValidatorFn): JW3Label;
  var
    InpHandle: variant;
    ErrHandle: variant;
  begin
    var Row := TElement.Create('div', Sec);
    Row.AddClass('nv-field-row');

    var Lbl := TElement.Create('div', Row);
    Lbl.AddClass('field-label');
    Lbl.SetText(Label);

    var Inp := JW3Input.Create(Row);
    Inp.Placeholder := Placeholder;

    var Err := JW3Label.Create(Row);
    Err.AddClass('field-error');
    Err.SetText(' ');

    Result := Err;

    // Store validator and error element on the DOM node so the
    // blur closure reads per-element data, not the captured parameter
    InpHandle := Inp.Handle;
    ErrHandle := Err.Handle;
    asm
      (@InpHandle)._validFn = @ValidFn;
      (@InpHandle)._errEl   = @ErrHandle;
      (@InpHandle)._label   = @Label;
    end;

    // Use blur (tab-out / focus-lost) for validation feedback
    InpHandle.addEventListener('blur', procedure(E: variant)
    begin
      var H     := E.currentTarget;
      var Val   := H.value;
      var EEl   := H._errEl;
      var Fn: TValidatorFn;
      var Lbl2: String;
      asm
        @Fn   = (@H)._validFn;
        @Lbl2 = (@H)._label;
      end;
      if Val = '' then
      begin
        asm
          (@H).classList.remove('valid');
          (@H).classList.remove('invalid');
          (@EEl).textContent = ' ';
        end;
      end
      else if Fn(Val) then
      begin
        asm
          (@H).classList.remove('invalid');
          (@H).classList.add('valid');
          (@EEl).textContent = ' ';
        end;
      end
      else
      begin
        asm
          (@H).classList.remove('valid');
          (@H).classList.add('invalid');
          (@EEl).textContent = 'Invalid ' + @Lbl2;
        end;
      end;
    end);
  end;

  MakeField('Email address',  'you@example.com',   @IsEmail);
  MakeField('URL',            'https://example.com', @IsURL);
  MakeField('Integer',        '42',                @IsInteger);
  MakeField('Numeric',        '3.14',              @IsNumeric);

  // MinLength/MaxLength row
  var MRow := TElement.Create('div', Sec);
  MRow.AddClass('nv-field-row');

  var MLbl := TElement.Create('div', MRow);
  MLbl.AddClass('field-label');
  MLbl.SetText('Password (8-32 chars)');

  var MInp := JW3Input.Create(MRow);
  MInp.SetAttribute('type', 'password');
  MInp.Placeholder := 'At least 8 characters';

  var MErr := JW3Label.Create(MRow);
  MErr.AddClass('field-error');
  MErr.SetText(' ');

  var MInpH := MInp.Handle;
  var MErrH := MErr.Handle;
  MInpH.addEventListener('blur', procedure(E: variant)
  begin
    var H   := E.currentTarget;
    var Val := H.value;
    var EEl := MErrH;
    if Val = '' then
    begin
      asm
        (@H).classList.remove('valid');
        (@H).classList.remove('invalid');
        (@EEl).textContent = ' ';
      end;
    end
    else if not MinLength(Val, 8) then
    begin
      asm
        (@H).classList.remove('valid');
        (@H).classList.add('invalid');
        (@EEl).textContent = 'Minimum 8 characters';
      end;
    end
    else if not MaxLength(Val, 32) then
    begin
      asm
        (@H).classList.remove('valid');
        (@H).classList.add('invalid');
        (@EEl).textContent = 'Maximum 32 characters';
      end;
    end
    else
    begin
      asm
        (@H).classList.remove('invalid');
        (@H).classList.add('valid');
        (@EEl).textContent = ' ';
      end;
    end;
  end);

  AddCodeHint(Sec,
    'if IsEmail(Input.Value)' + #13 +
    '  then Input.AddClass(''valid'')' + #13 +
    '  else Input.AddClass(''invalid'');');
end;


// DataStore

procedure TFormNonVisual.ShowDataStore;
begin
  var Desc := JW3Label.Create(FDisplay);
  Desc.SetText(
    'DataStore is an observable key-value store. Components subscribe to keys ' +
    'and receive a callback whenever a value changes. Put fires subscribers immediately. ' +
    'BeginUpdate/EndUpdate batches multiple changes into a single notification round.');
  Desc.AddClass('text-prose');

  FDataStore.Free;
  FDataStore := JW3DataStore.Create;
  var Store := FDataStore;

  // Subscribe / Put demo

  var Sec1 := AddSection('Subscribe and Put');

  // Two labels watching two different keys
  var CartRow := TElement.Create('div', Sec1);
  CartRow.AddClass('nv-row');
  var CartKey := TElement.Create('span', CartRow);
  CartKey.AddClass('nv-code');
  CartKey.SetText('cart.count ->');
  var CartVal := AddOutput(CartRow, '--');

  var UserRow := TElement.Create('div', Sec1);
  UserRow.AddClass('nv-row');
  var UserKey := TElement.Create('span', UserRow);
  UserKey.AddClass('nv-code');
  UserKey.SetText('user.name  ->');
  var UserVal := AddOutput(UserRow, '--');

  // Subscribe both labels
  Store.Subscribe('cart.count', procedure(const Key: String; Value: variant)
  begin
    CartVal.SetText(String(Value));
  end);

  Store.Subscribe('user.name', procedure(const Key: String; Value: variant)
  begin
    UserVal.SetText(String(Value));
  end);

  var BtnRow := TElement.Create('div', Sec1);
  BtnRow.AddClass('nv-row');

  var B1 := JW3Button.Create(BtnRow);
  B1.SetText('Add to cart');
  B1.AddClass(csBtnPrimary);
  B1.AddClass(csBtnSmall);
  var FCartCount := 0;
  B1.OnClick := procedure(Sender: TObject)
  begin
    FCartCount := FCartCount + 1;
    Store.Put('cart.count', FCartCount);
  end;

  var B2 := JW3Button.Create(BtnRow);
  B2.SetText('Set user');
  B2.AddClass(csBtnSecondary);
  B2.AddClass(csBtnSmall);
  B2.OnClick := procedure(Sender: TObject)
  begin
    Store.Put('user.name', 'Nico');
  end;

  var B3 := JW3Button.Create(BtnRow);
  B3.SetText('Clear cart');
  B3.AddClass(csBtnGhost);
  B3.AddClass(csBtnSmall);
  B3.OnClick := procedure(Sender: TObject)
  begin
    FCartCount := 0;
    Store.Put('cart.count', 0);
  end;

  // BeginUpdate/EndUpdate demo

  var Sec2 := AddSection('BeginUpdate / EndUpdate -- batched notifications');

  var BatchLog := AddOutput(Sec2,
    'With BeginUpdate active, all Put calls are deferred.' + #13 +
    'Subscribers fire once per key when EndUpdate is called.');

  var BtnBatch := JW3Button.Create(Sec2);
  BtnBatch.SetText('Run batch update');
  BtnBatch.AddClass(csBtnPrimary);
  BtnBatch.AddClass(csBtnSmall);

  var FNotifyCount := 0;
  Store.Subscribe('*', procedure(const Key: String; Value: variant)
  begin
    FNotifyCount := FNotifyCount + 1;
  end);

  BtnBatch.OnClick := procedure(Sender: TObject)
  begin
    FNotifyCount := 0;
    Store.BeginUpdate;
    Store.Put('x', 1);
    Store.Put('y', 2);
    Store.Put('x', 3);   // second write to same key -- one notification
    Store.Put('z', 4);
    Store.EndUpdate;

    BatchLog.SetText(
      'Put x=1, y=2, x=3, z=4 inside BeginUpdate.' + #13 +
      'Subscriber notified ' + IntToStr(FNotifyCount) + ' times total (3 keys, not 4 writes).');
  end;

  AddCodeHint(Sec2,
    'Store.BeginUpdate;' + #13 +
    'Store.Put(''x'', 1);  Store.Put(''y'', 2);  Store.Put(''x'', 3);' + #13 +
    'Store.EndUpdate;  // fires once per changed key');
end;


type
  TOrder = record
    OrderID:   String;
    Customer:  String;
    Amount:    Float;
    Lines:     Integer;
    Completed: Boolean;
  end;

// Models

procedure TFormNonVisual.ShowModels;
begin
  var Desc := JW3Label.Create(FDisplay);
  Desc.SetText(
    'Models are plain Pascal classes or records. They hold data, expose typed ' +
    'fields, and can carry validation logic. They have no DOM dependency and no ' +
    'framework coupling -- they can move unchanged to a Node.js backend.');
  Desc.AddClass('text-prose');

  // Build sample orders
  var Orders: array of TOrder;

  procedure MakeOrder(const ID, Customer: String;
    Amount: Float; Lines: Integer; Done: Boolean);
  var O: TOrder;
  begin
    O.OrderID   := ID;
    O.Customer  := Customer;
    O.Amount    := Amount;
    O.Lines     := Lines;
    O.Completed := Done;
    Orders.Add(O);
  end;

  MakeOrder('ORD-0041', 'Alice Johnson',  249.95, 3, true);
  MakeOrder('ORD-0042', 'Bob Smith',       89.00, 1, false);
  MakeOrder('ORD-0043', 'Carol White',    412.50, 5, false);
  MakeOrder('ORD-0044', 'Dave Brown',       0.00, 0, false);  // invalid

  // Render each order

    procedure AddRow(Sec: TElement; const Key, Val: String);
    begin
      var Row := TElement.Create('div', Sec);
      Row.AddClass('nv-detail-row');
      var K := TElement.Create('div', Row);
      K.AddClass('nv-detail-key');
      K.SetText(Key);
      var V := TElement.Create('div', Row);
      V.AddClass('nv-detail-val');
      V.SetText(Val);
    end;

  for var i := 0 to Orders.Count - 1 do
  begin
    var O := Orders[i];

    // Validation
    var Valid := (O.Customer <> '') and (O.Amount > 0) and (O.Lines > 0);

    var Sec := AddSection(O.OrderID);

    AddRow(Sec, 'Customer', O.Customer);
    AddRow(Sec, 'Amount',   '$' + FloatToStr(O.Amount));
    AddRow(Sec, 'Lines',    IntToStr(O.Lines));

    var StatusRow := TElement.Create('div', Sec);
    StatusRow.AddClass('nv-row');

    var Status := JW3Badge.Create(StatusRow);
    if O.Completed then
    begin
      Status.SetText('Completed');
      Status.AddClass(csBadgeSuccess);
    end
    else if Valid then
    begin
      Status.SetText('Pending');
      Status.AddClass(csBadgeWarning);
    end
    else
    begin
      Status.SetText('Invalid');
      Status.AddClass(csBadgeDanger);
    end;
  end;

  AddCodeHint(FDisplay,
    'type TOrder = record' + #13 +
    '  OrderID: String; Amount: Float; ...' + #13 +
    'end;' + #13 +
    'var Valid := (O.Customer <> ' + #39 + #39 + ') and (O.Amount > 0);');
end;


// Adapters

procedure TFormNonVisual.ShowAdapters;
begin
  var Desc := JW3Label.Create(FDisplay);
  Desc.SetText(
    'Adapters sit between non-visual data and visual components. ' +
    'TContactAdapter owns a data array and a JW3ListBox reference. ' +
    'SetData populates the list. Selecting an item reads back the original record. ' +
    'Neither side knows how the other works.');
  Desc.AddClass('text-prose');

  // Build the contact data
  var Contacts: array of TContact;

  procedure MakeContact(ID: Integer;
    const Name, Email, Company: String; Active: Boolean);
  var C: TContact;
  begin
    C.ID      := ID;
    C.Name    := Name;
    C.Email   := Email;
    C.Company := Company;
    C.Active  := Active;
    Contacts.Add(C);
  end;

  MakeContact(1, 'Alice Johnson',  'alice@acmecorp.com',   'Acme Corp',       true);
  MakeContact(2, 'Bob Smith',      'bob@widgets.io',       'Widgets Inc',     true);
  MakeContact(3, 'Carol White',    'carol@example.com',    'Example Ltd',     false);
  MakeContact(4, 'Dave Brown',     'dave@techventure.com', 'Tech Ventures',   true);
  MakeContact(5, 'Eve Davis',      'eve@designco.io',      'Design Co',       true);
  MakeContact(6, 'Frank Miller',   'frank@buildit.net',    'Build It',        false);

  // Two-panel layout: list (left) + detail (right)

  var Sec := AddSection('TContactAdapter -- data array -> JW3ListBox');

  var SplitRow := TElement.Create('div', Sec);
  SplitRow.SetStyle('display', 'flex');
  SplitRow.SetStyle('flex-direction', 'row');
  SplitRow.SetStyle('gap', '16px');

  // List
  var ListBox := JW3ListBox.Create(SplitRow);
  ListBox.SetStyle('width', '180px');
  ListBox.SetStyle('flex-shrink', '0');
  ListBox.SetStyle('height', '220px');

  // Detail panel
  var Detail := JW3Panel.Create(SplitRow);
  Detail.SetGrow(1);
  Detail.SetStyle('gap', '4px');

  var PlaceholderLbl := JW3Label.Create(Detail);
  PlaceholderLbl.SetText('Select a contact');
  PlaceholderLbl.SetStyle('color', 'var(--text-light, #64748b)');

  // Adapter
  var Adapter := TContactAdapter.Create(ListBox);
  Adapter.SetData(Contacts);

  // On selection, render the contact's fields
  ListBox.OnSelect := procedure(Sender: TObject; Value: String)
  begin
    var ID := StrToInt(Value);
    var C: TContact;
    for var i := 0 to Contacts.Count - 1 do
      if Contacts[i].ID = ID then C := Contacts[i];

    Detail.Clear;

    procedure AddDetailRow(const Key, Val: String);
    begin
      var Row := TElement.Create('div', Detail);
      Row.AddClass('nv-detail-row');
      var K := TElement.Create('span', Row);
      K.AddClass('nv-detail-key');
      K.SetText(Key);
      var V := TElement.Create('span', Row);
      V.AddClass('nv-detail-val');
      V.SetText(Val);
    end;

    AddDetailRow('Name',    C.Name);
    AddDetailRow('Email',   C.Email);
    AddDetailRow('Company', C.Company);

    var StatusRow := TElement.Create('div', Detail);
    StatusRow.AddClass('nv-row');
    StatusRow.SetStyle('margin-top', '4px');

    var Badge := JW3Badge.Create(StatusRow);
    if C.Active then
    begin
      Badge.SetText('Active');
      Badge.AddClass(csBadgeSuccess);
    end
    else
    begin
      Badge.SetText('Inactive');
      Badge.AddClass(csBadgeDanger);
    end;
  end;

  AddCodeHint(Sec,
    'var Adapter := TContactAdapter.Create(ListBox);' + #13 +
    'Adapter.SetData(Contacts);' + #13 +
    '// Adapter populates the list; selection reads back TContact.');
end;


// Init

initialization
  RegisterStyles;
end.