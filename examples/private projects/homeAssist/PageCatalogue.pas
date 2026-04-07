unit PageCatalogue;

// ═══════════════════════════════════════════════════════════════════════════
//
//  PageCatalogue — Services catalogue (activities list)
//
//  Roles: Administrator (CanManageCatalogue) — read + add
//         Others — read only
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

type
  TPageCatalogue = class(JW3Panel)
  private
    FProgEl:     TElement;   // program filter <select>
    FTableWrap:  TElement;
    FNewCard:    TElement;   // Add Activity form card

    // Add-activity form fields
    FNameEl:    TElement;
    FCatEl:     TElement;
    FProgNewEl: TElement;   // program <select> inside the form
    FSubsidyEl: TElement;
    FDescEl:    TElement;

    procedure BuildHeader;
    procedure BuildFilters;
    procedure BuildNewCard;
    procedure BuildTable;
    procedure RefreshTable;
    function  TableHTML(const ProgFilter: String): String;
    procedure ShowNewCard;
    procedure HideNewCard;
    procedure DoAddActivity;
  public
    constructor Create(Parent: TElement); override;
  end;

implementation

uses Globals, HASData, HASPermissions, HASTypes, HASStyles, ThemeStyles;

{ TPageCatalogue }

constructor TPageCatalogue.Create(Parent: TElement);
begin
  inherited(Parent);
  SetStyle('gap', 'var(--space-4, 16px)');
  BuildHeader;
  BuildFilters;
  BuildNewCard;
  BuildTable;
end;

// ── Page header ───────────────────────────────────────────────────────────

procedure TPageCatalogue.BuildHeader;
var Header, Title: TElement;
begin
  Header := TElement.Create('div', Self);
  Header.AddClass(csHasPageHeader);

  Title := TElement.Create('div', Header);
  Title.AddClass('has-page-header-title');
  Title.SetText('Services Catalogue');

  var Sub := TElement.Create('div', Header);
  Sub.SetStyle('font-size', '0.875rem');
  Sub.SetStyle('color', 'var(--text-light)');
  Sub.SetText(IntToStr(HAS_Activities.Count) + ' activities');
end;

// ── Filter row ────────────────────────────────────────────────────────────

procedure TPageCatalogue.BuildFilters;
var Row, Opt: TElement;
    P: TPermissions;
begin
  P := GetPermissions(CurrentRole);

  Row := TElement.Create('div', Self);
  Row.SetStyle('display', 'flex');
  Row.SetStyle('gap', 'var(--space-3, 12px)');
  Row.SetStyle('align-items', 'center');

  var Lbl := TElement.Create('label', Row);
  Lbl.AddClass(csFieldLabel);
  Lbl.SetStyle('margin', '0');
  Lbl.SetText('Program:');

  FProgEl := TElement.Create('select', Row);
  FProgEl.AddClass(csField);
  FProgEl.SetStyle('width', 'auto');
  FProgEl.SetStyle('height', 'auto');
  FProgEl.SetStyle('padding', '8px 12px');

  Opt := TElement.Create('option', FProgEl); Opt.SetAttribute('value', '');      Opt.SetText('All programs');
  Opt := TElement.Create('option', FProgEl); Opt.SetAttribute('value', progHAS);  Opt.SetText(progHASLabel);
  Opt := TElement.Create('option', FProgEl); Opt.SetAttribute('value', progHSSH); Opt.SetText(progHSSHLabel);

  FProgEl.Handle.addEventListener('change', procedure(E: variant) begin RefreshTable; end);

  if P.CanManageCatalogue then
  begin
    var Spacer := TElement.Create('div', Row);
    Spacer.SetStyle('flex', '1');
    var BtnNew := TElement.Create('button', Row);
    BtnNew.AddClass(csHasBtnPrimary);
    BtnNew.SetText('+ Add Activity');
    BtnNew.OnClick := lambda ShowNewCard; end;
  end;
end;

// ── Add Activity card ─────────────────────────────────────────────────────

procedure TPageCatalogue.BuildNewCard;
var Opt: TElement;
    P: TPermissions;
