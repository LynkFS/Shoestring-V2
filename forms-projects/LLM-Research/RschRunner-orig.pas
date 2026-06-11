unit RschRunner;

// ═══════════════════════════════════════════════════════════════════════════
//  RschRunner — the headless research loop (Node target).
//
//  Compiles to JavaScript that runs under:  node app.js  [crashAfter]
//
//  This is the endurance spine, and the structural answer to the Bridge burn:
//  WE own the loop — not a managed agent — the ledger is checkpointed to disk
//  after every unit of work, and a restart resumes from that checkpoint.
//
//  This first cut proves DURABILITY with a deterministic work plan and no model
//  calls; the metered call path through the proxy (the patched adapter's fetch)
//  layers on next, once the durable skeleton is trusted. That is "consistency
//  before endurance" applied to the runner itself.
//
//  Pass a number as argv[2] to simulate a crash after that many units:
//      node app.js 2     -> processes 2 units, checkpoints each, exits(1)
//      node app.js       -> resumes from the checkpoint, finishes
// ═══════════════════════════════════════════════════════════════════════════

interface

uses NodeTypes, JDataStore, JGates, JLedger, JBudget;

procedure RunResearch;

implementation

const
  CHECKPOINT = './research-ledger.json';
  UNIT_COUNT = 3;

var
  GFs: variant;

function PassStr(b: Boolean): String;
begin
  if b then Result := 'PASS' else Result := 'blocked';
end;

// ── checkpoint I/O (Node fs) ─────────────────────────────────────────────────
//  Note: these call the fs methods at the Pascal level rather than via asm.
//  A Pascal const inlines as a literal in Pascal code, but inside an asm block
//  '@CHECKPOINT' emits a bare identifier the compiler never declares — so asm
//  must never reference a const by name. Vars and params are fine in asm.

function CheckpointExists: Boolean;
begin
  Result := False;
  if GFs.existsSync(CHECKPOINT) then Result := True;
end;

procedure SaveCheckpoint(L: TLedger);
begin
  GFs.writeFileSync(CHECKPOINT, L.ToJSON);   // durability: persist after every unit
end;

function ReadCheckpoint: String;
begin
  Result := String(GFs.readFileSync(CHECKPOINT, 'utf8'));
end;

// ── the work plan (deterministic stand-in for plan/gather) ───────────────────
//  Each unit adds exactly one claim and drives it as far as the gates allow,
//  so resume keys off ClaimCount: N claims done -> next unit is index N.

procedure ProcessUnit(L: TLedger; AIndex: Integer);
var
  id: String;
  v:  TGateVerdict;
begin
  if AIndex = 0 then
  begin
    id := L.AddClaim('Heavy screen use is associated with more attention problems in children.', 'scientific');
    L.SetField(id, 'claimType',   'disease');
    L.SetField(id, 'causalBasis', 'interventional');
    L.SetField(id, 'riskGrade',   'MEDIUM');
    L.SetField(id, 'steelman',    'Reverse causation and confounding are plausible; effect sizes are contested.');
    L.AddSource(id, 1, 'cohort-trial', 'controlled estimate', '');
    L.AddSource(id, 2, 'meta-review',  'pooled synthesis', '');
    v := L.Promote(id);
    Console.log('  unit 0 promote: ' + PassStr(v.Pass));
  end
  else if AIndex = 1 then
  begin
    id := L.AddClaim('A marketed supplement implies regulator-evaluated efficacy.', 'marketing');
    L.AddSpecies(id, 'regulatory');
    L.SetField(id, 'riskGrade',        'MEDIUM');
    L.SetField(id, 'regulatoryStatus', 'listed; efficacy not evaluated');
    L.SetField(id, 'steelman',         'The listing is lawful; the wording is ambiguous, not plainly deceptive.');
    L.AddSource(id, 1, 'register-entry', 'official listing', '');
    L.AddSource(id, 4, 'product-site',   'the marketing copy', '');
    v := L.Promote(id);
    Console.log('  unit 1 promote: ' + PassStr(v.Pass));
  end
  else
  begin
    id := L.AddClaim('A widely-shared forecast of imminent collapse did not occur on its stated dates.', 'forecast');
    L.SetField(id, 'riskGrade',         'HIGH');
    L.SetField(id, 'predictionsTested', True);
    L.SetField(id, 'steelman',          'Some underlying mechanisms were real; the author flagged them early.');
    L.AddSource(id, 4, 'author-posts', 'the dated predictions', '');
    L.AddSource(id, 2, 'fact-review',  'assessment of the claims', '');
    L.AddSource(id, 1, 'outcome-data', 'the non-occurrence', '');
    v := L.Promote(id);
    Console.log('  unit 2 promote: ' + PassStr(v.Pass));
  end;
end;

// ── the loop ─────────────────────────────────────────────────────────────────

procedure RunResearch;
var
  Store:      JW3DataStore;
  Pack:       variant;
  L:          TLedger;
  Budget:     TBudget;
  crashAfter: Integer;
  done, i, processedThisRun: Integer;
begin
  GFs := ReqNodeModule('fs');
  asm @crashAfter = (process.argv[2] !== undefined) ? parseInt(process.argv[2], 10) : -1; end;

  Store := JW3DataStore.Create;
  asm
    @Pack = {
      corroborationByGrade:  { LOW: 2, MEDIUM: 2, HIGH: 3 },
      claimTypeRequiresTier: { disease: 1, therapeutic: 1, 'structure-function': 2 }
    };
  end;
  L      := TLedger.Create(Store, Pack, 'runner');
  Budget := TBudget.Create(Store, 200000);
  Budget.OnTrip(lambda Console.log('  >> BREAKER TRIPPED - halting; the checkpoint is the handoff'); end);

  if CheckpointExists then
  begin
    L.LoadJSON(ReadCheckpoint);
    Console.log('Resuming from checkpoint: ' + IntToStr(L.ClaimCount) + ' claim(s) already done.');
  end
  else
    Console.log('Fresh run (no checkpoint).');

  done := L.ClaimCount;
  processedThisRun := 0;

  for i := done to UNIT_COUNT - 1 do
  begin
    Console.log('Processing unit ' + IntToStr(i) + ' ...');
    ProcessUnit(L, i);
    SaveCheckpoint(L);                    // durability: persist after every unit
    processedThisRun := processedThisRun + 1;

    if Budget.Tripped then
    begin
      Console.log('Halted by breaker after unit ' + IntToStr(i) + '.');
      Exit;
    end;

    if (crashAfter > 0) and (processedThisRun >= crashAfter) and (i < UNIT_COUNT - 1) then
    begin
      Console.log('Simulating crash after ' + IntToStr(processedThisRun) + ' unit(s); checkpoint saved.');
      asm process.exit(1); end;
    end;
  end;

  Console.log('Done. Ledger holds ' + IntToStr(L.ClaimCount) + ' claim(s); checkpoint at ' + CHECKPOINT + '.');
end;

initialization
  RunResearch;
end.
