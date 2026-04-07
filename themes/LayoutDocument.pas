unit LayoutDocument;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Document Layout
//
//  A reading-focused layout with a fixed header, a centered content column,
//  and an optional sidebar. The header stays pinned while content scrolls.
//
//  Desktop:                        Mobile:
//  ┌──────────────────────┐        ┌──────────┐
//  │       header         │        │  header  │
//  ├──────────────┬───────┤        ├──────────┤
//  │              │       │        │          │
//  │   content    │ aside │        │ content  │
//  │   (narrow)   │       │        │          │
//  │              │       │        │          │
//  └──────────────┴───────┘        └──────────┘
//                                   (aside hidden)
//
//  CSS variables (set on any ancestor or :root to override):
//
//    --doc-header-height       Header height              default: 56px
//    --doc-header-bg           Header background          default: var(--surface-color, #fff)
//    --doc-header-border       Header bottom border       default: 1px solid var(--border-color, #e2e8f0)
//    --doc-header-z            Header z-index             default: 100
//
//    --doc-content-max-width   Content column max width   default: 720px
//    --doc-content-padding     Content padding            default: 32px 24px
//
//    --doc-aside-width         Sidebar width              default: 260px
//    --doc-aside-bg            Sidebar background         default: transparent
//    --doc-aside-padding       Sidebar padding            default: 32px 16px
//
//    --doc-body-bg             Body area background       default: var(--bg-color, #f8fafc)
//    --doc-body-gap            Gap between content/aside  default: 32px
//
//    --doc-breakpoint          Mobile breakpoint          default: 768px
//                              (note: used in @media, not runtime)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csDocShell   = 'doc-shell';
  csDocHeader  = 'doc-header';
  csDocBody    = 'doc-body';
  csDocContent = 'doc-content';
  csDocAside   = 'doc-aside';

procedure RegisterDocumentLayout;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterDocumentLayout;
begin
  if FRegistered then exit;
  FRegistered := true;
  AddStyleBlock(#'

    /* ── Shell: full viewport, vertical stack ─────────────────────── */

    .doc-shell {
      display: flex;
      flex-direction: column;
      height: 100vh;
      height: 100dvh;
      overflow: hidden;
    }

    /* ── Header: fixed at top, never scrolls ──────────────────────── */

    .doc-header {
      display: flex;
      flex-direction: row;
      align-items: center;
      flex-shrink: 0;
      height: var(--doc-header-height, 56px);
      min-height: var(--doc-header-height, 56px);
      padding: 0 24px;
      gap: 12px;
      background: var(--doc-header-bg, var(--surface-color, #ffffff));
      border-bottom: var(--doc-header-border, 1px solid var(--border-color, #e2e8f0));
      z-index: var(--doc-header-z, 100);
      user-select: none;
    }

    /* ── Body: scrollable area below the header ───────────────────── */

    .doc-body {
      display: flex;
      flex-direction: row;
      flex-grow: 1;
      overflow-y: auto;
      overflow-x: hidden;
      background: var(--doc-body-bg, var(--bg-color, #f8fafc));
      gap: var(--doc-body-gap, 32px);
      justify-content: center;
    }

    /* ── Content: centered, max-width for readability ─────────────── */

    .doc-content {
      display: flex;
      flex-direction: column;
      flex-grow: 1;
      max-width: var(--doc-content-max-width, 720px);
      padding: var(--doc-content-padding, 32px 24px);
      min-width: 0;
    }

    /* ── Aside: fixed-width sidebar on the right ──────────────────── */

    .doc-aside {
      display: flex;
      flex-direction: column;
      flex-shrink: 0;
      width: var(--doc-aside-width, 260px);
      padding: var(--doc-aside-padding, 32px 16px);
      background: var(--doc-aside-bg, transparent);
      overflow-y: auto;
      gap: 16px;
    }

    /* ── Mobile: single column, sidebar hidden ────────────────────── */

    @media (max-width: 768px) {

      .doc-body {
        flex-direction: column;
        gap: 0;
      }

      .doc-content {
        max-width: 100%;
        padding: var(--doc-content-padding, 24px 16px);
      }

      .doc-aside {
        display: none;
      }

      .doc-header {
        padding: 0 16px;
      }
    }
  ');
end;

initialization
  RegisterDocumentLayout;
end.
