unit JTextArea;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Text Area
//
//  Creates a <textarea> element. Uses .field from ThemeStyles. Overrides
//  height to auto since textareas are multi-line.
//
//  Usage:
//
//    var Notes := JW3TextArea.Create(Group);
//    Notes.Placeholder := 'Enter notes...';
//    Notes.Rows := 5;
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, Types;

type
  TTextAreaChangedEvent = procedure(Sender: TObject; Value: String);

  JW3TextArea = class(TElement)
  private
    FOnChange: TTextAreaChangedEvent;

    function  GetValue: String;
    procedure SetValue(const V: String);
    function  GetPlaceholder: String;
    procedure SetPlaceholder(const V: String);
    function  GetRows: Integer;
    procedure SetRows(V: Integer);
    function  GetReadOnly: Boolean;
    procedure SetReadOnly(V: Boolean);

    procedure CBInput(EventObj: JEvent);

  public
    constructor Create(Parent: TElement); virtual;

    property Value: String read GetValue write SetValue;
    property Placeholder: String read GetPlaceholder write SetPlaceholder;
    property Rows: Integer read GetRows write SetRows;
    property ReadOnly: Boolean read GetReadOnly write SetReadOnly;
    property OnChange: TTextAreaChangedEvent read FOnChange write FOnChange;
  end;

implementation

uses Globals;

{ JW3TextArea }

constructor JW3TextArea.Create(Parent: TElement);
begin
  inherited Create('textarea', Parent);
  AddClass('field');

  // Override field height — textarea grows with content
  SetStyle('height', 'auto');
  SetStyle('min-height', 'var(--field-height, 40px)');
  SetStyle('padding', 'var(--space-2, 8px) var(--space-3, 12px)');
  SetStyle('resize', 'vertical');
  SetStyle('line-height', '1.5');
  SetStyle('font-family', 'inherit');

  SetAttribute('rows', '3');

  Handle.addEventListener('input', @CBInput, false);
end;

procedure JW3TextArea.CBInput(EventObj: JEvent);
begin
  if assigned(FOnChange) then
    FOnChange(Self, GetValue);
end;

function JW3TextArea.GetValue: String;
begin
  Result := String(Handle.value);
end;

procedure JW3TextArea.SetValue(const V: String);
begin
  Handle.value := V;
end;

function JW3TextArea.GetPlaceholder: String;
begin
  //asm @Result = @self.FElement.placeholder; end;
  Result := handle.getAttribute('placeholder');
end;

procedure JW3TextArea.SetPlaceholder(const V: String);
begin
  //asm @self.FElement.placeholder = @V; end;
  SetAttribute('placeholder', V);
end;

function JW3TextArea.GetRows: Integer;
begin
  Result := Integer(Handle.rows);
end;

procedure JW3TextArea.SetRows(V: Integer);
begin
  //asm @self.FElement.rows = @V; end;
  handle.setAttribute('rows', V);
end;

function JW3TextArea.GetReadOnly: Boolean;
begin
  Result := Handle.hasAttribute('readonly');
end;

procedure JW3TextArea.SetReadOnly(V: Boolean);
begin
  //asm @self.FElement.readOnly = @V; end;
  handle.setAttribute('readonly', V);
end;

end.
