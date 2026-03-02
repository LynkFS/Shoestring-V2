unit JCheckbox;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Checkbox
//
//  Creates a <div> containing <input type="checkbox"> + <label for="id">.
//  The for/id link makes the label clickable. Structure:
//
//    <div class="checkbox">
//      <input type="checkbox" id="chk_N" class="checkbox-input">
//      <label for="chk_N" class="checkbox-label">Caption</label>
//    </div>
//
//  Usage:
//
//    var Agree := JW3Checkbox.Create(Group);
//    Agree.Caption := 'I agree to the terms';
//    Agree.OnChange := HandleAgreeChange;
//    if Agree.Checked then ...
//
//  CSS variables:
//
//    --chk-size         Checkbox size          default: 18px
//    --chk-radius       Checkbox radius        default: var(--radius-sm)
//    --chk-gap          Gap to label text      default: var(--space-2)
//    --chk-accent       Checked colour         default: var(--primary-color)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, Types;

const
  csCheckbox      = 'checkbox';
  csCheckboxInput = 'checkbox-input';
  csCheckboxLabel = 'checkbox-label';

type
  TCheckboxChangedEvent = procedure(Sender: TObject; Checked: Boolean);

  JW3Checkbox = class(TElement)
  private
    FInput:    variant;     // the <input> DOM element
    FLabel:    variant;     // the <label> element
    FOnChange: TCheckboxChangedEvent;

    function  GetChecked: Boolean;
    procedure SetChecked(V: Boolean);
    function  GetCaption: String;
    procedure SetCaption(const V: String);

  public
    constructor Create(Parent: TElement); virtual;

    procedure SetText(const Value: String);

    property Checked: Boolean read GetChecked write SetChecked;
    property Caption: String read GetCaption write SetCaption;
    property OnChange: TCheckboxChangedEvent read FOnChange write FOnChange;
  end;

procedure RegisterCheckboxStyles;

implementation

uses Globals;

var
  FRegistered: Boolean := false;
  FCheckId: Integer := 0;

procedure RegisterCheckboxStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    .checkbox {
      display: flex;
      flex-direction: row;
      align-items: center;
      gap: var(--chk-gap, var(--space-2, 8px));
      cursor: pointer;
      user-select: none;
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-color, #334155);
    }

    .checkbox-input {
      width: var(--chk-size, 18px);
      height: var(--chk-size, 18px);
      flex-shrink: 0;
      margin: 0;
      border-radius: var(--chk-radius, var(--radius-sm, 4px));
      accent-color: var(--chk-accent, var(--primary-color, #6366f1));
      cursor: pointer;
    }

    .checkbox-input:focus-visible {
      outline: 2px solid var(--primary-color, #6366f1);
      outline-offset: 2px;
    }

    .checkbox-label {
      line-height: 1.4;
      cursor: pointer;
    }

    .checkbox-input:disabled,
    .checkbox-input:disabled + .checkbox-label {
      opacity: 0.5;
      cursor: default;
    }
  ');
end;

{ JW3Checkbox }

constructor JW3Checkbox.Create(Parent: TElement);
var
  chkId: String;
  wrapper: variant;
begin
  inherited Create('div', Parent);
  AddClass(csCheckbox);

  // Generate a unique id for the input/label link
  inc(FCheckId);
  chkId := 'chk_' + IntToStr(FCheckId);

  // Build <input type="checkbox" id="chk_N">
  wrapper := Self.Handle;

  var inp: variant := document.createElement('input');
  inp.type := 'checkbox';
  inp.id := chkId;
  inp.className := csCheckboxInput;
  wrapper.appendChild(inp);
  FInput := inp;

  // Build <label for="chk_N">
  var lbl: variant := document.createElement('label');
  lbl.setAttribute('for', chkId);
  lbl.className := csCheckboxLabel;
  wrapper.appendChild(lbl);
  FLabel := lbl;

  // Change event
  inp.addEventListener('change', procedure(e: JEvent) begin
    if assigned(FOnChange) then
      FOnChange(Self, GetChecked);
  end);
end;

function JW3Checkbox.GetChecked: Boolean;
begin
  Result := FInput.checked;
end;

procedure JW3Checkbox.SetChecked(V: Boolean);
begin
  FInput.checked := V;
end;

function JW3Checkbox.GetCaption: String;
begin
  Result := FLabel.textContent;
end;

procedure JW3Checkbox.SetCaption(const V: String);
begin
  FLabel.textContent := V;
end;

procedure JW3Checkbox.SetText(const Value: String);
begin
  SetCaption(Value);
end;

initialization
  RegisterCheckboxStyles;
end.