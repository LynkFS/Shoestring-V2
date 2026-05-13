unit FormNew;

// Empty starter form. Compiles as-is. Override InitializeObject to build.

interface

uses
  JElement, JForm;

type
  TFormNew = class(TW3Form)
  protected
    procedure InitializeObject; override;
  end;

implementation

procedure TFormNew.InitializeObject;
begin
  inherited;
end;

end.
