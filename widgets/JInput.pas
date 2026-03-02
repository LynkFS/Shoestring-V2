unit JInput;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Text Input
//
//  Creates an <input> element. Uses the .field class from ThemeStyles
//  for consistent sizing, border, focus ring, and validation styling.
//
//  Usage:
//
//    var Email := JW3Input.Create(Group);
//    Email.Placeholder := 'you@example.com';
//    Email.InputType := 'email';
//    Email.OnChange := HandleEmailChange;
//
//  Supported InputType values: text, email, password, number, tel, url,
//  search, date, time, datetime-local, color
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, Types;

type
  TInputChangedEvent = procedure(Sender: TObject; Value: String);

  JW3Input = class(TElement)
  private
    FOnChange: TInputChangedEvent;

    function  GetValue: String;
    procedure SetValue(const V: String);
    function  GetPlaceholder: String;
    procedure SetPlaceholder(const V: String);
    function  GetInputType: String;
    procedure SetInputType(const V: String);
    function  GetReadOnly: Boolean;
    procedure SetReadOnly(V: Boolean);

    procedure CBInput(EventObj: JEvent);

  public
    constructor Create(Parent: TElement); virtual;

    property Value: String read GetValue write SetValue;
    property Placeholder: String read GetPlaceholder write SetPlaceholder;
    property InputType: String read GetInputType write SetInputType;
    property ReadOnly: Boolean read GetReadOnly write SetReadOnly;
    property OnChange: TInputChangedEvent read FOnChange write FOnChange;
  end;

implementation

uses Globals;

{ JW3Input }

constructor JW3Input.Create(Parent: TElement);
begin
  inherited Create('input', Parent);
  AddClass('field');
  SetAttribute('type', 'text');

  // Wire the 'input' event (fires on every keystroke)
  //Handle.addEventListener('input', mRef);
  Handle.addEventListener('input', @CBInput);
end;

procedure JW3Input.CBInput(EventObj: JEvent);
begin
  if assigned(FOnChange) then
    FOnChange(Self, GetValue);
end;

// ── Value ────────────────────────────────────────────────────────────────

function JW3Input.GetValue: String;
begin
  //asm @Result = @self.FElement.value; end;
  Result := GetAttribute('value');
end;

procedure JW3Input.SetValue(const V: String);
begin
  //asm @self.FElement.value = @V; end;
  SetAttribute('value', V);
end;

// ── Placeholder ──────────────────────────────────────────────────────────

function JW3Input.GetPlaceholder: String;
begin
  //asm @Result = @self.FElement.placeholder; end;
  Result := GetAttribute('placeholder');
end;

procedure JW3Input.SetPlaceholder(const V: String);
begin
  //asm @self.FElement.placeholder = @V; end;
  SetAttribute('placeholder', V);
end;

// ── InputType ────────────────────────────────────────────────────────────

function JW3Input.GetInputType: String;
begin
  Result := GetAttribute('type');
end;

procedure JW3Input.SetInputType(const V: String);
begin
  SetAttribute('type', V);
end;

// ── ReadOnly ─────────────────────────────────────────────────────────────

function JW3Input.GetReadOnly: Boolean;
begin
  //asm @Result = @self.FElement.readOnly; end;
  Result := handle.getAttribute('readonly');
end;

procedure JW3Input.SetReadOnly(V: Boolean);
begin
  //asm @self.FElement.readOnly = @V; end;
  handle.setAttribute('readonly', V);
end;

end.
