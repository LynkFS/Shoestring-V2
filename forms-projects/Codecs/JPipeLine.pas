unit JPipeline;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3Pipeline — Linear composition of nodes.
//
//  A pipeline is an ordered list of JW3Node steps. Encode walks left-to-
//  right; Decode walks right-to-left AND requires every step to be a
//  JW3Codec (i.e. the reversible subclass of JW3Node). If even one step
//  is a plain JW3Node, the pipeline is encode-only — reported honestly
//  by CanDecode and refused by Decode.
//
//  Assembly-time type validation:
//
//    For Encode: every adjacent pair must satisfy
//        steps[i].EncodeOutputType  ==  steps[i+1].EncodeInputType
//
//    For Decode (when every step is a JW3Codec): walked in reverse using
//    each codec's DecodeInputType / DecodeOutputType.
//
//    Either failure raises ECodecError naming the offending pair. Loud at
//    construction time beats silently corrupting data at runtime.
//
//  Fluent construction:
//
//    var P := JW3Pipeline.Create('encode-payload');
//    P.Add(JW3CodecJSON.Create)         // JW3Codec (reversible)
//     .Add(JW3CodecBase64.Create)       // JW3Codec
//     .Add(JW3CodecHex.Create);         // JW3Codec
//
//  Mixing a plain JW3Node into the chain is allowed (e.g. a tap or a
//  one-way sink) — Encode keeps working; CanDecode returns False.
//
//  Ownership:
//    The pipeline OWNS the nodes you add. Free the pipeline and every
//    step is freed. Don't add the same instance to two pipelines.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  NodeTypes, JNode, JCodec;

type
  JW3Pipeline = class
  private
    FName:  String;
    FSteps: array of JW3Node;
  public
    constructor Create(AName: String = '');
    destructor  Destroy; override;

    // Accepts any JW3Node — JW3Codec subclasses pass through unchanged.
    function Add(Node: JW3Node): JW3Pipeline;

    // Phase 2: async. Two-line method bodies delegate to unit-level
    // async helpers (DWScript only allows `async` on unit-level
    // functions, never on a class method).
    function Encode(Input: variant): JPromise;
    function Decode(Input: variant): JPromise;

    // True iff every step inherits JW3Codec.
    function CanDecode: Boolean;

    function StepCount: Integer;

    // Accessor for the unit-level async helpers (which cannot reach
    // private fields).
    function StepAt(Index: Integer): JW3Node;

    // Human-readable summary, e.g.
    //   'JSON[json→text] → Base64[text→text] → Hex[text→text]'
    function Describe: String;

    // Returns '' if the encode direction validates, else a diagnostic.
    function Validate: String;

    property Name: String read FName;
  end;

implementation


constructor JW3Pipeline.Create(AName: String = '');
begin
  inherited Create;
  FName := AName;
  // FSteps is already an empty array by default.
end;

destructor JW3Pipeline.Destroy;
var i: Integer;
begin
  for i := 0 to High(FSteps) do
    FSteps[i].Free;
  FSteps.Clear;
  inherited;
end;

function JW3Pipeline.Add(Node: JW3Node): JW3Pipeline;
begin
  FSteps.Add(Node);
  Result := Self;
end;

function JW3Pipeline.StepCount: Integer;
begin
  Result := Length(FSteps);
end;

function JW3Pipeline.StepAt(Index: Integer): JW3Node;
begin
  Result := FSteps[Index];
end;

function JW3Pipeline.CanDecode: Boolean;
var i: Integer;
begin
  if Length(FSteps) = 0 then begin Result := True; exit; end;
  for i := 0 to High(FSteps) do
    if not (FSteps[i] is JW3Codec) then begin Result := False; exit; end;
  Result := True;
end;

function JW3Pipeline.Validate: String;
var
  i: Integer;
  Producer, Consumer: TCodecType;
begin
  Result := '';
  if Length(FSteps) < 2 then exit;

  for i := 0 to High(FSteps) - 1 do
  begin
    Producer := FSteps[i].EncodeOutputType;
    Consumer := FSteps[i + 1].EncodeInputType;
    if not CodecTypesCompatible(Producer, Consumer) then
    begin
      Result := 'Type mismatch between step ' + IntToStr(i + 1) +
                ' "' + FSteps[i].Name + '" (outputs ' + CodecTypeName(Producer) +
                ') and step ' + IntToStr(i + 2) +
                ' "' + FSteps[i + 1].Name + '" (expects ' + CodecTypeName(Consumer) + ')';
      exit;
    end;
  end;
