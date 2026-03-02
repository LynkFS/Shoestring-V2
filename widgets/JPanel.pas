unit JPanel;

interface

uses
  JElement;

type
  JW3Panel = class(TElement)
  public
    constructor Create(Parent: TElement); virtual;
    property Text: String read GetText write SetText;
  end;

implementation

{ JW3Panel }

constructor JW3Panel.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass('ss-base');
  SetStyle('user-select', 'none');
end;

end.
