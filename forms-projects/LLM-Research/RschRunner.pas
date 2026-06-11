unit RschRunner;

// ═══════════════════════════════════════════════════════════════════════════
//  RschRunner — headless research loop (Node target), P1 Fan-Out.
//
//      node app.js                  research a subject end to end
//      node app.js 2                crash after 2 gathers; rerun resumes
//      CEILING=100 node app.js      tiny ceiling — watch the breaker bite
//
//  The structure is plan → gather (×N) → synthesise, and WE own it:
//    * PLAN   one call decomposes the subject into leads. Each lead is added to
//             the ledger as a 'lead'-status claim, so the ledger is the plan
//             state — resume gathers only the claims not yet promoted.
//    * GATHER one call per lead, with web search ON, returns structured
//             evidence (sources, claim type, causal basis, steelman). Applied
//             to the claim, then Promote runs the gates.
//    * SYNTH  one call writes the verified findings into research-synthesis.md.
//
//  Every call's usage feeds JBudget; the breaker halts a run; the checkpoint is
//  the handoff. Gatherers are independent (star, not mesh) and run sequentially
//  in this cut — true parallelism is a later optimisation.
//
//  Honest limit: the gatherer PROPOSES sources (web search makes them real-ish),
//  but rung-0 gates check that claims are sourced and structured, not that each
//  URL exists. Verifying sources is the next layer.
// ═══════════════════════════════════════════════════════════════════════════

interface

uses NodeTypes, JDataStore, JGates, JLedger, JBudget;

procedure RunResearch;

implementation

const
  CHECKPOINT   = './research-ledger.json';
  SYNTH_FILE   = './research-synthesis.md';
  PROXY_URL    = 'http://localhost:3030';
  MODEL_PLAN   = 'claude-sonnet-4-6';
  MODEL_GATHER = 'claude-haiku-4-5-20251001';
  MODEL_SYNTH  = 'claude-sonnet-4-6';
  SUBJECT      = 'The effects of extended screen time on children''s attention and development.';

type
  TJsonCb = procedure(Data: variant);
  TErrCb  = procedure(Status: Integer; Msg: String);

var
  GFs:               variant;
  GStore:            JW3DataStore;
  GPack:             variant;
  GLedger:           TLedger;
  GBudget:           TBudget;
  GProcessedThisRun: Integer;
  GCrashAfter:       Integer;

function PassStr(b: Boolean): String;
begin
  if b then Result := 'PASS' else Result := 'blocked';
end;

function YN(b: Boolean): String;
begin
  if b then Result := 'yes' else Result := 'no';
end;

// ── checkpoint + synth I/O (Pascal-level so consts inline) ───────────────────

function CheckpointExists: Boolean;
begin
  Result := False;
  if GFs.existsSync(CHECKPOINT) then Result := True;
end;

procedure SaveCheckpoint;
begin
  GFs.writeFileSync(CHECKPOINT, GLedger.ToJSON);
end;

function ReadCheckpoint: String;
begin
  Result := String(GFs.readFileSync(CHECKPOINT, 'utf8'));
end;

procedure WriteSynth(const AText: String);
begin
  GFs.writeFileSync(SYNTH_FILE, AText);
end;

// ── proxy call (Node fetch) — same /v1/chat contract the adapter uses ────────

procedure PostJSONNode(const AUrl, ABody: String; OnResult: TJsonCb; OnError: TErrCb);
begin
  asm
    fetch(@AUrl, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    @ABody
    }).then(function (resp) {
      return resp.text().then(function (t) { return { ok: resp.ok, status: resp.status, text: t }; });
    }).then(function (x) {
      if (x.ok) {
        var d;
        try { d = JSON.parse(x.text); } catch (e) { (@OnError)(x.status, 'bad JSON from proxy'); return; }
        (@OnResult)(d);
      } else {
        (@OnError)(x.status, x.text || 'HTTP error');
      }
    }).catch(function (e) {
      (@OnError)(0, String((e && e.message) || e));
    });
  end;
end;

procedure CallModel(const AModel, ASystem, AUser: String; AWebSearch: Boolean;
                    OnResult: TJsonCb; OnError: TErrCb);
var
  body: String;
begin
  asm
    @body = JSON.stringify({
      provider:          'claude',
      transport:         'api',
      model:             @AModel,
      system:            @ASystem,
      messages:          [{ role: 'user', content: @AUser }],
      maxTokens:         1500,
      temperature:       0.2,
      stream:            false,
      webSearch:         @AWebSearch,
      providerSessionId: ''
    });
  end;
  PostJSONNode(PROXY_URL + '/v1/chat', body, OnResult, OnError);
end;

function ResultText(AData: variant): String;
begin
  asm @Result = String(((@AData) && (@AData).text) || ''); end;
end;

