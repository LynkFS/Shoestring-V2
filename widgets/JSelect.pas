unit JSelect;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Select (Dropdown)
//
//  Creates a <select> element. Uses .field from ThemeStyles. Provides
//  typed methods for adding/removing options and reading the selected value.
//
//  Usage:
//
//    var Country := JW3Select.Create(Group);
//    Country.AddOption('', 'Choose a country...');
//    Country.AddOption('AU', 'Australia');
//    Country.AddOption('NZ', 'New Zealand');
//    Country.OnChange := HandleCountryChange;
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, Types;

type
  TSelectChangedEvent = procedure(Sender: TObject; Value: String);

  JW3Select = class(TElement)
  private
    FOnChange: TSelectChangedEvent;

    function  GetValue: String;
    procedure SetValue(const V: String);
    function  GetSelectedIndex: Integer;
    procedure SetSelectedIndex(V: Integer);
    function  GetSelectedText: String;

    procedure CBChange(EventObj: JEvent);

  public
    constructor Create(Parent: TElement); virtual;

    procedure AddOption(const Value, Text: String);
    procedure ClearOptions;
    function  OptionCount: Integer;

    property Value: String read GetValue write SetValue;
    property SelectedIndex: Integer read GetSelectedIndex write SetSelectedIndex;
    property SelectedText: String read GetSelectedText;
    property OnChange: TSelectChangedEvent read FOnChange write FOnChange;
  end;

implementation

uses Globals;

{ JW3Select }

constructor JW3Select.Create(Parent: TElement);
begin
  inherited Create('select', Parent);
  AddClass('field');

  SetStyle('height', 'auto');
  SetStyle('padding', '8px 12px');
  SetStyle('appearance', 'auto');
  SetStyle('cursor', 'pointer');

  Handle.addEventListener('change', @CBChange);
end;

procedure JW3Select.CBChange(EventObj: JEvent);
begin
  if assigned(FOnChange) then
    FOnChange(Self, GetValue);
end;

// ── Value ────────────────────────────────────────────────────────────────

function JW3Select.GetValue: String;
begin
  Result := self.handle.value;
end;

procedure JW3Select.SetValue(const V: String);
begin
  self.Handle.value := V;
end;

// ── Selected index ───────────────────────────────────────────────────────

function JW3Select.GetSelectedIndex: Integer;
begin
  Result := self.handle.selectedIndex;
end;

procedure JW3Select.SetSelectedIndex(V: Integer);
begin
  self.handle. selectedIndex := V;
end;

// ── Selected text ────────────────────────────────────────────────────────

function JW3Select.GetSelectedText: String;
begin
  Result := '';
  if self.handle.selectedIndex >= 0
    then Result := self.handle.options[self.handle.selectedIndex].text;
end;

// ── Option management ────────────────────────────────────────────────────

procedure JW3Select.AddOption(const Value, Text: String);
begin
  var opt : variant := document.createElement('option');
  opt.value := Value;
  opt.textContent := Text;
  self.handle.appendChild(opt);
end;

procedure JW3Select.ClearOptions;
begin
  while self.handle.options.length > 0 do
    self.handle.remove(0);
end;

function JW3Select.OptionCount: Integer;
begin
  Result := self.handle.options.length;
end;

end.