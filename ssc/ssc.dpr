program ssc;

{$APPTYPE CONSOLE}

{ ============================================================================

  ssc  -  ShoeString-V2 -> JavaScript compiler host

  A thin Delphi console program that embeds the DWScript compiler and its
  JavaScript code generator, resolves the ShoeString-V2 unit tree from disk,
  compiles a main script, and writes one .js file.

  Pipeline:
      configure compiler  ->  resolve units on demand  ->  compile
      ->  run JS codegen  ->  write output

  Build: Delphi XE2 (or Delphi 12 CE). No VCL / FMX. Add the DWScript
  Source directory (and Source\JSLibModule, Source\JSCodeGen) to your
  project search path.

  ----------------------------------------------------------------------------
  VERIFY AGAINST YOUR DWSCRIPT SNAPSHOT
  ----------------------------------------------------------------------------
  DWScript's public API is stable in shape but a handful of identifiers have
  drifted across versions. Before trusting this verbatim, open the JS codegen
  demo that ships in your snapshot (look under Demos\ for a project that uses
  TdwsJSCodeGen) - that demo is the ground truth for YOUR exact version. The
  items most likely to need adjustment are marked  <<VERIFY>>  below:

    1. The unit list (some RTL-registration units differ by version).
    2. TdwsJSCodeGen option-set member names (cgoXxx).
    3. The OnNeedUnit signature's string type (String vs UnicodeString).
    4. Whether smart-linking is an Option flag or an explicit call.

  ============================================================================ }

uses
  SysUtils,
  Classes,
  Types,            // TStringDynArray
  IOUtils,
  Generics.Collections,

  // --- DWScript core compiler -------------------------------------------- <<VERIFY>>
  dwsComp,         // TDelphiWebScript
  dwsCompiler,         // TdwsConfiguration, TdwsOnNeedUnitEvent
  dwsCompilerContext,  // TCompilerOption / TCompilerOptions, co* constants
  dwsExprs,        // IdwsProgram
  dwsErrors,       // message lists
  dwsSymbols,
  dwsUnitSymbols,  // IdwsUnit  (return type of OnNeedUnit)
  dwsUtils,

  // --- RTL function registration (scripts that call IntToStr, etc.) ------ <<VERIFY>>
  // Including these units registers the corresponding System functions.
  // ShoeString-V2 uses very little of System, but include the common ones.
  dwsMathFunctions,
  dwsStringFunctions,
  dwsTimeFunctions,
  dwsVariantFunctions,

  // --- JavaScript target ------------------------------------------------- <<VERIFY>>
  dwsJSLibModule,  // TdwsJSLibModule  - enables 'asm' blocks + JS bridge
  dwsCodeGen,      // TdwsCodeGen base, TdwsCodeGenOptions (cgoXxx)
  dwsJSCodeGen,    // TdwsJSCodeGen
  dwsJSRTL;        // registers JS implementations of RTL functions


// ============================================================================
//  Unit resolver
//
//  Scans the ShoeString-V2 root once, indexing every .pas by its filename
//  stem (lowercased). DWScript drives resolution lazily: each 'uses' clause
//  fires OnNeedUnit for names not yet seen, and we hand back the source text.
//  Only units actually reached from the main script's uses graph are loaded,
//  so unreachable folders (e.g. node/ when building a browser app) cost
//  nothing.
// ============================================================================
type
  TUnitResolver = class
  private
    FIndex: TDictionary<string, string>;  // unitname(lower) -> full path
    FLoaded: TStringList;                  // for a load report
  public
    constructor Create(const RootDir: string);
    destructor Destroy; override;

    // DWScript OnNeedUnit hook.                                      <<VERIFY>>
    // Signature across versions:
    //   function(const unitName: String; var unitSource: String): IdwsUnit
    // Returning nil + setting unitSource tells the compiler to compile the
    // supplied source AS that unit.
    function NeedUnit(const unitName: string;
                      var unitSource: string): IdwsUnit;

    procedure ReportLoaded;
    property Loaded: TStringList read FLoaded;
  end;


constructor TUnitResolver.Create(const RootDir: string);
var
  Files: TStringDynArray;
  FullPath, Stem: string;
begin
  inherited Create;
  FIndex  := TDictionary<string, string>.Create;
  FLoaded := TStringList.Create;

  if not TDirectory.Exists(RootDir) then
    raise Exception.CreateFmt('Root directory not found: %s', [RootDir]);

  // Recurse the whole tree. No filename collisions in ShoeString-V2, so a
  // flat stem index is safe; we still warn if a collision ever appears.
  Files := TDirectory.GetFiles(RootDir, '*.pas', TSearchOption.soAllDirectories);
  for FullPath in Files do
  begin
    Stem := LowerCase(TPath.GetFileNameWithoutExtension(FullPath));
    if FIndex.ContainsKey(Stem) then
      Writeln(ErrOutput, Format(
        'WARNING: duplicate unit name "%s"' + sLineBreak +
        '         keeping: %s' + sLineBreak +
        '         ignoring: %s',
        [Stem, FIndex[Stem], FullPath]))
    else
      FIndex.Add(Stem, FullPath);
  end;

  Writeln(ErrOutput, Format('Indexed %d units under %s', [FIndex.Count, RootDir]));
end;

destructor TUnitResolver.Destroy;
begin
  FIndex.Free;
  FLoaded.Free;
  inherited;
end;

function TUnitResolver.NeedUnit(const unitName: string;
                                var unitSource: string): IdwsUnit;
var
  Path: string;
