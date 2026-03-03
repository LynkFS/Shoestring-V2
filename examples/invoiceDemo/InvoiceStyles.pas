unit InvoiceStyles;

// ═══════════════════════════════════════════════════════════════════════════
//
//  InvoiceStyles — application-wide CSS for the invoice demo
//
//  Registers once via initialization. All CSS classes defined here.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

const
  // ── Stat cards (dashboard) ────────────────────────────────────────
  csStatCard       = 'inv-stat';
  csStatValue      = 'inv-stat-value';
  csStatLabel      = 'inv-stat-label';
  csStatSub        = 'inv-stat-sub';

  // ── Status badge colour override (maps to badge-* but secondary needed) ──
  csBadgeSecondary = 'badge-secondary';

  // ── Line item table ───────────────────────────────────────────────
  csLineTable      = 'inv-lines';
  csLineTotals     = 'inv-totals';

  // ── Invoice header block ──────────────────────────────────────────
  csInvHeader      = 'inv-header';
  csInvMeta        = 'inv-meta';
  csInvMetaRow     = 'inv-meta-row';
  csInvMetaKey     = 'inv-meta-key';
  csInvMetaVal     = 'inv-meta-val';

  // ── Client card ───────────────────────────────────────────────────
  csClientCard     = 'inv-client-card';

procedure RegisterInvoiceStyles;

implementation

uses Globals;

var FRegistered: Boolean = false;

