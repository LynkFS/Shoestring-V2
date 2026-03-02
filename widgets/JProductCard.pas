unit JProductCard;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Product Card
//
//  A responsive card that uses CSS Grid for internal structure and
//  container queries for layout shifts. When the container is narrow,
//  the card stacks vertically (image on top). When wide, image sits
//  beside the content (two-column grid).
//
//  The parent element must declare container-type: inline-size for
//  container queries to work. Use AddCardContainer on any parent,
//  or wrap cards in a TCardContainer.
//
//  Usage:
//
//    // Option 1: mark any parent as a card container
//    AddCardContainer(MyPanel);
//
//    var Card := TProductCard.Create(MyPanel);
//    Card.Title := 'Reef Snorkel Set';
//    Card.Price := '$49.95';
//    Card.ImageSrc := 'https://example.com/snorkel.jpg';
//    Card.AddTag('New');
//    Card.AddTag('Sale');
//
//    // Option 2: use the dedicated container
//    var Grid := TCardContainer.Create(Self);
//    var Card1 := TProductCard.Create(Grid);
//    var Card2 := TProductCard.Create(Grid);
//
//  Narrow container (<450px):     Wide container (≥450px):
//  ┌─────────────────────┐        ┌────────┬──────────────┐
//  │                     │        │        │  Tag  Tag    │
//  │      image          │        │  image │  Title       │
//  │                     │        │        │  $49.95      │
//  ├─────────────────────┤        │        │              │
//  │  Tag  Tag           │        └────────┴──────────────┘
//  │  Title              │
//  │  $49.95             │
//  └─────────────────────┘
//
//  CSS variables:
//
//    --card-gap            Grid gap               default: 1rem
//    --card-padding        Card padding           default: 1rem
//    --card-radius         Border radius          default: 8px
//    --card-border         Border                 default: 1px solid var(--border-color)
//    --card-bg             Background             default: var(--surface-color, #fff)
//    --card-hover-shadow   Hover shadow           default: 0 4px 12px rgba(0,0,0,0.08)
//    --card-img-height     Image height (narrow)  default: 160px
//    --card-img-width      Image width (wide)     default: 180px
//    --card-tag-bg         Tag background         default: var(--hover-color, #f1f5f9)
//    --card-tag-radius     Tag radius             default: 4px
//    --card-tag-font-size  Tag font size          default: 0.75rem
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

type

  TCardContainer = class(TElement)
  public
    constructor Create(Parent: TElement); virtual;
  end;

  TProductCard = class(TElement)
  private
    FImage: TElement;
    FBody:  TElement;
    FTags:  TElement;
    FTitle: TElement;
    FPrice: TElement;
    FDesc:  TElement;

    procedure SetTitle(const V: String);
    function  GetTitle: String;
    procedure SetPrice(const V: String);
    function  GetPrice: String;
    procedure SetImageSrc(const V: String);
    procedure SetDescription(const V: String);
    function  GetDescription: String;

  public
    constructor Create(Parent: TElement); virtual;

    property Title:       String read GetTitle       write SetTitle;
    property Price:       String read GetPrice       write SetPrice;
    property Description: String read GetDescription write SetDescription;
    property ImageSrc:    String                     write SetImageSrc;

    procedure AddTag(const Text: String);
    procedure ClearTags;

    property Image: TElement read FImage;
    property Body:  TElement read FBody;
    property Tags:  TElement read FTags;
  end;

// Mark any element as a card container context
procedure AddCardContainer(El: TElement);

