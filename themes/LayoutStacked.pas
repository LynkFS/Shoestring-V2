unit LayoutStacked;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Stacked Layout
//
//  Header, vertically flowing full-width sections, and a footer. The
//  simplest layout and the most mobile-native. Same structure on desktop
//  and mobile. Used for landing pages, marketing pages, forms, wizards,
//  single-page apps, and any content that flows vertically.
//
//  Desktop & Mobile (same):
//  ┌──────────────────────┐
//  │       header         │
//  ├──────────────────────┤
//  │                      │
//  │      section         │
//  │                      │
//  ├──────────────────────┤
//  │      section         │
//  ├──────────────────────┤
//  │      section         │
//  ├──────────────────────┤
//  │       footer         │
//  └──────────────────────┘
//
//  CSS variables:
//
//    --stack-header-height   Header height           default: 56px
//    --stack-header-bg       Header background       default: var(--surface-color, #fff)
//    --stack-header-border   Header border           default: 1px solid var(--border-color, #e2e8f0)
//
//    --stack-footer-bg       Footer background       default: var(--surface-color, #fff)
//    --stack-footer-border   Footer border           default: 1px solid var(--border-color, #e2e8f0)
//    --stack-footer-padding  Footer padding          default: 16px 24px
//
//    --stack-body-bg         Scrollable body bg      default: var(--bg-color, #f8fafc)
//
//    --stack-section-max     Section max width       default: 960px
//    --stack-section-padding Section padding         default: 48px 24px
//    --stack-section-gap     Gap within a section    default: 16px
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csStackShell   = 'stack-shell';
  csStackHeader  = 'stack-header';
  csStackBody    = 'stack-body';
  csStackSection = 'stack-section';
  csStackFooter  = 'stack-footer';

procedure RegisterStackedLayout;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterStackedLayout;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Shell: full viewport, vertical stack ─────────────────────── */

    .stack-shell {
      height: 100vh;
      overflow: hidden;
    }

    /* ── Header: pinned at top ────────────────────────────────────── */

    .stack-header {
      flex-direction: row;
      align-items: center;
      flex-shrink: 0;
      min-height: var(--stack-header-height, 56px);
      padding: 0 24px;
      gap: 12px;
      background: var(--stack-header-bg, var(--surface-color, #ffffff));
      border-bottom: var(--stack-header-border, 1px solid var(--border-color, #e2e8f0));
      user-select: none;
    }

    /* ── Body: scrollable area between header and footer ───────────── */

    .stack-body {
      flex-grow: 1;
      overflow-y: auto;
      align-items: center;
      background: var(--stack-body-bg, var(--bg-color, #f8fafc));
    }

    /* ── Section: centered, max-width constrained ─────────────────── */

    .stack-section {
      width: 100%;
      max-width: var(--stack-section-max, 960px);
      padding: var(--stack-section-padding, 48px 24px);
      gap: var(--stack-section-gap, 16px);
    }

    /* ── Footer ───────────────────────────────────────────────────── */

    .stack-footer {
      flex-direction: row;
      align-items: center;
      flex-shrink: 0;
      padding: var(--stack-footer-padding, 16px 24px);
      background: var(--stack-footer-bg, var(--surface-color, #ffffff));
      border-top: var(--stack-footer-border, 1px solid var(--border-color, #e2e8f0));
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-light, #64748b);
      gap: 12px;
    }

    /* ── Mobile: tighter padding ──────────────────────────────────── */

    @media (max-width: 768px) {

      .stack-header {
        padding: 0 16px;
      }

      .stack-section {
        padding: var(--stack-section-padding, 32px 16px);
      }

      .stack-footer {
        padding: 12px 16px;
      }
    }
  ');
end;

initialization
  RegisterStackedLayout;
end.