procedure RegisterInvoiceStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ──────────────────────────────────────────────────────────────
       badge-secondary — neutral grey for Draft status
    ────────────────────────────────────────────────────────────── */

    .badge-secondary {
      background: var(--border-color, #e2e8f0);
      color: var(--text-light, #64748b);
      border: 1px solid var(--border-color, #e2e8f0);
    }

    /* ──────────────────────────────────────────────────────────────
       Dashboard stat cards
    ────────────────────────────────────────────────────────────── */

    .inv-stats-row {
      display: flex;
      flex-direction: row;
      gap: 16px;
      flex-wrap: wrap;
    }
    .inv-stats-row > * {
      flex: 1;
      min-width: 150px;
    }

    .inv-stat {
      background: var(--surface-color, #fff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-lg, 8px);
      padding: 18px 20px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .inv-stat-label {
      font-size: 0.72rem;
      font-weight: 600;
      color: var(--text-light, #64748b);
      text-transform: uppercase;
      letter-spacing: 0.07em;
    }
    .inv-stat-value {
      font-size: 1.6rem;
      font-weight: 700;
      color: var(--text-color, #1e293b);
      line-height: 1.2;
    }
    .inv-stat-sub {
      font-size: 0.8rem;
      color: var(--primary-color, #6366f1);
    }

    /* ──────────────────────────────────────────────────────────────
       Invoice header block (detail view)
    ────────────────────────────────────────────────────────────── */

    .inv-header {
      display: flex;
      flex-direction: row;
      align-items: flex-start;
      justify-content: space-between;
      gap: 24px;
      padding: 24px;
      background: var(--surface-color, #fff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-lg, 8px);
      flex-wrap: wrap;
    }

    .inv-meta {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .inv-meta-row {
      display: flex;
      flex-direction: row;
      gap: 12px;
      align-items: baseline;
    }
    .inv-meta-key {
      font-size: 0.78rem;
      color: var(--text-light, #64748b);
      min-width: 90px;
    }
    .inv-meta-val {
      font-size: 0.875rem;
      color: var(--text-color, #1e293b);
      font-weight: 500;
    }

    /* ──────────────────────────────────────────────────────────────
       Client card (detail + editor)
    ────────────────────────────────────────────────────────────── */

    .inv-client-card {
      background: var(--bg-color, #f8fafc);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-lg, 8px);
      padding: 16px 20px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .inv-client-card .name {
      font-weight: 600;
      font-size: 0.9rem;
      color: var(--text-color, #1e293b);
    }
    .inv-client-card .detail {
      font-size: 0.8rem;
      color: var(--text-light, #64748b);
    }

    /* ──────────────────────────────────────────────────────────────
       Line items table
    ────────────────────────────────────────────────────────────── */

    .inv-lines {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.875rem;
    }
    .inv-lines th {
      text-align: left;
      padding: 8px 12px;
      font-size: 0.72rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: var(--text-light, #64748b);
      border-bottom: 2px solid var(--border-color, #e2e8f0);
    }
    .inv-lines th.right,
    .inv-lines td.right {
      text-align: right;
    }
    .inv-lines td {
      padding: 10px 12px;
      color: var(--text-color, #1e293b);
      border-bottom: 1px solid var(--border-color, #e2e8f0);
    }
    .inv-lines tr:last-child td {
      border-bottom: none;
    }
    .inv-lines tr:hover td {
      background: var(--hover-color, #f8fafc);
    }

    /* ──────────────────────────────────────────────────────────────
       Totals block
    ────────────────────────────────────────────────────────────── */

    .inv-totals {
      display: flex;
      flex-direction: column;
      gap: 6px;
      align-items: flex-end;
      padding: 16px 0 0;
    }
    .inv-totals-row {
      display: flex;
      flex-direction: row;
      gap: 32px;
      font-size: 0.875rem;
      color: var(--text-color, #1e293b);
    }
    .inv-totals-row .key {
      color: var(--text-light, #64748b);
      min-width: 100px;
      text-align: right;
    }
    .inv-totals-row .val {
      min-width: 90px;
      text-align: right;
      font-weight: 500;
    }
    .inv-totals-row.total {
      font-size: 1rem;
      font-weight: 700;
      color: var(--text-color, #1e293b);
      border-top: 2px solid var(--border-color, #e2e8f0);
      padding-top: 8px;
      margin-top: 2px;
    }

    /* ──────────────────────────────────────────────────────────────
       Editor line row (inline inputs)
    ────────────────────────────────────────────────────────────── */

    .inv-editor-line {
      display: flex;
      flex-direction: row;
      gap: 8px;
      align-items: center;
    }
    .inv-editor-line .desc {
      flex-grow: 1;
    }
    .inv-editor-line .num {
      width: 80px;
      flex-shrink: 0;
    }
    .inv-editor-line .tax {
      width: 70px;
      flex-shrink: 0;
    }
    .inv-editor-line .remove {
      flex-shrink: 0;
    }
    .inv-editor-lines-header {
      display: flex;
      flex-direction: row;
      gap: 8px;
      font-size: 0.72rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: var(--text-light, #64748b);
      padding: 0 0 4px;
    }

    /* ──────────────────────────────────────────────────────────────
       Client list rows
    ────────────────────────────────────────────────────────────── */

    .inv-client-row {
      display: flex;
      flex-direction: row;
      align-items: center;
      gap: 12px;
      padding: 12px 16px;
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      cursor: pointer;
    }
    .inv-client-row:hover {
      background: var(--hover-color, #f1f5f9);
    }
    .inv-client-row:last-child {
      border-bottom: none;
    }
    .inv-client-avatar {
      width: 36px;
      height: 36px;
      border-radius: 50%;
      background: var(--primary-color, #6366f1);
      color: #fff;
      font-weight: 700;
      font-size: 0.9rem;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .inv-client-info {
      display: flex;
      flex-direction: column;
      gap: 2px;
      flex-grow: 1;
    }
    .inv-client-name {
      font-weight: 600;
      font-size: 0.875rem;
      color: var(--text-color, #1e293b);
    }
    .inv-client-email {
      font-size: 0.78rem;
      color: var(--text-light, #64748b);
    }

    /* ──────────────────────────────────────────────────────────────
       Section card (generic white panel)
    ────────────────────────────────────────────────────────────── */

    .inv-section {
      background: var(--surface-color, #fff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-lg, 8px);
      padding: 20px 24px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .inv-section-title {
      font-size: 0.75rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: var(--text-light, #64748b);
      padding-bottom: 8px;
      border-bottom: 1px solid var(--border-color, #e2e8f0);
    }

    /* ──────────────────────────────────────────────────────────────
       Form field rows
    ────────────────────────────────────────────────────────────── */

    .inv-form-row {
      display: flex;
      flex-direction: row;
      gap: 16px;
      flex-wrap: wrap;
    }
    .inv-form-group {
      display: flex;
      flex-direction: column;
      gap: 4px;
      flex: 1;
      min-width: 180px;
    }
    .inv-form-label {
      font-size: 0.78rem;
      font-weight: 600;
      color: var(--text-light, #64748b);
    }

    /* ──────────────────────────────────────────────────────────────
       Sidebar nav items
    ────────────────────────────────────────────────────────────── */

    .inv-nav-item {
      display: flex;
      flex-direction: row;
      align-items: center;
      gap: 10px;
      padding: 9px 14px;
      border-radius: var(--radius-md, 6px);
      font-size: 0.875rem;
      cursor: pointer;
      color: var(--text-color, #334155);
      font-weight: 500;
    }
    .inv-nav-item:hover {
      background: var(--border-color, #e2e8f0);
    }
    .inv-nav-item.active {
      background: var(--primary-color, #6366f1);
      color: #fff;
    }
    .inv-nav-icon {
      font-size: 1rem;
      width: 20px;
      text-align: center;
      flex-shrink: 0;
    }

  ');
end;

initialization
  RegisterInvoiceStyles;
end.
