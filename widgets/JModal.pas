unit JModal;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Modal
//
//  A centered overlay dialog with a semi-transparent backdrop. The modal
//  creates a full-screen backdrop as a sibling of the application and
//  positions the dialog box centered within it. Clicking the backdrop
//  or the close button hides the modal.
//
//  Usage:
//
//    var Dlg := JW3Modal.Create(Self);
//    Dlg.Title := 'Confirm Delete';
//
//    var Msg := JW3Panel.Create(Dlg.Body);
//    Msg.SetText('Are you sure?');
//
//    var BtnOk := JW3Button.Create(Dlg.Footer);
//    BtnOk.Caption := 'Delete';
//    BtnOk.AddClass(csBtnDanger);
//
//    Dlg.Show;
//
//  Structure:
//
//    Backdrop  .modal-backdrop    (full screen, semi-transparent)
//      └── Dialog  .modal-dialog
//            ├── Header  .modal-header  (title + close button)
//            ├── Body    .modal-body    (developer content)
//            └── Footer  .modal-footer  (developer buttons)
//
//  CSS variables:
//
//    --modal-width        Dialog width           default: 480px
//    --modal-radius       Dialog radius          default: var(--radius-lg)
//    --modal-bg           Dialog background      default: var(--surface-color)
//    --modal-shadow       Dialog shadow          default: var(--shadow-xl)
//    --modal-backdrop     Backdrop colour        default: rgba(0,0,0,0.4)
//    --modal-padding      Body padding           default: var(--space-6)
//    --modal-z            Z-index                default: 1000
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

const
  csModalBackdrop = 'modal-backdrop';
  csModalDialog   = 'modal-dialog';
  csModalHeader   = 'modal-header';
  csModalBody     = 'modal-body';
  csModalFooter   = 'modal-footer';
  csModalClose    = 'modal-close';
  csModalTitle    = 'modal-title';

type
  JW3Modal = class(TElement)
  private
    FDialog:  JW3Panel;
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

    procedure Show;
    procedure Hide;

    property Title:   String     read GetTitle write SetTitle;
    property Body:    JW3Panel   read FBody;
    property Footer:  JW3Panel   read FFooter;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

procedure RegisterModalStyles;

implementation

uses Globals, Types;

var FRegistered: Boolean := false;

procedure RegisterModalStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Backdrop: full screen overlay ────────────────────────────── */

    .modal-backdrop {
      display: flex;
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: var(--modal-backdrop, rgba(0,0,0,0.4));
      z-index: var(--modal-z, 1000);
      align-items: center;
      justify-content: center;
      opacity: 0;
      transition: opacity var(--anim-duration, 0.2s);
      pointer-events: none;
    }

    .modal-backdrop.modal-visible {
      opacity: 1;
      pointer-events: auto;
    }

    /* ── Dialog box ───────────────────────────────────────────────── */

    .modal-dialog {
      width: var(--modal-width, 480px);
      max-width: calc(100vw - 32px);
      max-height: calc(100vh - 64px);
      background: var(--modal-bg, var(--surface-color, #ffffff));
      border-radius: var(--modal-radius, var(--radius-lg, 8px));
      box-shadow: var(--modal-shadow, var(--shadow-xl,
        0 20px 25px -5px rgba(0,0,0,0.1), 0 10px 10px -5px rgba(0,0,0,0.04)));
      overflow: hidden;
      transform: translateY(8px);
      transition: transform var(--anim-duration, 0.2s);
    }

    .modal-visible .modal-dialog {
      transform: translateY(0);
    }

    /* ── Header ───────────────────────────────────────────────────── */

    .modal-header {
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
      padding: var(--space-4, 16px) var(--space-6, 24px);
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      flex-shrink: 0;
    }

    .modal-title {
      font-weight: 600;
      font-size: var(--font-size-md, 1rem);
      color: var(--text-color, #334155);
    }

    /* ── Close button ─────────────────────────────────────────────── */

    .modal-close {
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

    .modal-close:hover {
      background: var(--hover-color, #f1f5f9);
    }

    /* ── Body ─────────────────────────────────────────────────────── */

    .modal-body {
      padding: var(--modal-padding, var(--space-6, 24px));
      overflow-y: auto;
      flex-grow: 1;
    }

    /* ── Footer ───────────────────────────────────────────────────── */

    .modal-footer {
      flex-direction: row;
      justify-content: flex-end;
      gap: var(--space-3, 12px);
      padding: var(--space-4, 16px) var(--space-6, 24px);
      border-top: 1px solid var(--border-color, #e2e8f0);
      flex-shrink: 0;
    }
  ');
end;

{ JW3Modal }

constructor JW3Modal.Create(Parent: TElement);
var
  CloseBtn: JW3Panel;
begin
  // Backdrop is the root element
  inherited Create('div', Parent);
  AddClass(csModalBackdrop);

  // Close on backdrop click — but not on clicks inside the dialog.
  Handle.addEventListener('click', procedure(e: JEvent) begin
    if e.target = Handle then Hide;
  end, false);

  // Dialog box
  FDialog := JW3Panel.Create(Self);
  FDialog.AddClass(csModalDialog);

  // Header
  FHeader := JW3Panel.Create(FDialog);
  FHeader.AddClass(csModalHeader);

  FTitleEl := JW3Panel.Create(FHeader);
  FTitleEl.AddClass(csModalTitle);
  FTitleEl.SetText('Dialog');

  CloseBtn := JW3Panel.Create(FHeader);
  CloseBtn.AddClass(csModalClose);
  CloseBtn.SetHTML('&#x2715;');
  CloseBtn.OnClick := HandleClose;

  // Body — developer adds content here
  FBody := JW3Panel.Create(FDialog);
  FBody.AddClass(csModalBody);

  // Footer — developer adds buttons here
  FFooter := JW3Panel.Create(FDialog);
  FFooter.AddClass(csModalFooter);
end;

function JW3Modal.GetTitle: String;
begin
  Result := FTitleEl.GetText;
end;

procedure JW3Modal.SetTitle(const V: String);
begin
  FTitleEl.SetText(V);
end;

procedure JW3Modal.Show;
begin
  AddClass('modal-visible');
end;

procedure JW3Modal.Hide;
begin
  RemoveClass('modal-visible');
  if assigned(FOnClose) then
    FOnClose(Self);
end;

procedure JW3Modal.HandleClose(Sender: TObject);
begin
  Hide;
end;

initialization
  RegisterModalStyles;
end.
