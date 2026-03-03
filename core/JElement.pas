unit JElement;

// ═══════════════════════════════════════════════════════════════════════════
//
//  TElement
//
//  The ancestor of every visual component. Wraps a single HTML element.
//  Sets only box-sizing:border-box — no layout opinion imposed.
//  Components that need flex-column set it via AddClass('ss-base').
//
//  Key design decisions:
//
//    - Single DOM field: FHandle (variant). No typed JHTMLElement.
//      Every DOM method works through variant dispatch.
//
//    - Click listener is lazy: only attached when OnClick is assigned.
//      No listener overhead for non-interactive elements.
//
//    - Click does NOT call stopPropagation. Events bubble normally.
//      Components that need to stop bubbling do so explicitly.
//
//    - Destroy frees all children before removing itself from the DOM.
//      No orphaned Pascal objects.
//
//    - Ready uses requestAnimationFrame. The callback fires once after
//      layout is computed. offsetWidth/offsetHeight are reliable.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses Types;

type

  TNotifyEvent = procedure(Sender: TObject);

  TElement = class
  private
    FHandle:        variant;
    FParent:        TElement;
    FChildren:      array of TElement;
    FClickAttached: Boolean;
    FReadyAttached: Boolean;

    FOnClick: TNotifyEvent;
    FOnReady: TNotifyEvent;

    procedure SetOnClick(Value: TNotifyEvent);
    procedure SetOnReady(Value: TNotifyEvent);

  protected
    procedure ElementReady; virtual;

  public
    constructor Create(TagName: String; Parent: TElement);
    destructor  Destroy; override;

    // ── DOM access ───────────────────────────────────────────────────
    function  Handle: variant;
    function  Parent: TElement;

    // ── Inline style ─────────────────────────────────────────────────
    procedure SetStyle(const Prop, Value: String);
    function  GetStyle(const Prop: String): String;

    // ── Stylesheet rules (by element ID) ─────────────────────────────
    procedure SetRule(const Prop, Value: String);
    procedure SetRulePseudo(const Pseudo, Prop, Value: String);
    procedure SetRuleMedia(const Query, Prop, Value: String);

    // ── CSS class management ─────────────────────────────────────────
    procedure AddClass(const Name: String);
    procedure RemoveClass(const Name: String);
    procedure ToggleClass(const Name: String);
    function  HasClass(const Name: String): Boolean;

    // ── Attributes ───────────────────────────────────────────────────
    procedure SetAttribute(const Name, Value: String);
    function  GetAttribute(const Name: String): String;
    procedure RemoveAttribute(const Name: String);

    // ── Content ──────────────────────────────────────────────────────
    procedure SetHTML(const Value: String);
    //function  GetHTML: String;
    procedure SetText(const Value: String);
    function  GetText: String;

    // ── Sizing ───────────────────────────────────────────────────────
    procedure SetWidth(Value: Integer);
    function  GetWidth: Integer;
    procedure SetHeight(Value: Integer);
    function  GetHeight: Integer;
    procedure SetGrow(Value: Integer);
    property  Width:  Integer read GetWidth  write SetWidth;
    property  Height: Integer read GetHeight write SetHeight;

    // ── Visibility & state ───────────────────────────────────────────
    function  GetVisible: Boolean;
    procedure SetVisible(Value: Boolean);
    function  GetEnabled: Boolean;
    procedure SetEnabled(Value: Boolean);
    property  Visible: Boolean read GetVisible write SetVisible;
    property  Enabled: Boolean read GetEnabled write SetEnabled;

    // ── Children ─────────────────────────────────────────────────────
    procedure Clear;
    //function  ChildCount: Integer;

    // ── Events ───────────────────────────────────────────────────────
    property  OnClick: TNotifyEvent read FOnClick write SetOnClick;
    property  OnReady: TNotifyEvent read FOnReady write SetOnReady;
    procedure CBClick(EventObj: JEvent); virtual;

    // ── Identity ─────────────────────────────────────────────────────
    Tag:  String;
    Name: String;
  end;


implementation

uses Globals;


constructor TElement.Create(TagName: String; Parent: TElement);
begin
  inherited Create;

  FHandle := document.createElement(TagName);
  FHandle.id := TW3Identifiers.GenerateUniqueObjectId;

  FClickAttached := false;
  FReadyAttached := false;
  FParent        := Parent;

  if Parent = nil then
    document.body.appendChild(FHandle)
  else
  begin
    Parent.FHandle.appendChild(FHandle);
    Parent.FChildren.Add(Self);
  end;
end;


destructor TElement.Destroy;
begin
  while FChildren.Count > 0 do
    FChildren[FChildren.Count - 1].Free;

  if assigned(FParent) then
  begin
    for var i := FParent.FChildren.Count - 1 downto 0 do
      if FParent.FChildren[i] = Self then
      begin
        FParent.FChildren.Delete(i);
        break;
      end;
  end;

  if FHandle.parentNode then
    FHandle.parentNode.removeChild(FHandle);

  inherited;
