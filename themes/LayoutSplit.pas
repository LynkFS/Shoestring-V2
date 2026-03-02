unit LayoutSplit;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Split Layout
//
//  Two panels side by side. Equal or weighted. Stacks vertically on mobile.
//  Used for login/signup, comparisons, master-detail, onboarding, email.
//
//  Desktop:                        Mobile:
//  ┌───────────┬──────────┐        ┌──────────┐
//  │           │          │        │          │
//  │   left    │  right   │        │   left   │
//  │           │          │        │          │
//  │           │          │        ├──────────┤
//  │           │          │        │          │
//  └───────────┴──────────┘        │  right   │
//                                  │          │
//                                  └──────────┘
//
//  CSS variables:
//
//    --split-left-width     Left panel width       default: 1fr (equal)
//    --split-right-width    Right panel width      default: 1fr (equal)
//    --split-left-bg        Left background        default: var(--surface-color, #fff)
//    --split-right-bg       Right background       default: var(--bg-color, #f8fafc)
//    --split-gap            Gap between panels     default: 0
//    --split-padding        Panel padding          default: 32px
//    --split-divider        Divider between panels default: 1px solid var(--border-color, #e2e8f0)
//
//  Modifier: add .split-weighted to the shell for a 2:3 ratio instead of 1:1
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csSplitShell    = 'split-shell';
  csSplitLeft     = 'split-left';
  csSplitRight    = 'split-right';
  csSplitWeighted = 'split-weighted';

procedure RegisterSplitLayout;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterSplitLayout;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Shell: two columns, full viewport ────────────────────────── */

    .split-shell {
      display: grid;
      height: 100vh;
      grid-template-columns: var(--split-left-width, 1fr) var(--split-right-width, 1fr);
      gap: var(--split-gap, 0);
    }

    /* ── Left panel ───────────────────────────────────────────────── */

    .split-left {
      overflow-y: auto;
      padding: var(--split-padding, 32px);
      background: var(--split-left-bg, var(--surface-color, #ffffff));
      align-items: center;
      justify-content: center;
    }

    /* ── Right panel ──────────────────────────────────────────────── */

    .split-right {
      overflow-y: auto;
      padding: var(--split-padding, 32px);
      background: var(--split-right-bg, var(--bg-color, #f8fafc));
      border-left: var(--split-divider, 1px solid var(--border-color, #e2e8f0));
      align-items: center;
      justify-content: center;
    }

    /* ── Weighted modifier: 2fr / 3fr ─────────────────────────────── */

    .split-weighted {
      grid-template-columns: 2fr 3fr;
    }

    /* ── Mobile: stack vertically ─────────────────────────────────── */

    @media (max-width: 768px) {

      .split-shell,
      .split-weighted {
        grid-template-columns: 1fr;
        grid-template-rows: auto 1fr;
      }

      .split-left {
        padding: var(--split-padding, 24px);
        min-height: 40vh;
      }

      .split-right {
        border-left: none;
        border-top: var(--split-divider, 1px solid var(--border-color, #e2e8f0));
        padding: var(--split-padding, 24px);
      }
    }
  ');
end;

initialization
  RegisterSplitLayout;
end.
