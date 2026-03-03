unit TypographyStyles;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Typography
//
//  Fluid base font size that scales with the viewport. All rem values
//  throughout the framework scale proportionally. No media queries needed.
//
//  The base size uses clamp():
//
//    clamp(15px, 1vw + 12px, 18px)
//
//    375px phone  → ~15.75px
//    768px tablet → ~16.68px
//    1440px desktop → ~17px (capped at 18px)
//
//  CSS variables (override on :root or any ancestor):
//
//    --font-family          Base font stack              default: inherited from body
//    --font-family-mono     Monospace font stack         default: system monospace
//
//    --font-size-base       Root font size               default: clamp(15px, 1vw + 12px, 18px)
//    --font-size-xs         Extra small                  default: 0.75rem   (~12px)
//    --font-size-sm         Small                        default: 0.875rem  (~14px)
//    --font-size-md         Body / default               default: 1rem      (~16px)
//    --font-size-lg         Large body                   default: 1.125rem  (~18px)
//    --font-size-xl         Small heading                default: 1.25rem   (~20px)
//    --font-size-2xl        Medium heading               default: 1.5rem    (~24px)
//    --font-size-3xl        Large heading                default: 1.875rem  (~30px)
//    --font-size-4xl        Page title                   default: 2.25rem   (~36px)
//
//    --line-height-tight    Headings                     default: 1.25
//    --line-height-normal   Body text                    default: 1.6
//    --line-height-relaxed  Long-form reading            default: 1.75
//
//    --letter-spacing-tight   Headings                   default: -0.01em
//    --letter-spacing-normal  Body                       default: 0
//    --letter-spacing-wide    Labels, overlines           default: 0.05em
//
//    --font-weight-normal   Body text                    default: 400
//    --font-weight-medium   Emphasis                     default: 500
//    --font-weight-semibold Subheadings                  default: 600
//    --font-weight-bold     Headings                     default: 700
//
//    --measure              Optimal line length           default: 65ch
//
//  Utility classes:
//
//    .text-xs  .text-sm  .text-md  .text-lg
//    .text-xl  .text-2xl .text-3xl .text-4xl
//
//    .font-normal  .font-medium  .font-semibold  .font-bold
//
//    .leading-tight  .leading-normal  .leading-relaxed
//
//    .tracking-tight  .tracking-normal  .tracking-wide
//
//    .text-muted      Secondary text colour
//    .text-mono       Monospace font
//    .text-prose      Optimised for reading (line length, height, spacing)
//    .text-truncate   Ellipsis overflow on single line
//    .text-uppercase  Uppercase with wide tracking (labels)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

const
  // Size
  csTextXs   = 'text-xs';
  csTextSm   = 'text-sm';
  csTextMd   = 'text-md';
  csTextLg   = 'text-lg';
  csTextXl   = 'text-xl';
  csText2xl  = 'text-2xl';
  csText3xl  = 'text-3xl';
  csText4xl  = 'text-4xl';

  // Weight
  csFontNormal   = 'font-normal';
  csFontMedium   = 'font-medium';
  csFontSemibold = 'font-semibold';
  csFontBold     = 'font-bold';

  // Line height
  csLeadingTight   = 'leading-tight';
  csLeadingNormal  = 'leading-normal';
  csLeadingRelaxed = 'leading-relaxed';

  // Letter spacing
  csTrackingTight  = 'tracking-tight';
  csTrackingNormal = 'tracking-normal';
  csTrackingWide   = 'tracking-wide';

  // Composite / utility
  csTextMuted    = 'text-muted';
  csTextMono     = 'text-mono';
  csTextProse    = 'text-prose';
  csTextTruncate = 'text-truncate';
  csTextUpper    = 'text-uppercase';

procedure RegisterTypographyStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterTypographyStyles;
begin
  if FRegistered then exit;
  FRegistered := true;
  AddStyleBlock(#'

    /* ── Root: fluid base size ────────────────────────────────────── */

    :root {
      --font-family-mono:     "SF Mono", "Cascadia Code", "Consolas", monospace;

      --font-size-base:       clamp(15px, 1vw + 12px, 18px);
      --font-size-xs:         0.75rem;
      --font-size-sm:         0.875rem;
      --font-size-md:         1rem;
      --font-size-lg:         1.125rem;
      --font-size-xl:         1.25rem;
      --font-size-2xl:        1.5rem;
      --font-size-3xl:        1.875rem;
      --font-size-4xl:        2.25rem;

      --line-height-tight:    1.25;
      --line-height-normal:   1.6;
      --line-height-relaxed:  1.75;

      --letter-spacing-tight:  -0.01em;
      --letter-spacing-normal: 0;
      --letter-spacing-wide:   0.05em;

      --font-weight-normal:   400;
      --font-weight-medium:   500;
      --font-weight-semibold: 600;
      --font-weight-bold:     700;

      --measure:              65ch;

      font-size: var(--font-size-base);
      line-height: var(--line-height-normal);
    }


    /* ── Size classes ─────────────────────────────────────────────── */

    .text-xs  { font-size: var(--font-size-xs);  }
    .text-sm  { font-size: var(--font-size-sm);  }
    .text-md  { font-size: var(--font-size-md);  }
    .text-lg  { font-size: var(--font-size-lg);  }
    .text-xl  { font-size: var(--font-size-xl);  line-height: var(--line-height-tight); }
    .text-2xl { font-size: var(--font-size-2xl); line-height: var(--line-height-tight); }
    .text-3xl { font-size: var(--font-size-3xl); line-height: var(--line-height-tight); }
    .text-4xl { font-size: var(--font-size-4xl); line-height: var(--line-height-tight); }


    /* ── Weight classes ───────────────────────────────────────────── */

    .font-normal   { font-weight: var(--font-weight-normal);   }
    .font-medium   { font-weight: var(--font-weight-medium);   }
    .font-semibold { font-weight: var(--font-weight-semibold); }
    .font-bold     { font-weight: var(--font-weight-bold);     }


    /* ── Line height classes ──────────────────────────────────────── */

    .leading-tight   { line-height: var(--line-height-tight);   }
    .leading-normal  { line-height: var(--line-height-normal);  }
    .leading-relaxed { line-height: var(--line-height-relaxed); }


    /* ── Letter spacing classes ───────────────────────────────────── */

    .tracking-tight  { letter-spacing: var(--letter-spacing-tight);  }
    .tracking-normal { letter-spacing: var(--letter-spacing-normal); }
    .tracking-wide   { letter-spacing: var(--letter-spacing-wide);   }


    /* ── Utility classes ──────────────────────────────────────────── */

    .text-muted {
      color: var(--text-light, #64748b);
    }

    .text-mono {
      font-family: var(--font-family-mono);
      font-size: 0.9em;
    }

    .text-truncate {
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .text-uppercase {
      text-transform: uppercase;
      letter-spacing: var(--letter-spacing-wide);
      font-size: var(--font-size-xs);
      font-weight: var(--font-weight-semibold);
    }

    .text-prose {
      max-width: var(--measure);
      line-height: var(--line-height-relaxed);
      font-size: var(--font-size-md);
      overflow-wrap: break-word;
      word-break: break-word;
      hyphens: auto;
    }

    .text-prose p,
    .text-prose .paragraph {
      margin-bottom: 1em;
    }
  ');
end;

initialization
  RegisterTypographyStyles;
end.
