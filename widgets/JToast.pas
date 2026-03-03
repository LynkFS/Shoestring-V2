unit JToast;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Toast
//
//  An auto-dismissing notification that appears at the top-right of the
//  viewport. Multiple toasts stack vertically. Each toast auto-removes
//  after a configurable duration.
//
//  Usage:
//
//    Toast('File saved successfully', ttSuccess);
//    Toast('Connection lost', ttDanger, 5000);
//    Toast('New version available', ttInfo);
//
//  The Toast() procedure is standalone — no component to create or manage.
//  It creates the container on first use and appends toast elements.
//
//  CSS variables:
//
//    --toast-width        Toast width            default: 340px
//    --toast-radius       Toast radius           default: var(--radius-lg)
//    --toast-shadow       Toast shadow           default: var(--shadow-lg)
//    --toast-padding      Toast padding          default: 12px 16px
//    --toast-gap          Gap between toasts     default: 8px
//    --toast-z            Z-index                default: 2000
//    --toast-duration     Slide animation        default: 0.3s
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type
  TToastType = (ttInfo, ttSuccess, ttWarning, ttDanger);

procedure Toast(const Message: String; ToastType: TToastType = ttInfo;
  DurationMs: Integer = 3000);

procedure RegisterToastStyles;

implementation

uses Globals;

var
  FRegistered: Boolean := false;
  FContainer:  variant;

procedure RegisterToastStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Container: fixed top-right stack ─────────────────────────── */

    .toast-container {
      position: fixed;
      top: var(--space-4, 16px);
      right: var(--space-4, 16px);
      z-index: var(--toast-z, 2000);
      display: flex;
      flex-direction: column;
      gap: var(--toast-gap, 8px);
      pointer-events: none;
    }

    /* ── Individual toast ─────────────────────────────────────────── */

    .toast {
      display: flex;
      flex-direction: row;
      align-items: flex-start;
      width: var(--toast-width, 340px);
      max-width: calc(100vw - 32px);
      padding: var(--toast-padding, 12px 16px);
      border-radius: var(--toast-radius, var(--radius-lg, 8px));
      box-shadow: var(--toast-shadow, var(--shadow-lg,
        0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px -2px rgba(0,0,0,0.05)));
      font-size: var(--font-size-sm, 0.875rem);
      line-height: 1.45;
      pointer-events: auto;
      cursor: pointer;

      /* Slide in from right */
      animation: toast-in var(--toast-duration, 0.3s) ease forwards;
    }

    .toast-removing {
      animation: toast-out var(--toast-duration, 0.3s) ease forwards;
    }

    @keyframes toast-in {
      from { opacity: 0; transform: translateX(100%); }
      to   { opacity: 1; transform: translateX(0); }
    }

    @keyframes toast-out {
      from { opacity: 1; transform: translateX(0); }
      to   { opacity: 0; transform: translateX(100%); }
    }

    /* ── Variants ─────────────────────────────────────────────────── */

    .toast-info {
      background: var(--color-info-bg, #eff6ff);
      color: var(--color-info, #3b82f6);
      border-left: 4px solid var(--color-info, #3b82f6);
    }

    .toast-success {
      background: var(--color-success-bg, #f0fdf4);
      color: var(--color-success, #22c55e);
      border-left: 4px solid var(--color-success, #22c55e);
    }

    .toast-warning {
      background: var(--color-warning-bg, #fffbeb);
      color: var(--color-warning, #f59e0b);
      border-left: 4px solid var(--color-warning, #f59e0b);
    }

    .toast-danger {
      background: var(--color-danger-bg, #fef2f2);
      color: var(--color-danger, #ef4444);
      border-left: 4px solid var(--color-danger, #ef4444);
    }
  ');
end;


procedure EnsureContainer;
begin
  if FContainer then exit;
  FContainer := document.createElement('div');
  FContainer.className := 'toast-container';
  document.body.appendChild(FContainer);
end;


procedure RemoveToast(el: variant);
begin
  asm
    (@el).classList.add('toast-removing');
    var raw = getComputedStyle(document.documentElement)
                .getPropertyValue('--toast-duration').trim();
    var dur = parseFloat(raw) * (raw.endsWith('ms') ? 1 : 1000);
    if (!dur || isNaN(dur)) dur = 300;
    setTimeout(function() {
      if ((@el).parentNode) (@el).parentNode.removeChild(@el);
    }, dur);
  end;
end;


procedure Toast(const Message: String; ToastType: TToastType = ttInfo;
  DurationMs: Integer = 3000);
var
  el: variant;
  cls: String;
begin
  RegisterToastStyles;
  EnsureContainer;

  case ToastType of
    ttInfo:    cls := 'toast toast-info';
    ttSuccess: cls := 'toast toast-success';
    ttWarning: cls := 'toast toast-warning';
    ttDanger:  cls := 'toast toast-danger';
  else
    cls := 'toast toast-info';
  end;

  asm
    var t = document.createElement('div');
    t.className = @cls;
    t.textContent = @Message;
    (@FContainer).appendChild(t);
    @el = t;

    // Click to dismiss early
    t.addEventListener('click', function() {
      @RemoveToast(@el);
    });
  end;

  // Auto-dismiss
  window.setTimeout(procedure()
  begin
    RemoveToast(el);
  end, DurationMs);
end;

initialization
  RegisterToastStyles;
end.