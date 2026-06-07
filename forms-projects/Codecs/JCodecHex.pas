unit JCodecHex;

// ============================================================================
//
//  JW3CodecHex -- Encode: text (ctText) -> hex text (ctText)
//                 Decode: hex text (ctText) -> text (ctText)
//
//  Each UTF-8 byte becomes two lowercase hex digits.
//    Encode('Hi')   -> '4869'
//    Decode('4869') -> 'Hi'
//
//  Symmetric, no padding, stable across runtimes.
//
// ============================================================================

interface

uses
  NodeTypes, JNode, JCodec;

type
  JW3CodecHex = class(JW3Codec)
  public
    function Name: String; override;
    function EncodeInputType:  TCodecType; override;
    function EncodeOutputType: TCodecType; override;
    function Encode(Input: variant): JPromise; override;
    function Decode(Input: variant): JPromise; override;
  end;

implementation

function JW3CodecHex.Name: String;
begin
  Result := 'Hex';
end;

function JW3CodecHex.EncodeInputType:  TCodecType; begin Result := ctText; end;
function JW3CodecHex.EncodeOutputType: TCodecType; begin Result := ctText; end;

function JW3CodecHex.Encode(Input: variant): JPromise;
begin
  asm
    try {
      var out;
      if (typeof Buffer !== 'undefined') {
        out = Buffer.from(String(@Input), 'utf8').toString('hex');
      } else {
        var bytes = new TextEncoder().encode(String(@Input));
        out = '';
        for (var i = 0; i < bytes.length; i++) {
          var h = bytes[i].toString(16);
          if (h.length === 1) h = '0' + h;
          out += h;
        }
      }
      @Result = Promise.resolve(out);
    } catch (e) {
      @Result = Promise.reject(new Error('Hex encode failed: ' + (e && e.message ? e.message : e)));
    }
  end;
end;

function JW3CodecHex.Decode(Input: variant): JPromise;
begin
  // Single @Result assignment at the end; no bare `return` inside asm
  // (would short-circuit the outer Pascal-function epilogue).
  asm
    var p;
    try {
      var s = String(@Input).trim();
      if (s.length % 2 !== 0) {
        p = Promise.reject(new Error('Hex input must have even length, got ' + s.length));
      } else if (!new RegExp('^[0-9a-fA-F]*$').test(s)) {
        p = Promise.reject(new Error('Hex input contains non-hex characters'));
      } else {
        var out;
        if (typeof Buffer !== 'undefined') {
          out = Buffer.from(s, 'hex').toString('utf8');
        } else {
          var bytes = new Uint8Array(s.length / 2);
          for (var i = 0; i < bytes.length; i++) {
            bytes[i] = parseInt(s.substr(i * 2, 2), 16);
          }
          out = new TextDecoder('utf-8').decode(bytes);
        }
        p = Promise.resolve(out);
      }
    } catch (e) {
      p = Promise.reject(new Error('Hex decode failed: ' + (e && e.message ? e.message : e)));
    }
    @Result = p;
  end;
end;

end.
