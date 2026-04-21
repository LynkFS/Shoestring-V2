unit JDrawer;

// ----------------------------------------------------------------------------
//
//  Drawer
//
//  A panel that slides in from the left edge of the viewport over a
//  semi-transparent backdrop. Clicking the backdrop or the close button
//  hides the drawer.
//
//  Usage:
//
//    var Drawer := JW3Drawer.Create(Self);
//    Drawer.Title    := 'Navigation';
//    Drawer.Duration := 350;   // ms, optional - default 350
//
//    var Item := JW3Panel.Create(Drawer.Body);
//    Item.SetText('Dashboard');
//    Item.AddClass('nav-item');
//
//    Drawer.OnAfterOpen  := HandleDrawerOpened;
//    Drawer.OnAfterClose := HandleDrawerClosed;
//
//    Drawer.Open;    // slide in
//    Drawer.Close;   // slide out
//    Drawer.Toggle;  // flip
//
//  How the animation works
//  -----------------------
//  ALL animation state (transform, opacity, pointer-events, transition) is
//  driven by inline SetStyle() calls, never by CSS class-based transitions.
//  This sidesteps two common pitfalls:
//
//    1. CSS cascade conflicts - other stylesheets cannot shorten the duration.
//    2. "Same-frame skip" - when Open() is called in the same JS execution
//       as Create() the browser has not yet painted the initial off-screen
//       position, so any CSS transition fires with zero duration.
//       We fix this by reading FPanel.GetWidth() before changing the
//       transform, which forces a synchronous style/layout flush.
//
//  CSS variables:
//
//    --drawer-width     Panel width      default 320px
//    --drawer-bg        Background       default var(--surface-color)
//    --drawer-shadow    Shadow           default var(--shadow-xl)
//    --drawer-backdrop  Backdrop colour  default rgba(0,0,0,0.4)
//    --drawer-padding   Body padding     default var(--space-6)
//    --drawer-z         Z-index          default 1000
//
// ----------------------------------------------------------------------------

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

  cDrawerDefaultDuration = 350;  // milliseconds

type
  JW3Drawer = class(TElement)
  private
    FPanel:        JW3Panel;
    FHeader:       JW3Panel;
    FTitleEl:      JW3Panel;
    FBody:         JW3Panel;
    FFooter:       JW3Panel;
    FDuration:     Integer;
    FIsOpen:       Boolean;
    FOnClose:      TNotifyEvent;
    FOnAfterOpen:  TNotifyEvent;
    FOnAfterClose: TNotifyEvent;

    function  GetTitle: String;
    procedure SetTitle(const V: String);
    procedure SetDuration(const V: Integer);

    // Apply transform + transition as inline styles.
    // Called from Create and whenever Duration changes.
    procedure ApplyInlineStyles;

    procedure HandleClose(Sender: TObject);
    procedure HandleOpenTransitionEnd;
    procedure HandleCloseTransitionEnd;

  public
    constructor Create(Parent: TElement); virtual;

    procedure Open;
    procedure Close;
    procedure Toggle;
    function  IsOpen: Boolean;

    // Slide duration in ms. Default 350.
    // Written as inline style - cascade-proof.
    property Duration:     Integer        read FDuration      write SetDuration;

    property Title:        String         read GetTitle       write SetTitle;
    property Body:         JW3Panel       read FBody;
    property Footer:       JW3Panel       read FFooter;

    property OnClose:      TNotifyEvent   read FOnClose       write FOnClose;
    property OnAfterOpen:  TNotifyEvent   read FOnAfterOpen   write FOnAfterOpen;
    property OnAfterClose: TNotifyEvent   read FOnAfterClose  write FOnAfterClose;
  end;

procedure RegisterDrawerStyles;

implementation

uses Globals, Types;

var FRegistered: Boolean := false;

// ---------------------------------------------------------------------------
// CSS - layout and visual only; NO animation state (transform/opacity etc.)
// ---------------------------------------------------------------------------

procedure RegisterDrawerStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* Full-screen fixed backdrop.
       opacity / pointer-events / transition are set inline by Pascal. */
    .drawer-backdrop {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: var(--drawer-backdrop, rgba(0,0,0,0.4));
      z-index: var(--drawer-z, 1000);
    }

    /* Slide panel.
       transform / transition are set inline by Pascal.
       position:fixed and flex layout come from here. */
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
        0 20px 25px -5px rgba(0,0,0,0.1),
        0 10px 10px -5px rgba(0,0,0,0.04)));
      overflow: hidden;
      z-index: calc(var(--drawer-z, 1000) + 1);
    }

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

    .drawer-body {
      padding: var(--drawer-padding, var(--space-6, 24px));
      overflow-y: auto;
      flex-grow: 1;
    }

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

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

constructor JW3Drawer.Create(Parent: TElement);
var
  CloseBtn: JW3Panel;
