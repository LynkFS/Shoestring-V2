unit JImage;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Image
//
//  Creates an <img> element with typed access to src, alt, and CSS
//  object-fit modes. Provides a loading/error state via CSS classes.
//
//  Usage:
//
//    var Photo := JW3Image.Create(Card.Body);
//    Photo.Src := 'https://example.com/photo.jpg';
//    Photo.Alt := 'Sunset over the reef';
//    Photo.Fit := ifCover;
//    Photo.Height := 200;
//
//  Fit modes:
//
//    ifContain  — scales to fit inside the element, preserving aspect ratio
//    ifCover    — scales to fill the element, cropping if necessary
//    ifFill     — stretches to fill (distorts if aspect ratios differ)
//    ifNone     — natural size, no scaling
//
//  CSS variables:
//
//    --img-radius         Image radius           default: 0
//    --img-bg             Placeholder bg         default: var(--hover-color)
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JElement;

const
  csImage = 'img-el';

type
  TImageFit = (ifContain, ifCover, ifFill, ifNone);

  JW3Image = class(TElement)
  private
    function  GetSrc: String;
    procedure SetSrc(const V: String);
    function  GetAlt: String;
    procedure SetAlt(const V: String);
    procedure SetFit(V: TImageFit);

  public
    constructor Create(Parent: TElement); virtual;

    property Src: String   read GetSrc write SetSrc;
    property Alt: String   read GetAlt write SetAlt;
    property Fit: TImageFit write SetFit;
  end;

procedure RegisterImageStyles;

implementation

uses Globals;

var FRegistered: Boolean := false;

procedure RegisterImageStyles;
begin
  if FRegistered then exit;
  FRegistered := true;

  AddStyleBlock(#'

    .img-el {
      display: block;
      max-width: 100%;
      height: auto;
      border-radius: var(--img-radius, 0);
      background: var(--img-bg, var(--border-color, #e2e8f0));
      object-fit: contain;
    }
  ');
end;

{ JW3Image }

constructor JW3Image.Create(Parent: TElement);
begin
  inherited Create('img', Parent);
  AddClass(csImage);
  // Prevent broken image icon from collapsing layout
  SetAttribute('alt', '');
end;

function JW3Image.GetSrc: String;
begin
  Result := '';
  Result := self.handle.src;
end;

procedure JW3Image.SetSrc(const V: String);
begin
  self.handle.src := V;
end;

function JW3Image.GetAlt: String;
begin
  Result := '';
  Result := self.handle.alt;
end;

procedure JW3Image.SetAlt(const V: String);
begin
  self.handle.alt := V;
end;

procedure JW3Image.SetFit(V: TImageFit);
begin
  case V of
    ifContain: SetStyle('object-fit', 'contain');
    ifCover:   SetStyle('object-fit', 'cover');
    ifFill:    SetStyle('object-fit', 'fill');
    ifNone:    SetStyle('object-fit', 'none');
  end;
end;

initialization
  RegisterImageStyles;
end.
