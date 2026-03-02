unit JToolbar;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Toolbar
//
//  A horizontal bar with clickable items, spacers, and separators.
//  Items wrap responsively via flex-wrap. The toolbar opts into
//  container queries so children can adapt to the toolbar's width.
//
//  Usage:
//
//    Toolbar := JW3Toolbar.Create(Nav);
//    var BtnFile := Toolbar.AddItem('File');
//    BtnFile.OnClick := HandleFile;
//    Toolbar.AddSeparator;
//    Toolbar.AddSpacer;
//    Toolbar.AddItem('Help');
//
//  CSS variables:
//
//    --tb-height          Toolbar min height     default: 40px
//    --tb-bg              Background             default: var(--surface-color)
//    --tb-border          Bottom border          default: 1px solid var(--border-color)
//    --tb-padding         Padding                default: 4px 8px
//    --tb-gap             Gap between items      default: 4px
//    --tb-item-padding    Item padding           default: 6px 12px
//    --tb-item-radius     Item border radius     default: var(--radius-sm)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csToolbar     = 'toolbar';
  csToolbarItem = 'toolbar-item';
  csToolbarSep  = 'toolbar-sep';
  csToolbarSpc  = 'toolbar-spc';

type
  TToolbarItem = class(TElement)
  public
    constructor Create(Parent: TElement); virtual;
  end;

  TToolbarSpacer = class(TElement)
  public
    constructor Create(Parent: TElement); virtual;
  end;

  TToolbarSeparator = class(TElement)
  public
    constructor Create(Parent: TElement); virtual;
  end;

  JW3Toolbar = class(TElement)
  public
    constructor Create(Parent: TElement); virtual;
    function AddItem(const Caption: String): TToolbarItem;
    function AddSpacer: TToolbarSpacer;
    function AddSeparator: TToolbarSeparator;
  end;

procedure RegisterToolbarStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterToolbarStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    .toolbar {
      display: flex;
      flex-direction: row;
      align-items: center;
      flex-wrap: wrap;
      gap: var(--tb-gap, 4px);
      padding: var(--tb-padding, 4px 8px);
      min-height: var(--tb-height, 40px);
      background: var(--tb-bg, var(--surface-color, #ffffff));
      border-bottom: var(--tb-border, 1px solid var(--border-color, #e2e8f0));
      user-select: none;
      container-type: inline-size;
    }

    .toolbar-item {
      flex-direction: row;
      align-items: center;
      justify-content: center;
      gap: 6px;
      flex-shrink: 0;
      padding: var(--tb-item-padding, 6px 12px);
      min-height: 32px;
      border-radius: var(--tb-item-radius, var(--radius-sm, 4px));
      cursor: pointer;
      white-space: nowrap;
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-color, #334155);
      transition: background-color var(--anim-duration, 0.2s);
    }

    .toolbar-item:hover {
      background: var(--hover-color, #f1f5f9);
    }

    .toolbar-item:active {
      background: var(--border-color, #e2e8f0);
    }

    .toolbar-spc {
      flex-grow: 1;
    }

    .toolbar-sep {
      width: 1px;
      height: 20px;
      background: var(--border-color, #e2e8f0);
      flex-shrink: 0;
      margin: 0 4px;
    }
  ');
end;


{ JW3Toolbar }

constructor JW3Toolbar.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csToolbar);
end;

function JW3Toolbar.AddItem(const Caption: String): TToolbarItem;
begin
  Result := TToolbarItem.Create(Self);
  Result.SetText(Caption);
end;

function JW3Toolbar.AddSpacer: TToolbarSpacer;
begin
  Result := TToolbarSpacer.Create(Self);
end;

function JW3Toolbar.AddSeparator: TToolbarSeparator;
begin
  Result := TToolbarSeparator.Create(Self);
end;


{ TToolbarItem }

constructor TToolbarItem.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csToolbarItem);
end;


{ TToolbarSpacer }

constructor TToolbarSpacer.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csToolbarSpc);
end;


{ TToolbarSeparator }

constructor TToolbarSeparator.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csToolbarSep);
end;

initialization
  RegisterToolbarStyles;
end.