begin
  Result := nil;  // we provide SOURCE, not a native IdwsUnit
  if FIndex.TryGetValue(LowerCase(unitName), Path) then
  begin
    // Load as UTF-8; ShoeString-V2 files carry a BOM, which TFile handles.
    unitSource := TFile.ReadAllText(Path, TEncoding.UTF8);
    FLoaded.Add(Format('%-28s %s', [unitName, Path]));
  end
  else
  begin
    // Leave unitSource empty -> compiler raises a clean "unit not found".
    unitSource := '';
    Writeln(ErrOutput, Format('  unresolved unit: %s', [unitName]));
  end;
end;

procedure TUnitResolver.ReportLoaded;
var
  S: string;
begin
  Writeln(ErrOutput, Format('Loaded %d units:', [FLoaded.Count]));
  for S in FLoaded do
    Writeln(ErrOutput, '  ' + S);
end;


// ============================================================================
//  Error reporting
// ============================================================================
procedure DumpMessages(const prog: IdwsProgram);
var
  i: Integer;
begin
  for i := 0 to prog.Msgs.Count - 1 do
    Writeln(ErrOutput, prog.Msgs.Msgs[i].AsInfo);
end;


// ============================================================================
//  Main
// ============================================================================
var
  RootDir, MainFile, OutFile, MainSource, JS: string;
  Resolver: TUnitResolver;
  DWS: TDelphiWebScript;
  JSLib: TdwsJSLibModule;
  prog: IdwsProgram;
  codeGen: TdwsJSCodeGen;
  Debug: Boolean;

begin
  try
    // ---- arguments -------------------------------------------------------
    // ssc <rootDir> <mainFile.pas> <output.js> [--debug]
    if ParamCount < 3 then
    begin
      Writeln(ErrOutput,
        'usage: ssc <rootDir> <mainFile.pas> <output.js> [--debug]');
      Writeln(ErrOutput,
        'example: ssc .\Shoestring-V2 .\Shoestring-V2\app.entrypoint.pas app.js');
      Halt(2);
    end;

    RootDir  := ParamStr(1);
    MainFile := ParamStr(2);
    OutFile  := ParamStr(3);
    Debug    := FindCmdLineSwitch('debug', True);

    if not TFile.Exists(MainFile) then
      raise Exception.CreateFmt('Main file not found: %s', [MainFile]);

    // app.entrypoint.pas is a uses-clause plus top-level statements - that
    // is exactly a DWScript main program body, so feed it verbatim.
    MainSource := TFile.ReadAllText(MainFile, TEncoding.UTF8);

    // ---- compiler --------------------------------------------------------
    Resolver := TUnitResolver.Create(RootDir);
    DWS      := TDelphiWebScript.Create(nil);
    JSLib    := TdwsJSLibModule.Create(nil);
    try
      // Enable 'asm' blocks and the JS bridge (Globals.pas, codecs, etc.).
      JSLib.Script := DWS;

      // Wire the on-demand unit resolver.                           <<VERIFY>>
      DWS.OnNeedUnit := Resolver.NeedUnit;

      // Compiler options. coSymbolDictionary + coContextMap are required for
      // the codegen / smart-linking to have the symbol information it needs.
      // coAllowClosures: ShoeString-V2 uses anonymous methods extensively, so
      //   the JS codegen needs closure capture enabled.
      // coAssertions: keep or drop script-level Assert(); drop for release.
      DWS.Config.CompilerOptions :=
        DWS.Config.CompilerOptions
          + [coSymbolDictionary, coContextMap]
          + [coOptimize, coAllowClosures, coAllowAsyncAwait];
      if not Debug then
        DWS.Config.CompilerOptions := DWS.Config.CompilerOptions - [coAssertions];

      // ---- compile -------------------------------------------------------
      Writeln(ErrOutput, 'Compiling ' + MainFile + ' ...');
      prog := DWS.Compile(MainSource);

      if Debug then
        Resolver.ReportLoaded;

      if prog.Msgs.HasErrors then
      begin
        Writeln(ErrOutput, '--- COMPILE FAILED ---');
        DumpMessages(prog);
        Halt(1);
      end;

      // Surface hints/warnings but continue.
      if prog.Msgs.Count > 0 then
        DumpMessages(prog);

      // ---- generate JavaScript ------------------------------------------
      codeGen := TdwsJSCodeGen.Create;
      try
        // Codegen options.                                          <<VERIFY>>
        // - keep source locations in DEBUG (needed for any source-map work)
        // - in RELEASE, optimise for size and strip checks
        if Debug then
        begin
          codeGen.Options := codeGen.Options
            - [cgoNoSourceLocations];      // emit source-location comments
        end
        else
        begin
          codeGen.Options := codeGen.Options
            + [cgoNoRangeChecks,
               cgoNoCheckInstantiated,
               cgoNoCheckLoopStep,
               cgoNoConditions,
               cgoNoSourceLocations,
               cgoOptimizeForSize];
        end;

        // Compile the whole program graph, then fetch the emitted JS.
        // Smart-linking (dead-code elimination) is driven by the symbol
        // dictionary enabled above; if your snapshot exposes it as an
        // explicit Option flag instead, add it here.                <<VERIFY>>
        Writeln(ErrOutput, 'Generating JavaScript ...');
        codeGen.CompileProgram(prog);
        JS := codeGen.CompiledOutput(prog);

        TFile.WriteAllText(OutFile, JS, TEncoding.UTF8);
        Writeln(ErrOutput, Format('Wrote %s (%d bytes)',
          [OutFile, Length(JS)]));
      finally
        codeGen.Free;
      end;

      // Release the compiled program interface BEFORE the owning script is
      // freed, otherwise DWScript's leak guard raises EdwsActivePrograms
      // ("still has N active IdwsProgram instance(s)") during teardown.
      prog := nil;

    finally
      JSLib.Free;
      DWS.Free;
      Resolver.Free;
    end;

  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName + ': ' + E.Message);
      Halt(1);
    end;
  end;
end.
