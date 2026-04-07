unit ThemeStyles;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Theme Styles  —  "Zinc Violet" (2026 palette)
//
//  Drop-in replacement for ThemeStyles. Use one or the other, not both.
//  Swap by changing `uses ThemeStyles` → `uses ThemeStyles2` in every unit.
//
//  Key differences from ThemeStyles:
//    • oklch() colours — perceptually uniform, more vibrant at same contrast
//    • Zinc neutrals (warm grey) instead of Slate (cool blue-grey)
//    • Deeper, more saturated primary violet
//    • Larger default radius (8 / 12 / 16px vs 6 / 8 / 12px)
//    • Added radius-2xl (20px) and radius-3xl (28px)
//    • Extended spacing: adds --space-5 (20px), --space-14 (56px), --space-20 (80px)
//    • Typography scale: --text-xs through --text-3xl + --leading-* + --weight-*
//    • Tri-level animation: --anim-fast / --anim-normal / --anim-slow with cubic-bezier
//    • Layered surfaces: --surface-color / --surface-2 / --surface-3 for depth
//    • Coloured primary scale: --primary-50 through --primary-900
//    • Focus ring uses outline-offset style (no glow halo)
//    • Taller default field: 44px (more touch-friendly)
//    • Dark mode has true-dark background (no navy tint)
//
//  ── Core palette ──────────────────────────────────────────────────
//    --primary-color, --primary-light, --primary-dark
//    --primary-50 … --primary-900  (full tint/shade scale)
//    --text-color, --text-light, --text-xlight
//    --bg-color, --surface-color, --surface-2, --surface-3
//    --border-color, --border-strong, --hover-color
//
//  ── Semantic colours ──────────────────────────────────────────────
//    --color-success/warning/danger/info  (+ -light, -bg variants)
//
//  ── Typography ────────────────────────────────────────────────────
//    --text-xs (0.75rem) … --text-3xl (1.875rem)
//    --leading-tight (1.25) / --leading-normal (1.5) / --leading-loose (1.75)
//    --weight-normal (400) / --weight-medium (500) / --weight-semi (600) / --weight-bold (700)
//
//  ── Spacing ───────────────────────────────────────────────────────
//    --space-1 (4px) through --space-20 (80px)
//
//  ── Border radius ─────────────────────────────────────────────────
//    --radius-sm (4px) through --radius-3xl (28px) + --radius-full
//
//  ── Elevation ─────────────────────────────────────────────────────
//    --shadow-sm through --shadow-xl  (warmer alpha)
//
//  ── Animation ─────────────────────────────────────────────────────
//    --anim-fast (0.1s) / --anim-normal (0.2s) / --anim-slow (0.35s)
//    --anim-ease  (cubic-bezier ease-out)
//    (--anim-duration kept as alias for --anim-normal for back-compat)
//
//  ── Field tokens ──────────────────────────────────────────────────
//    Same names as ThemeStyles — field height is 44px (up from 40px)
//
//  ── Dark mode ─────────────────────────────────────────────────────
//    Toggle: document.documentElement.classList.toggle('dark')
//
//  ── Utility classes ───────────────────────────────────────────────
//    Same class names as ThemeStyles — fully compatible
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

      /* ── Primary scale (oklch — perceptually uniform violet) ──── */
      /* oklch(L% C H) — hue 275 = violet, chroma 0.24 = vivid      */

      --primary-50:    oklch(97%  0.02  275);   /* #f3f2fd */
      --primary-100:   oklch(93%  0.04  275);   /* #e8e6fb */
      --primary-200:   oklch(85%  0.08  275);   /* #cbc8f7 */
      --primary-300:   oklch(75%  0.14  275);   /* #a9a3f1 */
      --primary-400:   oklch(65%  0.20  275);   /* #8078ea */
      --primary-color: oklch(55%  0.24  275);   /* #5c4ee3  ← base  */
      --primary-600:   oklch(48%  0.24  275);   /* #4b3ed0 */
      --primary-700:   oklch(40%  0.22  275);   /* #3b30b0 */
      --primary-800:   oklch(32%  0.18  275);   /* #2c248a */
      --primary-900:   oklch(24%  0.14  275);   /* #1f1a62 */

      --primary-light: var(--primary-300);
      --primary-dark:  var(--primary-700);

      /* ── Zinc neutrals (warm grey, not cool slate) ────────────── */

      --text-color:     oklch(22%  0.008 260);  /* #1c1b21 — near-black, warm */
      --text-light:     oklch(48%  0.012 260);  /* #6b6a74 */
      --text-xlight:    oklch(65%  0.010 260);  /* #999aa6 */

      --bg-color:       oklch(97%  0.003 260);  /* #f6f6f8 — warm off-white   */
      --surface-color:  oklch(100% 0     0  );  /* #ffffff                    */
      --surface-2:      oklch(97%  0.003 260);  /* same as bg — layer 2       */
      --surface-3:      oklch(94%  0.005 260);  /* #eeeef2 — layer 3          */

      --border-color:   oklch(88%  0.008 260);  /* #dddde3 */
      --border-strong:  oklch(76%  0.012 260);  /* #b9b9c4 */
      --hover-color:    oklch(93%  0.006 260);  /* #eaeaef */

      /* ── Semantic colours ─────────────────────────────────────── */

      --color-success:       oklch(55%  0.18  145);   /* #1a9e5a */
      --color-success-light: oklch(72%  0.14  145);   /* #52c98a */
      --color-success-bg:    oklch(96%  0.04  145);   /* #edfaf3 */

      --color-warning:       oklch(68%  0.18   75);   /* #c98b00 */
      --color-warning-light: oklch(82%  0.14   75);   /* #f0be44 */
      --color-warning-bg:    oklch(97%  0.04   85);   /* #fdf9e8 */

      --color-danger:        oklch(52%  0.22   25);   /* #d63230 */
      --color-danger-light:  oklch(68%  0.18   25);   /* #f46a68 */
      --color-danger-bg:     oklch(96%  0.04   25);   /* #fdf0f0 */

      --color-info:          oklch(57%  0.18  250);   /* #2673d6 */
      --color-info-light:    oklch(73%  0.13  250);   /* #6ba5f0 */
      --color-info-bg:       oklch(96%  0.04  250);   /* #eef4fd */

      /* ── Spacing scale ────────────────────────────────────────── */

      --space-1:    4px;
      --space-2:    8px;
      --space-3:   12px;
      --space-4:   16px;
      --space-5:   20px;
      --space-6:   24px;
      --space-8:   32px;
      --space-10:  40px;
      --space-12:  48px;
      --space-14:  56px;
      --space-16:  64px;
      --space-20:  80px;

      /* ── Border radius (larger defaults) ─────────────────────── */

      --radius-sm:   4px;
      --radius-md:   8px;    /* was 6px */
      --radius-lg:  12px;    /* was 8px */
      --radius-xl:  16px;    /* was 12px */
      --radius-2xl: 20px;    /* new */
      --radius-3xl: 28px;    /* new */
      --radius-full: 9999px;

      /* ── Elevation (warmer alpha) ─────────────────────────────── */

      --shadow-sm: 0 1px 2px oklch(0% 0 0 / 0.07),
                   0 1px 3px oklch(0% 0 0 / 0.05);
      --shadow-md: 0 4px  8px -2px oklch(0% 0 0 / 0.10),
                   0 2px  4px -2px oklch(0% 0 0 / 0.06);
      --shadow-lg: 0 12px 20px -4px oklch(0% 0 0 / 0.12),
                   0  4px  8px -4px oklch(0% 0 0 / 0.06);
      --shadow-xl: 0 24px 36px -6px oklch(0% 0 0 / 0.14),
                   0 10px 16px -6px oklch(0% 0 0 / 0.06);

      /* ── Animation ────────────────────────────────────────────── */

      --anim-ease:     cubic-bezier(0.16, 1, 0.3, 1);
      --anim-fast:     0.1s;
      --anim-normal:   0.2s;
      --anim-slow:     0.35s;
      --anim-duration: var(--anim-normal);   /* back-compat alias */

      /* ── Typography scale ─────────────────────────────────────── */

      --text-xs:   0.75rem;    /* 12px */
      --text-sm:   0.875rem;   /* 14px */
      --text-base: 1rem;       /* 16px */
      --text-lg:   1.125rem;   /* 18px */
      --text-xl:   1.25rem;    /* 20px */
      --text-2xl:  1.5rem;     /* 24px */
      --text-3xl:  1.875rem;   /* 30px */

      --leading-tight:  1.25;
      --leading-normal: 1.5;
      --leading-loose:  1.75;

      --weight-normal: 400;
      --weight-medium: 500;
      --weight-semi:   600;
      --weight-bold:   700;

      /* ── Field tokens ─────────────────────────────────────────── */

      --field-height:       44px;    /* was 40px — more touch-friendly */
      --field-padding:      0 14px;
      --field-border:       1.5px solid var(--border-color);
      --field-radius:       var(--radius-md);
      --field-bg:           var(--surface-color);
      --field-focus-border: var(--primary-color);
      --field-focus-ring:   0 0 0 3px oklch(55% 0.24 275 / 0.18);
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Dark mode — true dark (warm zinc-black, no navy tint)
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    :root.dark {

      --primary-color: oklch(68%  0.20  275);   /* lighter in dark mode */
      --primary-light: oklch(80%  0.14  275);
      --primary-dark:  oklch(55%  0.24  275);

      --text-color:    oklch(93%  0.005 260);   /* near-white, warm */
      --text-light:    oklch(68%  0.010 260);
      --text-xlight:   oklch(50%  0.010 260);

      --bg-color:       oklch(13%  0.006 280);  /* #18171d — true dark, slight violet */
      --surface-color:  oklch(18%  0.008 280);  /* #211f28 */
      --surface-2:      oklch(22%  0.008 280);  /* #28262f */
      --surface-3:      oklch(27%  0.008 280);  /* #312f39 */

      --border-color:   oklch(32%  0.010 280);  /* #3d3b47 */
      --border-strong:  oklch(42%  0.012 280);  /* #524f5f */
      --hover-color:    oklch(24%  0.010 280);  /* #2e2c37 */

      --shadow-sm: 0 1px 2px oklch(0% 0 0 / 0.30),
                   0 1px 3px oklch(0% 0 0 / 0.20);
      --shadow-md: 0 4px  8px -2px oklch(0% 0 0 / 0.40),
                   0 2px  4px -2px oklch(0% 0 0 / 0.25);
      --shadow-lg: 0 12px 20px -4px oklch(0% 0 0 / 0.50),
                   0  4px  8px -4px oklch(0% 0 0 / 0.30);
      --shadow-xl: 0 24px 36px -6px oklch(0% 0 0 / 0.55),
                   0 10px 16px -6px oklch(0% 0 0 / 0.30);

      --color-success:       oklch(65%  0.16  145);
      --color-success-light: oklch(78%  0.12  145);
      --color-success-bg:    oklch(20%  0.06  145);

      --color-warning:       oklch(78%  0.16   75);
      --color-warning-light: oklch(88%  0.12   80);
      --color-warning-bg:    oklch(20%  0.06   75);

      --color-danger:        oklch(65%  0.20   25);
      --color-danger-light:  oklch(78%  0.14   25);
      --color-danger-bg:     oklch(20%  0.06   25);

      --color-info:          oklch(67%  0.16  250);
      --color-info-light:    oklch(78%  0.12  250);
      --color-info-bg:       oklch(20%  0.06  250);

      --field-bg:         var(--surface-2);
      --field-focus-ring: 0 0 0 3px oklch(68% 0.20 275 / 0.25);
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Interaction states
  //  Focus uses outline-offset (no glow ring) — cleaner on complex UIs
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .interactive {
      cursor: pointer;
      user-select: none;
      transition: background-color var(--anim-normal, 0.2s) var(--anim-ease),
                  color            var(--anim-normal, 0.2s) var(--anim-ease),
                  border-color     var(--anim-normal, 0.2s) var(--anim-ease),
                  box-shadow       var(--anim-normal, 0.2s) var(--anim-ease),
                  opacity          var(--anim-normal, 0.2s) var(--anim-ease);
    }
    .interactive:hover {
      background-color: var(--hover-color);
    }
    .interactive:focus-visible {
      outline: 2px solid var(--primary-color);
      outline-offset: 3px;
    }
    .interactive:active {
      background-color: var(--surface-3);
    }
    .interactive[disabled],
    .interactive.disabled {
      opacity: 0.45;
      pointer-events: none;
      cursor: default;
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Form field base — same class names, same compatibility
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .field {
      height: var(--field-height);
      padding: var(--field-padding);
      border: var(--field-border);
      border-radius: var(--field-radius);
      background: var(--field-bg);
      font-size: var(--text-base, 1rem);
      color: var(--text-color);
      transition: border-color var(--anim-normal, 0.2s) var(--anim-ease),
                  box-shadow   var(--anim-normal, 0.2s) var(--anim-ease);
      outline: none;
      width: 100%;
      box-sizing: border-box;
    }
    .field:focus {
      border-color: var(--field-focus-border);
      box-shadow: var(--field-focus-ring);
    }
    .field.invalid {
      border-color: var(--color-danger);
    }
    .field.invalid:focus {
      box-shadow: 0 0 0 3px oklch(52% 0.22 25 / 0.18);
    }
    .field.valid {
      border-color: var(--color-success);
    }
    .field[disabled] {
      opacity: 0.45;
      cursor: not-allowed;
      background: var(--surface-3);
    }
    .field::placeholder {
      color: var(--text-xlight);
    }
    .field-label {
      font-size: var(--text-sm, 0.875rem);
      font-weight: var(--weight-medium, 500);
      color: var(--text-color);
      padding-bottom: 5px;
      letter-spacing: 0.01em;
    }
    .field-group {
      display: flex;
      flex-direction: column;
      gap: 5px;
      margin-bottom: var(--space-4, 16px);
    }
    .field-error {
      font-size: var(--text-xs, 0.75rem);
      color: var(--color-danger);
      min-height: 1.2em;
    }
  ');
end;

initialization
  RegisterThemeStyles;
end.
