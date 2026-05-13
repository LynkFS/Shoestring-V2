unit JCodec;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3Codec — Base class for all codecs in the Shoestring-V2 framework.
//
//  A codec is a typed, composable data transform. It has two directions:
//
//    Encode:  Input  →  Output      (always implemented)
//    Decode:  Output →  Input       (optional — pass CanDecode to check)
//
//  Each direction declares its own input and output type from a small
//  vocabulary (ctText, ctBytes, ctJSON, ctAny). Pipelines use these types
//  to validate that adjacent codecs are compatible at *assembly time* —
//  not at 3 a.m. when data is flowing through production.
//
//  Codecs in this MVP are synchronous. Async codecs (LLM, WebCrypto) will
//  be added as a separate JW3AsyncCodec class returning JPromise. See the
//  README for the phase-2 roadmap.
//
//  Usage:
//
//    var C := JW3CodecBase64.Create;
//    var Encoded := C.Encode('hello');           // 'aGVsbG8='
//    var Decoded := C.Decode(Encoded);           // 'hello'
//    C.Free;
//
//    if C.CanDecode then
//      Original := C.Decode(Encoded);
//
//  Subclasses override Name / EncodeInputType / EncodeOutputType / Encode,
//  and optionally Decode + override CanDecode to return true.
//
//  Cross-target: zero DOM dependency. Compiles to both browser and Node.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type
  // ─── Canonical type vocabulary ─────────────────────────────────────────
  //
  //  ctText   — a JS String (UTF-16 in memory, UTF-8 on the wire)
  //  ctBytes  — a Uint8Array  (variant wrapping the JS object)
  //  ctJSON   — a parsed JS object/array/primitive (variant)
  //  ctAny    — wildcard, accepts any input; useful for sinks and taps
  //
  TCodecType = (ctText, ctBytes, ctJSON, ctAny);

  // ─── Exception raised on any codec failure ─────────────────────────────
  ECodecError = class(Exception)
  end;

  // ─── Base class. All codecs inherit from this. ─────────────────────────
  JW3Codec = class
  public
    // Identity — used in pipeline.Describe and error messages.
    function Name: String; virtual; abstract;

    // Encode direction (always implemented by subclasses).
    function EncodeInputType:  TCodecType; virtual; abstract;
    function EncodeOutputType: TCodecType; virtual; abstract;
    function Encode(Input: variant): variant; virtual; abstract;

    // Decode direction (optional). Default implementation raises.
    // Subclasses that support decoding override CanDecode to return True
    // and override Decode.  The default decode types mirror encode in reverse.
    function CanDecode: Boolean; virtual;
    function DecodeInputType:  TCodecType; virtual;
    function DecodeOutputType: TCodecType; virtual;
    function Decode(Input: variant): variant; virtual;
  end;

// ─── Helpers ─────────────────────────────────────────────────────────────

// Returns 'text' | 'bytes' | 'json' | 'any' — for error messages and Describe.
function CodecTypeName(T: TCodecType): String;

// Returns True if the two types are compatible at an edge.
// ctAny matches anything; otherwise types must be exactly equal.
function CodecTypesCompatible(Producer, Consumer: TCodecType): Boolean;

implementation


//==============================================================================
// Helpers
//==============================================================================

function CodecTypeName(T: TCodecType): String;
begin
  case T of
    ctText:  Result := 'text';
    ctBytes: Result := 'bytes';
    ctJSON:  Result := 'json';
    ctAny:   Result := 'any';
  else
    Result := 'unknown';
  end;
end;

function CodecTypesCompatible(Producer, Consumer: TCodecType): Boolean;
begin
  Result := (Producer = Consumer) or
            (Producer = ctAny) or
            (Consumer = ctAny);
end;


//==============================================================================
// JW3Codec — base behaviour
//==============================================================================

function JW3Codec.CanDecode: Boolean;
begin
  Result := False;
end;

// Default decode types are encode types reversed; subclasses that supply
// asymmetric encode/decode shapes override these as well.
function JW3Codec.DecodeInputType: TCodecType;
begin
  Result := EncodeOutputType;
end;

function JW3Codec.DecodeOutputType: TCodecType;
begin
  Result := EncodeInputType;
end;

function JW3Codec.Decode(Input: variant): variant;
begin
  raise ECodecError.Create('Codec "' + Name + '" does not support Decode');
end;

end.