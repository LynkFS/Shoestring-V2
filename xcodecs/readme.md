# Codec library for Shoestring-V2 — MVP

A typed, composable transform primitive for Shoestring-V2. This is **phase 1** of a larger plan that ends in a JSON-defined dataflow graph runtime for LUWs (Logical Units of Work). The MVP is small on purpose — just enough to prove the design before more is built on top of it.

## Why codecs first

The earlier conversation flirted with grand architecture (FBP, headless agents, graph DSLs). The first thing actually worth shipping is the smallest typed primitive every later layer needs: a transform with declared input and output types that can be composed and type-checked at assembly time.

This MVP delivers exactly that. Nothing more.

## What you get

```text
helpers/JCodec.pas        Base class JW3Codec, type vocabulary, ECodecError
helpers/JCodecJSON.pas    ctJSON ↔ ctText (JSON.stringify / parse)
helpers/JCodecBase64.pas  ctText ↔ ctText, UTF-8 safe, works in browser + Node
helpers/JCodecHex.pas     ctText ↔ ctText, lowercase hex
helpers/JPipeline.pas     Linear chain, assembly-time type validation, .Describe
forms/FormCodecs.pas      Sidebar demo (JSON / Base64 / Hex / Pipeline / Type check / Roadmap)