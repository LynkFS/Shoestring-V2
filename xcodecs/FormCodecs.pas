unit FormCodecs;

// ═══════════════════════════════════════════════════════════════════════════
//
//  FormCodecs — interactive demo of the codec MVP.
//
//  Sidebar navigation. Each pane runs live encode/decode in the browser.
//
//    JSON        — object ↔ text round-trip
//    Base64      — UTF-8 safe text ↔ text round-trip (works in browser + Node)
//    Hex         — text ↔ text round-trip
//    Pipeline    — object → JSON → Base64 → Hex, and reverse
//    Type check  — deliberately bad pipeline, caught at assembly time
//    Roadmap     — what's next (async codecs, graph DSL, observability)
//
//  Modelled on FormNonVisual.pas — same toolbar + sidebar + display layout.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses
  JForm, JApplication, JElement,
  JPanel, JLabel, JButton, JListBox, JToolbar, JTextArea;

type
  TFormCodecs = class(TW3Form)
  private
    FToolbar: JW3Toolbar;
    FBody:    JW3Panel;
    FNav:     JW3ListBox;
    FDisplay: JW3Panel;

    // Section / output helpers
    function  AddSection(const Title: String): JW3Panel;
    function  AddOutput(Parent: TElement; const Text: String): JW3Label;
    procedure AddCodeHint(Parent: TElement; const Text: String);
    procedure AddBodyText(Parent: TElement; const Text: String);
    function  AddButton(Parent: TElement; const Caption: String): JW3Button;
    function  AddTextarea(Parent: TElement; const Initial: String; Rows: Integer): JW3TextArea;

    // Demos
    procedure ShowJSON;
    procedure ShowBase64;
    procedure ShowHex;
    procedure ShowPipeline;
    procedure ShowTypeCheck;
    procedure ShowRoadmap;

    procedure HandleNavSelect(Sender: TObject; Value: String);
    procedure ShowDemo(const Name: String);
  public
    procedure InitializeObject; override;
  end;

implementation

uses
  Globals, ThemeStyles,
  JCodec, JCodecJSON, JCodecBase64, JCodecHex, JPipeline;


// Local styles (registered once)

var GCodecStyled: Boolean = false;

