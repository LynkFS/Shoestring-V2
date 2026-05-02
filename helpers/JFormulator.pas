unit JFormulator;

// ─────────────────────────────────────────────────────────────────────────
//
//  TFormulator — render a JSON / variant config tree into a working form.
//
//  Public API:
//    class function TFormulator.Build(Parent, Config: variant,
//                                     OnSubmit): TElement;
//    class function TFormulator.BuildFromJSON(Parent, Json: String,
//                                             OnSubmit): TElement;
//
//  Config shape:
//    {
//      title:    'Contact us',
//      subtitle: 'Optional one-liner under the title',
//      submit:   { label: 'Send', variant: 'primary' },
//      fields: [
//        { name, type, label?, placeholder?, default?, rows?,
//          required?, requiredMessage?, options? },
//        { row: [ <field>, <field> ] },
//        { name: 'msg', type: 'textarea',
//          defaultFrom: { switch: 'topic',
//                         cases: { q: '...', bug: '...' } } }
//      ]
//    }
//
//  Field types:  text | email | password | number | textarea | select
//  Layout:       a top-level array element shaped { row: [...] } lays
//                its sub-fields out in a 2-column grid. One layout
//                primitive — that's deliberate.
//  Validation:   `required: true` + optional `requiredMessage`. Errors
//                surface inline under each offending field on submit.
//                Submit is blocked while any error remains.
//  Dynamic defaults:  `defaultFrom: { switch, cases }`. The source
//                field's value picks a case; the case's text is written
//                into the target field UNLESS the user has already
//                typed/changed the target (per-DOM-node dirty bit).
//
//  Reuses framework theme classes (csFieldGroup, csFieldLabel,
//  csFieldError, csBtnPrimary, etc.). Adds three of its own:
//  .fml-form, .fml-title, .fml-subtitle, .fml-row.
//
// ─────────────────────────────────────────────────────────────────────────

interface

uses JElement;

type
  TFormulatorSubmit = procedure(Values: variant);

  TFormulator = class
  public
    class function Build(Parent: TElement; Config: variant;
                         OnSubmit: TFormulatorSubmit): TElement;
    class function BuildFromJSON(Parent: TElement; const Json: String;
                                 OnSubmit: TFormulatorSubmit): TElement;
  end;

implementation

uses Globals, JInput, JTextArea, JSelect, JButton, ThemeStyles;

// Single type block, before any function bodies (DWScript constraint).
type
  TFmlField = record
    Name:        String;
    InputEl:     variant;    // DOM <input>/<textarea>/<select>
    ErrorEl:     TElement;   // .field-error span beneath the input
    Required:    Boolean;
    RequiredMsg: String;
  end;

  TFmlFields = array of TFmlField;

// ── Styles ────────────────────────────────────────────────────────────

var GFmlStyled: Boolean = false;

