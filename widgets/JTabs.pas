unit JTabs;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Tab Control
//
//  A tabbed container with a clickable tab strip and switchable content
//  panels. One tab is active at a time. Content panels are shown/hidden
//  by toggling Visible — component state inside each panel survives
//  tab switches (same principle as GoToForm).
//
//  Structure:
//
//    JW3TabControl               .tabs
//      ├── tab strip             .tabs-strip       (flex row of buttons)
//      │     ├── tab button      .tabs-btn          (.tabs-btn-active)
//      │     ├── tab button      .tabs-btn
//      │     └── tab button      .tabs-btn
//      └── content area          .tabs-content      (flex column, grows)
//            ├── tab panel       .tabs-panel         (visible when active)
//            ├── tab panel       .tabs-panel
//            └── tab panel       .tabs-panel
//
//  Usage:
//
//    Tabs := JW3TabControl.Create(Self);
//
//    var Page1 := Tabs.AddTab('General');
//    // Page1 is a TElement — add children to it
//    var Label1 := JW3Panel.Create(Page1);
//    Label1.SetText('General settings go here');
//
//    var Page2 := Tabs.AddTab('Advanced');
//    var Label2 := JW3Panel.Create(Page2);
//    Label2.SetText('Advanced settings go here');
//
//    // Switch programmatically
//    Tabs.ActiveIndex := 1;
//
//  CSS variables (override on ancestor or :root):
//
//    --tabs-strip-bg          Strip background        default: transparent
//    --tabs-strip-border      Strip bottom border     default: 1px solid var(--border-color, #e2e8f0)
//    --tabs-strip-gap         Gap between buttons     default: 0
//    --tabs-strip-padding     Strip padding           default: 0 var(--space-4, 16px)
//
//    --tabs-btn-padding       Button padding          default: var(--space-3, 12px) var(--space-4, 16px)
//    --tabs-btn-color         Inactive text colour    default: var(--text-light, #64748b)
//    --tabs-btn-font-size     Button font size        default: var(--font-size-sm, 0.875rem)
//    --tabs-btn-hover-color   Hover text colour       default: var(--text-color, #334155)
//    --tabs-btn-hover-bg      Hover background        default: var(--hover-color, #f1f5f9)
//
//    --tabs-active-color      Active text colour      default: var(--primary-color, #6366f1)
//    --tabs-active-border     Active indicator        default: 2px solid var(--primary-color, #6366f1)
//
//    --tabs-content-padding   Content area padding    default: var(--space-4, 16px)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csTabs         = 'tabs';
  csTabsStrip    = 'tabs-strip';
  csTabsBtn      = 'tabs-btn';
  csTabsBtnActive = 'tabs-btn-active';
  csTabsContent  = 'tabs-content';
  csTabsPanel    = 'tabs-panel';

type

  TTabChangedEvent = procedure(Sender: TObject; Index: Integer);

  JW3TabControl = class(TElement)
  private
    FStrip:       TElement;
    FContent:     TElement;
    FButtons:     array of TElement;
    FPanels:      array of TElement;
    FActiveIndex: Integer;
    FOnTabChanged: TTabChangedEvent;

    procedure SetActiveIndex(Value: Integer);
    procedure HandleTabClick(Sender: TObject);

  public
    constructor Create(Parent: TElement); virtual;

    function  AddTab(const Caption: String): TElement;
    procedure RemoveTab(Index: Integer);
    function  TabCount: Integer;
    function  Panel(Index: Integer): TElement;

    property  ActiveIndex: Integer read FActiveIndex write SetActiveIndex;
    property  OnTabChanged: TTabChangedEvent read FOnTabChanged write FOnTabChanged;
  end;

procedure RegisterTabStyles;

implementation

uses Globals;


//=============================================================================
// Styles
//=============================================================================

var FStylesRegistered: Boolean := false;

