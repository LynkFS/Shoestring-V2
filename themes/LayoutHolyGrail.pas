unit LayoutHolyGrail;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Holy Grail Layout
//
//  Header, footer, and three columns: left nav, centre content, right
//  sidebar. The classic portal layout. Used by news sites, complex apps,
//  IDE-style interfaces, and applications with toolbars on both sides.
//
//  Desktop:                        Mobile:
//  ┌──────────────────────┐        ┌──────────┐
//  │       header         │        │  header  │
//  ├─────┬────────┬───────┤        ├──────────┤
//  │     │        │       │        │          │
//  │ nav │ center │ aside │        │  center  │
//  │     │        │       │        │          │
//  ├─────┴────────┴───────┤        ├──────────┤
//  │       footer         │        │  footer  │
//  └──────────────────────┘        └──────────┘
//                                   (nav + aside hidden)
//
//  CSS variables:
//
//    --hg-header-height     Header height           default: 52px
//    --hg-header-bg         Header background       default: var(--surface-color, #fff)
//    --hg-header-border     Header border           default: 1px solid var(--border-color, #e2e8f0)
//
//    --hg-footer-height     Footer height           default: 40px
//    --hg-footer-bg         Footer background       default: var(--surface-color, #fff)
//    --hg-footer-border     Footer border           default: 1px solid var(--border-color, #e2e8f0)
//
//    --hg-nav-width         Left nav width          default: 220px
//    --hg-nav-bg            Nav background          default: var(--surface-color, #fff)
//    --hg-nav-border        Nav border              default: 1px solid var(--border-color, #e2e8f0)
//    --hg-nav-padding       Nav padding             default: 12px
//
//    --hg-aside-width       Right sidebar width     default: 240px
//    --hg-aside-bg          Sidebar background      default: transparent
//    --hg-aside-border      Sidebar border          default: 1px solid var(--border-color, #e2e8f0)
//    --hg-aside-padding     Sidebar padding         default: 16px
//
//    --hg-center-bg         Center background       default: var(--bg-color, #f8fafc)
//    --hg-center-padding    Center padding          default: 24px
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csHgShell   = 'hg-shell';
  csHgHeader  = 'hg-header';
  csHgNav     = 'hg-nav';
  csHgCenter  = 'hg-center';
  csHgAside   = 'hg-aside';
  csHgFooter  = 'hg-footer';

procedure RegisterHolyGrailLayout;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterHolyGrailLayout;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Shell: CSS Grid with named areas ─────────────────────────── */

    .hg-shell {
      display: grid;
      height: 100vh;
      grid-template-areas:
        "header header header"
        "nav    center aside"
        "footer footer footer";
      grid-template-columns: var(--hg-nav-width, 220px) 1fr var(--hg-aside-width, 240px);
      grid-template-rows: auto 1fr auto;
    }

    /* ── Header ───────────────────────────────────────────────────── */

    .hg-header {
      grid-area: header;
      flex-direction: row;
      align-items: center;
      flex-shrink: 0;
      min-height: var(--hg-header-height, 52px);
      padding: 0 16px;
      gap: 12px;
      background: var(--hg-header-bg, var(--surface-color, #ffffff));
      border-bottom: var(--hg-header-border, 1px solid var(--border-color, #e2e8f0));
      user-select: none;
    }

    /* ── Left nav ─────────────────────────────────────────────────── */

    .hg-nav {
      grid-area: nav;
      overflow-y: auto;
      padding: var(--hg-nav-padding, 12px);
      gap: 4px;
      background: var(--hg-nav-bg, var(--surface-color, #ffffff));
      border-right: var(--hg-nav-border, 1px solid var(--border-color, #e2e8f0));
    }

    /* ── Center content ───────────────────────────────────────────── */

    .hg-center {
      grid-area: center;
      overflow-y: auto;
      padding: var(--hg-center-padding, 24px);
      background: var(--hg-center-bg, var(--bg-color, #f8fafc));
    }

    /* ── Right sidebar ────────────────────────────────────────────── */

    .hg-aside {
      grid-area: aside;
      overflow-y: auto;
      padding: var(--hg-aside-padding, 16px);
      gap: 12px;
      background: var(--hg-aside-bg, transparent);
      border-left: var(--hg-aside-border, 1px solid var(--border-color, #e2e8f0));
    }

    /* ── Footer ───────────────────────────────────────────────────── */

    .hg-footer {
      grid-area: footer;
      flex-direction: row;
      align-items: center;
      flex-shrink: 0;
      min-height: var(--hg-footer-height, 40px);
      padding: 0 16px;
      gap: 12px;
      background: var(--hg-footer-bg, var(--surface-color, #ffffff));
      border-top: var(--hg-footer-border, 1px solid var(--border-color, #e2e8f0));
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-light, #64748b);
    }

    /* ── Mobile: single column, nav + aside hidden ────────────────── */

    @media (max-width: 768px) {

      .hg-shell {
        grid-template-areas:
          "header"
          "center"
          "footer";
        grid-template-columns: 1fr;
        grid-template-rows: auto 1fr auto;
      }

      .hg-nav,
      .hg-aside {
        display: none;
      }

      .hg-center {
        padding: 16px;
      }
    }
  ');
end;

initialization
  RegisterHolyGrailLayout;
end.