function ResultIn(AData: variant): Integer;
begin
  asm @Result = ((@AData) && (@AData).usage && (@AData).usage.inputTokens) || 0; end;
end;

function ResultOut(AData: variant): Integer;
begin
  asm @Result = ((@AData) && (@AData).usage && (@AData).usage.outputTokens) || 0; end;
end;

// ── tolerant JSON extraction from model text (no regex, no backticks) ────────

function ParseJsonLoose(const AText: String): variant;
begin
  asm
    var s = String(@AText || '');
    var a = s.indexOf('['); var o = s.indexOf('{');
    var start = -1;
    if (a === -1) start = o; else if (o === -1) start = a; else start = Math.min(a, o);
    var endA = s.lastIndexOf(']'); var endO = s.lastIndexOf('}');
    var fin = Math.max(endA, endO);
    var r = null;
    if (start !== -1 && fin !== -1 && fin > start) {
      try { r = JSON.parse(s.slice(start, fin + 1)); } catch (e) { r = null; }
    }
    @Result = r;
  end;
end;

function JsonOk(v: variant): Boolean;
begin
  asm @Result = ((@v) !== null && (@v) !== undefined); end;
end;

function ArrLen(a: variant): Integer;
begin
  asm @Result = (Array.isArray(@a) ? (@a).length : 0); end;
end;

function ItemStr(a: variant; i: Integer; const f: String): String;
begin
  asm @Result = String(((@a)[@i] && (@a)[@i][@f]) || ''); end;
end;

function FieldStr(o: variant; const f: String): String;
begin
  asm @Result = String(((@o) && (@o)[@f]) || ''); end;
end;

function FieldBool(o: variant; const f: String): Boolean;
begin
  asm @Result = ((@o) && (@o)[@f] === true); end;
end;

function VSrcTier(a: variant; i: Integer): Integer;
begin
  asm @Result = ((@a)[@i] && (@a)[@i].tier) || 5; end;
end;

function VSrcOrigin(a: variant; i: Integer): String;
begin
  asm @Result = String(((@a)[@i] && (@a)[@i].origin) || ''); end;
end;

function VSrcUrl(a: variant; i: Integer): String;
begin
  asm @Result = String(((@a)[@i] && (@a)[@i].url) || ''); end;
end;

function VSrcVerified(a: variant; i: Integer): Boolean;
begin
  asm @Result = ((@a)[@i] && (@a)[@i].verified === true); end;
end;

// ── ledger snapshot readers (by index, for the gather walk) ──────────────────

function ClaimsJson: variant;
var
  raw: String;
begin
  raw := String(GStore.Get('ledger.claims'));
  asm @Result = @raw ? JSON.parse(@raw) : []; end;
end;

function ClaimIdAt(a: variant; i: Integer): String;
begin
  asm @Result = String(((@a)[@i] && (@a)[@i].id) || ''); end;
end;

function ClaimStatusAt(a: variant; i: Integer): String;
begin
  asm @Result = String(((@a)[@i] && (@a)[@i].status) || ''); end;
end;

function ClaimTextAt(a: variant; i: Integer): String;
begin
  asm @Result = String(((@a)[@i] && (@a)[@i].text) || ''); end;
end;

// ── apply a gather result onto a claim ───────────────────────────────────────

procedure ApplyGatherFields(const AId: String; AGather: variant);
var
  ct, cb, steel, regst: String;
begin
  ct    := Trim(FieldStr(AGather, 'claimType'));
  cb    := Trim(FieldStr(AGather, 'causalBasis'));
  steel := Trim(FieldStr(AGather, 'steelman'));
  regst := Trim(FieldStr(AGather, 'regulatoryStatus'));

  if ct    <> '' then GLedger.SetField(AId, 'claimType',   ct);
  if cb    <> '' then GLedger.SetField(AId, 'causalBasis', cb);
  if steel <> '' then GLedger.SetField(AId, 'steelman',    steel);
  if regst <> '' then GLedger.SetField(AId, 'regulatoryStatus', regst);
  if FieldBool(AGather, 'predictionsTested') then
    GLedger.SetField(AId, 'predictionsTested', True);
end;

// Fetch each proposed source URL to confirm it resolves; mark .verified and
// hand the augmented sources array to OnDone. A fabricated or dead link comes
// back verified:false and will not count toward the gates. Conservative: a
// non-2xx (including a bot-blocked 403) or a timeout counts as unverified.
procedure VerifySources(AGather: variant; OnDone: TJsonCb);
begin
  asm
    var srcs = ((@AGather) && (@AGather).sources) || [];
    var checks = srcs.map(function (s) {
      var url = s && s.url;
      if (!url) { s.verified = false; return Promise.resolve(s); }
      return fetch(url, { method: 'GET', signal: AbortSignal.timeout(8000) })
        .then(function (r) { s.verified = !!(r && r.ok); return s; })
        .catch(function () { s.verified = false; return s; });
    });
    Promise.all(checks).then(function (arr) { (@OnDone)(arr); });
  end;
