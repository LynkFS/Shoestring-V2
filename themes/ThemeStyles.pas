unit ThemeStyles;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Theme Styles
//
//  The single source of truth for all design tokens. Every visual value
//  that a component might reference is declared here and nowhere else.
//
//  ── Core palette ──────────────────────────────────────────────────
//    --primary-color, --primary-light, --text-color, --text-light
//    --bg-color, --surface-color, --border-color, --hover-color
//
//  ── Semantic colours ──────────────────────────────────────────────
//    --color-success, --color-warning, --color-danger, --color-info
//    (each has a -bg variant for soft backgrounds)
//
//  ── Spacing ───────────────────────────────────────────────────────
//    --space-1 (4px) through --space-16 (64px)
//
//  ── Border radius ─────────────────────────────────────────────────
//    --radius-sm (4px) through --radius-full (9999px)
//
//  ── Elevation ─────────────────────────────────────────────────────
//    --shadow-sm through --shadow-xl
//
//  ── Animation ─────────────────────────────────────────────────────
//    --anim-duration (0.2s)
//
//  ── Field tokens ──────────────────────────────────────────────────
//    --field-height, --field-padding, --field-border, etc.
//
//  ── Dark mode ─────────────────────────────────────────────────────
//    Toggle: document.documentElement.classList.toggle('dark')
//
//  ── Utility classes ───────────────────────────────────────────────
//    .interactive    Hover, focus, active, disabled
//    .field          Form field base
//    .field-label    Label above a field
//    .field-group    Vertical stack: label + field + error
//    .field-error    Error message text
//
// ═══════════════════════════════════════════════════════════════════════════

interface

const
  csInteractive  = 'interactive';
  csField        = 'field';
  csFieldLabel   = 'field-label';
  csFieldGroup   = 'field-group';
  csFieldError   = 'field-error';
  csFieldValid   = 'valid';
  csFieldInvalid = 'invalid';