end;


procedure TElement.ElementReady;
begin
  if assigned(FOnReady) then
    FOnReady(Self);
end;

procedure TElement.SetOnReady(Value: TNotifyEvent);
begin
  FOnReady := Value;
  if (not FReadyAttached) and assigned(Value) then
  begin
    FReadyAttached := true;
    window.requestAnimationFrame(@ElementReady);
  end;
end;


function TElement.Handle: variant;
begin
  Result := FHandle;
end;

function TElement.Parent: TElement;
begin
  Result := FParent;
end;


procedure TElement.SetStyle(const Prop, Value: String);
begin
  FHandle.style.setProperty(Prop, Value);
end;

function TElement.GetStyle(const Prop: String): String;
begin
  Result := FHandle.style.getPropertyValue(Prop);
end;


procedure TElement.SetRule(const Prop, Value: String);
begin
  var sel := '#' + FHandle.id;
  styleSheet.insertRule(
    sel + ' { ' + Prop + ': ' + Value + ' }',
    styleSheet.cssRules.length);
end;

procedure TElement.SetRulePseudo(const Pseudo, Prop, Value: String);
begin
  var sel := '#' + FHandle.id + ':' + Pseudo;
  styleSheet.insertRule(
    sel + ' { ' + Prop + ': ' + Value + ' }',
    styleSheet.cssRules.length);
end;

procedure TElement.SetRuleMedia(const Query, Prop, Value: String);
begin
  var sel := '#' + FHandle.id;
  styleSheet.insertRule(
    '@media (' + Query + ') { ' + sel + ' { ' + Prop + ': ' + Value + ' } }',
    styleSheet.cssRules.length);
end;

procedure TElement.AddClass(const Name: String);
begin
  FHandle.classList.add(Name);
end;

procedure TElement.RemoveClass(const Name: String);
begin
  FHandle.classList.remove(Name);
end;

procedure TElement.ToggleClass(const Name: String);
begin
  FHandle.classList.toggle(Name);
end;

function TElement.HasClass(const Name: String): Boolean;
begin
  Result := FHandle.classList.contains(Name);
end;


procedure TElement.SetAttribute(const Name, Value: String);
begin
  FHandle.setAttribute(Name, Value);
end;

function TElement.GetAttribute(const Name: String): String;
var
  v: variant;
begin
  v := FHandle.getAttribute(Name);
  if v then Result := v else Result := '';
end;

procedure TElement.RemoveAttribute(const Name: String);
begin
  FHandle.removeAttribute(Name);
end;


procedure TElement.SetHTML(const Value: String);
begin
  FHandle.innerHTML := Value;
end;

//function TElement.GetHTML: String;
//begin
//  Result := FHandle.innerHTML;
//end;

procedure TElement.SetText(const Value: String);
begin
  FHandle.textContent := Value;
end;

function TElement.GetText: String;
begin
  Result := FHandle.textContent;
end;


procedure TElement.SetWidth(Value: Integer);
begin
  SetStyle('width', IntToStr(Value) + 'px');
end;

function TElement.GetWidth: Integer;
begin
  Result := FHandle.offsetWidth;
end;

procedure TElement.SetHeight(Value: Integer);
begin
  SetStyle('height', IntToStr(Value) + 'px');
end;

function TElement.GetHeight: Integer;
begin
  Result := FHandle.offsetHeight;
end;

procedure TElement.SetGrow(Value: Integer);
begin
  SetStyle('flex-grow', IntToStr(Value));
end;


function TElement.GetVisible: Boolean;
begin
  Result := GetStyle('display') <> 'none';
end;

procedure TElement.SetVisible(Value: Boolean);
begin
  if Value then
    SetStyle('display', '')
  else
    SetStyle('display', 'none');
end;

function TElement.GetEnabled: Boolean;
begin
  Result := not FHandle.hasAttribute('disabled');
end;

procedure TElement.SetEnabled(Value: Boolean);
begin
  if Value then
  begin
    RemoveAttribute('disabled');
    SetStyle('opacity', '');
    SetStyle('pointer-events', '');
  end
  else
  begin
    SetAttribute('disabled', '');
    SetStyle('opacity', '0.5');
    SetStyle('pointer-events', 'none');
  end;
end;


procedure TElement.Clear;
begin
  while FChildren.Count > 0 do
    FChildren[FChildren.Count - 1].Free;
end;

//function TElement.ChildCount: Integer;
//begin
//  Result := FChildren.Count;
//end;


procedure TElement.SetOnClick(Value: TNotifyEvent);
begin
  FOnClick := Value;

  if (not FClickAttached) and assigned(Value) then
  begin
    FClickAttached := true;
    FHandle.addEventListener('click', @CBClick, false);
  end;
end;

procedure TElement.CBClick(EventObj: JEvent);
begin
  if assigned(FOnClick) then
    FOnClick(Self);
end;

end.
