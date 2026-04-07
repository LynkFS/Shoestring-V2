unit PageAuditLog;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PageAuditLog — Full audit log with search filter (newest first)
//
//  Roles: Administrator, Assessor
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPageAuditLog = class(JW3Panel)
  private
    FSearchEl:  TElement;   // <input> — filters actor / event / details
    FTableWrap: TElement;

    procedure BuildHeader;
    procedure BuildFilters;
    procedure BuildTable;
    procedure RefreshTable;
    function  TableHTML(const Filter: String): String;
  public
    constructor Create(Parent: TElement); override;
  end;

implementation

uses Globals, HASData, HASTypes, HASStyles, ThemeStyles;

{ TPageAuditLog }

constructor TPageAuditLog.Create(Parent: TElement);
begin
  inherited(Parent);
  SetStyle('gap', 'var(--space-4, 16px)');
  BuildHeader;
  BuildFilters;
  BuildTable;
end;

// ── Page header ───────────────────────────────────────────────────────────

procedure TPageAuditLog.BuildHeader;
var Header, Title: TElement;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  Title.SetText('Audit Log');

  var Sub := TElement.Create('div', Header);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetText(IntToStr(HAS_AuditLog.Count) + ' events');
end;

// ── Filter row ────────────────────────────────────────────────────────────

procedure TPageAuditLog.BuildFilters;
var Row: TElement;
begin
  Row := TElement.Create('div', Self);
  Row.SetStyle('display', 'flex');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('align-items', 'center');

  FSearchEl := TElement.Create('input', Row);
  FSearchEl.AddClass(csField);
  FSearchEl.SetAttribute('placeholder', 'Search by event, actor or details…');
  FSearchEl.SetStyle('max-width', '400px');

  FSearchEl.Handle.addEventListener('input', procedure(E: variant) begin RefreshTable; end);
end;

// ── Table ─────────────────────────────────────────────────────────────────

procedure TPageAuditLog.BuildTable;
begin
  FTableWrap := TElement.Create('div', Self);
  FTableWrap.AddClass(csHasTableWrap);
  FTableWrap.SetHTML(TableHTML(''));
end;

procedure TPageAuditLog.RefreshTable;
begin
  FTableWrap.SetHTML(TableHTML(FSearchEl.Handle.value));
end;

// ── HTML generation ───────────────────────────────────────────────────────

function TPageAuditLog.TableHTML(const Filter: String): String;
var HTML, FLow: String;
    I, Count: Integer;
    Ev: TAuditEvent;
begin
  FLow := LowerCase(Filter);

  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>Time</th><th>Event</th><th>Entity</th><th>Actor</th><th>Details</th>' +
    '</tr></thead><tbody>';

  Count := 0;

  // Iterate newest-first
  I := HAS_AuditLog.Count - 1;
  while I >= 0 do
  begin
    Ev := HAS_AuditLog[I];

    if (FLow <> '') and
       (Pos(FLow, LowerCase(Ev.EventType))  = 0) and
       (Pos(FLow, LowerCase(Ev.Actor))      = 0) and
       (Pos(FLow, LowerCase(Ev.Details))    = 0) and
       (Pos(FLow, LowerCase(Ev.EntityType)) = 0) and
       (Pos(FLow, LowerCase(Ev.EntityID))   = 0)
    then
    begin
      Dec(I);
      continue;
    end;

    var EventBadge: String;
    if (Ev.EventType = 'Login') or (Ev.EventType = 'Logout') then
      EventBadge := '<span class="has-status has-status-grey">' + Ev.EventType + '</span>'
    else
      EventBadge := StatusBadge(Ev.EventType);

    HTML := HTML +
      '<tr>' +
      '<td style="white-space:nowrap;font-size:0.8rem;color:var(--text-light)">' +
        FmtDate(Ev.LoggedAt) + '</td>' +
      '<td>' + EventBadge + '</td>' +
      '<td style="font-size:0.8rem">' + Ev.EntityType +
        '<br><span style="color:var(--text-light)">' + Ev.EntityID + '</span></td>' +
      '<td style="font-size:0.875rem">' + Ev.Actor + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + Ev.Details + '</td>' +
      '</tr>';
    Inc(Count);
    Dec(I);
  end;

  if Count = 0 then
    HTML := HTML +
      '<tr><td colspan="5" style="text-align:center;color:var(--text-light);padding:24px">' +
      'No events found.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Result := HTML;
end;

end.