procedure RegisterFmlStyles;
begin
  if GFmlStyled then exit;
  GFmlStyled := true;
  AddStyleBlock(#'
    .fml-form {
      display: flex;
      flex-direction: column;
      gap: var(--space-3, 12px);
      width: 100%;
      max-width: 640px;
    }
    .fml-title {
      font-size: var(--text-lg, 18px);
      font-weight: 700;
      color: var(--text-color, #1e293b);
      margin: 0;
    }
    .fml-subtitle {
      font-size: var(--text-sm, 14px);
      color: var(--text-light, #64748b);
      margin: 0 0 var(--space-1, 4px) 0;
    }
    .fml-row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: var(--space-3, 12px);
    }
  ');
end;

// ── One field (label + control + error slot) ─────────────────────────

function BuildOneField(Parent: TElement; FieldDef: variant): TFmlField;
var
  Group:       TElement;
  LabelEl:     TElement;
  ErrEl:       TElement;
  Kind:        String;
  FldName:     String;
  LabelText:   String;
  Placeholder: String;
  DefaultVal:  String;
  RowsCount:   Integer;
  IsRequired:  Boolean;
  RequiredMsg: String;
  Handle_:     variant;
begin
  asm
    @Kind        = (@FieldDef).type        || 'text';
    @FldName     = (@FieldDef).name        || '';
    @LabelText   = (@FieldDef).label       || '';
    @Placeholder = (@FieldDef).placeholder || '';
    @DefaultVal  = ((@FieldDef)['default'] !== undefined &&
                    (@FieldDef)['default'] !== null)
                   ? String((@FieldDef)['default']) : '';
    @RowsCount   = (@FieldDef).rows                  || 0;
    @IsRequired  = (@FieldDef).required              === true;
    @RequiredMsg = (@FieldDef).requiredMessage       || 'Required';
  end;

  Group := TElement.Create('div', Parent);
  Group.AddClass(csFieldGroup);

  if LabelText <> '' then
  begin
    LabelEl := TElement.Create('span', Group);
    LabelEl.AddClass(csFieldLabel);
    LabelEl.SetText(LabelText);
  end;

  if Kind = 'textarea' then
  begin
    var TA := JW3TextArea.Create(Group);
    if Placeholder <> '' then TA.Placeholder := Placeholder;
    if RowsCount > 0    then TA.Rows := RowsCount;
    if DefaultVal <> '' then TA.Value := DefaultVal;
    Handle_ := TA.Handle;
  end
  else if Kind = 'select' then
  begin
    var Sel := JW3Select.Create(Group);
    var Opts: variant;
    var OptCount: Integer;
    asm
      @Opts     = (@FieldDef).options || [];
      @OptCount = (@Opts).length      || 0;
    end;
    for var i := 0 to OptCount - 1 do
    begin
      var V_, T_: String;
      asm
        @V_ = (@Opts[@i]).value || '';
        @T_ = (@Opts[@i]).label || (@Opts[@i]).value || '';
      end;
      Sel.AddOption(V_, T_);
    end;
    if DefaultVal <> '' then Sel.Value := DefaultVal;
    Handle_ := Sel.Handle;
  end
  else
  begin
    // text, email, password, number, …
    var Inp := JW3Input.Create(Group);
    if (Kind <> 'text') and (Kind <> '') then Inp.InputType := Kind;
    if Placeholder <> '' then Inp.Placeholder := Placeholder;
    if DefaultVal <> '' then Inp.Value := DefaultVal;
    Handle_ := Inp.Handle;
  end;

  ErrEl := TElement.Create('span', Group);
  ErrEl.AddClass(csFieldError);
  ErrEl.SetText(' ');

  // Per-DOM-node dirty bit. defaultFrom only writes when not dirty.
  asm
    (@Handle_)._fmlDirty = false;
    (@Handle_).addEventListener('input',  function(){ (@Handle_)._fmlDirty = true; });
    (@Handle_).addEventListener('change', function(){ (@Handle_)._fmlDirty = true; });
  end;

  Result.Name        := FldName;
  Result.InputEl     := Handle_;
  Result.ErrorEl     := ErrEl;
  Result.Required    := IsRequired;
  Result.RequiredMsg := RequiredMsg;
end;

function FindRef(const Refs: TFmlFields; const Name: String): Integer;
begin
  for var i := 0 to Refs.Count - 1 do
    if Refs[i].Name = Name then exit(i);
  Result := -1;
end;

procedure WireDefaultFrom(FieldDef: variant; const Refs: TFmlFields;
                          TargetIdx: Integer);
var
  HasDFrom: Boolean;
  SwitchOn: String;
  SrcIdx:   Integer;
  SrcEl, TgtEl, Cases: variant;
begin
  asm
    @HasDFrom = !!(@FieldDef).defaultFrom;
    @SwitchOn = ((@FieldDef).defaultFrom &&
                 (@FieldDef).defaultFrom.switch) || '';
  end;
  if (not HasDFrom) or (SwitchOn = '') then exit;

  SrcIdx := FindRef(Refs, SwitchOn);
  if SrcIdx < 0 then exit;

  SrcEl := Refs[SrcIdx].InputEl;
  TgtEl := Refs[TargetIdx].InputEl;
  asm @Cases = (@FieldDef).defaultFrom.cases || {}; end;

  // Initial population — only if user hasn't touched the target yet.
  asm
    var v0 = (@SrcEl).value;
    if ((v0 in @Cases) && !(@TgtEl)._fmlDirty)
      (@TgtEl).value = (@Cases)[v0];
  end;

  // Source change rewrites target unless target is dirty.
  asm
    (@SrcEl).addEventListener('change', function(){
      if ((@TgtEl)._fmlDirty) return;
      var v = (@SrcEl).value;
      if (v in @Cases) (@TgtEl).value = (@Cases)[v];
    });
  end;
end;

function CollectValues(const Refs: TFmlFields): variant;
var V: variant;
begin
  asm @V = {}; end;
  for var i := 0 to Refs.Count - 1 do
  begin
    var N := Refs[i].Name;
    var H := Refs[i].InputEl;
    asm @V[@N] = (@H).value; end;
  end;
  Result := V;
end;

function Validate(const Refs: TFmlFields): Boolean;
begin
  Result := true;
  for var i := 0 to Refs.Count - 1 do
  begin
    Refs[i].ErrorEl.SetText(' ');
    if Refs[i].Required then
    begin
      var Val_: String;
      var H := Refs[i].InputEl;
      asm @Val_ = (@H).value || ''; end;
      if Trim(Val_) = '' then
      begin
        Refs[i].ErrorEl.SetText(Refs[i].RequiredMsg);
        Result := false;
      end;
    end;
  end;
end;

// ── Public API ───────────────────────────────────────────────────────

class function TFormulator.Build(Parent: TElement; Config: variant;
                                 OnSubmit: TFormulatorSubmit): TElement;
var
  FormEl:        TElement;
  Title:         String;
  Subtitle:      String;
  SubmitLabel:   String;
  SubmitVariant: String;
  HasTitle:      Boolean;
  HasSubtitle:   Boolean;
  Fields_:       variant;
  FCount:        Integer;
  Refs:          TFmlFields;
  SubmitBtn:     JW3Button;
begin
  RegisterFmlStyles;

  asm
    @Title         = (@Config).title    || '';
    @HasTitle      = !!(@Config).title;
    @Subtitle      = (@Config).subtitle || '';
    @HasSubtitle   = !!(@Config).subtitle;
    @Fields_       = (@Config).fields   || [];
    @FCount        = (@Fields_).length  || 0;
    @SubmitLabel   = ((@Config).submit && (@Config).submit.label)   || 'Submit';
    @SubmitVariant = ((@Config).submit && (@Config).submit.variant) || 'primary';
  end;

  FormEl := TElement.Create('div', Parent);
  FormEl.AddClass('fml-form');

  if HasTitle then
  begin
    var H := TElement.Create('div', FormEl);
    H.AddClass('fml-title');
    H.SetText(Title);
  end;
  if HasSubtitle then
  begin
    var S := TElement.Create('div', FormEl);
    S.AddClass('fml-subtitle');
    S.SetText(Subtitle);
  end;

  // Pass 1: build every field DOM node, collect refs.
  for var i := 0 to FCount - 1 do
  begin
    var Item:  variant;
    var IsRow: Boolean;
    asm
      @Item  = @Fields_[@i];
      @IsRow = !!(@Item).row && Array.isArray((@Item).row);
    end;
    if IsRow then
    begin
      var RowEl := TElement.Create('div', FormEl);
      RowEl.AddClass('fml-row');
      var RowItems: variant;
      var RC: Integer;
      asm
        @RowItems = (@Item).row;
        @RC       = (@RowItems).length || 0;
      end;
      for var j := 0 to RC - 1 do
      begin
        var Sub: variant;
        asm @Sub = @RowItems[@j]; end;
        Refs.Add(BuildOneField(RowEl, Sub));
      end;
    end
    else
      Refs.Add(BuildOneField(FormEl, Item));
  end;

  // Pass 2: wire defaultFrom now that every field exists.
  for var i := 0 to FCount - 1 do
  begin
    var Item:  variant;
    var IsRow: Boolean;
    asm
      @Item  = @Fields_[@i];
      @IsRow = !!(@Item).row && Array.isArray((@Item).row);
    end;
    if IsRow then
    begin
      var RowItems: variant;
      var RC: Integer;
      asm
        @RowItems = (@Item).row;
        @RC       = (@RowItems).length || 0;
      end;
      for var j := 0 to RC - 1 do
      begin
        var Sub:     variant;
        var SubName: String;
        asm
          @Sub     = @RowItems[@j];
          @SubName = (@Sub).name || '';
        end;
        var Idx := FindRef(Refs, SubName);
        if Idx >= 0 then WireDefaultFrom(Sub, Refs, Idx);
      end;
    end
    else
    begin
      var ItemName: String;
      asm @ItemName = (@Item).name || ''; end;
      var Idx := FindRef(Refs, ItemName);
      if Idx >= 0 then WireDefaultFrom(Item, Refs, Idx);
    end;
  end;

  // Submit button
  SubmitBtn := JW3Button.Create(FormEl);
  SubmitBtn.Caption := SubmitLabel;
  if      SubmitVariant = 'secondary' then SubmitBtn.AddClass(csBtnSecondary)
  else if SubmitVariant = 'danger'    then SubmitBtn.AddClass(csBtnDanger)
  else if SubmitVariant = 'ghost'     then SubmitBtn.AddClass(csBtnGhost)
  else                                     SubmitBtn.AddClass(csBtnPrimary);

  SubmitBtn.OnClick := procedure(Sender: TObject)
  begin
    if not Validate(Refs) then exit;
    if assigned(OnSubmit) then
      OnSubmit(CollectValues(Refs));
  end;

  Result := FormEl;
end;

class function TFormulator.BuildFromJSON(Parent: TElement; const Json: String;
                                         OnSubmit: TFormulatorSubmit): TElement;
var Cfg: variant;
begin
  asm @Cfg = JSON.parse(@Json); end;
  Result := Build(Parent, Cfg, OnSubmit);
end;

end.
