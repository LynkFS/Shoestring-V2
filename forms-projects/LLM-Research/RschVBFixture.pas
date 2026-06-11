unit RschVBFixture;

// ═══════════════════════════════════════════════════════════════════════════
//  RschVBFixture — M1 acceptance check (no model loop).
//
//  The Vanden Bossche article reconstructed as ledger rows, used to prove the
//  gates bite and the breaker trips. Run from an entrypoint:
//
//      uses Globals, RschVBFixture;
//      RunVandenBosscheAcceptance;
//
//  Reads the console: each EXPECT logs PASS/FAIL, then a summary and the
//  ledger snapshot. This is M1's definition of done — engine-level, no GUI,
//  no autonomy.
// ═══════════════════════════════════════════════════════════════════════════

interface

procedure RunVandenBosscheAcceptance;

implementation

uses JDataStore, JGates, JLedger, JBudget;

var
  GPass: Integer;
  GFail: Integer;

procedure Log(const S: String);
begin
  asm console.log(@S); end;
end;

procedure Expect(const AWhat: String; ACond: Boolean);
begin
  if ACond then
  begin
    GPass := GPass + 1;
    Log('PASS  ' + AWhat);
  end
  else
  begin
    GFail := GFail + 1;
    Log('FAIL  ' + AWhat);
  end;
end;

procedure RunVandenBosscheAcceptance;
var
  Store:  JW3DataStore;
  Pack:   variant;
  L:      TLedger;
  Budget: TBudget;
  v:      TGateVerdict;
  idThesis, idSingle, idCausal, idMulti: String;
begin
  GPass := 0;
  GFail := 0;
  Store := JW3DataStore.Create;

  // A minimal frozen pack: corroboration by grade, and which claim types
  // demand which evidence tier. (The full pack is Gate-Compiler output.)
  asm
    @Pack = {
      corroborationByGrade:  { LOW: 2, MEDIUM: 2, HIGH: 3 },
      claimTypeRequiresTier: { disease: 1, therapeutic: 1, 'structure-function': 2 }
    };
  end;

  L := TLedger.Create(Store, Pack, 'nico');

  // ── 1. The thesis as a forecast claim. The falsifiability gate must block
  //       it until dated predictions are recorded and tested. ───────────────
  idThesis := L.AddClaim(
    'Vanden Bossche''s mass-vaccination catastrophe thesis has failed: the ' +
    'predicted die-off did not occur across five years of dated deadlines.',
    'forecast');
  L.SetField(idThesis, 'riskGrade', 'HIGH');   // names an individual; thesis "failed"

  v := L.Promote(idThesis);
  Expect('forecast with no tested predictions is blocked', not v.Pass);

  L.SetField(idThesis, 'predictionsTested', True);
  L.SetField(idThesis, 'steelman',
    'Immune escape and imprinting are real and he flagged them early; the ' +
    'vaccines were never sterilising.');
  L.AddSource(idThesis, 4, 'vandenbossche-substack', 'dated posts 2021-2025', '');
  L.AddSource(idThesis, 2, 'science-feedback',       'review of the tsunami claims', '');

  v := L.Promote(idThesis);
  Expect('HIGH forecast with only 2 sources still blocked (needs 3)', not v.Pass);

  L.AddSource(idThesis, 1, 'ourworldindata-mortality', 'no excess die-off in vaccinated cohorts', '');
  v := L.Promote(idThesis);
  Expect('forecast promotes once tested + steelmanned + 3 independent sources', v.Pass);

  // ── 2. Publication is a human act. ────────────────────────────────────────
  Expect('publish refused without a sign-off', not L.Publish(idThesis, ''));
  Expect('publish succeeds with a sign-off',         L.Publish(idThesis, 'Nico'));

  // ── 3. A single-sourced claim cannot become a finding. ────────────────────
  idSingle := L.AddClaim('Vaccination drives long COVID.', 'scientific');
  L.SetField(idSingle, 'steelman', 'Some early reports suggested a link.');
  L.AddSource(idSingle, 4, 'one-substack-post', 'assertion', '');
  v := L.Promote(idSingle);
  Expect('single-sourced scientific claim is blocked', not v.Pass);

  // ── 4. A causal claim on observational evidence is blocked; interventional
  //       Tier-1 lets it through (the article''s own discipline). ────────────
  idCausal := L.AddClaim('Vaccination reduces the risk of long COVID.', 'scientific');
  L.SetField(idCausal, 'claimType',   'disease');        // a causal claim
  L.SetField(idCausal, 'causalBasis', 'observational');
  L.SetField(idCausal, 'riskGrade',   'MEDIUM');
  L.SetField(idCausal, 'steelman', 'Confounding by who chooses vaccination could explain it.');
  L.AddSource(idCausal, 2, 'review-A', 'observational synthesis', '');
  L.AddSource(idCausal, 3, 'news-B',   'general coverage', '');
  v := L.Promote(idCausal);
  Expect('causal claim on observational evidence is blocked', not v.Pass);

  L.SetField(idCausal, 'causalBasis', 'interventional');
  L.AddSource(idCausal, 1, 'trial-C', 'randomised controlled evidence', '');
  v := L.Promote(idCausal);
  Expect('causal claim promotes on interventional Tier-1 evidence', v.Pass);

  // ── 4b. One sentence, several species. A marketing + regulatory claim must
  //        satisfy the regulatory gate even though it reads as marketing. ─────
  idMulti := L.AddClaim('Brand X markets its AUST L product as if the TGA evaluated its efficacy.', 'marketing');
  L.AddSpecies(idMulti, 'regulatory');
  L.SetField(idMulti, 'steelman', 'AUST L products are lawfully listed; the wording is ambiguous, not plainly deceptive.');
  L.AddSource(idMulti, 1, 'artg-listing', 'the AUST L entry', '');
  L.AddSource(idMulti, 4, 'brandx-site',  'the marketing copy', '');
  v := L.Promote(idMulti);
  Expect('multi-species (marketing+regulatory) blocked until register status stated', not v.Pass);

  L.SetField(idMulti, 'regulatoryStatus', 'AUST L - listed; efficacy not evaluated');
  v := L.Promote(idMulti);
  Expect('multi-species promotes once the regulatory member''s gate is satisfied', v.Pass);

  // ── 5. The meter and the breaker. ─────────────────────────────────────────
  Budget := TBudget.Create(Store, 5000);   // ceiling 5000 tokens
  Budget.OnTrip(lambda Log('   >> BREAKER TRIPPED - run halts, handoff written'); end);
  Budget.RecordUsage(1200, 800);           // total 2000
  Expect('meter not tripped under ceiling', not Budget.Tripped);
  Budget.RecordUsage(2000, 1500);          // total 5500 > 5000
  Expect('breaker trips when the ceiling is crossed', Budget.Tripped);

  Log('');
  Log('Vanden Bossche acceptance: ' + IntToStr(GPass) + ' passed, ' +
      IntToStr(GFail) + ' failed.');
  Log('Ledger snapshot:');
  Log(L.ToJSON);
end;

end.
