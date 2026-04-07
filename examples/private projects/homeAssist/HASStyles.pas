unit HASStyles;

// ═══════════════════════════════════════════════════════════════════════════
//
//  HASStyles — Home Assist Secure visual theme
//
//  Registers a teal CSS theme via the .has-app scope class.
//  All CSS custom properties are overridden inside .has-app so the
//  standard framework widgets (buttons, fields, badges, etc.) pick up
//  the government teal palette automatically through CSS inheritance.
//
//  Key class constants:
//    csHasApp          Scope root — teal theme override
//    csHasCard         Raised white card panel
//    csHasKpiCard      KPI metric card
//    csHasKpiValue     Large number inside KPI card
//    csHasKpiLabel     Label below the number
//    csHasNavItem      Sidebar navigation link
//    csHasNavActive    Active nav item modifier
//    csHasPageHeader   Page title row
//    csHasTableWrap    Overflow wrapper for data tables
//    csHasTable        Styled <table>
//    csHasBtnLogout    White-on-teal logout button
//    csHasLoginCard    Centered login card
//    csHasLoginLogo    Logo/title block inside login card
//
// ═══════════════════════════════════════════════════════════════════════════

interface

const
  csHasApp        = 'has-app';
  csHasCard       = 'has-card';
  csHasKpiCard    = 'has-kpi-card';
  csHasKpiValue   = 'has-kpi-value';
  csHasKpiLabel   = 'has-kpi-label';
  csHasKpiRow     = 'has-kpi-row';
  csHasNavItem    = 'has-nav-item';
  csHasNavActive  = 'active';
  csHasPageHeader = 'has-page-header';
  csHasTableWrap  = 'has-table-wrap';
  csHasTable      = 'has-table';
  csHasBtnLogout  = 'has-btn-logout';
  csHasLoginCard  = 'has-login-card';
  csHasLoginLogo  = 'has-login-logo';
  csHasRoleBadge  = 'has-role-badge';
  csHasBtn        = 'has-btn';
  csHasBtnPrimary = 'has-btn-primary';
  csHasBtnDanger  = 'has-btn-danger';

