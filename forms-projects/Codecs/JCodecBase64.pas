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
  NodeTypes, JNode, JCodec;

type
  JW3CodecBase64 = class(JW3Codec)
  public
    function Name: String; override;
    function EncodeInputType:  TCodecType; override;
    function EncodeOutputType: TCodecType; override;
    function Encode(Input: variant): JPromise; override;
    function Decode(Input: variant): JPromise; override;
  end;

implementation

function JW3CodecBase64.Name: String;
begin
  Result := 'Base64';
end;

function JW3CodecBase64.EncodeInputType:  TCodecType; begin Result := ctText; end;
function JW3CodecBase64.EncodeOutputType: TCodecType; begin Result := ctText; end;

function JW3CodecBase64.Encode(Input: variant): JPromise;
begin
  asm
    try {
      var out;
      if (typeof Buffer !== 'undefined') {
        out = Buffer.from(String(@Input), 'utf8').toString('base64');
      } else {
        var bytes = new TextEncoder().encode(String(@Input));
        var bin = '';
        for (var i = 0; i < bytes.length; i++) {
          bin += String.fromCharCode(bytes[i]);
        }
        out = btoa(bin);
      }
      @Result = Promise.resolve(out);
    } catch (e) {
      @Result = Promise.reject(new Error('Base64 encode failed: ' + (e && e.message ? e.message : e)));
    }
  end;
end;

function JW3CodecBase64.Decode(Input: variant): JPromise;
begin
  asm
    try {
      var out;
      if (typeof Buffer !== 'undefined') {
        out = Buffer.from(String(@Input), 'base64').toString('utf8');
      } else {
        var bin = atob(String(@Input));
        var bytes = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) {
          bytes[i] = bin.charCodeAt(i);
        }
        out = new TextDecoder('utf-8').decode(bytes);
      }
      @Result = Promise.resolve(out);
    } catch (e) {
      @Result = Promise.reject(new Error('Base64 decode failed: ' + (e && e.message ? e.message : e)));
    }
  end;
end;

end.