unit JPipeline;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3Pipeline — Linear composition of codecs.
//
//  A pipeline is an ordered list of codecs.  Calling Encode walks the list
//  left-to-right; calling Decode walks it right-to-left (and requires
//  every codec to support decoding).
//
//  Assembly-time type validation:
//
//    When you call .Validate (or any .Encode / .Decode), the pipeline
//    checks that every adjacent pair has compatible types:
//
//        steps[i].EncodeOutputType  ==  steps[i+1].EncodeInputType
//
//    If not, it raises ECodecError naming the two offending codecs and the
//    types that didn't match.  This fails LOUD at construction time
//    instead of silently corrupting data at runtime.
//
//  Fluent construction:
//
//    var P := JW3Pipeline.Create('encode-payload');
//    P.Add(JW3CodecJSON.Create)
//     .Add(JW3CodecBase64.Create)
//     .Add(JW3CodecHex.Create);
//
//    var Encoded := P.Encode(SomeObject);
//    var Roundtripped := P.Decode(Encoded);   // back to SomeObject
//
//  Ownership:
//
//    The pipeline OWNS the codecs you add to it.  Calling P.Free frees
//    every codec in the chain.  Don't add the same codec instance to
//    two pipelines.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  JCodec;

type
  JW3Pipeline = class
  private
    FName:  String;
    FSteps: array of JW3Codec;
  public
    constructor Create(AName: String = '');
    destructor  Destroy; override;

    // Fluent — returns Self for chaining.
    function Add(Codec: JW3Codec): JW3Pipeline;

    // Direction-aware execution. Both raise ECodecError on type mismatch
    // or on any codec's internal failure (with a message identifying the
    // offending step).
    function Encode(Input: variant): variant;
    function Decode(Input: variant): variant;

    // True if every step supports Decode.
    function CanDecode: Boolean;

    // Number of codecs in the chain.
    function StepCount: Integer;

    // Human-readable summary, e.g.
    //   'JSON[json→text] → Base64[text→text] → Hex[text→text]'
    function Describe: String;

    // Returns '' if assembly is valid, otherwise a diagnostic string
    // ('step 2 "Base64" outputs text but step 3 "JSON" expects json').
    function Validate: String;

    property Name: String read FName;
  end;

implementation


constructor JW3Pipeline.Create(AName: String = '');
begin
  inherited Create;
  FName := AName;
  // FSteps is already an empty array by default
end;

destructor JW3Pipeline.Destroy;
var i: Integer;
begin
  for i := 0 to High(FSteps) do
    FSteps[i].Free;
  FSteps.Clear;
  inherited;
end;

function JW3Pipeline.Add(Codec: JW3Codec): JW3Pipeline;
begin
  FSteps.Add(Codec);
  Result := Self;
end;

function JW3Pipeline.StepCount: Integer;
begin
  Result := Length(FSteps);
end;

function JW3Pipeline.CanDecode: Boolean;
var i: Integer;
begin
  if Length(FSteps) = 0 then begin Result := True; exit; end;
  for i := 0 to High(FSteps) do
    if not FSteps[i].CanDecode then begin Result := False; exit; end;
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

function JW3Pipeline.Encode(Input: variant): variant;
var
  i: Integer;
  Cur: variant;
  Err: String;
begin
  Err := Validate;
  if Err <> '' then
    raise ECodecError.Create(Err);

  Cur := Input;
  for i := 0 to High(FSteps) do
  begin
    try
      Cur := FSteps[i].Encode(Cur);
    except
      on E: Exception do
        raise ECodecError.Create(
          'Encode failed at step ' + IntToStr(i + 1) +
          ' "' + FSteps[i].Name + '": ' + E.Message);
    end;
  end;
  Result := Cur;
end;

function JW3Pipeline.Decode(Input: variant): variant;
var
  i: Integer;
  Cur: variant;
  Err: String;
begin
  if not CanDecode then
    raise ECodecError.Create('Pipeline "' + FName +
      '" cannot decode — at least one step is encode-only');

  // Type-check the decode direction (reverse).
  for i := High(FSteps) downto 1 do
  begin
    if not CodecTypesCompatible(
             FSteps[i].DecodeOutputType,
             FSteps[i - 1].DecodeInputType) then
    begin
      Err := 'Decode type mismatch between step ' + IntToStr(i + 1) +
             ' "' + FSteps[i].Name + '" (decode output ' +
             CodecTypeName(FSteps[i].DecodeOutputType) +
             ') and step ' + IntToStr(i) +
             ' "' + FSteps[i - 1].Name + '" (decode input ' +
             CodecTypeName(FSteps[i - 1].DecodeInputType) + ')';
      raise ECodecError.Create(Err);
    end;
  end;

  Cur := Input;
  for i := High(FSteps) downto 0 do
  begin
    try
      Cur := FSteps[i].Decode(Cur);
    except
      on E: Exception do
        raise ECodecError.Create(
          'Decode failed at step ' + IntToStr(i + 1) +
          ' "' + FSteps[i].Name + '": ' + E.Message);
    end;
  end;
  Result := Cur;
end;

end.