procedure RegisterTabStyles;
begin
  if FStylesRegistered then exit;
  FStylesRegistered := true;

  AddStyleBlock(#'

    /* ── Container ────────────────────────────────────────────────── */

    .tabs {
      min-height: 0;
    }

    /* ── Strip: horizontal row of tab buttons ─────────────────────── */

    .tabs-strip {
      display: flex;
      flex-direction: row;
      flex-shrink: 0;
      flex-wrap: nowrap;
      overflow-x: auto;
      gap: var(--tabs-strip-gap, 0);
      padding: var(--tabs-strip-padding, 0 16px);
      background: var(--tabs-strip-bg, transparent);
      border-bottom: var(--tabs-strip-border, 1px solid var(--border-color, #e2e8f0));
      user-select: none;
      -webkit-overflow-scrolling: touch;
    }

    /* Hide scrollbar on strip but keep functionality */
    .tabs-strip::-webkit-scrollbar { display: none; }
    .tabs-strip { scrollbar-width: none; }

    /* ── Mobile: stack tabs vertically ───────────────────────────── */

    @media (max-width: 600px) {
      .tabs-strip {
        flex-direction: column;
        overflow-x: visible;
        overflow-y: auto;
        border-bottom: none;
        border-right: var(--tabs-strip-border, 1px solid var(--border-color, #e2e8f0));
        padding: 8px 0;
      }

      .tabs-btn {
        justify-content: flex-start;
        border-bottom: none;
        border-left: 2px solid transparent;
        margin-bottom: 0;
        margin-right: -1px;
      }

      .tabs-btn-active {
        border-bottom: none;
        border-left: var(--tabs-active-border, 2px solid var(--primary-color, #6366f1));
      }
    }

    /* ── Tab button ───────────────────────────────────────────────── */

    .tabs-btn {
      flex-shrink: 0;
      align-items: center;
      justify-content: center;
      padding: var(--tabs-btn-padding, 12px 16px);
      font-size: var(--tabs-btn-font-size, var(--font-size-sm, 0.875rem));
      font-weight: 500;
      color: var(--tabs-btn-color, var(--text-light, #64748b));
      cursor: pointer;
      white-space: nowrap;
      border-bottom: 2px solid transparent;
      margin-bottom: -1px;
      transition: color 0.15s, background-color 0.15s, border-color 0.15s;
    }

    .tabs-btn:hover {
      color: var(--tabs-btn-hover-color, var(--text-color, #334155));
      background: var(--tabs-btn-hover-bg, var(--hover-color, #f1f5f9));
    }

    /* ── Active tab button ────────────────────────────────────────── */

    .tabs-btn-active {
      color: var(--tabs-active-color, var(--primary-color, #6366f1));
      border-bottom: var(--tabs-active-border, 2px solid var(--primary-color, #6366f1));
    }

    .tabs-btn-active:hover {
      color: var(--tabs-active-color, var(--primary-color, #6366f1));
      background: transparent;
    }

    /* ── Content area ─────────────────────────────────────────────── */

    .tabs-content {
      flex-grow: 1;
      min-height: 0;
      overflow: hidden;
    }

    /* ── Individual panel ─────────────────────────────────────────── */

    .tabs-panel {
      flex-grow: 1;
      padding: var(--tabs-content-padding, 16px);
      overflow-y: auto;
    }
  ');
end;


//=============================================================================
// JW3TabControl
//=============================================================================

constructor JW3TabControl.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csTabs);
  SetGrow(1);

  FActiveIndex := -1;

  // Tab strip — horizontal row of buttons
  FStrip := TElement.Create('div', Self);
  FStrip.AddClass(csTabsStrip);

  // Content area — panels stack here, only one visible at a time
  FContent := TElement.Create('div', Self);
  FContent.AddClass(csTabsContent);
end;


//=============================================================================
// AddTab — creates a button + panel pair, returns the panel
//=============================================================================

function JW3TabControl.AddTab(const Caption: String): TElement;
var
  Btn, Pnl: TElement;
  Index: Integer;
begin
  Index := FButtons.Count;

  // Button in the strip
  Btn := TElement.Create('div', FStrip);
  Btn.AddClass(csTabsBtn);
  Btn.SetText(Caption);
  Btn.Tag := IntToStr(Index);
  Btn.OnClick := HandleTabClick;
  FButtons.Add(Btn);

  // Panel in the content area
  Pnl := TElement.Create('div', FContent);
  Pnl.AddClass(csTabsPanel);
  Pnl.Visible := false;
  FPanels.Add(Pnl);

  // First tab added becomes active
  if FActiveIndex < 0 then
    SetActiveIndex(0);

  Result := Pnl;
end;


//=============================================================================
// RemoveTab
//=============================================================================

procedure JW3TabControl.RemoveTab(Index: Integer);
var
  prevActive: Integer;
begin
  if (Index < 0) or (Index >= FButtons.Count) then exit;

  // Deactivate current active before modifying arrays
  prevActive := FActiveIndex;
  if (prevActive >= 0) and (prevActive < FButtons.Count) then
  begin
    FButtons[prevActive].RemoveClass(csTabsBtnActive);
    FPanels[prevActive].Visible := false;
  end;
  FActiveIndex := -1;

  FButtons[Index].Free;
  FPanels[Index].Free;
  FButtons.Delete(Index);
  FPanels.Delete(Index);

  // Re-index the tag values on remaining buttons
  for var i := 0 to FButtons.Count - 1 do
    FButtons[i].Tag := IntToStr(i);

  // Activate the correct tab in the updated arrays
  if FButtons.Count = 0 then
    FActiveIndex := -1
  else if Index > prevActive then
    SetActiveIndex(prevActive)                      // removed tab was after active — no shift
  else if Index < prevActive then
    SetActiveIndex(prevActive - 1)                  // removed tab was before active — shift down
  else
    SetActiveIndex(Min(Index, FButtons.Count - 1)); // removed tab was the active one
end;


//=============================================================================
// ActiveIndex
//=============================================================================

procedure JW3TabControl.SetActiveIndex(Value: Integer);
begin
  if (Value < 0) or (Value >= FButtons.Count) then exit;

  // Deactivate previous
  if (FActiveIndex >= 0) and (FActiveIndex < FButtons.Count) then
  begin
    FButtons[FActiveIndex].RemoveClass(csTabsBtnActive);
    FPanels[FActiveIndex].Visible := false;
  end;

  // Activate new
  FActiveIndex := Value;
  FButtons[FActiveIndex].AddClass(csTabsBtnActive);
  FPanels[FActiveIndex].Visible := true;

  // Notify
  if assigned(FOnTabChanged) then
    FOnTabChanged(Self, FActiveIndex);
end;

procedure JW3TabControl.HandleTabClick(Sender: TObject);
begin
  var Index := StrToInt(TElement(Sender).Tag);
  SetActiveIndex(Index);
end;


//=============================================================================
// Helpers
//=============================================================================

function JW3TabControl.TabCount: Integer;
begin
  Result := FButtons.Count;
end;

function JW3TabControl.Panel(Index: Integer): TElement;
begin
  if (Index >= 0) and (Index < FPanels.Count)
    then Result := FPanels[Index]
    else Result := nil;
end;


//=============================================================================
// Registration
//=============================================================================

initialization
  RegisterTabStyles;
end.