procedure RegisterStyles;
begin
  if GCodecStyled then exit;
  GCodecStyled := true;
  AddStyleBlock(#'

    .cd-section {
      display: flex;
      flex-direction: column;
      gap: 10px;
      padding: 16px;
      background: var(--surface-color, #fff);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-lg, 8px);
      max-width: 680px;
      width: 100%;
    }

    .cd-section-title {
      font-size: 0.75rem;
      font-weight: 600;
      color: var(--text-light, #64748b);
      text-transform: uppercase;
      letter-spacing: 0.07em;
      padding-bottom: 4px;
      border-bottom: 1px solid var(--border-color, #e2e8f0);
    }

    .cd-output {
      font-family: var(--font-family-mono, monospace);
      font-size: 0.85rem;
      padding: 10px 14px;
      background: var(--surface-2, #f1f5f9);
      border: 1px solid var(--border-color, #e2e8f0);
      border-radius: var(--radius-md, 6px);
      color: var(--text-color, #334155);
      white-space: pre-wrap;
      word-break: break-all;
      min-height: 1.2em;
    }

    .cd-error {
      font-family: var(--font-family-mono, monospace);
      font-size: 0.85rem;
      padding: 10px 14px;
      background: var(--color-danger-bg, #fee2e2);
      border: 1px solid var(--color-danger, #ef4444);
      border-radius: var(--radius-md, 6px);
      color: var(--color-danger, #b91c1c);
      white-space: pre-wrap;
    }

    .cd-code {
      font-family: var(--font-family-mono, monospace);
      font-size: 0.8rem;
      color: var(--text-light, #64748b);
      font-style: italic;
    }

    .cd-body {
      font-size: 0.9rem;
      line-height: 1.5;
      color: var(--text-color, #334155);
    }

    .cd-row {
      display: flex;
      flex-direction: row;
      gap: 8px;
      align-items: center;
      flex-wrap: wrap;
    }
  ');
end;


//==============================================================================
// TFormCodecs — construction
//==============================================================================

procedure TFormCodecs.InitializeObject;
begin
  inherited;
  RegisterStyles;

  // Toolbar
  FToolbar := JW3Toolbar.Create(Self);
  var BtnBack := FToolbar.AddItem('<< Back');
  BtnBack.OnClick := procedure(Sender: TObject)
  begin
    Application.GoToForm('Kitchensink');
  end;

  var Title := JW3Label.Create(FToolbar);
  Title.SetText('Codec Library (MVP)');
  Title.SetStyle('font-weight', '600');
  Title.SetStyle('font-size', '0.9rem');
  Title.SetStyle('padding-left', '8px');

  // Body
  FBody := JW3Panel.Create(Self);
  FBody.SetGrow(1);
  FBody.SetStyle('flex-direction', 'row');

  // Nav sidebar
  FNav := JW3ListBox.Create(FBody);
  FNav.SetStyle('width', '200px');
  FNav.SetStyle('flex-shrink', '0');
  FNav.SetStyle('border-right', '1px solid var(--border-color, #e2e8f0)');

  FNav.AddItem('json',      'JSON');
  FNav.AddItem('base64',    'Base64');
  FNav.AddItem('hex',       'Hex');
  FNav.AddItem('pipeline',  'Pipeline');
  FNav.AddItem('typecheck', 'Type check');
  FNav.AddItem('roadmap',   'Roadmap');

  FNav.OnSelect := HandleNavSelect;

  // Display panel
  FDisplay := JW3Panel.Create(FBody);
  FDisplay.SetGrow(1);
  FDisplay.SetStyle('padding', 'var(--space-6, 24px)');
  FDisplay.SetStyle('overflow', 'auto');
  FDisplay.SetStyle('gap', 'var(--space-4, 16px)');
  FDisplay.SetStyle('align-items', 'flex-start');

  var Hint := JW3Label.Create(FDisplay);
  Hint.SetText('Pick a demo on the left. Each one runs live in your browser.');
  Hint.SetStyle('color', 'var(--text-light, #64748b)');
end;

procedure TFormCodecs.HandleNavSelect(Sender: TObject; Value: String);
begin
  ShowDemo(Value);
end;

procedure TFormCodecs.ShowDemo(const Name: String);
begin
  FDisplay.Clear;

  var Heading := JW3Label.Create(FDisplay);
  Heading.SetStyle('font-size', '1.25rem');
  Heading.SetStyle('font-weight', '700');

  if      Name = 'json'      then begin Heading.SetText('JSON codec');          ShowJSON;      end
  else if Name = 'base64'    then begin Heading.SetText('Base64 codec');        ShowBase64;    end
  else if Name = 'hex'       then begin Heading.SetText('Hex codec');           ShowHex;       end
  else if Name = 'pipeline'  then begin Heading.SetText('Pipeline');            ShowPipeline;  end
  else if Name = 'typecheck' then begin Heading.SetText('Assembly-time check'); ShowTypeCheck; end
  else if Name = 'roadmap'   then begin Heading.SetText('Roadmap');             ShowRoadmap;   end;
end;


//==============================================================================
// Shared display helpers
//==============================================================================

function TFormCodecs.AddSection(const Title: String): JW3Panel;
begin
  Result := JW3Panel.Create(FDisplay);
  Result.AddClass('cd-section');

  if Title <> '' then
  begin
    var T := TElement.Create('div', Result);
    T.AddClass('cd-section-title');
    T.SetText(Title);
  end;
end;

function TFormCodecs.AddOutput(Parent: TElement; const Text: String): JW3Label;
begin
  Result := JW3Label.Create(Parent);
  Result.AddClass('cd-output');
  Result.SetText(Text);
end;

procedure TFormCodecs.AddCodeHint(Parent: TElement; const Text: String);
begin
  var El := TElement.Create('div', Parent);
  El.AddClass('cd-code');
  El.SetText(Text);
end;

procedure TFormCodecs.AddBodyText(Parent: TElement; const Text: String);
begin
  var El := TElement.Create('div', Parent);
  El.AddClass('cd-body');
  El.SetText(Text);
end;

function TFormCodecs.AddButton(Parent: TElement; const Caption: String): JW3Button;
begin
  Result := JW3Button.Create(Parent);
  Result.Caption := Caption;
end;

function TFormCodecs.AddTextarea(Parent: TElement; const Initial: String; Rows: Integer): JW3TextArea;
begin
  Result := JW3TextArea.Create(Parent);
  Result.Rows := Rows;
  Result.Value := Initial;
  Result.SetStyle('font-family', 'var(--font-family-mono, monospace)');
  Result.SetStyle('font-size', '0.85rem');
  Result.SetStyle('width', '100%');
end;


//==============================================================================
// Demo: JSON
//==============================================================================

procedure TFormCodecs.ShowJSON;
begin
  AddBodyText(FDisplay,
    'JSON is the simplest codec: it serialises a parsed object to text and ' +
    'parses text back. Encode goes ctJSON ' + #$2192 + ' ctText, decode reverses.');

  // Encode section
  var Sec1 := AddSection('Encode: object ' + #$2192 + ' text');
  AddCodeHint(Sec1, 'var C := JW3CodecJSON.Create(2); Out := C.Encode(SampleObj);');

  var Out1 := AddOutput(Sec1, '(click Encode)');

  var Btn1 := AddButton(Sec1, 'Encode');
  Btn1.OnClick := procedure(Sender: TObject)
  var
    Sample: variant;
    C:      JW3CodecJSON;
    Text:   variant;
  begin
    asm
      @Sample = {
        name: 'Ada',
        lang: 'Pascal',
        skills: ['DWScript', 'codecs', 'graphs'],
        active: true
      };
    end;
    C := JW3CodecJSON.Create(2);
    try
      Text := C.Encode(Sample);
      Out1.SetText(String(Text));
    finally
      C.Free;
    end;
  end;

  // Decode section
  var Sec2 := AddSection('Decode: text ' + #$2192 + ' object');
  AddCodeHint(Sec2, 'Out := C.Decode(JsonTextFromUser);');

  var TA := AddTextarea(Sec2, '{"name":"Ada","year":1815,"skills":["math","tables"]}', 4);

  var Out2 := AddOutput(Sec2, '(click Decode)');

  var Btn2 := AddButton(Sec2, 'Decode');
  Btn2.OnClick := procedure(Sender: TObject)
  var
    C:        JW3CodecJSON;
    Obj:      variant;
    Pretty:   variant;
  begin
    C := JW3CodecJSON.Create(2);
    try
      try
        Obj := C.Decode(TA.Value);
        // Show the parsed object back as pretty JSON so we can see structure.
        Pretty := C.Encode(Obj);
        Out2.SetText('parsed and re-stringified:'#10 + String(Pretty));
      except
        on E: Exception do
          Out2.SetText('ERROR: ' + E.Message);
      end;
    finally
      C.Free;
    end;
  end;
end;


//==============================================================================
// Demo: Base64
//==============================================================================

procedure TFormCodecs.ShowBase64;
begin
  AddBodyText(FDisplay,
    'Base64 is UTF-8 safe in this implementation. The codec auto-detects ' +
    'Node (Buffer) vs. browser (TextEncoder + btoa).');

  var Sec := AddSection('Round-trip: text ' + #$2192 + ' base64 ' + #$2192 + ' text');
  AddCodeHint(Sec, 'var C := JW3CodecBase64.Create; Encoded := C.Encode(s); Back := C.Decode(Encoded);');

  var TA := AddTextarea(Sec, 'caf' + #$00E9 + ' ' + #$2014 + ' r' + #$00E9 + 'sum' + #$00E9 + ' na' + #$00EF + 've', 3);

  var OutEnc := AddOutput(Sec, '(encoded output)');
  var OutDec := AddOutput(Sec, '(decoded output)');

  var Row := TElement.Create('div', Sec);
  Row.AddClass('cd-row');

  var BtnEnc := AddButton(Row, 'Encode');
  BtnEnc.OnClick := procedure(Sender: TObject)
  var
    C:       JW3CodecBase64;
    Encoded: variant;
    Back:    variant;
  begin
    C := JW3CodecBase64.Create;
    try
      try
        Encoded := C.Encode(TA.Value);
        OutEnc.SetText(String(Encoded));
        Back := C.Decode(Encoded);
        OutDec.SetText(String(Back));
      except
        on E: Exception do
          OutEnc.SetText('ERROR: ' + E.Message);
      end;
    finally
      C.Free;
    end;
  end;

  var BtnClear := AddButton(Row, 'Clear');
  BtnClear.OnClick := procedure(Sender: TObject)
  begin
    OutEnc.SetText('');
    OutDec.SetText('');
  end;
end;


//==============================================================================
// Demo: Hex
//==============================================================================

procedure TFormCodecs.ShowHex;
begin
  AddBodyText(FDisplay,
    'Hex encodes each UTF-8 byte as two lowercase hex digits. Symmetric, ' +
    'no padding, useful for logs and wire-debugging.');

  var Sec := AddSection('Round-trip: text ' + #$2192 + ' hex ' + #$2192 + ' text');
  AddCodeHint(Sec, 'var C := JW3CodecHex.Create; Encoded := C.Encode(s); Back := C.Decode(Encoded);');

  var TA := AddTextarea(Sec, 'Hello, world!', 2);

  var OutEnc := AddOutput(Sec, '(encoded output)');
  var OutDec := AddOutput(Sec, '(decoded output)');

  var Btn := AddButton(Sec, 'Encode + Decode');
  Btn.OnClick := procedure(Sender: TObject)
  var
    C:       JW3CodecHex;
    Encoded: variant;
    Back:    variant;
  begin
    C := JW3CodecHex.Create;
    try
      try
        Encoded := C.Encode(TA.Value);
        OutEnc.SetText(String(Encoded));
        Back := C.Decode(Encoded);
        OutDec.SetText(String(Back));
      except
        on E: Exception do
          OutEnc.SetText('ERROR: ' + E.Message);
      end;
    finally
      C.Free;
    end;
  end;
end;


//==============================================================================
// Demo: Pipeline
//==============================================================================

procedure TFormCodecs.ShowPipeline;
begin
  AddBodyText(FDisplay,
    'A pipeline composes codecs into a chain. Encode walks left-to-right, ' +
    'decode walks right-to-left. The pipeline owns its codecs and validates ' +
    'types at assembly time.');

  var Sec := AddSection('Chain: object ' + #$2192 + ' JSON ' + #$2192 + ' Base64 ' + #$2192 + ' Hex');
  AddCodeHint(Sec,
    'P := JW3Pipeline.Create(''demo'');' +
    'P.Add(JW3CodecJSON.Create).Add(JW3CodecBase64.Create).Add(JW3CodecHex.Create);');

  var OutShape := AddOutput(Sec, '(pipeline shape)');
  var OutEnc   := AddOutput(Sec, '(encoded)');
  var OutDec   := AddOutput(Sec, '(decoded back to JSON text)');

  var Btn := AddButton(Sec, 'Run round-trip');
  Btn.OnClick := procedure(Sender: TObject)
  var
    P:       JW3Pipeline;
    Sample:  variant;
    Enc:     variant;
    Deco:    variant;
  begin
    asm
      @Sample = {
        process: 'sales-lead',
        score:   0.87,
        actions: ['draft-reply','set-warm','queue-followup']
      };
    end;

    P := JW3Pipeline.Create('demo');
    try
      P.Add(JW3CodecJSON.Create)
       .Add(JW3CodecBase64.Create)
       .Add(JW3CodecHex.Create);

      OutShape.SetText(P.Describe);

      try
        Enc := P.Encode(Sample);
        OutEnc.SetText(String(Enc));

        Deco := P.Decode(Enc);
        asm @Deco = JSON.stringify(@Deco, null, 2) end;  //just for display purposes
        OutDec.SetText(String(Deco));
      except
        on E: Exception do
          OutEnc.SetText('ERROR: ' + E.Message);
      end;
    finally
      P.Free;     // frees every codec in the chain
    end;
  end;
end;


//==============================================================================
// Demo: Type check (deliberately bad pipeline)
//==============================================================================

procedure TFormCodecs.ShowTypeCheck;
begin
  AddBodyText(FDisplay,
    'A pipeline validates types at assembly time. If two adjacent codecs ' +
    'are incompatible, you get a clear error before any data flows. This ' +
    'catches bugs at deploy, not at 3am.');

  var Sec := AddSection('Bad chain: Base64 ' + #$2192 + ' JSON.Encode');
  AddCodeHint(Sec,
    '// Base64 outputs text, but JSON.Encode expects ctJSON. ' +
    'Validate catches this and refuses to run.');

  var OutShape := AddOutput(Sec, '(pipeline shape)');
  var OutErr   := JW3Label.Create(Sec);
  OutErr.AddClass('cd-error');
  OutErr.SetText('(click Validate)');

  var Btn := AddButton(Sec, 'Build and Validate');
  Btn.OnClick := procedure(Sender: TObject)
  var
    P:    JW3Pipeline;
    Msg:  String;
  begin
    P := JW3Pipeline.Create('bad-demo');
    try
      P.Add(JW3CodecBase64.Create)   // ctText -> ctText
       .Add(JW3CodecJSON.Create);    // expects ctJSON -> ctText  -- MISMATCH

      OutShape.SetText(P.Describe);

      Msg := P.Validate;
      if Msg = '' then
        OutErr.SetText('(unexpectedly valid)')
      else
        OutErr.SetText(Msg);
    finally
      P.Free;
    end;
  end;
end;


//==============================================================================
// Demo: Roadmap
//==============================================================================

procedure TFormCodecs.ShowRoadmap;
begin
  AddBodyText(FDisplay,
    'What you see here is the v1 MVP. The architecture deliberately leaves ' +
    'room for the next phases without rewrites.');

  var Sec1 := AddSection('Phase 2 ' + #$2014 + ' Async codecs');
  AddBodyText(Sec1,
    'JW3AsyncCodec returning JPromise. Backs WebCrypto AES-GCM, LLM nodes, ' +
    'any I/O-bound transform. Pipeline grows an EncodeAsync / DecodeAsync ' +
    'method. Per the Pascal rules, async lives in top-level helpers; class ' +
    'methods delegate via 2-line bodies.');

  var Sec2 := AddSection('Phase 2 ' + #$2014 + ' Stateful chunking');
  AddBodyText(Sec2,
    'Chunk-buffered codecs for streaming (block ciphers, gzip). Adds ' +
    'Flush() and an internal partial-buffer slot. Pipeline gains a Reset(). ' +
    'The bytes side of the type vocabulary starts paying off.');

  var Sec3 := AddSection('Phase 3 ' + #$2014 + ' JSON-DSL graph loader');
  AddBodyText(Sec3,
    'A JSON blueprint defines nodes (codec instances) and edges (typed ' +
    'connections) of a LUW (Logical Unit of Work). A loader instantiates ' +
    'the graph from event-driven design output: events become typed edges, ' +
    'actors become authorisation boundaries.');

  var Sec4 := AddSection('Phase 4 ' + #$2014 + ' Graph runtime');
  AddBodyText(Sec4,
    'Fan-out, fan-in, conditional routing (when), error edges (onError), ' +
    'timeouts, retries. The orchestrator is the LUW run itself; nodes ' +
    'remain dumb. LLM nodes are one specific node category, not the model.');

  var Sec5 := AddSection('Phase 5 ' + #$2014 + ' Observability');
  AddBodyText(Sec5,
    'Single event bus emitting lifecycle events (started, completed, ' +
    'errored, duration). The debugger UI and the tap node both fall out ' +
    'of this; neither is special-cased.');
end;

end.