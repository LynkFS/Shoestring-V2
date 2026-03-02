unit JLabel;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Label
//
//  Creates a <label> element. Associates with a field via ForElement.
//  Uses the field-label class from ThemeStyles.
//
//  Usage:
//
//    var Lbl := JW3Label.Create(Group);
//    Lbl.Caption := 'Email address';
//    Lbl.ForElement := FEmail;
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

type
  JW3Label = class(TElement)
  private
    function  GetCaption: String;
    procedure SetCaption(const Value: String);
    procedure SetForElement(El: TElement);
  public
    constructor Create(Parent: TElement); virtual;
    property Caption: String read GetCaption write SetCaption;
    property ForElement: TElement write SetForElement;
  end;

implementation

{ JW3Label }

constructor JW3Label.Create(Parent: TElement);
begin
  inherited Create('label', Parent);
  AddClass('field-label');
end;

function JW3Label.GetCaption: String;
begin
  Result := GetText;
end;

procedure JW3Label.SetCaption(const Value: String);
begin
  SetText(Value);
end;

procedure JW3Label.SetForElement(El: TElement);
begin
  SetAttribute('for', El.Handle.id);
end;

end.