procedure RegisterProductCardStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterProductCardStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    /* ── Container context ───────────────────────────────────────── */

    .card-container {
      container-type: inline-size;
    }

    /* ── Card: single-column grid by default (narrow) ────────────── */

    .product-card {
      display: grid;
      grid-template-columns: 1fr;
      gap: var(--card-gap, 1rem);
      padding: var(--card-padding, 1rem);
      border: var(--card-border, 1px solid var(--border-color, #e2e8f0));
      border-radius: var(--card-radius, 8px);
      background: var(--card-bg, var(--surface-color, #fff));
      overflow: hidden;
      transition: box-shadow 0.2s;
    }

    .product-card:hover {
      box-shadow: var(--card-hover-shadow, 0 4px 12px rgba(0,0,0,0.08));
    }

    /* ── Image ────────────────────────────────────────────────────── */

    .product-card-img {
      width: 100%;
      height: var(--card-img-height, 160px);
      object-fit: cover;
      border-radius: 4px;
    }

    /* ── Body ─────────────────────────────────────────────────────── */

    .product-card-body {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    /* ── Tags ─────────────────────────────────────────────────────── */

    .product-card-tags {
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem;
      margin-bottom: 0.5rem;
    }

    .product-card-tag {
      display: inline-flex;
      align-items: center;
      padding: 2px 8px;
      background: var(--card-tag-bg, var(--hover-color, #f1f5f9));
      border-radius: var(--card-tag-radius, 4px);
      font-size: var(--card-tag-font-size, 0.75rem);
      color: var(--text-light, #64748b);
    }

    /* ── Title & Price ────────────────────────────────────────────── */

    .product-card-title {
      font-weight: 600;
      color: var(--text-color, #334155);
    }

    .product-card-price {
      color: var(--text-light, #64748b);
    }

    .product-card-desc {
      font-size: var(--font-size-sm, 0.875rem);
      color: var(--text-light, #64748b);
      line-height: 1.5;
    }

    /* ── Wide container: two-column layout ────────────────────────── */

    @container (min-width: 450px) {
      .product-card {
        grid-template-columns: var(--card-img-width, 180px) 1fr;
        align-items: center;
      }
      .product-card-img {
        height: 120px;
      }
    }
  ');
end;


// ═════════════════════════════════════════════════════════════════════════
// Helper
// ═════════════════════════════════════════════════════════════════════════

procedure AddCardContainer(El: TElement);
begin
  El.AddClass('card-container');
end;


// ═════════════════════════════════════════════════════════════════════════
// TCardContainer
// ═════════════════════════════════════════════════════════════════════════

constructor TCardContainer.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass('card-container');
end;


// ═════════════════════════════════════════════════════════════════════════
// TProductCard
// ═════════════════════════════════════════════════════════════════════════

constructor TProductCard.Create(Parent: TElement);
begin
  inherited Create('div', Parent);
  AddClass('product-card');

  FImage := TElement.Create('img', Self);
  FImage.AddClass('product-card-img');

  FBody := TElement.Create('div', Self);
  FBody.AddClass('product-card-body');

  FTags := TElement.Create('div', FBody);
  FTags.AddClass('product-card-tags');

  FTitle := TElement.Create('div', FBody);
  FTitle.AddClass('product-card-title');

  FPrice := TElement.Create('div', FBody);
  FPrice.AddClass('product-card-price');

  FDesc := TElement.Create('div', FBody);
  FDesc.AddClass('product-card-desc');
end;

procedure TProductCard.SetTitle(const V: String);
begin
  FTitle.SetText(V);
end;

function TProductCard.GetTitle: String;
begin
  Result := FTitle.GetText;
end;

procedure TProductCard.SetPrice(const V: String);
begin
  FPrice.SetText(V);
end;

function TProductCard.GetPrice: String;
begin
  Result := FPrice.GetText;
end;

procedure TProductCard.SetImageSrc(const V: String);
begin
  FImage.Handle.src := V;
end;

procedure TProductCard.SetDescription(const V: String);
begin
  FDesc.SetText(V);
end;

function TProductCard.GetDescription: String;
begin
  Result := FDesc.GetText;
end;

procedure TProductCard.AddTag(const Text: String);
var
  tag: TElement;
begin
  tag := TElement.Create('span', FTags);
  tag.AddClass('product-card-tag');
  tag.SetText(Text);
end;

procedure TProductCard.ClearTags;
begin
  FTags.Clear;
end;

initialization
  RegisterProductCardStyles;
end.
