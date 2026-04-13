unit JSpinner;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Spinner
//
//  A CSS-animated activity indicator: two bouncing dots on a rotating
//  container (classic "double bounce" effect).
//
//  Usage:
//
//    var Busy := JW3Spinner.Create(Panel);
//    Busy.SetStyle('display', 'none');          // hidden until needed
//    ...
//    Busy.SetStyle('display', 'inline-block');  // show while loading
//    Busy.SetStyle('display', 'none');          // hide when done
//
//  CSS variables:
//
//    --spinner-size    Outer width/height    default: 40px
//    --spinner-color   Dot colour            default: var(--primary-color, #6366f1)
//    --spinner-speed   Full cycle duration   default: 2.0s
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csSpinner      = 'spinner';
  csSpinnerDot   = 'spinner-dot';
  csSpinnerDot1  = 'spinner-dot1';
  csSpinnerDot2  = 'spinner-dot2';

type
  JW3Spinner = class(TElement)
  public
    constructor Create(Parent: TElement); virtual;
  end;

procedure RegisterSpinnerStyles;

implementation

uses Globals;

var
  FRegistered: Boolean := false;

procedure RegisterSpinnerStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Outer container: rotates continuously ────────────────────── */

    .spinner {
      position: relative;
      width:    var(--spinner-size, 40px);
      height:   var(--spinner-size, 40px);
      animation: spinner-rotate var(--spinner-speed, 2.0s) infinite linear;
    }

    /* ── Dots: scale up/down in alternation ───────────────────────── */

    .spinner-dot {
      width:            60%;
      height:           60%;
      position:         absolute;
      top:              0;
      display:          inline-block;
      border-radius:    50%;
      background-color: var(--spinner-color, var(--primary-color, #6366f1));
      animation:        spinner-bounce var(--spinner-speed, 2.0s) infinite ease-in-out;
    }

    .spinner-dot2 {
      top:             auto;
      bottom:          0;
      animation-delay: calc(var(--spinner-speed, 2.0s) / -2);
    }

    /* ── Keyframes ────────────────────────────────────────────────── */

    @keyframes spinner-rotate {
      100% { transform: rotate(360deg); }
    }

    @keyframes spinner-bounce {
      0%, 100% { transform: scale(0); }
      50%       { transform: scale(1); }
    }

  ');
end;

{ JW3Spinner }

constructor JW3Spinner.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csSpinner);

  var Dot1 := TElement.Create('div', Self);
  Dot1.AddClass(csSpinnerDot);
  Dot1.AddClass(csSpinnerDot1);

  var Dot2 := TElement.Create('div', Self);
  Dot2.AddClass(csSpinnerDot);
  Dot2.AddClass(csSpinnerDot2);
end;

initialization
  RegisterSpinnerStyles;
end.
