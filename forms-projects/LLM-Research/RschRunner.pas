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
  PACK_FILE    = './research-pack.json';
  PROXY_URL    = 'http://localhost:3030';
  SUBJECT      = 'The effects of extended screen time on children''s attention and development.';

type
  TJsonCb = procedure(Data: variant);
  TErrCb  = procedure(Status: Integer; Msg: String);
  TVoidCb = procedure;

var
  GSubject:          String;   // RESEARCH_SUBJECT   (default: the SUBJECT const)
  GProvider:         String;   // RESEARCH_PROVIDER  (default 'claude')
  GModelPlan:        String;   // MODEL_PLAN
  GModelGather:      String;   // MODEL_GATHER
  GModelSynth:       String;   // MODEL_SYNTH
  GModelJudge:       String;   // MODEL_JUDGE
  GModelAdvisor:     String;   // MODEL_ADVISOR      (rung 2)
  GModelCompiler:    String;   // MODEL_COMPILER     (gate compiler)
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

function PackFileExists: Boolean;
begin
  Result := False;
  if GFs.existsSync(PACK_FILE) then Result := True;
end;

function ReadPackFile: String;
begin
  Result := String(GFs.readFileSync(PACK_FILE, 'utf8'));
end;

procedure WritePackFile(const AText: String);
begin
  GFs.writeFileSync(PACK_FILE, AText);
end;

function PackToJSON(APack: variant): String;
begin
  asm @Result = JSON.stringify(@APack, null, 2); end;
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
      provider:          @GProvider,
      transport:         'api',
      model:             @AModel,
      system:            @ASystem,
      messages:          [{ role: 'user', content: @AUser }],
      maxTokens:         1500,
      temperature:       0.2,
      stream:            false,
      webSearch:         @AWebSearch,
      budgetId:          'research',
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
        .then(function (r) {
          var st = (r && r.status) || 0;
          s.httpStatus = st;
          s.verified = !!(r && (r.ok || st === 401 || st === 403 || st === 405 || st === 429));
          return s;
        })
        .catch(function () { s.httpStatus = 0; s.verified = false; return s; });
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

// Build a plain list of the VERIFIED sources for the judge to read.
function BuildSourceSummary(AVer: variant): String;
var
  i, n: Integer;
  s: String;
begin
  s := '';
  n := ArrLen(AVer);
  for i := 0 to n - 1 do
    if VSrcVerified(AVer, i) then
      s := s + '- Tier ' + IntToStr(VSrcTier(AVer, i)) + ': '
             + VSrcOrigin(AVer, i) + ' (' + VSrcUrl(AVer, i) + ')' + #10;
  if s = '' then s := '(no verified sources)';
  Result := s;
end;

// Rung 1 — the advisory judge. Reads the claim and its verified sources (not the
// gatherer's reasoning) and records a verdict on the claim. It NEVER blocks:
// the deterministic gates already decided; this verdict is counsel for the human
// at the publish gate. Failure or unparseable output records a note and proceeds.
procedure DoJudge(const AId, AClaimText: String; AVer: variant; OnDone: TVoidCb);
var
  sys, usr, sums: String;
begin
  sums := BuildSourceSummary(AVer);
  sys := 'You are an independent research judge. You are given a claim and the sources gathered '
       + 'for it; you do not see how they were gathered. Judge strictly: (1) supported - do these '
       + 'sources, taken together, actually support the claim as worded? (2) wordingMatch - does the '
       + 'strength of the claim match the strength of the evidence (a causal claim needs experimental '
       + 'evidence; an associational claim must not imply causation)? Reply with ONLY a JSON object '
       + '{"supported": boolean, "wordingMatch": boolean, "note": one short sentence}. No prose, no fences.';
  usr := 'Claim: ' + AClaimText + #10 + 'Sources:' + #10 + sums;
  CallModel(GModelJudge, sys, usr, False,
    procedure (Data: variant)
    var
      j:    variant;
      note: String;
    begin
      GBudget.RecordUsage(ResultIn(Data), ResultOut(Data));
      j := ParseJsonLoose(ResultText(Data));
      if JsonOk(j) then
      begin
        GLedger.SetField(AId, 'judgeSupported', FieldBool(j, 'supported'));
        GLedger.SetField(AId, 'judgeWording',   FieldBool(j, 'wordingMatch'));
        note := Trim(FieldStr(j, 'note'));
        if note = '' then note := '(no note)';
        GLedger.SetField(AId, 'judgeNote', note);
      end
      else
        GLedger.SetField(AId, 'judgeNote', '(judge returned no parseable verdict)');
      OnDone();
    end,
    procedure (Status: Integer; Msg: String)
    begin
      GLedger.SetField(AId, 'judgeNote', 'judge call failed (' + IntToStr(Status) + ')');
      OnDone();
    end);
