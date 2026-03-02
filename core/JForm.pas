unit JForm;

// ═══════════════════════════════════════════════════════════════════════════
//
//  TW3Form
//
//  A form fills its parent, enables overflow scrolling, and is the only
//  element that listens for window resize. Resize updates global screen
//  dimensions and calls the virtual Resize method.
//
//  Lifecycle:
//    1. JApplication creates the form via TFormClass.Create
//    2. InitializeObject is called — descendants create components here
//    3. Resize is called — descendants do any manual layout here
//    4. On return visits, Visible is set to true and Resize fires again
//
//  ~50 lines.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, Types;

type

  TW3Form = class(TElement)
  public
    constructor Create(Parent: TElement); virtual;
    procedure InitializeObject; virtual;
    procedure Resize; virtual;
    procedure CBResize(EventObj: JEvent);
  end;

  TFormClass = class of TW3Form;

implementation

uses Globals;

{ TW3Form }

constructor TW3Form.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass('ss-base');

  // Fill parent
  SetStyle('width',  '100%');
  SetStyle('height', '100%');

  // Scroll when content overflows
  SetStyle('overflow', 'auto');

  // Default background — overridable via CSS variable
  SetStyle('background-color', 'var(--bg-color, #f8fafc)');

  // GPU compositing layer
  SetStyle('will-change', 'transform');

  // Only forms listen for resize — TElement does not
  window.addEventListener('resize', @CBResize, false);
end;

procedure TW3Form.CBResize(EventObj: JEvent);
begin
  ScreenWidth  := window.innerWidth;
  ScreenHeight := window.innerHeight;
  Resize;
end;

procedure TW3Form.InitializeObject;
begin
  // Override in descendants to create components
end;

procedure TW3Form.Resize;
begin
  // Override in descendants for manual layout
end;

end.
