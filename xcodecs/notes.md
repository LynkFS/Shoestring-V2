# Working notes — Shoestring-V2 Codec MVP

## Current state of /mnt/session/outputs/

Done:
- NOTES.md (this file)
- helpers/JCodec.pas         — base class JW3Codec + TCodecType enum + ECodecError
- helpers/JCodecJSON.pas     — JW3CodecJSON: ctJSON ↔ ctText (JSON.stringify/parse)
- helpers/JCodecBase64.pas   — JW3CodecBase64: ctText ↔ ctText, UTF-8 safe, Node+browser
- helpers/JCodecHex.pas      — JW3CodecHex: ctText ↔ ctText, lowercase hex
- helpers/JPipeline.pas      — JW3Pipeline: fluent .Add(), .Encode/.Decode, assembly-time .Validate, .Describe, owns codecs
- forms/FormCodecs.pas       — TFormCodecs demo with sidebar (JSON/Base64/Hex/Pipeline/TypeCheck/Roadmap)

Still to write:
- app.entrypoint.snippet.pas — exact lines to paste
- README.md                  — plan, integration, roadmap

## Architectural recap (decisions made)

- Codec is a class (JW3Codec) with Encode always + optional Decode (override CanDecode).
- Type vocabulary: ctText, ctBytes, ctJSON, ctAny. Pipelines validate at assembly time, fail loud.
- Pipeline owns codecs (frees them in destructor). Fluent .Add() returns Self for chaining.
- MVP is sync only. Async = phase 2 with JW3AsyncCodec returning JPromise.

## Roadmap (for the README)

- Phase 1: Sync MVP (Done).
- Phase 2: Async codecs (LLM, WebCrypto), stateful/chunked codecs (AES-GCM, gzip), Reset() and Flush().
- Phase 3: JSON-DSL graph loader. Define a LUW (Logical Unit of Work) in JSON, instantiate the graph.
- Phase 4: Graph runtime (fan-out, fan-in, conditional routing, error edges, retries).
- Phase 5: Observability. Single event bus for lifecycle (started, completed, duration). Tap nodes.

## README structure

1. Why starting with codecs is the right starting place. Brief why.
2. The plan (5 phases). Concise table.
3. What I built (file list).
4. Where to drop the files.
5. The exact lines to add to app.entrypoint.pas.
6. What's deliberately NOT in the MVP and why (async, state, DSL, graph, observability).
7. Hand-off question: pick a real LUW (Performance Audit or Sales Lead) for the first event-modelling pass. The framework needs a real process to grow around.

## Quirks I followed (don't second-guess)

- All constructors override Create(Parent: TElement) with inherited(Parent) — never inherited;
- procedure(Sender: TObject) begin ... end; for OnClick (works AND captures closure)
- procedure(Sender: TObject; Value: String) begin ... end; for OnSelect (or method ref like FNav.OnSelect := HandleNavSelect)
- SetText / SetHTML — never SetInnerText
- #$2192 for →, #$2014 for —, #$00E9 for é, #$00EF for ï — never raw UTF-8 in string literals
- No #<non-digit> anywhere in asm blocks (lexer trap)
- (@Var).method() in asm when chaining; bare @Var otherwise
- Pascal types with default values can't be const — used AIndent: Integer = 0 (not const)
- All type decls in one block before any function bodies in implementation.