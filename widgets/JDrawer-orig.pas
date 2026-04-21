unit JDrawer;

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
//  Drawer
//
//  A panel that slides in from the left edge of the viewport over a
//  semi-transparent backdrop. Clicking the backdrop or the close button
//  hides the drawer. Useful for navigation menus, filter panels, detail
//  views, and any off-canvas content.
//
//  Usage:
//
//    var Drawer := JW3Drawer.Create(Self);
//    Drawer.Title := 'Navigation';
//
//    var Item := JW3Panel.Create(Drawer.Body);
//    Item.SetText('Dashboard');
//    Item.AddClass('nav-item');
//
//    var BtnClose := JW3Button.Create(Drawer.Footer);
//    BtnClose.Caption := 'Close';
//    BtnClose.OnClick := procedure(Sender: TObject) begin Drawer.Close; end;
//
//    Drawer.Open;
//
//  Structure:
//
//    Backdrop  .drawer-backdrop    (full screen, semi-transparent)
//      â””â”€â”€ Panel   .drawer-panel   (fixed to left edge, slides in)
//            â”œâ”€â”€ Header  .drawer-header  (title + close button)
//            â”œâ”€â”€ Body    .drawer-body    (developer content, scrollable)
//            â””â”€â”€ Footer  .drawer-footer  (developer buttons, optional)
//
//  CSS variables:
//
//    --drawer-width       Panel width               default: 320px
//    --drawer-bg          Panel background          default: var(--surface-color)
//    --drawer-shadow      Panel shadow              default: var(--shadow-xl)
//    --drawer-backdrop    Backdrop colour           default: rgba(0,0,0,0.4)
//    --drawer-padding     Body padding              default: var(--space-6)
//    --drawer-z           Z-index                   default: 1000
//
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

interface

uses JElement, JPanel;

const
  csDrawerBackdrop = 'drawer-backdrop';
  csDrawerPanel    = 'drawer-panel';
  csDrawerHeader   = 'drawer-header';
  csDrawerTitle    = 'drawer-title';
  csDrawerClose    = 'drawer-close';
  csDrawerBody     = 'drawer-body';
  csDrawerFooter   = 'drawer-footer';
  csDrawerOpen     = 'drawer-open';

type
  JW3Drawer = class(TElement)
  private
    FPanel:   JW3Panel;
    FHeader:  JW3Panel;
    FTitleEl: JW3Panel;
    FBody:    JW3Panel;
    FFooter:  JW3Panel;
    FOnClose: TNotifyEvent;

    function  GetTitle: String;
    procedure SetTitle(const V: String);

    procedure HandleClose(Sender: TObject);

  public
    constructor Create(Parent: TElement); virtual;

    procedure Open;
    procedure Close;

    function  IsOpen: Boolean;

    property Title:   String       read GetTitle  write SetTitle;
    property Body:    JW3Panel     read FBody;
    property Footer:  JW3Panel     read FFooter;
    property OnClose: TNotifyEvent read FOnClose  write FOnClose;
  end;

procedure RegisterDrawerStyles;

implementation

uses Globals, Types;

var FRegistered: Boolean := false;

