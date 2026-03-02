unit JApplication;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3Application
//
//  Manages form registration and navigation. CreateForm registers a name
//  and a class. GoToForm creates the form on first visit (lazy) and hides
//  all others. On return visits the form is shown, not recreated — state
//  is preserved.
//
//  Usage:
//
//    Application.CreateForm('Main', TFormMain);
//    Application.CreateForm('Settings', TFormSettings);
//    Application.GoToForm('Main');
//
//  ~60 lines.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JForm;

type

  TFormEntry = record
    Name:     String;
    FormClass: TFormClass;
    Instance: TW3Form;
  end;

  JW3Application = class(TElement)
  private
    FForms: array of TFormEntry;
  public
    constructor Create(Parent: TElement); virtual;
    procedure CreateForm(const FormName: String; AClass: TFormClass);
    procedure GoToForm(const FormName: String);
  end;

implementation

{ JW3Application }

constructor JW3Application.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass('ss-base');

  SetStyle('width',  '100%');
  SetStyle('height', '100%');
end;

procedure JW3Application.CreateForm(const FormName: String; AClass: TFormClass);
var
  Entry: TFormEntry;
begin
  Entry.Name      := FormName;
  Entry.FormClass := AClass;
  Entry.Instance  := nil;
  FForms.Add(Entry);
end;

procedure JW3Application.GoToForm(const FormName: String);
begin
  for var i := 0 to FForms.Count - 1 do
  begin
    if FForms[i].Name = FormName then
    begin
      // Create on first visit
      if FForms[i].Instance = nil then
      begin
        FForms[i].Instance := FForms[i].FormClass.Create(Self);
        FForms[i].Instance.InitializeObject;
        FForms[i].Instance.Resize;
      end;

      // Show
      FForms[i].Instance.Visible := true;
    end
    else
    begin
      // Hide all others
      if FForms[i].Instance <> nil then
        FForms[i].Instance.Visible := false;
    end;
  end;
end;

end.