end;

function JW3Pipeline.Describe: String;
var
  i: Integer;
  Step: String;
begin
  Result := '';
  for i := 0 to High(FSteps) do
  begin
    Step := FSteps[i].Name + '[' +
            CodecTypeName(FSteps[i].EncodeInputType)  + #$2192 +
            CodecTypeName(FSteps[i].EncodeOutputType) + ']';
    if Result = '' then
      Result := Step
    else
      Result := Result + ' ' + #$2192 + ' ' + Step;
  end;
end;

// ── Validate the decode direction (called from PipeDecodeImpl). Returns
//    '' if all reverse type-edges are compatible, else a diagnostic.
//    Assumes CanDecode has already been checked by the caller.
function ValidateDecode(APipe: JW3Pipeline): String;
var
  i: Integer;
  C1, C2: JW3Codec;
begin
  Result := '';
  if APipe.StepCount < 2 then exit;

  for i := APipe.StepCount - 1 downto 1 do
  begin
    C1 := APipe.StepAt(i)     as JW3Codec;
    C2 := APipe.StepAt(i - 1) as JW3Codec;
    if not CodecTypesCompatible(C1.DecodeOutputType, C2.DecodeInputType) then
    begin
      Result := 'Decode type mismatch between step ' + IntToStr(i + 1) +
                ' "' + C1.Name + '" (decode output ' +
                CodecTypeName(C1.DecodeOutputType) +
                ') and step ' + IntToStr(i) +
                ' "' + C2.Name + '" (decode input ' +
                CodecTypeName(C2.DecodeInputType) + ')';
      exit;
    end;
  end;
end;

// ── Unit-level async helpers ──────────────────────────────────────────
//
//  Pascal class methods cannot be `async`; CLAUDE.md rule. The Encode /
//  Decode methods on JW3Pipeline are two-line wrappers that call these
//  helpers. We use `Result := JPromiseReject(...); exit;` from inside the
//  except blocks because raising inside an async function does not
//  reliably re-raise — CLAUDE.md note.
//
async function PipeEncodeImpl(APipe: JW3Pipeline; AInput: variant): JPromise;
var
  i:   Integer;
  cur: variant;
  err: String;
begin
  err := APipe.Validate;
  if err <> '' then
  begin
    Result := JPromiseReject(err);
    exit;
  end;

  cur := AInput;
  for i := 0 to APipe.StepCount - 1 do
  begin
    try
      cur := await APipe.StepAt(i).Encode(cur);
    except
      on E: Exception do
      begin
        Result := JPromiseReject(
          'Encode failed at step ' + IntToStr(i + 1) +
          ' "' + APipe.StepAt(i).Name + '": ' + E.Message);
        exit;
      end;
    end;
  end;
  Result := JPromise.resolve(cur);
end;

async function PipeDecodeImpl(APipe: JW3Pipeline; AInput: variant): JPromise;
var
  i:   Integer;
  cur: variant;
  err: String;
  step: JW3Codec;
begin
  if not APipe.CanDecode then
  begin
    Result := JPromiseReject('Pipeline "' + APipe.Name +
      '" cannot decode -- at least one step is a plain JW3Node, not a JW3Codec');
    exit;
  end;

  err := ValidateDecode(APipe);
  if err <> '' then
  begin
    Result := JPromiseReject(err);
    exit;
  end;

  cur := AInput;
  for i := APipe.StepCount - 1 downto 0 do
  begin
    step := APipe.StepAt(i) as JW3Codec;
    try
      cur := await step.Decode(cur);
    except
      on E: Exception do
      begin
        Result := JPromiseReject(
          'Decode failed at step ' + IntToStr(i + 1) +
          ' "' + step.Name + '": ' + E.Message);
        exit;
      end;
    end;
  end;
  Result := JPromise.resolve(cur);
end;

// ── Methods: two-line delegates to the async helpers ──────────────────

function JW3Pipeline.Encode(Input: variant): JPromise;
begin
  Result := PipeEncodeImpl(Self, Input);
end;

function JW3Pipeline.Decode(Input: variant): JPromise;
begin
  Result := PipeDecodeImpl(Self, Input);
end;

end.