end;

// A short, human-readable judge summary for the log line, or '' if none recorded.
function JudgeNoteOf(const AId: String): String;
var
  c:         variant;
  hasJudge:  Boolean;
  supported: Boolean;
  note:      String;
begin
  Result := '';
  c := GLedger.GetClaim(AId);
  asm @hasJudge = ((@c) && (@c).judgeNote !== undefined); end;
  if not hasJudge then Exit;
  note := ClaimStr(c, 'judgeNote');
  asm @supported = ((@c) && (@c).judgeSupported === true); end;
  if note = '' then Exit;
  if supported then Result := 'supported - ' + note
  else Result := 'DOUBT - ' + note;
end;

// ── Rung 2: the advisor ──────────────────────────────────────────────────────
// A STRONGER model than the judge, consulted rarely — only on reviewer doubt or
// heading-to-publish — and cached on a content hash of claim text + verified
// source URLs. The cache mark (advisorKey) lives ON THE CLAIM, so it rides the
// checkpoint into the console and back: neither side re-spends on an unchanged
// claim. Advisory like the judge: records counsel, never blocks.

function ClaimHash(const AText: String; ASources: variant): String;
begin
  asm
    var urls = [];
    var a = (@ASources) || [];
    for (var i = 0; i < a.length; i++) {
      if (a[i] && a[i].verified !== false && a[i].url) urls.push(String(a[i].url));
    }
    urls.sort();
    var s = String(@AText) + '|' + urls.join('|');
    var h = 5381;
    for (var j = 0; j < s.length; j++) { h = ((h * 33) ^ s.charCodeAt(j)) >>> 0; }
    @Result = 'k' + h.toString(36);
  end;
end;

procedure DoAdvise(const AId, AClaimText: String; AVer: variant; OnDone: TVoidCb);
var
  c: variant;
  sys, usr, sums, key, jn, mdl: String;
begin
  key := ClaimHash(AClaimText, AVer);
  c := GLedger.GetClaim(AId);
  if ClaimStr(c, 'advisorKey') = key then begin OnDone(); Exit; end;   // cached — no spend

  mdl  := GModelAdvisor;
  sums := BuildSourceSummary(AVer);
  jn   := ClaimStr(c, 'judgeNote');
  sys := 'You are a senior research advisor, consulted rarely and only where it matters: a claim '
       + 'that passed deterministic gates but drew reviewer doubt, or a claim about to be published. '
       + 'You see the claim and its verified sources; adjudicate independently and strictly. Reply '
       + 'with ONLY a JSON object {"supported": boolean (the sources genuinely support the claim as '
       + 'worded), "publishable": boolean (fit to publish as written), "betterWording": string (an '
       + 'improved wording if needed, else ""), "note": one or two short sentences}. No prose, no fences.';
  usr := 'Claim: ' + AClaimText + #10 + 'Sources:' + #10 + sums;
  if jn <> '' then usr := usr + #10 + 'First reviewer note: ' + jn;

  CallModel(mdl, sys, usr, False,
    procedure (Data: variant)
    var
      j: variant;
      note: String;
    begin
      GBudget.RecordUsage(ResultIn(Data), ResultOut(Data));
      j := ParseJsonLoose(ResultText(Data));
      if JsonOk(j) then
      begin
        GLedger.SetField(AId, 'advisorSupported',   FieldBool(j, 'supported'));
        GLedger.SetField(AId, 'advisorPublishable', FieldBool(j, 'publishable'));
        GLedger.SetField(AId, 'advisorWording',     Trim(FieldStr(j, 'betterWording')));
        note := Trim(FieldStr(j, 'note'));
        if note = '' then note := '(no note)';
        GLedger.SetField(AId, 'advisorNote',  note);
        GLedger.SetField(AId, 'advisorModel', mdl);
        GLedger.SetField(AId, 'advisorKey',   key);   // the cache mark — only on success
      end
      else
        GLedger.SetField(AId, 'advisorNote', '(advisor returned no parseable verdict)');
      OnDone();
    end,
    procedure (Status: Integer; Msg: String)
    begin
      GLedger.SetField(AId, 'advisorNote', 'advisor call failed (' + IntToStr(Status) + ')');
      OnDone();                                        // advisory: failure never blocks
    end);
end;

function AdvisorNoteOf(const AId: String): String;
var
  c: variant;
  note: String;