begin
  inherited Create('div', Parent);
  AddClass(csDrawerBackdrop);

  FDuration := cDrawerDefaultDuration;
  FIsOpen   := false;

  // Close on backdrop click (not on panel clicks - they bubble past)
  Handle.addEventListener('click', procedure(e: JEvent) begin
    if e.target = Handle then Close;
  end, false);

  // Panel
  FPanel := JW3Panel.Create(Self);
  FPanel.AddClass(csDrawerPanel);

  // Set all animation-relevant properties inline now so the browser
  // has committed them before any Open() call.
  ApplyInlineStyles;

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

  // Body
  FBody := JW3Panel.Create(FPanel);
  FBody.AddClass(csDrawerBody);

  // Footer (hidden until the developer adds content)
  FFooter := JW3Panel.Create(FPanel);
  FFooter.AddClass(csDrawerFooter);
  FFooter.Visible := false;
end;

// ---------------------------------------------------------------------------
// ApplyInlineStyles
//   Sets transform, transition and backdrop opacity/pointer-events as
//   inline styles.  Called once at construction and again if Duration
//   is changed.  Inline styles beat the entire CSS cascade.
// ---------------------------------------------------------------------------

procedure JW3Drawer.ApplyInlineStyles;
var
  Ms: String;
begin
  Ms := IntToStr(FDuration) + 'ms';

  // Panel: parked off-screen to the left
  FPanel.SetStyle('transform',  'translateX(-100%)');
  FPanel.SetStyle('transition', 'transform ' + Ms + ' cubic-bezier(0.4, 0, 0.2, 1)');

  // Backdrop: invisible and non-interactive
  SetStyle('opacity',        '0');
  SetStyle('pointer-events', 'none');
  SetStyle('transition',     'opacity ' + Ms + ' ease');
end;

// ---------------------------------------------------------------------------
// Duration
// ---------------------------------------------------------------------------

procedure JW3Drawer.SetDuration(const V: Integer);
begin
  FDuration := V;
  ApplyInlineStyles;  // re-applies all inline styles with the new timing
end;

// ---------------------------------------------------------------------------
// Title
// ---------------------------------------------------------------------------

function JW3Drawer.GetTitle: String;
begin
  Result := FTitleEl.GetText;
end;

procedure JW3Drawer.SetTitle(const V: String);
begin
  FTitleEl.SetText(V);
end;

// ---------------------------------------------------------------------------
// Open
// ---------------------------------------------------------------------------

procedure JW3Drawer.Open;
var
  Dummy: Integer;
begin
  if FIsOpen then exit;
  FIsOpen := true;
  AddClass(csDrawerOpen);

  // *** KEY: force a synchronous style/layout flush before changing the
  // transform.  Reading offsetWidth causes the browser to commit the
  // current computed styles (including transform: translateX(-100%)).
  // Without this, when the drawer is created and opened in the same JS
  // frame the browser batches both states together and skips the
  // transition entirely.
  Dummy := FPanel.GetWidth;

  // Now change the animated properties - the browser will transition
  // from the committed initial state to these new values.
  FPanel.SetStyle('transform',  'translateX(0)');
  SetStyle('opacity',        '1');
  SetStyle('pointer-events', 'auto');

  // Fire OnAfterOpen once the panel finishes sliding in
  FPanel.Handle.addEventListener('transitionend', procedure(e: JEvent) begin
    FPanel.Handle.removeEventListener('transitionend', nil);
    HandleOpenTransitionEnd;
  end, false);
end;

// ---------------------------------------------------------------------------
// Close
// ---------------------------------------------------------------------------

procedure JW3Drawer.Close;
begin
  if not FIsOpen then exit;
  FIsOpen := false;
  RemoveClass(csDrawerOpen);

  // Slide out and fade backdrop
  FPanel.SetStyle('transform',  'translateX(-100%)');
  SetStyle('opacity',        '0');
  SetStyle('pointer-events', 'none');

  // Legacy OnClose fires immediately (keeps old callers working)
  if assigned(FOnClose) then
    FOnClose(Self);

  // Fire OnAfterClose once the panel finishes sliding out
  FPanel.Handle.addEventListener('transitionend', procedure(e: JEvent) begin
    FPanel.Handle.removeEventListener('transitionend', nil);
    HandleCloseTransitionEnd;
  end, false);
end;

// ---------------------------------------------------------------------------
// Toggle / IsOpen
// ---------------------------------------------------------------------------

procedure JW3Drawer.Toggle;
begin
  if FIsOpen then Close else Open;
end;

function JW3Drawer.IsOpen: Boolean;
begin
  Result := FIsOpen;
end;

// ---------------------------------------------------------------------------
// transitionend callbacks
// ---------------------------------------------------------------------------

procedure JW3Drawer.HandleOpenTransitionEnd;
begin
  if assigned(FOnAfterOpen) then
    FOnAfterOpen(Self);
end;

procedure JW3Drawer.HandleCloseTransitionEnd;
begin
  if assigned(FOnAfterClose) then
    FOnAfterClose(Self);
end;

// ---------------------------------------------------------------------------
// Close-button handler
// ---------------------------------------------------------------------------

procedure JW3Drawer.HandleClose(Sender: TObject);
begin
  Close;
end;

initialization
  RegisterDrawerStyles;
end.
