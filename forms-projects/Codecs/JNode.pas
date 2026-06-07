unit JNode;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3Node — the framework's general typed transform.
//
//  A node has one declared input type and one declared output type and an
//  Encode method that does work. Reversibility is NOT part of this contract;
//  HTTP fetches, DB writes, LLM calls, sinks and taps are all nodes that
//  cannot meaningfully decode.
//
//  Reversibility is opt-in BY INHERITANCE: see JW3Codec (JCodec.pas), which
//  inherits JW3Node and adds Decode. If you can decode, you ARE a codec;
//  if you can't, you stay a plain node. There is no apologetic CanDecode
//  Boolean on every node anymore — the type system says it.
//
//  Pipelines (JPipeline.pas) compose JW3Node. Decode is available on a
//  pipeline only if every step is a JW3Codec.
//
//  The shared type vocabulary + error type live here (the lower unit), so
//  nodes that never know about codecs can still talk types and fail
//  loudly.
//
//  Phase-1 contract is synchronous. From Phase 2 onwards the node
//  primitive returns JPromise — sync nodes become a one-line degenerate
//  case (`JPromise.resolve(value)`). One hierarchy, async as the general
//  case. See readme.md "Roadmap".
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses NodeTypes;   // for JPromise (external 'Promise' — global in browser + Node)

type
  // ─── Canonical type vocabulary ─────────────────────────────────────────
  //
  //  Name kept as TCodecType for backward-source-compat with the original
  //  phase-1 demo (FormCodecs); a future rename to TPortType is on the
  //  table once the node abstraction settles.
  //
  TCodecType = (ctText, ctBytes, ctJSON, ctAny);

  // Single framework error type. Pipelines and concrete steps raise this;
  // callers catch one thing.
  ECodecError = class(Exception)
  end;

  // The general typed transform. Concrete classes either inherit JW3Node
  // directly (encode-only stages: HTTP, DB, LLM, sink, tap) or inherit
  // JW3Codec (reversible: JSON, Base64, Hex, …).
  //
  // Phase 2: Encode is async by default. Sync codecs return
  // JPromise.resolve(value) — a one-line degenerate case. One hierarchy.
  JW3Node = class
  public
    function Name:              String;     virtual; abstract;
    function EncodeInputType:   TCodecType; virtual; abstract;
    function EncodeOutputType:  TCodecType; virtual; abstract;
    function Encode(Input: variant): JPromise; virtual; abstract;
  end;

// ─── Helpers ─────────────────────────────────────────────────────────────

function CodecTypeName(T: TCodecType): String;
function CodecTypesCompatible(Producer, Consumer: TCodecType): Boolean;

// Build a rejected JPromise carrying a JS Error with the given message.
// Use from inside an async pipeline / codec when try/except cannot propagate
// reliably (CLAUDE.md: try/except does not actually re-raise — return
// JPromise.reject explicitly).
function JPromiseReject(const AMessage: String): JPromise;

implementation

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
            (Producer = ctAny)    or
            (Consumer = ctAny);
end;

function JPromiseReject(const AMessage: String): JPromise;
begin
  asm
    @Result = Promise.reject(new Error(@AMessage));
  end;
end;

end.