procedure RegisterThemeStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterThemeStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  // ══════════════════════════════════════════════════════════════════
  //  Light mode tokens
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    :root {

      /* ── Core palette ─────────────────────────────────────────── */

      --primary-color:    #6366f1;
      --primary-light:    #a5b4fc;
      --text-color:       #334155;
      --text-light:       #64748b;
      --bg-color:         #f8fafc;
      --surface-color:    #ffffff;
      --border-color:     #e2e8f0;
      --hover-color:      #f1f5f9;

      /* ── Semantic colours ─────────────────────────────────────── */

      --color-success:    #22c55e;
      --color-success-bg: #f0fdf4;
      --color-warning:    #f59e0b;
      --color-warning-bg: #fffbeb;
      --color-danger:     #ef4444;
      --color-danger-bg:  #fef2f2;
      --color-info:       #3b82f6;
      --color-info-bg:    #eff6ff;

      /* ── Spacing scale ────────────────────────────────────────── */

      --space-1:   4px;
      --space-2:   8px;
      --space-3:  12px;
      --space-4:  16px;
      --space-6:  24px;
      --space-8:  32px;
      --space-10: 40px;
      --space-12: 48px;
      --space-16: 64px;

      /* ── Border radius ────────────────────────────────────────── */

      --radius-sm:   4px;
      --radius-md:   6px;
      --radius-lg:   8px;
      --radius-xl:  12px;
      --radius-full: 9999px;

      /* ── Elevation ────────────────────────────────────────────── */

      --shadow-sm: 0 1px 3px rgba(0,0,0,0.1);
      --shadow-md: 0 4px 6px -1px rgba(0,0,0,0.1),
                   0 2px 4px -1px rgba(0,0,0,0.06);
      --shadow-lg: 0 10px 15px -3px rgba(0,0,0,0.1),
                   0 4px  6px  -2px rgba(0,0,0,0.05);
      --shadow-xl: 0 20px 25px -5px rgba(0,0,0,0.1),
                   0 10px 10px -5px rgba(0,0,0,0.04);

      /* ── Animation ────────────────────────────────────────────── */

      --anim-duration: 0.2s;

      /* ── Field tokens ─────────────────────────────────────────── */

      --field-height:       40px;
      --field-padding:      0 12px;
      --field-border:       1px solid var(--border-color);
      --field-radius:       var(--radius-md);
      --field-bg:           var(--surface-color);
      --field-focus-border: var(--primary-color);
      --field-focus-ring:   0 0 0 3px rgba(99, 102, 241, 0.15);
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Dark mode
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    :root.dark {
      --primary-color:    #818cf8;
      --primary-light:    #c7d2fe;
      --text-color:       #e2e8f0;
      --text-light:       #94a3b8;
      --bg-color:         #0f172a;
      --surface-color:    #1e293b;
      --border-color:     #334155;
      --hover-color:      #1e293b;

      --shadow-sm:  0 1px 3px rgba(0,0,0,0.3);
      --shadow-md:  0 4px 6px -1px rgba(0,0,0,0.3),
                    0 2px 4px -1px rgba(0,0,0,0.2);
      --shadow-lg:  0 10px 15px -3px rgba(0,0,0,0.3),
                    0 4px  6px  -2px rgba(0,0,0,0.2);
      --shadow-xl:  0 20px 25px -5px rgba(0,0,0,0.3),
                    0 10px 10px -5px rgba(0,0,0,0.2);

      --color-success:    #4ade80;
      --color-success-bg: #052e16;
      --color-warning:    #fbbf24;
      --color-warning-bg: #451a03;
      --color-danger:     #f87171;
      --color-danger-bg:  #450a0a;
      --color-info:       #60a5fa;
      --color-info-bg:    #172554;

      --field-bg:         var(--surface-color);
      --field-focus-ring: 0 0 0 3px rgba(129, 140, 248, 0.2);
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Interaction states
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .interactive {
      cursor: pointer;
      user-select: none;
      transition: background-color var(--anim-duration, 0.2s),
                  color var(--anim-duration, 0.2s),
                  border-color var(--anim-duration, 0.2s),
                  box-shadow var(--anim-duration, 0.2s),
                  opacity var(--anim-duration, 0.2s);
    }
    .interactive:hover {
      background-color: var(--hover-color, #f1f5f9);
    }
    .interactive:focus-visible {
      outline: 2px solid var(--primary-color, #6366f1);
      outline-offset: 2px;
    }
    .interactive:active {
      background-color: var(--border-color, #e2e8f0);
    }
    .interactive[disabled],
    .interactive.disabled {
      opacity: 0.5;
      pointer-events: none;
      cursor: default;
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Form field base
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .field {
      height: var(--field-height);
      padding: var(--field-padding);
      border: var(--field-border);
      border-radius: var(--field-radius);
      background: var(--field-bg);
      font-size: 1rem;
      color: var(--text-color, #334155);
      transition: border-color var(--anim-duration, 0.2s),
                  box-shadow var(--anim-duration, 0.2s);
      outline: none;
      width: 100%;
      box-sizing: border-box;
    }
    .field:focus {
      border-color: var(--field-focus-border);
      box-shadow: var(--field-focus-ring);
    }
    .field.invalid {
      border-color: var(--color-danger, #ef4444);
    }
    .field.invalid:focus {
      box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.15);
    }
    .field.valid {
      border-color: var(--color-success, #22c55e);
    }
    .field[disabled] {
      opacity: 0.5;
      cursor: not-allowed;
      background: var(--hover-color, #f1f5f9);
    }
    .field::placeholder {
      color: var(--text-light, #64748b);
    }
    .field-label {
      font-size: 0.875rem;
      font-weight: 500;
      color: var(--text-color, #334155);
      padding-bottom: 4px;
    }
    .field-group {
      gap: 4px;
      margin-bottom: 16px;
    }
    .field-error {
      font-size: 0.75rem;
      color: var(--color-danger, #ef4444);
      min-height: 1.2em;
    }
  ');
end;

initialization
  RegisterThemeStyles;
end.
