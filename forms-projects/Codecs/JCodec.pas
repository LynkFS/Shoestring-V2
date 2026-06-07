unit JCodec;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3Codec — the REVERSIBLE subclass of JW3Node.
//
//  Inheriting JW3Codec is the contract for "I have a decode direction".
//  There is no CanDecode Boolean — the class hierarchy is the answer:
//
//     JW3Node   (encode only — HTTP, DB, LLM, sink, …)
//        ↓
//     JW3Codec  (encode AND decode — JSON, Base64, Hex, …)
//
//  Pipelines check `is JW3Codec` for the decode path; non-codec stages
//  are valid in the graph but make the pipeline encode-only, which the
//  pipeline reports honestly.
//
//  Asymmetric decode types (input/output) are supported by overriding
//  DecodeInputType / DecodeOutputType; by default they mirror the encode
//  types reversed.
//
//  Phase 1 is sync. Phase 2 keeps this split but lifts Encode/Decode to
//  return JPromise — see readme.md.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses NodeTypes, JNode;

type
  JW3Codec = class(JW3Node)
  public
    // Decode types — default to encode types reversed; subclasses with
    // asymmetric shapes override.
    function DecodeInputType:  TCodecType; virtual;
    function DecodeOutputType: TCodecType; virtual;

    // Phase 2: async by default. Concrete codecs MUST implement this —
    // being a JW3Codec is the promise.
    function Decode(Input: variant): JPromise; virtual; abstract;

    // Stateful / chunked support. One-shot codecs (JSON / Base64 / Hex /
    // AES-GCM one-pass) leave the defaults; chunked codecs (streaming
    // gzip, AES-CTR with manual auth) override.
    //   Reset() — clear internal buffers; codec is reusable.
    //   Flush() — emit any buffered tail; resolves to the final block
    //             (or undefined if nothing buffered).
    procedure Reset;  virtual;
    function  Flush:  JPromise; virtual;
  end;

implementation

function JW3Codec.DecodeInputType: TCodecType;
begin
  Result := EncodeOutputType;
end;

function JW3Codec.DecodeOutputType: TCodecType;
begin
  Result := EncodeInputType;
end;

procedure JW3Codec.Reset;
begin
  // Default: no buffered state to clear. Stateful codecs override.
end;

function JW3Codec.Flush: JPromise;
begin
  // Default: nothing buffered, nothing to emit.
  asm @Result = Promise.resolve(undefined); end;
end;

end.
