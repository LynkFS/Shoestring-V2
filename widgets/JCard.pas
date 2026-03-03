unit JCard;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Card
//
//  A bordered content container with optional header, body, and footer.
//  Used for dashboard widgets, content previews, settings groups, and
//  any discrete block of content.
//
//  Usage:
//
//    var Card := JW3Card.Create(Grid);
//    Card.Title := 'Monthly Revenue';
//
//    var Value := JW3Panel.Create(Card.Body);
//    Value.SetText('$42,500');
//    Value.AddClass('text-2xl');
//    Value.AddClass('font-bold');
//
//  Simple usage (no header/footer):
//
//    var Card := JW3Card.Create(Grid);
//    var P := JW3Panel.Create(Card.Body);
//    P.SetText('Card content goes here');
//
//  CSS variables:
//
//    --card-bg            Card background        default: var(--surface-color)
//    --card-border        Card border            default: 1px solid var(--border-color)
//    --card-radius        Card radius            default: var(--radius-lg)
//    --card-shadow        Card shadow            default: var(--shadow-sm)
//    --card-padding       Body padding           default: var(--space-4)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement, JPanel;

const
  csCard       = 'card';
  csCardHeader = 'card-header';
  csCardBody   = 'card-body';
  csCardFooter = 'card-footer';

type
  JW3Card = class(TElement)
  private
    FHeader:  JW3Panel;
    FTitleEl: JW3Panel;
    FBody:    JW3Panel;
    FFooter:  JW3Panel;

    function  GetTitle: String;
    procedure SetTitle(const V: String);

  public
    constructor Create(Parent: TElement); virtual;

    property Title:  String    read GetTitle write SetTitle;
    property Header: JW3Panel  read FHeader;
    property Body:   JW3Panel  read FBody;
    property Footer: JW3Panel  read FFooter;
  end;

procedure RegisterCardStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterCardStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    .card {
      background: var(--card-bg, var(--surface-color, #ffffff));
      border: var(--card-border, 1px solid var(--border-color, #e2e8f0));
      border-radius: var(--card-radius, var(--radius-lg, 8px));
      box-shadow: var(--card-shadow, var(--shadow-sm, 0 1px 3px rgba(0,0,0,0.1)));
      overflow: hidden;
    }

    .card-header {
      flex-direction: row;
      align-items: center;
      justify-content: space-between;
      padding: var(--space-4, 16px);
      border-bottom: 1px solid var(--border-color, #e2e8f0);
      flex-shrink: 0;
    }

    .card-header > :first-child {
      font-weight: 600;
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-color, #334155);
    }

    .card-body {
      padding: var(--card-padding, var(--space-4, 16px));
      flex-grow: 1;
    }

    .card-footer {
      flex-direction: row;
      align-items: center;
      gap: var(--space-3, 12px);
      padding: var(--space-3, 12px) var(--space-4, 16px);
      border-top: 1px solid var(--border-color, #e2e8f0);
      flex-shrink: 0;
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-light, #64748b);
    }
  ');
end;

{ JW3Card }

constructor JW3Card.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass(csCard);

  FHeader := JW3Panel.Create(Self);
  FHeader.AddClass(csCardHeader);
  FHeader.Visible := false;  // hidden until Title is set

  FTitleEl := JW3Panel.Create(FHeader);

  FBody := JW3Panel.Create(Self);
  FBody.AddClass(csCardBody);

  FFooter := JW3Panel.Create(Self);
  FFooter.AddClass(csCardFooter);
  FFooter.Visible := false;  // hidden until developer adds content
end;

function JW3Card.GetTitle: String;
begin
  Result := FTitleEl.GetText;
end;

procedure JW3Card.SetTitle(const V: String);
begin
  FTitleEl.SetText(V);
  FHeader.Visible := (V <> '');
end;

initialization
  RegisterCardStyles;
end.
