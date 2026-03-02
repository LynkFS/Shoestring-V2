unit NodeTypes;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Types
//
//  External class bindings for browser APIs. These are typed interfaces
//  over JavaScript objects that already exist in the browser. At runtime
//  they cost nothing — no code is emitted. They give the Pascal compiler
//  enough type information to check calls at compile time.
//
//  This unit has no implementation section. Nothing to compile. Nothing
//  to execute. Pure declarations.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type

  JConsole = class external 'Console'
  public
    constructor Create(output, errorOutput: Variant);

    procedure log(data: Variant); overload;
    procedure log(data, data2: Variant); overload;
    procedure log(const data: array of const); overload;

    procedure info(data: Variant); overload;
    procedure info(data: array of Variant); overload;
    procedure error(data: Variant); overload;
    procedure error(data: array of Variant); overload;
    procedure warn(data: Variant); overload;
    procedure warn(data: array of Variant); overload;

    procedure dir(obj: Variant); overload;
    procedure dir(obj: Variant; options: Variant); overload;

    procedure time; overload;
    procedure time(label: Variant); overload;
    procedure timeEnd; overload;
    procedure timeEnd(label: Variant); overload;

    procedure trace(label: Variant); overload;
    procedure trace(label: array of Variant); overload;

    procedure assert(value: Boolean); overload;
    procedure assert(value: Boolean; message: Variant); overload;
    procedure assert(value: Boolean; message: array of Variant); overload;
  end;

  JRequire = class external 'require'
  public
    cache: Variant;
    procedure resolve;
    property extensions: Variant; deprecated;
  end;

  // ── JSON ───────────────────────────────────────────────────────────────

  TJSON = class external 'JSON'
  public
    function Parse(Text: String): variant; overload; external 'parse';
    function Stringify(const Value: variant): String; overload; external 'stringify';
  end;

var
  Console external 'console': JConsole;
  JSON external 'JSON': TJSON;
//var Process external 'process': JNodeProcess;
var Global external 'global': Variant;


// The function 'require' has been replaced by RequireModule because 'require'
// is already used by the global 'require'
function ReqNodeModule(id: string): Variant; external 'require';
var Require external 'require': JRequire;

implementation
end.