begin
  P := GetPermissions(CurrentRole);

  FNewCard := TElement.Create('div', Self);
  FNewCard.AddClass(csHasCard);
  FNewCard.SetStyle('display', 'none');

  if not P.CanManageCatalogue then exit;

  var TitleEl := TElement.Create('div', FNewCard);
  TitleEl.AddClass('has-card-title');
  TitleEl.SetText('Add Activity');

  var FormRows := TElement.Create('div', FNewCard);
  FormRows.SetStyle('display', 'flex');
  FormRows.SetStyle('flex-direction', 'column');
  FormRows.SetStyle('gap', '12px');

  // Two-column row: Name + Category
  var TwoCol := TElement.Create('div', FormRows);
  TwoCol.SetStyle('display', 'grid');
  TwoCol.SetStyle('grid-template-columns', '1fr 1fr');
  TwoCol.SetStyle('gap', '12px');

  var NameRow := TElement.Create('div', TwoCol);
  NameRow.AddClass(csFieldGroup);
  var NameLbl := TElement.Create('label', NameRow);
  NameLbl.AddClass(csFieldLabel);
  NameLbl.SetText('Activity Name');
  FNameEl := TElement.Create('input', NameRow);
  FNameEl.AddClass(csField);
  FNameEl.SetAttribute('placeholder', 'e.g. Deadbolt Replacement');

  var CatRow := TElement.Create('div', TwoCol);
  CatRow.AddClass(csFieldGroup);
  var CatLbl := TElement.Create('label', CatRow);
  CatLbl.AddClass(csFieldLabel);
  CatLbl.SetText('Category');
  FCatEl := TElement.Create('input', CatRow);
  FCatEl.AddClass(csField);
  FCatEl.SetAttribute('placeholder', 'e.g. Locks');

  // Two-column row: Program + Max Subsidy
  var TwoCol2 := TElement.Create('div', FormRows);
  TwoCol2.SetStyle('display', 'grid');
  TwoCol2.SetStyle('grid-template-columns', '1fr 1fr');
  TwoCol2.SetStyle('gap', '12px');

  var ProgRow := TElement.Create('div', TwoCol2);
  ProgRow.AddClass(csFieldGroup);
  var ProgLbl := TElement.Create('label', ProgRow);
  ProgLbl.AddClass(csFieldLabel);
  ProgLbl.SetText('Program');
  FProgNewEl := TElement.Create('select', ProgRow);
  FProgNewEl.AddClass(csField);
  Opt := TElement.Create('option', FProgNewEl); Opt.SetAttribute('value', progHAS);  Opt.SetText(progHASLabel);
  Opt := TElement.Create('option', FProgNewEl); Opt.SetAttribute('value', progHSSH); Opt.SetText(progHSSHLabel);

  var SubRow := TElement.Create('div', TwoCol2);
  SubRow.AddClass(csFieldGroup);
  var SubLbl := TElement.Create('label', SubRow);
  SubLbl.AddClass(csFieldLabel);
  SubLbl.SetText('Max Subsidy ($)');
  FSubsidyEl := TElement.Create('input', SubRow);
  FSubsidyEl.AddClass(csField);
  FSubsidyEl.SetAttribute('type', 'number');
  FSubsidyEl.SetAttribute('step', '0.01');
  FSubsidyEl.SetAttribute('min', '0');

  // Description
  var DescRow := TElement.Create('div', FormRows);
  DescRow.AddClass(csFieldGroup);
  var DescLbl := TElement.Create('label', DescRow);
  DescLbl.AddClass(csFieldLabel);
  DescLbl.SetText('Description');
  FDescEl := TElement.Create('textarea', DescRow);
  FDescEl.AddClass(csField);
  FDescEl.SetStyle('height', '64px');

  // Buttons
  var BtnRow := TElement.Create('div', FNewCard);
  BtnRow.SetStyle('display', 'flex');
  BtnRow.SetStyle('gap', '8px');
  BtnRow.SetStyle('margin-top', '4px');

  var BtnAdd := TElement.Create('button', BtnRow);
  BtnAdd.AddClass(csHasBtnPrimary);
  BtnAdd.SetText('Add Activity');
  BtnAdd.OnClick := lambda DoAddActivity; end;

  var BtnCancel := TElement.Create('button', BtnRow);
  BtnCancel.AddClass(csHasBtn);
  BtnCancel.SetText('Cancel');
  BtnCancel.OnClick := lambda HideNewCard; end;
end;

procedure TPageCatalogue.ShowNewCard;
begin
  FNewCard.SetStyle('display', 'block');
end;

procedure TPageCatalogue.HideNewCard;
begin
  FNewCard.SetStyle('display', 'none');
end;

// ── Table ─────────────────────────────────────────────────────────────────

procedure TPageCatalogue.BuildTable;
begin
  FTableWrap := TElement.Create('div', Self);
  FTableWrap.AddClass(csHasTableWrap);
  FTableWrap.SetHTML(TableHTML(''));
end;

procedure TPageCatalogue.RefreshTable;
begin
  FTableWrap.SetHTML(TableHTML(FProgEl.Handle.value));
end;

// ── HTML generation ───────────────────────────────────────────────────────

function TPageCatalogue.TableHTML(const ProgFilter: String): String;
var HTML: String;
    I, Count: Integer;
    A: TActivity;
begin
  HTML :=
    '<table class="has-table">' +
    '<thead><tr>' +
    '<th>Name</th><th>Category</th><th>Program</th>' +
    '<th style="text-align:right">Max Subsidy</th><th>Description</th>' +
    '</tr></thead><tbody>';

  Count := 0;
  for I := 0 to HAS_Activities.Count - 1 do
  begin
    A := HAS_Activities[I];
    if (ProgFilter <> '') and (A.Program <> ProgFilter) then continue;

    HTML := HTML +
      '<tr>' +
      '<td><strong>' + A.Name + '</strong></td>' +
      '<td style="font-size:0.875rem">' + A.Category + '</td>' +
      '<td><span class="has-status has-status-blue">' + A.Program + '</span></td>' +
      '<td style="text-align:right;font-size:0.875rem">' + FmtCur(A.MaxSubsidy) + '</td>' +
      '<td style="font-size:0.8rem;color:var(--text-light)">' + A.Description + '</td>' +
      '</tr>';
    Inc(Count);
  end;

  if Count = 0 then
    HTML := HTML +
      '<tr><td colspan="5" style="text-align:center;color:var(--text-light);padding:24px">' +
      'No activities found.</td></tr>';

  HTML := HTML + '</tbody></table>';
  Result := HTML;
end;

// ── Action handler ────────────────────────────────────────────────────────

procedure TPageCatalogue.DoAddActivity;
var Name, Cat, Prog, Desc: String;
    MaxSub: Float;
begin
  Name := FNameEl.Handle.value;
  Cat  := FCatEl.Handle.value;
  Prog := FProgNewEl.Handle.value;
  Desc := FDescEl.Handle.value;
  asm @MaxSub = parseFloat((@FSubsidyEl).Handle.value) || 0; end;
  if (Name = '') or (Cat = '') or (Prog = '') then exit;
  CatalogueAddActivity(Name, Cat, Prog, MaxSub, Desc);
  HideNewCard;
  RefreshTable;
end;

end.
