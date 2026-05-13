unit JCodecBase64;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3CodecBase64 — Encode: text (ctText) → base64 text (ctText)
//                   Decode: base64 text (ctText) → text (ctText)
//
//  UTF-8 safe. Works in both browser and Node, by detecting which platform
//  primitive is available (Node `Buffer` vs. browser `btoa/atob` + TextEncoder).
//
//  Why both paths?
//    - Node's `Buffer` handles UTF-8 natively and is the right tool there.
//    - Browser `btoa` is Latin-1 only — passing 'café' to it throws. So we
//      first UTF-8-encode via TextEncoder, then convert bytes → latin-1
//      string → btoa. Decode does the reverse via atob + TextDecoder.
//
//  This is a textbook example of why a Codec is the right abstraction:
//    callers say `Encode('café')` and never know which runtime they're on.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  JCodec;

type
  JW3CodecBase64 = class(JW3Codec)
  public
    function Name: String; override;
    function EncodeInputType:  TCodecType; override;
    function EncodeOutputType: TCodecType; override;
    function Encode(Input: variant): variant; override;

    function CanDecode: Boolean; override;
    function Decode(Input: variant): variant; override;
  end;

implementation

function JW3CodecBase64.Name: String;
begin
  Result := 'Base64';
end;

function JW3CodecBase64.EncodeInputType:  TCodecType; begin Result := ctText; end;
function JW3CodecBase64.EncodeOutputType: TCodecType; begin Result := ctText; end;

function JW3CodecBase64.Encode(Input: variant): variant;
begin
  asm
    try {
      if (typeof Buffer !== 'undefined') {
        // Node.js path — Buffer is UTF-8 native.
        @Result = Buffer.from(String(@Input), 'utf8').toString('base64');
      } else {
        // Browser path — UTF-8 bridge through TextEncoder + binary string.
        var bytes = new TextEncoder().encode(String(@Input));
        var bin = '';
        for (var i = 0; i < bytes.length; i++) {
          bin += String.fromCharCode(bytes[i]);
        }
        @Result = btoa(bin);
      }
    } catch (e) {
      throw new Error('Base64 encode failed: ' + e.message);
    }
  end;
end;

function JW3CodecBase64.CanDecode: Boolean;
begin
  Result := True;
end;

function JW3CodecBase64.Decode(Input: variant): variant;
begin
  asm
    try {
      if (typeof Buffer !== 'undefined') {
        // Node.js path
        @Result = Buffer.from(String(@Input), 'base64').toString('utf8');
      } else {
        // Browser path
        var bin = atob(String(@Input));
        var bytes = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) {
          bytes[i] = bin.charCodeAt(i);
        }
        @Result = new TextDecoder('utf-8').decode(bytes);
      }
    } catch (e) {
      throw new Error('Base64 decode failed: ' + e.message);
    }
  end;
end;

end.