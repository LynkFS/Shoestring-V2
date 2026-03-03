unit JBadge;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Badge
//
//  A small inline status indicator. Used for notification counts, status
//  labels, tags, and category markers. Renders as a compact <span>.
//
//  Usage:
//
//    var Status := JW3Badge.Create(Header);
//    Status.Caption := 'Active';
//    Status.AddClass(csBadgeSuccess);
//
//    var Count := JW3Badge.Create(NavItem);
//    Count.Caption := '3';
//    Count.AddClass(csBadgeDanger);
//
//  Variants: default (neutral), success, warning, danger, info, primary
//
//  CSS variables:
//
//    --badge-padding      Badge padding          default: 2px 8px
//    --badge-radius       Badge radius           default: var(--radius-full)
//    --badge-font-size    Font size              default: var(--font-size-xs)
//    --badge-font-weight  Font weight            default: 500
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csBadge        = 'badge';
  csBadgeSuccess = 'badge-success';
  csBadgeWarning = 'badge-warning';
  csBadgeDanger  = 'badge-danger';
  csBadgeInfo    = 'badge-info';
  csBadgePrimary = 'badge-primary';

type
  JW3Badge = class(TElement)
  private
    function  GetCaption: String;
    procedure SetCaption(const V: String);
  public
    constructor Create(Parent: TElement); virtual;
    property Caption: String read GetCaption write SetCaption;
  end;

procedure RegisterBadgeStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterBadgeStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    .badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      padding: var(--badge-padding, 2px 8px);
      border-radius: var(--badge-radius, var(--radius-full, 9999px));
      font-size: var(--badge-font-size, var(--font-size-xs, 0.75rem));
      font-weight: var(--badge-font-weight, 500);
      line-height: 1.4;
      white-space: nowrap;
      user-select: none;

      /* Default: neutral */
      background: var(--border-color, #e2e8f0);
      color: var(--text-color, #334155);
    }

    .badge-success {
      background: var(--color-success-bg, #f0fdf4);
      color: var(--color-success, #22c55e);
    }

    .badge-warning {
      background: var(--color-warning-bg, #fffbeb);
      color: var(--color-warning, #f59e0b);
    }

    .badge-danger {
      background: var(--color-danger-bg, #fef2f2);
      color: var(--color-danger, #ef4444);
    }

    .badge-info {
      background: var(--color-info-bg, #eff6ff);
      color: var(--color-info, #3b82f6);
    }

    .badge-primary {
      background: var(--primary-color, #6366f1);
      color: #ffffff;
    }
  ');
end;

{ JW3Badge }

constructor JW3Badge.Create(Parent: TElement);
begin
  inherited Create('span', Parent);
  AddClass(csBadge);
end;

function JW3Badge.GetCaption: String;
begin
  Result := GetText;
end;

procedure JW3Badge.SetCaption(const V: String);
begin
  SetText(V);
end;

initialization
  RegisterBadgeStyles;
end.
