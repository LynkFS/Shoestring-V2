unit JCodecJSON;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3CodecJSON — Encode: parsed object (ctJSON) → string (ctText)
//                 Decode: string (ctText)         → parsed object (ctJSON)
//
//  A thin, typed wrapper around JS native JSON.stringify / JSON.parse.
//
//  Why is this a codec?
//
//    Because the eventual graph runtime needs to treat "serialize to JSON"
//    and "parse JSON" as standard transforms that fit at typed edges. It
//    also lets pipelines like  obj → JSON.encode → Base64.encode → Hex.encode
//    work naturally (and their reverse round-trips back to obj).
//
//  Constructor:
//    JW3CodecJSON.Create               — default, no pretty-printing
//    JW3CodecJSON.Create(Indent)       — pretty-print with given indent
//
//  Note: per DWScript rules, a parameter with a default value cannot be
//  declared `const`, so `AIndent: Integer = 0` (no const).
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  JCodec;

type
  JW3CodecJSON = class(JW3Codec)
  private
    FIndent: Integer;
  public
    constructor Create(AIndent: Integer = 0);

    function Name: String; override;
    function EncodeInputType:  TCodecType; override;
    function EncodeOutputType: TCodecType; override;
    function Encode(Input: variant): variant; override;

    function CanDecode: Boolean; override;
    function Decode(Input: variant): variant; override;
  end;

implementation

constructor JW3CodecJSON.Create(AIndent: Integer = 0);
begin
  inherited Create;
  FIndent := AIndent;
end;

function JW3CodecJSON.Name: String;
begin
  Result := 'JSON';
end;

function JW3CodecJSON.EncodeInputType:  TCodecType; begin Result := ctJSON; end;
function JW3CodecJSON.EncodeOutputType: TCodecType; begin Result := ctText; end;

function JW3CodecJSON.Encode(Input: variant): variant;
var
  Indent: Integer;
begin
  Indent := FIndent;
  asm
    try {
      if (@Indent > 0) {
        @Result = JSON.stringify(@Input, null, @Indent);
      } else {
        @Result = JSON.stringify(@Input);
      }
    } catch (e) {
      throw new Error('JSON encode failed: ' + e.message);
    }
  end;
end;

function JW3CodecJSON.CanDecode: Boolean;
begin
  Result := True;
end;

function JW3CodecJSON.Decode(Input: variant): variant;
begin
  asm
    try {
      @Result = JSON.parse(@Input);
    } catch (e) {
      throw new Error('JSON decode failed: ' + e.message);
    }
  end;
end;

end.