procedure RegisterDrawerStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* â”€â”€ Backdrop: full-screen overlay â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

    .drawer-backdrop {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: var(--drawer-backdrop, rgba(0,0,0,0.4));
      z-index: var(--drawer-z, 1000);
      opacity: 0;
      transition: opacity var(--anim-duration, 0.25s);
      pointer-events: none;
    }

    .drawer-backdrop.drawer-open {
      opacity: 1;
      pointer-events: auto;
    }

    /* â”€â”€ Drawer panel: fixed to the left edge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

    .drawer-panel {
      position: fixed;
      top: 0;
      left: 0;
      height: 100%;
      width: var(--drawer-width, 320px);
      max-width: calc(100vw - 48px);
      display: flex;
      flex-direction: column;
      background: var(--drawer-bg, var(--surface-color, #ffffff));
      box-shadow: var(--drawer-shadow, var(--shadow-xl,
        0 20px 25px -5px rgba(0,0,0,0.1), 0 10px 10px -5px rgba(0,0,0,0.04)));
      overflow: hidden;
      transform: translateX(-100%);
      transition: transform var(--anim-duration, 0.25s)
                  cubic-bezier(0.4, 0, 0.2, 1);
    }

    .drawer-open .drawer-panel {
      transform: translateX(0);
    }

    /* â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

    .drawer-header {
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
      padding: var(--space-4, 16px) var(--space-6, 24px);
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      flex-shrink: 0;
    }

    .drawer-title {
      font-weight: 600;
      font-size: var(--font-size-md, 1rem);
      color: var(--text-color, #334155);
    }

    /* â”€â”€ Close button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

    .drawer-close {
      flex-direction: row;
      align-items: center;
      justify-content: center;
      width: 32px;
      height: 32px;
      border-radius: var(--radius-md, 6px);
      cursor: pointer;
      font-size: 1.2rem;
      color: var(--text-light, #64748b);
      transition: background var(--anim-duration, 0.2s);
      flex-shrink: 0;
    }

    .drawer-close:hover {
      background: var(--hover-color, #f1f5f9);
    }

    /* â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

    .drawer-body {
      padding: var(--drawer-padding, var(--space-6, 24px));
      overflow-y: auto;
      flex-grow: 1;
    }

    /* â”€â”€ Footer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */

    .drawer-footer {
      flex-direction: row;
      justify-content: flex-end;
      gap: var(--space-3, 12px);
      padding: var(--space-4, 16px) var(--space-6, 24px);
      border-top: 1px solid var(--border-color, #e2e8f0);
      flex-shrink: 0;
    }
  ');
end;

{ JW3Drawer }

constructor JW3Drawer.Create(Parent: TElement);
var
  CloseBtn: JW3Panel;
begin
  // Backdrop is the root element
  inherited Create('div', Parent);
  AddClass(csDrawerBackdrop);

  // Close on backdrop click â€” but not on clicks inside the panel
  Handle.addEventListener('click', procedure(e: JEvent) begin
    if e.target = Handle then Close;
  end, false);

  // Drawer panel â€” fixed to the left edge
  FPanel := JW3Panel.Create(Self);
  FPanel.AddClass(csDrawerPanel);

  // Header
  FHeader := JW3Panel.Create(FPanel);
  FHeader.AddClass(csDrawerHeader);

  FTitleEl := JW3Panel.Create(FHeader);
  FTitleEl.AddClass(csDrawerTitle);
  FTitleEl.SetText('Drawer');

  CloseBtn := JW3Panel.Create(FHeader);
  CloseBtn.AddClass(csDrawerClose);
  CloseBtn.SetHTML('&#x2715;');
  CloseBtn.OnClick := HandleClose;

  // Body â€” developer adds content here
  FBody := JW3Panel.Create(FPanel);
  FBody.AddClass(csDrawerBody);

  // Footer â€” developer adds buttons here
  FFooter := JW3Panel.Create(FPanel);
  FFooter.AddClass(csDrawerFooter);
  FFooter.Visible := false;  // hidden until developer adds content
end;

function JW3Drawer.GetTitle: String;
begin
  Result := FTitleEl.GetText;
end;

procedure JW3Drawer.SetTitle(const V: String);
begin
  FTitleEl.SetText(V);
end;

procedure JW3Drawer.Open;
begin
  AddClass(csDrawerOpen);
end;

procedure JW3Drawer.Close;
begin
  RemoveClass(csDrawerOpen);
  if assigned(FOnClose) then
    FOnClose(Self);
end;

function JW3Drawer.IsOpen: Boolean;
begin
  Result := HasClass(csDrawerOpen);
end;

procedure JW3Drawer.HandleClose(Sender: TObject);
begin
  Close;
end;

initialization
  RegisterDrawerStyles;
end.
