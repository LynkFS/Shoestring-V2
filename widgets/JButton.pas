unit JButton;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Button
//
//  Creates a <button> element. Variants via CSS classes: primary (filled),
//  secondary (outlined), danger (red), ghost (no background). All sizes
//  and states handled in CSS. Pascal code is minimal.
//
//  Usage:
//
//    var Btn := JW3Button.Create(Self);
//    Btn.Caption := 'Save';
//    Btn.AddClass(csBtnPrimary);
//    Btn.OnClick := HandleSave;
//
//  CSS variables:
//
//    --btn-height         Button height          default: 40px
//    --btn-padding        Button padding         default: 0 var(--space-4)
//    --btn-radius         Button radius          default: var(--radius-md)
//    --btn-font-size      Font size              default: var(--font-size-sm)
//    --btn-font-weight    Font weight            default: 500
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csBtn          = 'btn';
  csBtnPrimary   = 'btn-primary';
  csBtnSecondary = 'btn-secondary';
  csBtnDanger    = 'btn-danger';
  csBtnGhost     = 'btn-ghost';
  csBtnSmall     = 'btn-sm';
  csBtnLarge     = 'btn-lg';

type
  JW3Button = class(TElement)
  private
    function  GetCaption: String;
    procedure SetCaption(const Value: String);
  public
    constructor Create(Parent: TElement); virtual;
    property Caption: String read GetCaption write SetCaption;
  end;

procedure RegisterButtonStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterButtonStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Base button ──────────────────────────────────────────────── */

    .btn {
      flex-direction: row;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      gap: var(--space-2, 8px);
      height: var(--btn-height, 40px);
      padding: var(--btn-padding, 0 16px);
      border: 1px solid transparent;
      border-radius: var(--btn-radius, var(--radius-md, 6px));
      font-size: var(--btn-font-size, var(--font-size-sm, 0.875rem));
      font-weight: var(--btn-font-weight, 500);
      cursor: pointer;
      user-select: none;
      white-space: nowrap;
      transition: background-color var(--anim-duration, 0.2s),
                  border-color var(--anim-duration, 0.2s),
                  color var(--anim-duration, 0.2s),
                  box-shadow var(--anim-duration, 0.2s);
    }

    .btn:focus-visible {
      outline: 2px solid var(--primary-color, #6366f1);
      outline-offset: 2px;
    }

    .btn[disabled] {
      opacity: 0.5;
      pointer-events: none;
      cursor: default;
    }

    /* ── Primary: filled ──────────────────────────────────────────── */

    .btn-primary {
      background: var(--primary-color, #6366f1);
      color: #ffffff;
    }

    .btn-primary:hover {
      opacity: 0.85;
    }

    .btn-primary:active {
      background: var(--primary-color, #6366f1);
      box-shadow: inset 0 2px 4px rgba(0,0,0,0.15);
    }

    /* ── Secondary: outlined ──────────────────────────────────────── */

    .btn-secondary {
      background: transparent;
      color: var(--text-color, #334155);
      border-color: var(--border-color, #e2e8f0);
    }

    .btn-secondary:hover {
      background: var(--hover-color, #f1f5f9);
    }

    .btn-secondary:active {
      background: var(--border-color, #e2e8f0);
    }

    /* ── Danger: red ──────────────────────────────────────────────── */

    .btn-danger {
      background: var(--color-danger, #ef4444);
      color: #ffffff;
    }

    .btn-danger:hover {
      opacity: 0.9;
    }

    .btn-danger:active {
      box-shadow: inset 0 2px 4px rgba(0,0,0,0.15);
    }

    /* ── Ghost: no background ─────────────────────────────────────── */

    .btn-ghost {
      background: transparent;
      color: var(--text-color, #334155);
    }

    .btn-ghost:hover {
      background: var(--hover-color, #f1f5f9);
    }

    /* ── Sizes ─────────────────────────────────────────────────────── */

    .btn-sm {
      height: 32px;
      padding: 0 var(--space-3, 12px);
      font-size: var(--font-size-xs, 0.75rem);
    }

    .btn-lg {
      height: 48px;
      padding: 0 var(--space-6, 24px);
      font-size: var(--font-size-md, 1rem);
    }
  ');
end;

{ JW3Button }

constructor JW3Button.Create(Parent: TElement);
begin
  inherited Create('button', Parent);
  AddClass(csBtn);
  SetAttribute('type', 'button');
end;

function JW3Button.GetCaption: String;
begin
  Result := GetText;
end;

procedure JW3Button.SetCaption(const Value: String);
begin
  SetText(Value);
end;

initialization
  RegisterButtonStyles;
end.