procedure RegisterHASStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterHASStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  // ══════════════════════════════════════════════════════════════════
  //  Teal theme token overrides (scoped to .has-app)
  //  All child widgets inherit these via CSS cascade
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-app {
      --primary-color:    #0d9488;
      --primary-light:    #5eead4;
      --color-success:    #22c55e;
      --color-success-bg: #f0fdf4;
      --color-warning:    #f59e0b;
      --color-warning-bg: #fffbeb;
      --color-danger:     #ef4444;
      --color-danger-bg:  #fef2f2;
      --color-info:       #0ea5e9;
      --color-info-bg:    #f0f9ff;
      --field-focus-border: #0d9488;
      --field-focus-ring:   0 0 0 3px rgba(13, 148, 136, 0.2);
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Nav bar (teal background)
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-app .dash-nav {
      --dash-nav-bg: #0f766e;
      color: #ffffff;
    }
    .has-app .dash-nav .dash-nav-title {
      font-weight: 700;
      font-size: 1.1rem;
      color: #ffffff;
      flex: 1;
    }
    .has-app .dash-nav .dash-nav-sub {
      font-size: 0.75rem;
      color: rgba(255,255,255,0.75);
      margin-top: 1px;
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Logout button (white outline on teal)
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-btn-logout {
      background: rgba(255,255,255,0.15);
      color: #ffffff;
      border: 1px solid rgba(255,255,255,0.4);
      border-radius: var(--radius-md, 6px);
      padding: 0 14px;
      height: 34px;
      font-size: 0.875rem;
      cursor: pointer;
      user-select: none;
      transition: background var(--anim-duration, 0.2s);
    }
    .has-btn-logout:hover {
      background: rgba(255,255,255,0.28);
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Sidebar navigation items
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-nav-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 12px;
      border-radius: var(--radius-md, 6px);
      cursor: pointer;
      font-size: 0.875rem;
      color: var(--text-color, #334155);
      user-select: none;
      transition: background var(--anim-duration, 0.2s),
                  color var(--anim-duration, 0.2s);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .has-nav-item:hover {
      background: var(--hover-color, #f1f5f9);
      color: var(--primary-color, #0d9488);
    }
    .has-nav-item.active {
      background: rgba(13,148,136,0.1);
      color: var(--primary-color, #0d9488);
      font-weight: 600;
    }
    .has-nav-group-label {
      font-size: 0.7rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--text-light, #64748b);
      padding: 12px 12px 4px 12px;
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Cards
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-card {
      background: var(--surface-color, #ffffff);
      border-radius: var(--radius-lg, 8px);
      border: 1px solid var(--border-color, #e2e8f0);
      padding: var(--space-4, 16px);
      box-shadow: var(--shadow-sm);
    }
    .has-card-title {
      font-size: 1rem;
      font-weight: 600;
      color: var(--text-color, #334155);
      margin-bottom: var(--space-3, 12px);
      padding-bottom: var(--space-2, 8px);
      border-bottom: 1px solid var(--border-color, #e2e8f0);
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  KPI cards
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-kpi-row {
      display: flex;
      flex-wrap: wrap;
      gap: var(--space-4, 16px);
    }
    .has-kpi-card {
      flex: 1;
      min-width: 140px;
      background: var(--surface-color, #ffffff);
      border-radius: var(--radius-lg, 8px);
      border: 1px solid var(--border-color, #e2e8f0);
      padding: var(--space-4, 16px);
      box-shadow: var(--shadow-sm);
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .has-kpi-value {
      font-size: 2rem;
      font-weight: 700;
      color: var(--primary-color, #0d9488);
      line-height: 1;
    }
    .has-kpi-label {
      font-size: 0.8rem;
      color: var(--text-light, #64748b);
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Page header
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-page-header {
      display: flex;
      align-items: center;
      gap: var(--space-3, 12px);
      padding-bottom: var(--space-4, 16px);
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      margin-bottom: var(--space-4, 16px);
    }
    .has-page-header-title {
      font-size: 1.25rem;
      font-weight: 700;
      color: var(--text-color, #334155);
      flex: 1;
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Data tables
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-table-wrap {
      overflow-x: auto;
      border-radius: var(--radius-md, 6px);
      border: 1px solid var(--border-color, #e2e8f0);
    }
    .has-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.875rem;
      color: var(--text-color, #334155);
    }
    .has-table th {
      background: var(--bg-color, #f8fafc);
      padding: 10px 14px;
      text-align: left;
      font-weight: 600;
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--text-light, #64748b);
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      white-space: nowrap;
    }
    .has-table td {
      padding: 10px 14px;
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      vertical-align: middle;
    }
    .has-table tr:last-child td {
      border-bottom: none;
    }
    .has-table tr:hover td {
      background: var(--hover-color, #f1f5f9);
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Login card
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-login-card {
      background: var(--surface-color, #ffffff);
      border-radius: var(--radius-xl, 12px);
      border: 1px solid var(--border-color, #e2e8f0);
      padding: 40px;
      width: 400px;
      max-width: calc(100vw - 40px);
      box-shadow: var(--shadow-lg);
      display: flex;
      flex-direction: column;
      gap: var(--space-4, 16px);
    }
    .has-login-logo {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      padding-bottom: var(--space-4, 16px);
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      margin-bottom: var(--space-2, 8px);
    }
    .has-login-logo-mark {
      width: 52px;
      height: 52px;
      border-radius: var(--radius-lg, 8px);
      background: var(--primary-color, #0d9488);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.5rem;
      color: #ffffff;
    }
    .has-login-logo-title {
      font-size: 1.1rem;
      font-weight: 700;
      color: var(--text-color, #334155);
      text-align: center;
    }
    .has-login-logo-sub {
      font-size: 0.8rem;
      color: var(--text-light, #64748b);
      text-align: center;
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Role badge inside nav
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-role-badge {
      display: inline-block;
      padding: 2px 8px;
      border-radius: var(--radius-full, 9999px);
      font-size: 0.7rem;
      font-weight: 600;
      background: rgba(255,255,255,0.2);
      color: #ffffff;
      white-space: nowrap;
    }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Status badge colours (used in table cells)
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-status {
      display: inline-block;
      padding: 2px 8px;
      border-radius: var(--radius-full, 9999px);
      font-size: 0.75rem;
      font-weight: 600;
      white-space: nowrap;
    }
    .has-status-green  { background: var(--color-success-bg, #f0fdf4); color: #15803d; }
    .has-status-blue   { background: var(--color-info-bg,    #f0f9ff); color: #0369a1; }
    .has-status-yellow { background: var(--color-warning-bg, #fffbeb); color: #92400e; }
    .has-status-red    { background: var(--color-danger-bg,  #fef2f2); color: #b91c1c; }
    .has-status-grey   { background: #f1f5f9; color: #475569; }
  ');

  // ══════════════════════════════════════════════════════════════════
  //  Action buttons
  // ══════════════════════════════════════════════════════════════════

  AddStyleBlock(#'
    .has-btn, .has-btn-primary, .has-btn-danger {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 8px 16px;
      border-radius: var(--radius-md, 6px);
      font-size: 0.875rem;
      font-weight: 500;
      cursor: pointer;
      border: 1px solid transparent;
      transition: background var(--anim-duration, 0.2s);
      user-select: none;
    }
    .has-btn {
      background: var(--bg-color, #f8fafc);
      color: var(--text-color, #334155);
      border-color: var(--border-color, #e2e8f0);
    }
    .has-btn:hover { background: var(--hover-color, #f1f5f9); }
    .has-btn-primary {
      background: var(--primary-color, #0d9488);
      color: #ffffff;
    }
    .has-btn-primary:hover { background: #0f766e; }
    .has-btn-danger {
      background: var(--color-danger, #ef4444);
      color: #ffffff;
    }
    .has-btn-danger:hover { background: #dc2626; }
  ');

end;

initialization
  RegisterHASStyles;
end.
