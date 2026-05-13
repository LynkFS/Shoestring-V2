unit JCodecHex;

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//
//  JW3CodecHex â€” Encode: text (ctText) â†’ hex text (ctText)
//                Decode: hex text (ctText) â†’ text (ctText)
//
//  Each UTF-8 byte becomes two lowercase hex digits.
//    Encode('Hi')  â†’  '4869'
//    Decode('4869') â†’ 'Hi'
//
//  Symmetric, no padding, stable across runtimes.
//
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

interface

uses
  JCodec;

type
  JW3CodecHex = class(JW3Codec)
  public
    function Name: String; override;
    function EncodeInputType:  TCodecType; override;
    function EncodeOutputType: TCodecType; override;
    function Encode(Input: variant): variant; override;

    function CanDecode: Boolean; override;
    function Decode(Input: variant): variant; override;
  end;

implementation

function JW3CodecHex.Name: String;
begin
  Result := 'Hex';
end;

function JW3CodecHex.EncodeInputType:  TCodecType; begin Result := ctText; end;
function JW3CodecHex.EncodeOutputType: TCodecType; begin Result := ctText; end;

function JW3CodecHex.Encode(Input: variant): variant;
begin
  asm
    try {
      var bytes;
      if (typeof Buffer !== 'undefined') {
        // Node.js path
        bytes = Buffer.from(String(@Input), 'utf8');
        @Result = bytes.toString('hex');
      } else {
        // Browser path
        bytes = new TextEncoder().encode(String(@Input));
        var out = '';
        for (var i = 0; i < bytes.length; i++) {
          var h = bytes[i].toString(16);
          if (h.length === 1) h = '0' + h;
          out += h;
        }
        @Result = out;
      }
    } catch (e) {
      throw new Error('Hex encode failed: ' + e.message);
    }
  end;
end;

function JW3CodecHex.CanDecode: Boolean;
begin
  Result := True;
end;

function JW3CodecHex.Decode(Input: variant): variant;
begin
  asm
    try {
      var s = String(@Input).trim();
      if (s.length % 2 !== 0) {
        throw new Error('Hex input must have even length, got ' + s.length);
      }
      if (!new RegExp('^[0-9a-fA-F]*$').test(s)) {
        throw new Error('Hex input contains non-hex characters');
      }
      if (typeof Buffer !== 'undefined') {
        // Node.js path
        @Result = Buffer.from(s, 'hex').toString('utf8');
      } else {
        // Browser path
        var bytes = new Uint8Array(s.length / 2);
        for (var i = 0; i < bytes.length; i++) {
          bytes[i] = parseInt(s.substr(i * 2, 2), 16);
        }
        @Result = new TextDecoder('utf-8').decode(bytes);
      }
    } catch (e) {
      throw new Error('Hex decode failed: ' + e.message);
    }
  end;
end;

end.