begin
  Result := '';
  c := GLedger.GetClaim(AId);
  note := ClaimStr(c, 'advisorNote');
  if note = '' then Exit;
  if ClaimBool(c, 'advisorSupported') and ClaimBool(c, 'advisorPublishable') then
    Result := 'supported - ' + note
  else
    Result := 'CONCERN - ' + note;
end;

procedure FinaliseGather(AIndex, AOkc, ATotal: Integer; ASearched: Boolean;
                         const AId, AReasons: String; APass: Boolean);
var
  jn, an, aw, line: String;
begin
  SaveCheckpoint;
  jn := JudgeNoteOf(AId);
  an := AdvisorNoteOf(AId);
  line := '  lead ' + IntToStr(AIndex) + ' promote: ' + PassStr(APass)
        + '  (web=' + YN(ASearched) + ', ' + IntToStr(AOkc) + '/' + IntToStr(ATotal) + ' verified';
  if jn <> '' then line := line + ', judge: ' + jn;
  if an <> '' then line := line + ', advisor: ' + an;
  line := line + ')  [meter ' + IntToStr(GBudget.Total) + ' tok]';
  Console.log(line);
  aw := ClaimStr(GLedger.GetClaim(AId), 'advisorWording');
  if aw <> '' then Console.log('    advisor wording: ' + aw);
  if not APass then Console.log('    blocked: ' + AReasons);

  GProcessedThisRun := GProcessedThisRun + 1;
  if GBudget.Tripped then begin Console.log('Halted by breaker; the checkpoint is the handoff.'); Exit; end;
  if (GCrashAfter > 0) and (GProcessedThisRun >= GCrashAfter) then
  begin
    Console.log('Simulating crash after ' + IntToStr(GProcessedThisRun) + ' gather(s); checkpoint saved.');
    asm process.exit(1); end;
  end;
  DoGatherNext(AIndex + 1);
end;

// The doubt trigger: after the judge records its verdict, escalate to the
// advisor ONLY if the judge doubted (not supported, or wording mismatch).
// A clean judge pass goes straight to finalise — rung 2 stays rare.
procedure AdviseThenFinalise(AIndex, AOkc, ATotal: Integer; ASearched: Boolean;
                             const AId, AText, AReasons: String; AVer: variant; APass: Boolean);
var
  c: variant;
  doubt: Boolean;
begin
  c := GLedger.GetClaim(AId);
  doubt := (not ClaimBool(c, 'judgeSupported')) or (not ClaimBool(c, 'judgeWording'));
  if doubt then
    DoAdvise(AId, AText, AVer,
      lambda FinaliseGather(AIndex, AOkc, ATotal, ASearched, AId, AReasons, APass); end)
  else
    FinaliseGather(AIndex, AOkc, ATotal, ASearched, AId, AReasons, APass);
end;

procedure DoPlan;
var
  sys: String;
