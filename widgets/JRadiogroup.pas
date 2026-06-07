unit JRadioGroup;

// =====================================================================================
//
//  JW3RadioGroup
//
//  A group of mutually exclusive radio buttons sharing a common HTML name.
//  Each button is an <input type="radio"> + <label> pair wrapped in a <div>.
//
//  Layout is adaptive: a ResizeObserver watches the container and switches
//  between flex-direction: row (horizontal) when all buttons fit side-by-side,
//  or flex-direction: column (vertical) when they do not. Transitions are
//  instant and re-evaluated on every container size change.
//
//  DOM structure:
//
//    <div class="radio-group">             <- JW3RadioGroup root
//      <div class="radio-item">
//        <input type="radio" name="rg_N" id="ri_M" class="radio-input">
//        <label for="ri_M" class="radio-label">Caption</label>
//      </div>
//      <div class="radio-item"> ... </div>
//      ...
//    </div>
//
//  Usage:
//
//    var Gender := JW3RadioGroup.Create(Panel);
//    Gender.AddButton('Male',   'M');
//    Gender.AddButton('Female', 'F');
//    Gender.AddButton('Other',  'O');
//    Gender.OnChange := HandleGenderChange;
//    if Gender.SelectedValue = 'F' then ...
//    Gender.SelectedIndex := 0;
//
//  CSS custom properties:
//
//    --rg-gap          Gap between buttons    default: var(--space-3, 12px)
//    --rg-item-gap     Gap inside each item   default: var(--space-2, 8px)
//    --radio-size      Radio circle diameter  default: 18px
//    --radio-accent    Checked fill colour    default: var(--primary-color)
//
// =====================================================================================

interface

uses JElement, Types;

const
  csRadioGroup    = 'radio-group';
  csRadioItem     = 'radio-item';
  csRadioInput    = 'radio-input';
  csRadioLabel    = 'radio-label';
  csRadioDisabled = 'radio-item--disabled';

type
  TRadioGroupChangeEvent = procedure(Sender: TObject; ItemIndex: Integer;
    const Value: String);

  JW3RadioGroup = class(TElement)
  private
    // Parallel arrays - one entry per button, same order as DOM.
    // FInputIds holds the <input> element's HTML id attribute.
    // FValues   holds the application-defined value string.
    FInputIds:  array of String;
    FValues:    array of String;
    FGroupName: String;
    FOnChange:  TRadioGroupChangeEvent;

    function  GetCount: Integer;
    function  GetSelectedIndex: Integer;
    procedure SetSelectedIndex(Index: Integer);
    function  GetSelectedValue: String;
    function  GetEnabled: Boolean;
    procedure SetEnabled(V: Boolean);
    function  GetItemCaption(Index: Integer): String;
    procedure SetItemCaption(Index: Integer; const V: String);

    procedure InitResizeObserver;

  public
    constructor Create(Parent: TElement); virtual;

    // Add a radio button. Returns the zero-based index of the new button.
    // Value is an optional application string; Caption is the display text.
    function AddButton(const Caption: String; Value: String = ''): Integer;

    // Remove all buttons from the group.
    procedure Clear;

    // Number of buttons currently in the group.
    property Count: Integer read GetCount;

    // Zero-based index of the selected button, -1 when nothing is selected.
    property SelectedIndex: Integer read GetSelectedIndex write SetSelectedIndex;

    // Application value of the selected button, '' when nothing is selected.
    property SelectedValue: String read GetSelectedValue;

    // Enable or disable all buttons at once.
    property Enabled: Boolean read GetEnabled write SetEnabled;

    // Read/write the visible caption of an individual button by index.
    property ItemCaption[Index: Integer]: String
      read GetItemCaption write SetItemCaption;

    // Fired whenever the user changes the selection.
    property OnChange: TRadioGroupChangeEvent read FOnChange write FOnChange;
  end;

procedure RegisterRadioGroupStyles;

implementation

uses Globals;

var
  FRegistered: Boolean := false;
  FGroupSeq:   Integer := 0;  // counter for unique group name
  FItemSeq:    Integer := 0;  // counter for unique input IDs