end;

// ── the async pipeline: plan → gather (×N) → synthesise ──────────────────────

procedure Finish;
begin
  Console.log('Done. Ledger holds ' + IntToStr(GLedger.ClaimCount)
    + ' claim(s); checkpoint at ' + CHECKPOINT + '.');
end;

procedure DoGatherNext(AStart: Integer); forward;
procedure DoGatherForClaim(AIndex: Integer; const AId, AText: String); forward;
procedure DoSynthesize; forward;

procedure DoPlan;
var
  sys: String;
begin
  Console.log('Planning: ' + SUBJECT);
  sys := 'You are a research planner. Break the subject into 3 to 5 specific, checkable factual '
       + 'claims worth investigating. Phrase each claim at the strength the evidence can bear: '
       + 'prefer associational or descriptive wording such as "is associated with", "studies report", '
       + 'or "the evidence is mixed on", over causal wording such as "causes" or "leads to", unless '
       + 'the subject plausibly has randomised or experimental evidence. Do not overstate. Reply with '
       + 'ONLY a JSON array; each element {"claim": string, "species": one of '
       + '"scientific","marketing","regulatory","forecast"}. No prose, no code fences.';
  CallModel(MODEL_PLAN, sys, SUBJECT, False,
    procedure (Data: variant)
    var
      plan: variant;
      n, i: Integer;
      txt, sp: String;
    begin
      GBudget.RecordUsage(ResultIn(Data), ResultOut(Data));
      plan := ParseJsonLoose(ResultText(Data));
      n := ArrLen(plan);
      if n = 0 then
      begin
        Console.log('Planner returned no parseable claims; stopping.');
        Exit;
      end;
      for i := 0 to n - 1 do
      begin
        txt := Trim(ItemStr(plan, i, 'claim'));
        sp  := Trim(ItemStr(plan, i, 'species'));
        if sp = '' then sp := 'scientific';
        if txt <> '' then GLedger.AddClaim(txt, sp);
      end;
      SaveCheckpoint;
      Console.log('Planned ' + IntToStr(GLedger.ClaimCount) + ' lead(s)  [meter '
        + IntToStr(GBudget.Total) + ' tok]');
      if GBudget.Tripped then begin Console.log('Halted by breaker after planning.'); Exit; end;
      DoGatherNext(0);
    end,
    procedure (Status: Integer; Msg: String)
    begin
      Console.log('Plan call failed (' + IntToStr(Status) + '): ' + Msg);
    end);
end;

procedure DoGatherForClaim(AIndex: Integer; const AId, AText: String);
var
  sys: String;
begin
  Console.log('Gathering for lead ' + IntToStr(AIndex) + ': ' + AText);
  sys := 'You are a research gatherer with web search. Search for the real evidence on the claim and '
       + 'report it HONESTLY: classify by what the claim actually asserts and what you find, never to '
       + 'pass a test. Reply with ONLY a JSON object: '
       + '{"claimType": one of "disease","therapeutic","structure-function","" (use "disease" or '
       + '"therapeutic" ONLY for a genuine causal medical claim for which you found randomised or '
       + 'controlled evidence; otherwise use ""), '
       + '"causalBasis": one of "interventional","observational","mechanism","none","n/a" (use '
       + '"interventional" ONLY if randomised or controlled evidence exists, else "observational" for '
       + 'correlational evidence), '
       + '"steelman": the single strongest opposing reading, '
       + '"regulatoryStatus": string if a regulatory claim else "", '
       + '"predictionsTested": boolean, '
       + '"sources": [{"tier": 1-5 (1=systematic review or RCT, 2=peer-reviewed study, 3=reputable '
       + 'report, 4=primary document, 5=social post), "origin": short independence key, "url": a real '
       + 'URL you found}]}. Include at least two independent sources with real URLs; prefer a Tier-1 '
       + 'systematic review when one exists. No prose, no code fences.';
  CallModel(MODEL_GATHER, sys, 'Claim: ' + AText, True,
    procedure (Data: variant)
    var
      g: variant;
      searched: Boolean;
    begin
      GBudget.RecordUsage(ResultIn(Data), ResultOut(Data));
      asm @searched = ((@Data) && (@Data).webSearchUsed === true); end;
      g := ParseJsonLoose(ResultText(Data));
      if not JsonOk(g) then asm @g = {}; end;        // empty -> promote will block uniformly
      ApplyGatherFields(AId, g);

      VerifySources(g,
        procedure (AVer: variant)
        var
          i, n, okc: Integer;
          v: TGateVerdict;
        begin
          n := ArrLen(AVer);
          okc := 0;
          for i := 0 to n - 1 do
          begin
            GLedger.AddSourceVerified(AId, VSrcTier(AVer, i), VSrcOrigin(AVer, i), '',
                                      VSrcUrl(AVer, i), VSrcVerified(AVer, i));
            if VSrcVerified(AVer, i) then okc := okc + 1;
          end;
          v := GLedger.Promote(AId);
          SaveCheckpoint;
          Console.log('  lead ' + IntToStr(AIndex) + ' promote: ' + PassStr(v.Pass)
            + '  (web=' + YN(searched) + ', ' + IntToStr(okc) + '/' + IntToStr(n) + ' sources verified)'
            + '  [meter ' + IntToStr(GBudget.Total) + ' tok]');
          if not v.Pass then Console.log('    blocked: ' + v.Reasons);

          GProcessedThisRun := GProcessedThisRun + 1;
          if GBudget.Tripped then begin Console.log('Halted by breaker; the checkpoint is the handoff.'); Exit; end;
          if (GCrashAfter > 0) and (GProcessedThisRun >= GCrashAfter) then
          begin
            Console.log('Simulating crash after ' + IntToStr(GProcessedThisRun) + ' gather(s); checkpoint saved.');
            asm process.exit(1); end;
          end;
          DoGatherNext(AIndex + 1);
        end);
    end,
    procedure (Status: Integer; Msg: String)
    begin
      Console.log('  gather call failed (' + IntToStr(Status) + '): ' + Msg + ' — stopping.');
    end);
