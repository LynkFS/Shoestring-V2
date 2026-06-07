unit JCodecAesGcm;

// ============================================================================
//
//  JW3CodecAesGcm  --  AES-256-GCM via WebCrypto.
//
//  This is the Phase-2 worked example. It exists to prove the async
//  contract carries real load -- WebCrypto's SubtleCrypto is natively
//  promise-based, so there is no degeneracy here: every Encode and every
//  Decode is a genuine async operation that the pipeline awaits.
//
//  Shape (ctText to ctText, for clean composability with the other
//  Phase-1 codecs):
//
//     Encode:  utf-8 plaintext text  ->  base64( IV || ciphertext )
//     Decode:  base64( IV || ciphertext )  ->  utf-8 plaintext text
//
//  A fresh 96-bit IV is generated PER Encode and prepended to the cipher
//  blob -- standard practice for AES-GCM. The output is base64 so it
//  chains naturally with the other text-to-text codecs in the demo.
//
//  Key management: the constructor takes a base64-encoded 256-bit raw key
//  (32 bytes -> 44 base64 chars). If empty, a fresh key is generated and
//  exported (call ExportedKeyBase64 to read it back). Imports/exports
//  happen against WebCrypto, which is natively async -- so FKeyReady is a
//  promise the Encode/Decode chains begin with.
//
//  Cross-target: browser uses window.crypto.subtle; Node 16+ uses
//  require('crypto').webcrypto.subtle. The if (typeof crypto) guard
//  picks the right one.
//
//  This codec is one-shot (encrypt-the-whole-payload). Streaming AEAD is
//  a separate exercise; Reset/Flush are the no-op defaults from the
//  base class.
//
// ============================================================================

interface

uses
  NodeTypes, JNode, JCodec;

type
  JW3CodecAesGcm = class(JW3Codec)
  private
    FKey:       variant;   // CryptoKey (resolved JS object), or undefined
    FKeyReady:  JPromise;  // resolves once FKey is set
    FExportedB64: String;  // raw key as base64 (only set if generated here)
  public
    // AKeyBase64 = 32-byte raw key, base64-encoded (44 chars). If empty,
    // a fresh key is generated and ExportedKeyBase64 will be populated
    // once FKeyReady resolves.
    constructor Create(AKeyBase64: String = '');

    function Name: String; override;
    function EncodeInputType:  TCodecType; override;
    function EncodeOutputType: TCodecType; override;
    function Encode(Input: variant): JPromise; override;
    function Decode(Input: variant): JPromise; override;

    // Returns the base64 of the raw key, but only AFTER FKeyReady
    // resolves -- await ReadyKey first, or call from a .then chain.
    function ExportedKeyBase64: String;

    // Convenience: a promise that resolves once the key is usable.
    function ReadyKey: JPromise;
  end;

implementation

constructor JW3CodecAesGcm.Create(AKeyBase64: String = '');
begin
  inherited Create;
  FExportedB64 := AKeyBase64;
  asm
    var self_ = @Self;
    var subtle = (typeof crypto !== 'undefined' && crypto.subtle)
      ? crypto.subtle
      : require('crypto').webcrypto.subtle;

    function b64ToBytes(b64) {
      if (typeof Buffer !== 'undefined') return new Uint8Array(Buffer.from(b64, 'base64'));
      var bin = atob(b64);
      var out = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
      return out;
    }
    function bytesToB64(bytes) {
      if (typeof Buffer !== 'undefined') return Buffer.from(bytes).toString('base64');
      var bin = '';
      for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
      return btoa(bin);
    }

    var keyPromise;
    if (@AKeyBase64) {
      keyPromise = subtle.importKey(
        'raw', b64ToBytes(@AKeyBase64),
        { name: 'AES-GCM' }, false, ['encrypt', 'decrypt']);
    } else {
      keyPromise = subtle.generateKey(
        { name: 'AES-GCM', length: 256 }, true, ['encrypt', 'decrypt']
      ).then(function (k) {
        return subtle.exportKey('raw', k).then(function (raw) {
          self_.FExportedB64 = bytesToB64(new Uint8Array(raw));
          return k;
        });
      });
    }
    @FKeyReady = keyPromise.then(function (k) {
      self_.FKey = k;
      return k;
    });
  end;
end;

function JW3CodecAesGcm.Name: String;
begin
  Result := 'AES-GCM';
end;

function JW3CodecAesGcm.EncodeInputType:  TCodecType; begin Result := ctText; end;
function JW3CodecAesGcm.EncodeOutputType: TCodecType; begin Result := ctText; end;

function JW3CodecAesGcm.ExportedKeyBase64: String;
begin
  Result := FExportedB64;
end;

function JW3CodecAesGcm.ReadyKey: JPromise;
begin
  Result := FKeyReady;
end;

function JW3CodecAesGcm.Encode(Input: variant): JPromise;
begin
  // Chain off FKeyReady so the first Encode waits for key import/export
  // to complete. Subsequent Encodes find a resolved promise and proceed
  // immediately.
  asm
    var self_ = @Self;
    var input = @Input;
    var subtle = (typeof crypto !== 'undefined' && crypto.subtle)
      ? crypto.subtle
      : require('crypto').webcrypto.subtle;
    var randomBytes = function (n) {
      if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
        var b = new Uint8Array(n); crypto.getRandomValues(b); return b;
      }
      return new Uint8Array(require('crypto').randomBytes(n));
    };
    var bytesToB64 = function (bytes) {
      if (typeof Buffer !== 'undefined') return Buffer.from(bytes).toString('base64');
      var bin = ''; for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
      return btoa(bin);
    };

    @Result = self_.FKeyReady.then(function () {
      var iv = randomBytes(12);
      var pt = new TextEncoder().encode(String(input));
      return subtle.encrypt({ name: 'AES-GCM', iv: iv }, self_.FKey, pt)
        .then(function (ctBuf) {
          var ct = new Uint8Array(ctBuf);
          var out = new Uint8Array(iv.length + ct.length);
          out.set(iv, 0);
          out.set(ct, iv.length);
          return bytesToB64(out);
        });
    }).catch(function (e) {
      return Promise.reject(new Error('AES-GCM encode failed: ' + (e && e.message ? e.message : e)));
    });
  end;
end;

function JW3CodecAesGcm.Decode(Input: variant): JPromise;
begin
  asm
    var self_ = @Self;
    var input = @Input;
    var subtle = (typeof crypto !== 'undefined' && crypto.subtle)
      ? crypto.subtle
      : require('crypto').webcrypto.subtle;
    var b64ToBytes = function (b64) {
      if (typeof Buffer !== 'undefined') return new Uint8Array(Buffer.from(b64, 'base64'));
      var bin = atob(b64); var out = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
      return out;
    };

    @Result = self_.FKeyReady.then(function () {
      var blob = b64ToBytes(String(input));
      if (blob.length < 13) {
        return Promise.reject(new Error('AES-GCM input too short to contain IV + ciphertext'));
      }
      var iv = blob.slice(0, 12);
      var ct = blob.slice(12);
      return subtle.decrypt({ name: 'AES-GCM', iv: iv }, self_.FKey, ct)
        .then(function (ptBuf) {
          return new TextDecoder('utf-8').decode(new Uint8Array(ptBuf));
        });
    }).catch(function (e) {
      return Promise.reject(new Error('AES-GCM decode failed: ' + (e && e.message ? e.message : e)));
    });
  end;
end;

end.
