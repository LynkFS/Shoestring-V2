unit JSwitch;

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
//  JW3Switch
//
//  A toggle switch (on/off, yes/no, enabled/disabled).
//  Renders as a sliding pill-shaped track with a circular thumb.
//  Clicking the track or the caption label both toggle the state.
//
//  Structure:
//
//    <div class="switch">
//      <input type="checkbox" id="sw_N" class="switch-input" role="switch">
//      <label for="sw_N" class="switch-track">
//        <span class="switch-thumb"></span>
//      </label>
//      <label for="sw_N" class="switch-caption">Caption</label>
//    </div>
//
//  Usage:
//
//    var Dark := JW3Switch.Create(Panel);
//    Dark.Caption  := 'Dark mode';
//    Dark.Checked  := True;
//    Dark.OnChange := HandleDarkModeChange;
//    if Dark.Checked then ...
//
//  CSS variables:
//
//    --sw-width          Track width            default: 44px
//    --sw-height         Track height           default: 24px
//    --sw-thumb-size     Thumb diameter         default: 18px
//    --sw-thumb-offset   Thumb inset from edge  default: 3px
//    --sw-on-color       Track colour when ON   default: var(--primary-color)
//    --sw-off-color      Track colour when OFF  default: #cbd5e1
//    --sw-gap            Gap to caption text    default: var(--space-2)
//
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

interface

uses JElement, Types;

const
  csSwitch        = 'switch';
  csSwitchInput   = 'switch-input';
  csSwitchTrack   = 'switch-track';
  csSwitchThumb   = 'switch-thumb';
  csSwitchCaption = 'switch-caption';

type
  TSwitchChangedEvent = procedure(Sender: TObject; Checked: Boolean);

  JW3Switch = class(TElement)
  private
    FInput:    variant;     // the <input type="checkbox"> DOM element
    FCaption:  variant;     // the caption <label> element
    FOnChange: TSwitchChangedEvent;

    function  GetChecked: Boolean;
    procedure SetChecked(V: Boolean);
    function  GetCaption: String;
    procedure SetCaption(const V: String);
    function  GetEnabled: Boolean;
    procedure SetEnabled(V: Boolean);

  public
    constructor Create(Parent: TElement); virtual;

    property Checked:  Boolean read GetChecked write SetChecked;
    property Value:    Boolean read GetChecked write SetChecked;   // alias
    property Caption:  String  read GetCaption write SetCaption;
    property Enabled:  Boolean read GetEnabled write SetEnabled;
    property OnChange: TSwitchChangedEvent read FOnChange write FOnChange;
  end;

procedure RegisterSwitchStyles;

implementation

uses Globals;

var
  FRegistered: Boolean := false;
  FSwitchId:   Integer := 0;

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  Styles
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

procedure RegisterSwitchStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* -- Wrapper ------------------------------------------------------------ */

    .switch {
      display:        inline-flex;
      flex-direction: row;
      align-items:    center;
      gap:            var(--sw-gap, var(--space-2, 8px));
      cursor:         pointer;
      user-select:    none;
    }

    /* -- Hide native checkbox, keep it keyboard-accessible ----------------- */

    .switch-input {
      position:    absolute;
      width:       1px;
      height:      1px;
      margin:      -1px;
      padding:     0;
      overflow:    hidden;
      clip:        rect(0, 0, 0, 0);
      white-space: nowrap;
      border:      0;
    }

    /* -- Track (the pill) -------------------------------------------------- */

    .switch-track {
      position:      relative;
      display:       inline-flex;
      align-items:   center;
      flex-shrink:   0;
      width:         var(--sw-width,  44px);
      height:        var(--sw-height, 24px);
      border-radius: 9999px;
      background:    var(--sw-off-color, #cbd5e1);
      transition:    background var(--anim-duration, 0.2s);
      cursor:        pointer;
    }

    /* -- Thumb (the circle) ------------------------------------------------ */

    .switch-thumb {
      position:      absolute;
      left:          var(--sw-thumb-offset, 3px);
      width:         var(--sw-thumb-size, 18px);
      height:        var(--sw-thumb-size, 18px);
      border-radius: 50%;
      background:    #ffffff;
      box-shadow:    0 1px 3px rgba(0, 0, 0, 0.25);
      transition:    left var(--anim-duration, 0.2s);
    }

    /* -- ON state ----------------------------------------------------------- */

    .switch-input:checked + .switch-track {
      background: var(--sw-on-color, var(--primary-color, #6366f1));
    }

    .switch-input:checked + .switch-track .switch-thumb {
      left: calc(
        var(--sw-width,        44px)
      - var(--sw-thumb-size,   18px)
      - var(--sw-thumb-offset,  3px)
      );
    }

    /* -- Focus ring --------------------------------------------------------- */

    .switch-input:focus-visible + .switch-track {
      outline:        2px solid var(--primary-color, #6366f1);
      outline-offset: 2px;
    }

    /* -- Disabled ----------------------------------------------------------- */

    .switch-input:disabled + .switch-track {
      opacity: 0.45;
      cursor:  default;
    }

    .switch-input:disabled ~ .switch-caption {
      opacity: 0.45;
      cursor:  default;
    }

    /* -- Caption label ------------------------------------------------------ */

    .switch-caption {
      font-size:   var(--font-size-sm, 0.875rem);
      color:       var(--text-color, #334155);
      line-height: 1.4;
      cursor:      pointer;
    }

  ');
end;

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  JW3Switch
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

constructor JW3Switch.Create(Parent: TElement);
var
  swId:    String;
  wrapper: variant;
begin
  inherited Create('div', Parent);
  AddClass(csSwitch);
  RegisterSwitchStyles;

  // Unique id links <input> and both <label> elements
  inc(FSwitchId);
  swId := 'sw_' + IntToStr(FSwitchId);

  wrapper := Self.Handle;

  // <input type="checkbox" role="switch" id="sw_N">
  var inp: variant := document.createElement('input');
  inp.setAttribute('type', 'checkbox');
  inp.setAttribute('role', 'switch');
  inp.id        := swId;
  inp.className := csSwitchInput;
  wrapper.appendChild(inp);
  FInput := inp;

  // <label for="sw_N" class="switch-track"><span class="switch-thumb"></span></label>
  var track: variant := document.createElement('label');
  track.setAttribute('for', swId);
  track.className := csSwitchTrack;
  var thumb: variant := document.createElement('span');
  thumb.className := csSwitchThumb;
  track.appendChild(thumb);
  wrapper.appendChild(track);

  // <label for="sw_N" class="switch-caption"></label>
  var cap: variant := document.createElement('label');
  cap.setAttribute('for', swId);
  cap.className := csSwitchCaption;
  wrapper.appendChild(cap);
  FCaption := cap;

  // Wire change event
  inp.addEventListener('change', procedure(e: JEvent)
  begin
    if assigned(FOnChange) then
      FOnChange(Self, GetChecked);
  end);
end;

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  Property implementations
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

function JW3Switch.GetChecked: Boolean;
begin
  Result := FInput.checked;
end;

procedure JW3Switch.SetChecked(V: Boolean);
begin
  FInput.checked := V;
end;

function JW3Switch.GetCaption: String;
begin
  Result := FCaption.textContent;
end;

procedure JW3Switch.SetCaption(const V: String);
begin
  FCaption.textContent := V;
end;

function JW3Switch.GetEnabled: Boolean;
begin
  Result := not FInput.disabled;
end;

procedure JW3Switch.SetEnabled(V: Boolean);
begin
  FInput.disabled := not V;
end;

initialization
  RegisterSwitchStyles;
end.
