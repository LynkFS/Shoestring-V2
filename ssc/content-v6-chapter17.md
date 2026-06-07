# Chapter 17: The Compile Toolchain

## The Problem

ShoeString-V2 source is Object Pascal. Browsers and Node.js run JavaScript. Something has to translate. Smart Mobile Studio did it for a decade and is now defunct. The compiler it was built on, however, is open source and still maintained.

This chapter documents how to build a self-contained Pascal-to-JavaScript toolchain for ShoeString-V2 from current parts: one command-line compiler (`ssc.exe`), one long-running HTTP compile service (`sscserver.exe`), and the three open-source libraries they sit on.

## The Components

**DWScript.** The compiler. Object Pascal lexer, parser, type checker, and JavaScript code generator. Originally the engine inside Smart Mobile Studio; the JS code generator that Optimale Systemer extended into SMS is closed-source, but DWScript's own `dwsJSCodeGen` remains open and is what we use here.

Source: `github.com/EricGrange/DWScript`. Clone the repo; do not build it as a library. It compiles into the host program directly from source via the search path.

License: MPL 1.1 for the core, GPL v3 for the JS code generator. The GPL clause matters: running the compiler as a network service is **not distribution** and does not trigger source-disclosure obligations. Shipping the compiler binary to end users does. The architecture below stays on the safe side of that line.

**mORMot (SynZip only).** One transitive dependency. DWScript's `dwsJSRTL` registers JS implementations for the Pascal RTL, including the zip functions, and pulls in `SynZip.pas` from the Synopse mORMot tree. ShoeString-V2 never calls zip, but the unit has to resolve at compile time.

Source: `github.com/synopse/mORMot`. Clone alongside DWScript. Add the folder containing `SynZip.pas` to the project search path. No other mORMot units are needed for ShoeString-V2; if the build asks for more, it means a code path was enabled that ShoeString-V2 does not use, and the registration can be trimmed in `dwsJSRTL`.

License: MPL/GPL/LGPL tri-license. Same disposition as DWScript — network service use does not distribute the binary.

**Indy.** The HTTP server inside `sscserver.exe`. `TIdHTTPServer` listens on a port, dispatches requests on its own thread pool, serves static files, and routes `/compile` to the compiler.

Source: ships with Delphi Community Edition 12. No download required. The version field in the About box reads `Internet Direct (Indy) 10.6.2.0`.

License: dual MIT-style / Indy License. Permissive; no obligations beyond attribution.

**Delphi Community Edition 12.** Builds the two host executables. Free for individuals and small teams under the revenue cap stated in its EULA. Use the Win64 target — Win32 works but is the wrong shape for a server.

## The Two Products

**`ssc.exe` — the CLI compiler.** A console app that takes a source root and an entrypoint, resolves the unit graph on demand, runs the DWScript compiler, runs the JS code generator, writes one `.js` file.

```
ssc.exe <rootDir> <mainFile.pas> <output.js> [--debug]
```

For ShoeString-V2's kitchen-sink demo:

```
ssc.exe .\Shoestring-V2 .\Shoestring-V2\app.entrypoint.pas app.js
```

Produces approximately 615 KB of JavaScript. With `--debug` added, approximately 960 KB — source-location comments retained, range checks and other safety code kept in. Compile time on a current desktop: under one second for 87 units.

**`sscserver.exe` — the active compiler.** The same pipeline, exposed over HTTP. One process, one port, two endpoints:

```
GET /compile?root=<dir>&main=<file.pas>[&debug=1]
   -> { "ok": true, "bytes": 615118, "messages": [ ... ] }
   -> { "ok": false, "error": "...", "messages": [ ... ] }

GET /<anything>
   -> static file from the web root (./www by default)
```

The compile endpoint writes `app.js` into the web root, so the same origin that compiles also serves. Codecs, async fetch, anything requiring real HTTP — works. The compiler is not reentrant; concurrent requests are serialized by a critical section.

Both products are the same DWScript setup. The CLI is the simplest possible host for one-shot builds. The server is the foundation for an editor, an IDE, or any agent that compiles repeatedly.

## Reproducing the Build

1. **Install Delphi CE 12.** Free download from Embarcadero. During install, include the Windows 64-bit platform. (CE selects Win32 + iOS by default; add Win64 via Tools → Manage Platforms if missed.)

2. **Clone the dependencies** into one workspace:

```
git clone https://github.com/EricGrange/DWScript.git
git clone https://github.com/synopse/mORMot.git
```

3. **Create a new Win64 Console Application.** Set the project's search path under *All configurations – All platforms* (Project → Options → Building → Delphi Compiler → Search path):

```
<workspace>\DWScript\Source
<workspace>\DWScript\Source\SourceUtils
<workspace>\DWScript\Source\external
<workspace>\DWScript\Libraries\JSCodeGen
<workspace>\DWScript\Libraries\ClassesLib
<workspace>\DWScript\Libraries\BigIntegersLib
<workspace>\DWScript\Libraries\SimpleServer
<path-to>\SynZip
```

4. **Build `ssc.exe`.** Drop the `ssc.dpr` source into the project, build, run against ShoeString-V2:

```
ssc.exe .\Shoestring-V2 .\Shoestring-V2\app.entrypoint.pas app.js
```

A `615 KB` `app.js` and a few harmless hints (`Result is never used`, unused locals) means the toolchain is working.

5. **Build `sscserver.exe`.** Same project template, same search path. Add `sscserver.dpr`. Indy needs no extra paths — it is registered in CE. Build, run:

```
sscserver.exe
```

Defaults: port 8080, web root `.\www`. Trigger a compile:

```
http://localhost:8080/compile?root=<full path>&main=<full path>\app.entrypoint.pas
```

Then open `http://localhost:8080/index.html` — the kitchen sink renders.

## Compiler Options That Matter

ShoeString-V2 uses anonymous methods extensively, so `coAllowClosures` must be set, otherwise the JS code generator rejects the program. The other relevant flags:

```pascal
DWS.Config.CompilerOptions :=
  DWS.Config.CompilerOptions
    + [coSymbolDictionary, coContextMap]   // required for codegen
    + [coOptimize, coAllowClosures];
if not Debug then
  DWS.Config.CompilerOptions := DWS.Config.CompilerOptions - [coAssertions];
```

And on the code generator:

```pascal
codeGen.Options := codeGen.Options
  + [cgoNoRangeChecks,
     cgoNoCheckInstantiated,
     cgoNoCheckLoopStep,
     cgoNoConditions,
     cgoNoSourceLocations,
     cgoOptimizeForSize];
```

For debug builds, omit `cgoNoSourceLocations` to keep the source-location comments that map errors back to Pascal lines.

## The Unit Resolver

DWScript has no concept of the filesystem. It calls back via `OnNeedUnit` whenever a `uses` clause names a unit it has not seen. The host registers a callback, hands back the source text:

```pascal
function TUnitResolver.NeedUnit(const unitName: string;
                                var unitSource: string): IdwsUnit;
var Path: string;
begin
  Result := nil;
  if FIndex.TryGetValue(LowerCase(unitName), Path) then
    unitSource := TFile.ReadAllText(Path, TEncoding.UTF8);
end;
```

The index is built once by scanning the source root recursively for `*.pas`. Stem-keyed, case-insensitive. ShoeString-V2's 87 units have no filename collisions, so a flat index is sufficient. The resolver runs lazily — units not reached through the `uses` graph are never read.

## Licensing Summary

Three libraries, three licenses. None of them require source disclosure when the resulting binary is used as a network service.

- DWScript core: MPL 1.1. Permissive, file-level copyleft on modifications to DWScript's own source.
- DWScript JS code generator: GPL v3. Triggers on distribution of the binary; running as a service is not distribution.
- mORMot SynZip: MPL/GPL/LGPL tri-license. Same disposition.
- Indy: MIT-style. Attribution only.
- Delphi CE: free under the revenue cap in its EULA.

The architecture — compile on a server, serve JavaScript to clients — keeps every license obligation on the manageable side. Distributing `ssc.exe` or `sscserver.exe` to third parties re-engages the GPL v3 clause and warrants legal review at that point.

## What This Enables

A Pascal-to-JavaScript pipeline that does not depend on Smart Mobile Studio, runs on a single Windows server, builds with free tooling, and produces platform-neutral output every browser and Node.js runtime accepts.

`ssc.exe` is the foundation for build scripts, CI runs, and offline development.

`sscserver.exe` is the foundation for a web IDE, an LLM-driven coding assistant, a live-reload preview, an agent that compiles on every keystroke. Everything ShoeString-V2 wants to be next sits on top of this one binary.
