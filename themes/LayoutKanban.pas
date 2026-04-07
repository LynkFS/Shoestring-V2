unit LayoutKanban;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Kanban Layout
//
//  A header bar and a horizontally scrolling board of columns. Each
//  column scrolls vertically independently. Used by Trello, Jira,
//  GitHub Projects, Monday.com, Notion boards.
//
//  Desktop:
//  ┌──────────────────────────────────────┐
//  │              header                  │
//  ├─────────┬──────────┬─────────┬───  ──┤
//  │         │          │         │       │
//  │  col 1  │  col 2   │  col 3  │ col 4 │  ← horizontal scroll
//  │         │          │         │       │
//  │  ↕ vert │  ↕ vert  │  ↕ vert │       │
//  └─────────┴──────────┴─────────┴───  ──┘
//
//  Mobile:
//  ┌──────────┐
//  │  header  │
//  ├──────────┤
//  │  col 1   │
//  │  ↕ vert  │
//  ├──────────┤
//  │  col 2   │
//  │  ↕ vert  │
//  ├──────────┤
//  │  col 3   │
//  └──────────┘
//
//  CSS variables:
//
//    --kb-header-height     Header height           default: 52px
//    --kb-header-bg         Header background       default: var(--surface-color, #fff)
//    --kb-header-border     Header border           default: 1px solid var(--border-color, #e2e8f0)
//
//    --kb-board-bg          Board background        default: var(--bg-color, #f8fafc)
//    --kb-board-padding     Board padding           default: 16px
//    --kb-board-gap         Gap between columns     default: 16px
//
//    --kb-col-width         Column width            default: 300px
//    --kb-col-bg            Column background       default: var(--surface-color, #fff)
//    --kb-col-radius        Column border radius    default: var(--radius-lg, 8px)
//    --kb-col-padding       Column padding          default: 12px
//    --kb-col-gap           Gap between cards       default: 8px
//    --kb-col-max-height    Column max height       default: none (fills board)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csKbShell   = 'kb-shell';
  csKbHeader  = 'kb-header';
  csKbBoard   = 'kb-board';
  csKbCol     = 'kb-col';
  csKbColHead = 'kb-col-head';
  csKbColBody = 'kb-col-body';

procedure RegisterKanbanLayout;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterKanbanLayout;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Shell: full viewport, vertical stack ─────────────────────── */

    .kb-shell {
      height: 100vh;
      height: 100dvh;
      overflow: hidden;
    }

    /* ── Header ───────────────────────────────────────────────────── */

    .kb-header {
      flex-direction: row;
      align-items: center;
      flex-shrink: 0;
      min-height: var(--kb-header-height, 52px);
      padding: 0 16px;
      gap: 12px;
      background: var(--kb-header-bg, var(--surface-color, #ffffff));
      border-bottom: var(--kb-header-border, 1px solid var(--border-color, #e2e8f0));
      user-select: none;
    }

    /* ── Board: horizontal scrolling container ────────────────────── */

    .kb-board {
      flex-direction: row;
      flex-grow: 1;
      flex-wrap: nowrap;
      overflow-x: auto;
      overflow-y: hidden;
      padding: var(--kb-board-padding, 16px);
      gap: var(--kb-board-gap, 16px);
      background: var(--kb-board-bg, var(--bg-color, #f8fafc));
      align-items: flex-start;
      -webkit-overflow-scrolling: touch;
    }

    /* Hide scrollbar but keep functionality */
    .kb-board::-webkit-scrollbar { height: 6px; }
    .kb-board::-webkit-scrollbar-track { background: transparent; }
    .kb-board::-webkit-scrollbar-thumb {
      background: var(--border-color, #e2e8f0);
      border-radius: 3px;
    }

    /* ── Column ───────────────────────────────────────────────────── */

    .kb-col {
      flex-shrink: 0;
      width: var(--kb-col-width, 300px);
      background: var(--kb-col-bg, var(--surface-color, #ffffff));
      border-radius: var(--kb-col-radius, var(--radius-lg, 8px));
      padding: var(--kb-col-padding, 12px);
      gap: var(--kb-col-gap, 8px);
      max-height: 100%;
    }

    /* ── Column header ────────────────────────────────────────────── */

    .kb-col-head {
      flex-shrink: 0;
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
      padding: 4px 4px 8px;
      font-weight: 600;
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-color, #334155);
      user-select: none;
    }

    /* ── Column body: vertical scroll for cards ───────────────────── */

    .kb-col-body {
      flex-grow: 1;
      overflow-y: auto;
      gap: var(--kb-col-gap, 8px);
      min-height: 0;
    }

    .kb-col-body::-webkit-scrollbar { width: 4px; }
    .kb-col-body::-webkit-scrollbar-track { background: transparent; }
    .kb-col-body::-webkit-scrollbar-thumb {
      background: var(--border-color, #e2e8f0);
      border-radius: 2px;
    }

    /* ── Mobile: columns stack vertically ─────────────────────────── */

    @media (max-width: 768px) {

      .kb-board {
        flex-direction: column;
        overflow-x: hidden;
        overflow-y: auto;
        align-items: stretch;
      }

      .kb-col {
        width: 100%;
        max-height: none;
      }

      .kb-col-body {
        max-height: 300px;
        overflow-y: auto;
      }
    }
  ');
end;

initialization
  RegisterKanbanLayout;
end.