end;

procedure DoGatherNext(AStart: Integer);
var
  arr: variant;
  n, i: Integer;
  st: String;
begin
  arr := ClaimsJson;
  n := ArrLen(arr);
  i := AStart;
  while i < n do
  begin
    st := ClaimStatusAt(arr, i);
    if st = 'lead' then          // only never-gathered leads; 'working' = blocked, left for review
    begin
      DoGatherForClaim(i, ClaimIdAt(arr, i), ClaimTextAt(arr, i));
      Exit;                              // async; the callback drives the next
    end;
    i := i + 1;
  end;
  DoSynthesize;                          // nothing left to gather
end;

procedure DoSynthesize;
var
  arr: variant;
  n, i: Integer;
  st, body, sys: String;
begin
  arr := ClaimsJson;
  n := ArrLen(arr);
  body := '';
  for i := 0 to n - 1 do
  begin
    st := ClaimStatusAt(arr, i);
    if (st = 'finding') or (st = 'published') then
      body := body + '- ' + ClaimTextAt(arr, i) + #10;
  end;

  if body = '' then
  begin
    Console.log('No findings cleared the gates; nothing to synthesise.');
    Finish;
    Exit;
  end;

  sys := 'You are a research writer. Given the verified findings, write a brief, plain, '
       + 'well-calibrated synthesis of two short paragraphs. State uncertainty honestly. No headings.';
  CallModel(MODEL_SYNTH, sys, 'Findings:' + #10 + body, False,
    procedure (Data: variant)
    begin
      GBudget.RecordUsage(ResultIn(Data), ResultOut(Data));
      WriteSynth(ResultText(Data));
      Console.log('Synthesis written to ' + SYNTH_FILE + '  [meter ' + IntToStr(GBudget.Total) + ' tok]');
      Finish;
    end,
    procedure (Status: Integer; Msg: String)
    begin
      Console.log('Synthesis call failed (' + IntToStr(Status) + '): ' + Msg);
      Finish;
    end);
end;

procedure RunResearch;
var
  ceil: Integer;
begin
  GFs := ReqNodeModule('fs');
  asm @GCrashAfter = (process.argv[2] !== undefined) ? parseInt(process.argv[2], 10) : -1; end;
  asm @ceil        = process.env.CEILING ? parseInt(process.env.CEILING, 10) : 200000; end;

  GStore := JW3DataStore.Create;
  asm
    @GPack = {
      corroborationByGrade:  { LOW: 2, MEDIUM: 2, HIGH: 3 },
      claimTypeRequiresTier: { disease: 1, therapeutic: 1, 'structure-function': 2 }
    };
  end;
  GLedger := TLedger.Create(GStore, GPack, 'runner');
  GBudget := TBudget.Create(GStore, ceil);
  GBudget.OnTrip(lambda Console.log('  >> BREAKER TRIPPED'); end);
  GProcessedThisRun := 0;

  if CheckpointExists then
  begin
    GLedger.LoadJSON(ReadCheckpoint);
    Console.log('Resuming from checkpoint: ' + IntToStr(GLedger.ClaimCount) + ' claim(s).');
    DoGatherNext(0);                     // finish gathering, then synthesise
  end
  else
  begin
    Console.log('Fresh run. Proxy ' + PROXY_URL + ', ceiling ' + IntToStr(ceil) + ' tok.');
    DoPlan;
  end;
end;

initialization
  RunResearch;
end.
