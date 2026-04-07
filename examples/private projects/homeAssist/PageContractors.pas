unit PageContractors;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PageContractors — read-only contractor list with status filter
//
//  Roles: Administrator (CanManageContractors)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPageContractors = class(JW3Panel)
  private
    FStatusEl:  TElement;   // plain <select> — value read via Handle.value
    FTableWrap: TElement;

    procedure BuildHeader;
    procedure BuildFilters;
    procedure BuildTable;
    procedure RefreshTable;
    function  TableHTML(const StatusFilter: String): String;
  public
    constructor Create(Parent: TElement); override;
  end;

implementation

uses Globals, HASData, HASTypes, HASStyles, ThemeStyles;

{ TPageContractors }

constructor TPageContractors.Create(Parent: TElement);
begin
  inherited(Parent);
  SetStyle('gap', 'var(--space-4, 16px)');
  BuildHeader;
  BuildFilters;
  BuildTable;
end;

// ── Page header ───────────────────────────────────────────────────────────

procedure TPageContractors.BuildHeader;
var Header, Title: TElement;
    Active, I: Integer;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  Title.SetText('Contractors');

  Active := 0;
  for I := 0 to HAS_Contractors.Count - 1 do
    if HAS_Contractors[I].Status = stActive then Inc(Active);

  var Sub := TElement.Create('div', Header);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetText(IntToStr(HAS_Contractors.Count) + ' total · ' +
              IntToStr(Active) + ' active');
end;

// ── Filter row ────────────────────────────────────────────────────────────

procedure TPageContractors.BuildFilters;
var Row, Opt: TElement;
begin
  Row := TElement.Create('div', Self);
  Row.SetStyle('display', 'flex');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('align-items', 'center');

  var Lbl := TElement.Create('label', Row);
  Lbl.AddClass(csFieldLabel);
  Lbl.SetStyle('margin', '0');
  Lbl.SetText('Status:');

  FStatusEl := TElement.Create('select', Row);
  FStatusEl.AddClass(csField);
  FStatusEl.SetStyle('width', 'auto');
  FStatusEl.SetStyle('height', 'auto');
  FStatusEl.SetStyle('padding', '8px 12px');

  Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', '');       Opt.SetText('All');
  Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stActive);    Opt.SetText('Active');
  Opt := TElement.Create('option', FStatusEl); Opt.SetAttribute('value', stSuspended); Opt.SetText('Suspended');

  FStatusEl.Handle.addEventListener('change', procedure(E: variant) begin RefreshTable; end);
end;

// ── Table ─────────────────────────────────────────────────────────────────

procedure TPageContractors.BuildTable;
begin
  FTableWrap := TElement.Create('div', Self);
  FTableWrap.AddClass(csHasTableWrap);
  FTableWrap.SetHTML(TableHTML(''));
end;

procedure TPageContractors.RefreshTable;
begin
  FTableWrap.SetHTML(TableHTML(FStatusEl.Handle.value));
end;

// ── HTML generation ───────────────────────────────────────────────────────

function TPageContractors.TableHTML(const StatusFilter: String): String;
var HTML: String;
    I, Count: Integer;
    C: TContractor;
begin
  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>Business</th><th>Contact</th><th>Phone</th>' +
    '<th>ABN</th><th>Categories</th><th>Regions</th>' +
    '<th>Licence Exp.</th><th>Status</th>' +
    '</tr></thead><tbody>';

  Count := 0;
  for I := 0 to HAS_Contractors.Count - 1 do
  begin
    C := HAS_Contractors[I];
    if (StatusFilter <> '') and (C.Status <> StatusFilter) then continue;

    HTML := HTML +
      '<tr>' +
      '<td><strong>' + C.BusinessName + '</strong></td>' +
      '<td style="font-size:0.875rem">' + C.ContactName + '</td>' +
      '<td style="font-size:0.875rem">' + C.Phone + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + C.ABN + '</td>' +
      '<td style="font-size:0.8rem">' + C.Categories + '</td>' +
      '<td style="font-size:0.8rem">' + C.Regions + '</td>' +
      '<td style="font-size:0.8rem">' + FmtDate(C.LicenceExpiry) + '</td>' +
      '<td>' + StatusBadge(C.Status) + '</td>' +
      '</tr>';
    Inc(Count);
  end;

  if Count = 0 then
    HTML := HTML +
      '<tr><td colspan="8" style="text-align:center;color:var(--text-light);padding:24px">' +
      'No contractors found.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Result := HTML;
end;

end.
