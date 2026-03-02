unit BookletStyles;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Booklet Styles
//
//  CSS classes for rendering booklet content: chapters, sections, code
//  blocks, pull quotes, and TOC sidebar items.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

const
  csChapter       = 'chapter';
  csChapterNumber = 'chapter-num';
  csChapterTitle  = 'chapter-title';
  csSection       = 'section';
  csSectionTitle  = 'section-title';
  csBodyText      = 'body-text';
  csCodeBlock     = 'code-block';
  csQuote         = 'quote-block';
  csTocLabel      = 'toc-label';
  csTocItem       = 'toc-item';
  csTocActive     = 'toc-active';
  csDivider       = 'ch-divider';

procedure RegisterBookletStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterBookletStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Chapter container ────────────────────────────────────────── */

    .chapter {
      padding-top: 40px;
      padding-bottom: 8px;
    }

    .chapter-num {
      font-size: var(--font-size-xs, 0.75rem);
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.1em;
      color: var(--primary-color, #6366f1);
      margin-bottom: 4px;
    }

    .chapter-title {
      font-size: var(--font-size-2xl, 1.5rem);
      font-weight: 700;
      line-height: 1.25;
      color: var(--text-color, #334155);
      margin-bottom: 24px;
      padding-bottom: 12px;
      border-bottom: 2px solid var(--primary-color, #6366f1);
    }

    /* ── Section ──────────────────────────────────────────────────── */

    .section {
      margin-bottom: 24px;
    }

    .section-title {
      font-size: var(--font-size-lg, 1.125rem);
      font-weight: 600;
      color: var(--text-color, #334155);
      margin-bottom: 8px;
    }

    /* ── Body text ────────────────────────────────────────────────── */

    .body-text {
      line-height: 1.7;
      color: var(--text-color, #334155);
      margin-bottom: 12px;
      overflow-wrap: break-word;
    }

    /* ── Code block ───────────────────────────────────────────────── */

    .code-block {
      font-family: "Consolas", "Courier New", monospace;
      font-size: 0.82rem;
      line-height: 1.6;
      color: #1e293b;
      background: var(--hover-color, #f1f5f9);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: 6px;
      padding: 14px 18px;
      margin-bottom: 16px;
      overflow-x: auto;
      white-space: pre;
      flex-shrink: 0;
    }

    /* ── Pull quote ───────────────────────────────────────────────── */

    .quote-block {
      font-style: italic;
      color: var(--text-light, #64748b);
      border-left: 3px solid var(--primary-color, #6366f1);
      padding: 8px 0 8px 20px;
      margin-bottom: 16px;
      line-height: 1.6;
    }

    /* ── TOC sidebar ──────────────────────────────────────────────── */

    .toc-label {
      font-size: var(--font-size-xs, 0.75rem);
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--text-light, #64748b);
      padding-bottom: 8px;
    }

    .toc-item {
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-light, #64748b);
      padding: 6px 0;
      cursor: pointer;
      user-select: none;
      border-left: 2px solid transparent;
      padding-left: 12px;
      transition: color 0.15s;
    }

    .toc-item:hover {
      color: var(--text-color, #334155);
    }

    .toc-active {
      color: var(--primary-color, #6366f1);
      border-left-color: var(--primary-color, #6366f1);
      font-weight: 500;
    }

    /* ── Chapter divider ──────────────────────────────────────────── */

    .ch-divider {
      height: 1px;
      background: var(--border-color, #e2e8f0);
      flex-shrink: 0;
      margin: 0;
    }
  ');
end;

initialization
  RegisterBookletStyles;
end.
