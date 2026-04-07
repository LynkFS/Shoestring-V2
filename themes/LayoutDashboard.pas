unit LayoutDashboard;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Dashboard Layout
//
//  The most common application layout. Sidebar navigation, a top header
//  bar, and a main content area. The sidebar collapses to a bottom bar
//  on mobile.
//
//  Desktop:                        Mobile:
//  ┌──────────────────────┐        ┌──────────┐
//  │       nav bar        │        │  nav bar │
//  ├────────┬─────────────┤        ├──────────┤
//  │        │             │        │          │
//  │  side  │    main     │        │   main   │
//  │        │             │        │          │
//  │        │             │        ├──────────┤
//  └────────┴─────────────┘        │ side bar │
//                                  └──────────┘
//
//  CSS variables:
//
//    --dash-nav-height      Nav bar height           default: 52px
//    --dash-nav-bg          Nav background           default: var(--surface-color, #fff)
//    --dash-nav-border      Nav bottom border        default: 1px solid var(--border-color, #e2e8f0)
//    --dash-nav-z           Nav z-index              default: 100
//
//    --dash-side-width      Sidebar width            default: 240px
//    --dash-side-bg         Sidebar background       default: var(--surface-color, #fff)
//    --dash-side-border     Sidebar border           default: 1px solid var(--border-color, #e2e8f0)
//    --dash-side-padding    Sidebar padding          default: 12px
//    --dash-side-gap        Sidebar item gap         default: 4px
//
//    --dash-main-bg         Main area background     default: var(--bg-color, #f8fafc)
//    --dash-main-padding    Main area padding        default: 20px
//    --dash-main-gap        Main item gap            default: 16px
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csDashShell = 'dash-shell';
  csDashNav   = 'dash-nav';
  csDashSide  = 'dash-side';
  csDashMain  = 'dash-main';

procedure RegisterDashboardLayout;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterDashboardLayout;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Shell: CSS Grid, full viewport ───────────────────────────── */

    .dash-shell {
      display: grid;
      height: 100vh;
      height: 100dvh;
      grid-template-areas:
        "nav  nav"
        "side main";
      grid-template-columns: var(--dash-side-width, 240px) 1fr;
      grid-template-rows: auto 1fr;
    }

    /* ── Nav bar ──────────────────────────────────────────────────── */

    .dash-nav {
      grid-area: nav;
      flex-direction: row;
      align-items: center;
      flex-shrink: 0;
      min-height: var(--dash-nav-height, 52px);
      padding: 0 16px;
      gap: 12px;
      background: var(--dash-nav-bg, var(--surface-color, #ffffff));
      border-bottom: var(--dash-nav-border, 1px solid var(--border-color, #e2e8f0));
      z-index: var(--dash-nav-z, 100);
      user-select: none;
    }

    /* ── Sidebar ──────────────────────────────────────────────────── */

    .dash-side {
      grid-area: side;
      overflow-y: auto;
      padding: var(--dash-side-padding, 12px);
      gap: var(--dash-side-gap, 4px);
      background: var(--dash-side-bg, var(--surface-color, #ffffff));
      border-right: var(--dash-side-border, 1px solid var(--border-color, #e2e8f0));
    }

    /* ── Main content ─────────────────────────────────────────────── */

    .dash-main {
      grid-area: main;
      overflow-y: auto;
      padding: var(--dash-main-padding, 20px);
      gap: var(--dash-main-gap, 16px);
      background: var(--dash-main-bg, var(--bg-color, #f8fafc));
    }

    /* ── Mobile ───────────────────────────────────────────────────── */

    @media (max-width: 768px) {

      .dash-shell {
        grid-template-areas:
          "nav"
          "main"
          "side";
        grid-template-columns: 1fr;
        grid-template-rows: auto 1fr auto;
      }

      .dash-side {
        flex-direction: row;
        justify-content: space-around;
        overflow-y: visible;
        overflow-x: auto;
        border-right: none;
        border-top: var(--dash-side-border, 1px solid var(--border-color, #e2e8f0));
        padding: 8px;
      }

      .dash-main {
        padding: 12px;
      }
    }
  ');
end;

initialization
  RegisterDashboardLayout;
end.