begin
  Console.log('Planning: ' + GSubject);
  sys := 'You are a research planner. Break the subject into 3 to 5 specific, checkable factual '
       + 'claims worth investigating. Phrase each claim at the strength the evidence can bear: '
       + 'prefer associational or descriptive wording such as "is associated with", "studies report", '
       + 'or "the evidence is mixed on", over causal wording such as "causes" or "leads to", unless '
       + 'the subject plausibly has randomised or experimental evidence. Do not overstate. Reply with '
       + 'ONLY a JSON array; each element {"claim": string, "species": one of '
       + '"scientific","marketing","regulatory","forecast"}. No prose, no code fences.';
  CallModel(GModelPlan, sys, GSubject, False,
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
  sys, tg: String;
begin
  Console.log('Gathering for lead ' + IntToStr(AIndex) + ': ' + AText);
  tg := Trim(ClaimStr(GPack, 'tierGuide'));
  if tg = '' then
    tg := '1=systematic review or RCT, 2=peer-reviewed study, 3=reputable report, '
        + '4=primary document, 5=social post';
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
       + '"sources": [{"tier": 1-5 where ' + tg + ', "origin": short independence key, "url": a real '
       + 'URL you found}]}. A claim hedged with "associated with", "linked to", or "causality not '
       + 'established" is NOT a causal claim: set claimType to "" for it. '
       + 'Include at least two independent sources with real URLs. When the claim concerns the '
       + 'content of a specific text, instrument, ruling, or official record, include that '
       + 'authoritative source itself with its real URL - in such domains it is the Tier-1 evidence. '
       + 'Otherwise prefer the highest tier available as defined above. Never invent a URL. '
       + 'No prose, no code fences.';
  CallModel(GModelGather, sys, 'Claim: ' + AText, True,
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
          if v.Pass then
            // gates passed → judge (rung 1) records counsel; if the judge doubts,
            // the advisor (rung 2, stronger model, cached) adjudicates the doubt.
            // Neither blocks — counsel rides the claim to the human.
            DoJudge(AId, AText, AVer,
              lambda AdviseThenFinalise(AIndex, okc, n, searched, AId, AText, v.Reasons, AVer, v.Pass); end)
          else
            FinaliseGather(AIndex, okc, n, searched, AId, v.Reasons, v.Pass);
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
  CallModel(GModelSynth, sys, 'Findings:' + #10 + body, False,
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

// ── Gate Compiler ────────────────────────────────────────────────────────────
// Once per session: derive the gate pack from the subject by HARM-FIRST
// analysis (name the worst realistic harm a FALSE published claim could do,
// then set strictness to match) and define what the evidence TIERS MEAN in
// this domain — the lesson of the constitutional run, where Tier-1 meant RCTs
// and the Constitution itself scored Tier-4. Cached as PACK_FILE in the
// session folder: human-readable, hand-editable, delete to recompile. The
// merge applies FLOORS so neither the model nor a hand edit can loosen rung 0,
// and it mutates the live pack IN PLACE so the ledger's gates see the result.
// Unparseable or failed compiler output degrades to the baseline and the run
// proceeds — the compiler can only ever tighten, never weaken, never block.

function SanitiseMergePack(ABase, ADerived: variant): variant;
begin
  asm
    var base = (@ABase) || {};
    var der  = (@ADerived) || {};

    var bc = base.corroborationByGrade || {};
    var dc = (der && der.corroborationByGrade) || {};
    var grades = ['LOW', 'MEDIUM', 'HIGH'];
    for (var g = 0; g < grades.length; g++) {
      var k = grades[g];
      var bv = (typeof bc[k] === 'number') ? bc[k] : 2;
      var dv = (typeof dc[k] === 'number') ? dc[k] : bv;
      bc[k] = Math.floor(Math.max(bv, dv, 2));
    }
    base.corroborationByGrade = bc;

    var bt = base.claimTypeRequiresTier || {};
    var dt = (der && der.claimTypeRequiresTier) || {};
    for (var key in dt) {
      if (Object.prototype.hasOwnProperty.call(dt, key)) {
        var t = dt[key];
        if (typeof t === 'number' && t >= 1 && t <= 5) {
          t = Math.floor(t);
          if (typeof bt[key] === 'number') bt[key] = Math.min(bt[key], t);
          else bt[key] = t;
        }
      }
    }
    base.claimTypeRequiresTier = bt;

    if (der && typeof der.harmNote === 'string') {
      var hv = der.harmNote.split(String.fromCharCode(10)).join(' ')
                           .split(String.fromCharCode(13)).join(' ').trim();
      if (hv.length > 300) hv = hv.slice(0, 300);
      if (hv) base.harmNote = hv;
    }
    if (der && typeof der.tierGuide === 'string') {
      var tv = der.tierGuide.split(String.fromCharCode(10)).join(' ')
                            .split(String.fromCharCode(13)).join(' ').trim();
      if (tv.length > 400) tv = tv.slice(0, 400);
      if (tv) base.tierGuide = tv;
    }
    @Result = base;
  end;
end;

procedure CompileGatePack(OnReady: TVoidCb);
var
  sys, txt, hn, tg: String;
  parsed: variant;
begin
  if PackFileExists then
  begin
    txt := ReadPackFile;
    parsed := ParseJsonLoose(txt);
    if JsonOk(parsed) then
    begin
      GPack := SanitiseMergePack(GPack, parsed);   // floors re-applied: hand edits cannot loosen
      hn := ClaimStr(GPack, 'harmNote');
      tg := ClaimStr(GPack, 'tierGuide');
      Console.log('Gate pack: loaded ' + PACK_FILE);
      if hn <> '' then Console.log('  harm:  ' + hn);
      if tg <> '' then Console.log('  tiers: ' + tg);
    end
    else
      Console.log('Gate pack: ' + PACK_FILE + ' unreadable; baseline gates stand.');
    OnReady();
    Exit;
  end;

  Console.log('Gate pack: compiling for subject (' + GModelCompiler + ')...');
  sys := 'You are a gate compiler for a research verification system. Given a research subject, '
       + 'derive evidence gates by HARM-FIRST analysis: first name the worst realistic harm a FALSE '
       + 'published claim in this domain could cause, then set strictness to match. You may TIGHTEN '
       + 'the baseline but never loosen it. Baseline: corroboration LOW=2 MEDIUM=2 HIGH=3 independent '
       + 'sources; claim types disease and therapeutic require Tier-1 evidence, structure-function '
       + 'requires Tier-2. Also define what the five source tiers MEAN in this domain, strongest '
       + 'first: for empirical or medical subjects Tier 1 is systematic reviews or RCTs; for legal or '
       + 'constitutional subjects Tier 1 is the authoritative legal text, apex court judgments, and '
       + 'official government or parliamentary sources; for markets or policy, official statistics '
       + 'and primary filings. Choose what fits THIS subject. Reply with ONLY a JSON object '
       + '{"harmNote": one sentence naming the worst realistic harm, '
       + '"tierGuide": a single line of the form 1=..., 2=..., 3=..., 4=..., 5=... for this domain, '
       + '"corroborationByGrade": {"LOW": n, "MEDIUM": n, "HIGH": n}, '
       + '"claimTypeRequiresTier": {claimType: tier}}. No prose, no fences.';
  CallModel(GModelCompiler, sys, GSubject, False,
    procedure (Data: variant)
    var
      j: variant;
    begin
      GBudget.RecordUsage(ResultIn(Data), ResultOut(Data));
      j := ParseJsonLoose(ResultText(Data));
      if JsonOk(j) then
      begin
        GPack := SanitiseMergePack(GPack, j);
        WritePackFile(PackToJSON(GPack));
        Console.log('Gate pack: compiled and saved to ' + PACK_FILE
          + '  [meter ' + IntToStr(GBudget.Total) + ' tok]');
        if ClaimStr(GPack, 'harmNote') <> '' then
          Console.log('  harm:  ' + ClaimStr(GPack, 'harmNote'));
        if ClaimStr(GPack, 'tierGuide') <> '' then
          Console.log('  tiers: ' + ClaimStr(GPack, 'tierGuide'));
      end
      else
        Console.log('Gate pack: no parseable pack returned; baseline gates stand.');
      OnReady();
    end,
    procedure (Status: Integer; Msg: String)
    begin
      Console.log('Gate pack: compiler call failed (' + IntToStr(Status) + '); baseline gates stand.');
      OnReady();
    end);
end;

procedure StartPipeline(ACeil: Integer);
begin
  if CheckpointExists then
  begin
    GLedger.LoadJSON(ReadCheckpoint);
    Console.log('Resuming from checkpoint: ' + IntToStr(GLedger.ClaimCount) + ' claim(s).');
    DoGatherNext(0);                     // finish gathering, then synthesise
  end
  else
  begin
    Console.log('Fresh run. Proxy ' + PROXY_URL + ', ceiling ' + IntToStr(ACeil) + ' tok.');
    DoPlan;
  end;
end;

procedure RunResearch;
var
  ceil: Integer;
begin
  GFs := ReqNodeModule('fs');
  asm @GCrashAfter = (process.argv[2] !== undefined) ? parseInt(process.argv[2], 10) : -1; end;
  asm @ceil        = process.env.CEILING ? parseInt(process.env.CEILING, 10) : 200000; end;
  asm
    @GProvider     = process.env.RESEARCH_PROVIDER || 'claude';
    @GModelPlan    = process.env.MODEL_PLAN        || 'claude-sonnet-4-6';
    @GModelGather  = process.env.MODEL_GATHER      || 'claude-haiku-4-5-20251001';
    @GModelSynth   = process.env.MODEL_SYNTH       || 'claude-sonnet-4-6';
    @GModelJudge   = process.env.MODEL_JUDGE       || 'claude-sonnet-4-6';
    @GModelAdvisor = process.env.MODEL_ADVISOR     || 'claude-opus-4-8';
    @GModelCompiler = process.env.MODEL_COMPILER   || 'claude-opus-4-8';
  end;
  Console.log('Models  plan=' + GModelPlan + '  gather=' + GModelGather + '  judge=' + GModelJudge
    + '  advisor=' + GModelAdvisor + '  synth=' + GModelSynth + '  provider=' + GProvider);
  asm @GSubject = process.env.RESEARCH_SUBJECT || ''; end;
  if Trim(GSubject) = '' then GSubject := SUBJECT;   // const inlines here, never in asm

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

  // The Gate Compiler runs first (cached after a session's first run), so
  // every gate decision — fresh or resumed — uses the same tightened pack.
  CompileGatePack(lambda StartPipeline(ceil); end);
end;

initialization
  RunResearch;
end.