// ============================================================================
//  Styles
// =============================================================================

procedure RegisterRadioGroupStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* Group container */

    .radio-group {
      display:        flex;
      flex-direction: row;        /* ResizeObserver may switch to column */
      flex-wrap:      nowrap;
      align-items:    center;
      gap:            var(--rg-gap, var(--space-3, 12px));
    }

    /* Individual item wrapper */

    .radio-item {
      display:        inline-flex;
      flex-direction: row;
      flex-shrink:    0;          /* must not compress - used for width measure */
      align-items:    center;
      gap:            var(--rg-item-gap, var(--space-2, 8px));
      cursor:         pointer;
      user-select:    none;
    }

    /* Native radio input */

    .radio-input {
      width:        var(--radio-size, 18px);
      height:       var(--radio-size, 18px);
      flex-shrink:  0;
      margin:       0;
      accent-color: var(--radio-accent, var(--primary-color, #6366f1));
      cursor:       pointer;
    }

    .radio-input:focus-visible {
      outline:        2px solid var(--primary-color, #6366f1);
      outline-offset: 2px;
    }

    /* Label */

    .radio-label {
      font-size:   var(--font-size-sm, 0.875rem);
      color:       var(--text-color, #334155);
      line-height: 1.4;
      cursor:      pointer;
    }

    /* Disabled state */

    .radio-item--disabled .radio-input,
    .radio-item--disabled .radio-label {
      opacity:        0.5;
      cursor:         default;
      pointer-events: none;
    }

  ');
end;

// =============================================================================
//  Layout detection via ResizeObserver
// =============================================================================

procedure JW3RadioGroup.InitResizeObserver;
var
  h: variant;
begin
  // Capture Handle into a local so the asm block can reference it via @h.
  // (Do not use (@FField) inside asm - field name mangling is not safe there.)
  h := Self.Handle;
  asm
    var el = @h;
    var ro = new ResizeObserver(function() {
      var items = el.querySelectorAll('.radio-item');
      if (items.length === 0) return;

      var cw = el.clientWidth;
      if (cw === 0) return;     /* not yet in layout - skip */

      /* Items have flex-shrink:0 so scrollWidth gives their natural width */
      var gap = parseFloat(getComputedStyle(el).gap) || 12;
      var needed = (items.length - 1) * gap;
      for (var i = 0; i < items.length; i++) {
        needed += items[i].scrollWidth;
      }

      if (needed <= cw) {
        el.style.flexDirection = 'row';
        el.style.alignItems    = 'center';
      } else {
        el.style.flexDirection = 'column';
        el.style.alignItems    = 'flex-start';
      }
    });
    ro.observe(el);
  end;
end;

// =========================================================================================
//  Constructor
// =========================================================================================

constructor JW3RadioGroup.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csRadioGroup);

  // Each group instance gets its own unique name so browsers enforce
  // mutual exclusion only within the group, not across groups on the page.
  inc(FGroupSeq);
  FGroupName := 'rg_' + IntToStr(FGroupSeq);

  InitResizeObserver;
end;

// =========================================================================================
//  AddButton
// =========================================================================================

function JW3RadioGroup.AddButton(const Caption: String;
  Value: String = ''): Integer;
var
  idx:         Integer;
  itemId:      String;
  wrap:        variant;
  inp:         variant;
  lbl:         variant;
  h:           variant;
  capturedIdx: Integer;  // named var so closure captures it safely
begin
  // Record the index this button will occupy before we add it.
  idx         := FInputIds.Count;
  capturedIdx := idx;

  inc(FItemSeq);
  itemId := 'ri_' + IntToStr(FItemSeq);

  h := Self.Handle;

  // <div class="radio-item">
  wrap := document.createElement('div');
  wrap.className := csRadioItem;
  h.appendChild(wrap);

  // <input type="radio" name="rg_N" id="ri_M">
  inp := document.createElement('input');
  inp.setAttribute('type',  'radio');
  inp.setAttribute('name',  FGroupName);
  inp.id        := itemId;
  inp.className := csRadioInput;
  wrap.appendChild(inp);

  // <label for="ri_M">Caption</label>
  lbl := document.createElement('label');
  lbl.setAttribute('for', itemId);
  lbl.className   := csRadioLabel;
  lbl.textContent := Caption;
  wrap.appendChild(lbl);

  // Store metadata
  FInputIds.Add(itemId);
  FValues.Add(Value);

  // Wire change event.
  // The closure captures capturedIdx (a named var) and Self.FValues / FOnChange
  // in the same way JCheckbox captures FOnChange - safe cross-frame re-entry.
  inp.addEventListener('change', procedure(e: JEvent)
  begin
    if assigned(FOnChange) then
      FOnChange(Self, capturedIdx, FValues[capturedIdx]);
  end);

  Result := idx;
end;

// =========================================================================================
//  Clear
// =========================================================================================

procedure JW3RadioGroup.Clear;
var
  i:    Integer;
  h:    variant;
  inp:  variant;
  wrap: variant;
begin
  h := Self.Handle;
  // Walk backwards so indices stay valid during deletion.
  for i := FInputIds.Count - 1 downto 0 do
  begin
    inp  := document.getElementById(FInputIds[i]);
    wrap := inp.parentElement;
    h.removeChild(wrap);
    FInputIds.Delete(i);
    FValues.Delete(i);
  end;
end;

// =========================================================================================
//  Count
// =========================================================================================

function JW3RadioGroup.GetCount: Integer;
begin
  Result := FInputIds.Count;
end;

// =========================================================================================
//  SelectedIndex
// =========================================================================================

function JW3RadioGroup.GetSelectedIndex: Integer;
var
  i:   Integer;
  inp: variant;
begin
  Result := -1;
  for i := 0 to FInputIds.Count - 1 do
  begin
    inp := document.getElementById(FInputIds[i]);
    if inp.checked then
    begin
      Result := i;
      exit;
    end;
  end;
end;

procedure JW3RadioGroup.SetSelectedIndex(Index: Integer);
var
  i:   Integer;
  inp: variant;
begin
  for i := 0 to FInputIds.Count - 1 do
  begin
    inp         := document.getElementById(FInputIds[i]);
    inp.checked := (i = Index);
  end;
end;

// =========================================================================================
//  SelectedValue
// =========================================================================================
function JW3RadioGroup.GetSelectedValue: String;
var
  idx: Integer;
begin
  idx := GetSelectedIndex;
  if idx >= 0 then
    Result := FValues[idx]
  else
    Result := '';
end;

// =========================================================================================
//  Enabled
// =========================================================================================

function JW3RadioGroup.GetEnabled: Boolean;
var
  inp: variant;
begin
  if FInputIds.Count = 0 then
  begin
    Result := true;
    exit;
  end;
  inp    := document.getElementById(FInputIds[0]);
  Result := not inp.disabled;
end;

procedure JW3RadioGroup.SetEnabled(V: Boolean);
var
  i:    Integer;
  inp:  variant;
  wrap: variant;
begin
  for i := 0 to FInputIds.Count - 1 do
  begin
    inp          := document.getElementById(FInputIds[i]);
    inp.disabled := not V;
    wrap         := inp.parentElement;
    if V then
      wrap.classList.remove(csRadioDisabled)
    else
      wrap.classList.add(csRadioDisabled);
  end;
end;

// =========================================================================================
//  ItemCaption
// =========================================================================================

function JW3RadioGroup.GetItemCaption(Index: Integer): String;
var
  inp: variant;
begin
  if (Index >= 0) and (Index < FInputIds.Count) then
  begin
    // The label is always the next sibling of the input inside .radio-item.
    inp    := document.getElementById(FInputIds[Index]);
    Result := inp.nextElementSibling.textContent;
  end
  else
    Result := '';
end;

procedure JW3RadioGroup.SetItemCaption(Index: Integer; const V: String);
var
  inp: variant;
begin
  if (Index >= 0) and (Index < FInputIds.Count) then
  begin
    inp := document.getElementById(FInputIds[Index]);
    inp.nextElementSibling.textContent := V;
  end;
end;

initialization
  RegisterRadioGroupStyles;
end.
