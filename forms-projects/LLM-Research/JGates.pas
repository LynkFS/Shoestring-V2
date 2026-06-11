unit JGates;

// ═══════════════════════════════════════════════════════════════════════════
//  JGates — rung 0 of the Verification Ladder.
//
//  Deterministic checks over a single claim. No model calls — this is the free
//  rung that answers most "is it ready?" before a judge is ever paid.
//
//  Layer 0 is hardcoded here and may only ever tighten. Domain rules arrive as
//  DATA (a frozen Gate-Compiler pack), never as code — onboarding a domain is
//  loading a pack, the providers.json move from the LLM chapter.
//
//  A claim is a plain object held as a variant (the JProjectStore idiom):
//    { id, text, species, status, claimType, causalBasis, riskGrade,
//      sources:[{tier,origin,ref,url}], steelman, regulatoryStatus,
//      predictionsTested, harmfulInstruction, signoff, actor }
//  species ∈ marketing | scientific | regulatory | forecast
// ═══════════════════════════════════════════════════════════════════════════

interface

type
  TGateVerdict = record
    Pass:    Boolean;
    Reasons: String;      // newline-joined; empty when Pass
  end;

// Claim readers — exposed so JLedger reads fields without duplicating the idiom.
function ClaimStr(AClaim: variant; const AField: String): String;
function ClaimBool(AClaim: variant; const AField: String): Boolean;
function SourceCount(AClaim: variant): Integer;
function IndependentCount(AClaim: variant): Integer;   // distinct source origins
function HasTier1(AClaim: variant): Boolean;
function BestTier(AClaim: variant): Integer;           // lowest tier number present
function ClaimHasSpecies(AClaim: variant; const ASpecies: String): Boolean;
function SpeciesCSV(AClaim: variant): String;          // joined, for display/logging

// The gate guarding lead -> finding. Pass only if every Layer-0 and domain
// check holds. Reasons lists each failure, tagged [L0] or [domain].
function CheckPromote(AClaim, APack: variant): TGateVerdict;

implementation

const
  LF = #10;

function ClaimStr(AClaim: variant; const AField: String): String;
begin
  asm @Result = String(((@AClaim) && (@AClaim)[@AField]) || ''); end;
end;

function ClaimBool(AClaim: variant; const AField: String): Boolean;
begin
  asm @Result = ((@AClaim) && (@AClaim)[@AField] === true); end;
end;

function SourceCount(AClaim: variant): Integer;
begin
  asm
    var s = ((@AClaim) && (@AClaim).sources) || [];
    var n = 0;
    for (var i = 0; i < s.length; i++) { if (s[i] && s[i].verified !== false) n++; }
    @Result = n;
  end;
end;

function IndependentCount(AClaim: variant): Integer;
begin
  asm
    var s = ((@AClaim) && (@AClaim).sources) || [];
    var seen = {};
    for (var i = 0; i < s.length; i++) {
      if (s[i] && s[i].verified !== false) {
        var o = s[i].origin;
        if (o) seen[String(o)] = 1;
      }
    }
    @Result = Object.keys(seen).length;
  end;
end;

function HasTier1(AClaim: variant): Boolean;
begin
  asm
    var s = ((@AClaim) && (@AClaim).sources) || [];
    var ok = false;
    for (var i = 0; i < s.length; i++) { if (s[i] && s[i].verified !== false && s[i].tier === 1) ok = true; }
    @Result = ok;
  end;
end;

function BestTier(AClaim: variant): Integer;
begin
  asm
    var s = ((@AClaim) && (@AClaim).sources) || [];
    var b = 99;
    for (var i = 0; i < s.length; i++) {
      if (s[i] && s[i].verified !== false) {
        var t = s[i].tier;
        if (typeof t === 'number' && t < b) b = t;
      }
    }
    @Result = b;
  end;
end;

function ClaimHasSpecies(AClaim: variant; const ASpecies: String): Boolean;
begin
  asm
    var s = ((@AClaim) && (@AClaim).species) || [];
    @Result = Array.isArray(s) ? (s.indexOf(@ASpecies) !== -1) : (s === @ASpecies);
  end;
end;

function SpeciesCSV(AClaim: variant): String;
begin
  asm
    var s = ((@AClaim) && (@AClaim).species) || [];
    @Result = Array.isArray(s) ? s.join(', ') : String(s || '');
  end;
end;

function PackCorroboration(APack: variant; const AGrade: String): Integer;
begin
  asm
    var c = ((@APack) && (@APack).corroborationByGrade) || {};
    var v = c[@AGrade];
    @Result = (typeof v === 'number') ? v : 2;
  end;
end;

function PackRequiredTier(APack: variant; const AClaimType: String): Integer;
begin
  asm
    var m = ((@APack) && (@APack).claimTypeRequiresTier) || {};
    var v = m[@AClaimType];
    @Result = (typeof v === 'number') ? v : 99;   // 99 = no special requirement
  end;
end;

procedure AddReason(var V: TGateVerdict; const R: String);
begin
  V.Pass := False;
  if V.Reasons <> '' then V.Reasons := V.Reasons + LF;
  V.Reasons := V.Reasons + R;
end;

function CheckPromote(AClaim, APack: variant): TGateVerdict;
var
  v:      TGateVerdict;
  ct, cb: String;
  need:   Integer;
begin
  v.Pass    := True;
  v.Reasons := '';

  ct := ClaimStr(AClaim, 'claimType');
  cb := ClaimStr(AClaim, 'causalBasis');

  // ── Layer 0 — never weakened ───────────────────────────────────────────────
  if SourceCount(AClaim) < 1 then
    AddReason(v, '[L0] provenance: every claim must cite at least one source.');

  need := PackCorroboration(APack, ClaimStr(AClaim, 'riskGrade'));
  if need < 2 then need := 2;                       // absolute floor
  if IndependentCount(AClaim) < need then
    AddReason(v, '[L0] corroboration: needs ' + IntToStr(need) +
                 ' independent sources, has ' + IntToStr(IndependentCount(AClaim)) + '.');

  if Trim(ClaimStr(AClaim, 'steelman')) = '' then
    AddReason(v, '[L0] steelman: write the strongest opposing reading first.');

  if ClaimBool(AClaim, 'harmfulInstruction') then
    AddReason(v, '[L0] no-harm: claim carries a usable harmful instruction.');

  // ── Domain — from the frozen pack ──────────────────────────────────────────
  if ClaimHasSpecies(AClaim, 'scientific') and (not HasTier1(AClaim)) then
    AddReason(v, '[domain] a scientific verdict needs a Tier-1 source.');

  need := PackRequiredTier(APack, ct);
  if (need < 99) and (BestTier(AClaim) > need) then
    AddReason(v, '[domain] claim type "' + ct + '" needs Tier-' + IntToStr(need) +
                 ' evidence; best source is Tier-' + IntToStr(BestTier(AClaim)) + '.');

  if ((ct = 'disease') or (ct = 'therapeutic')) and (cb <> 'interventional') then
    AddReason(v, '[domain] causal claim ("' + ct + '") rests on ' + cb +
                 ' evidence, not interventional.');

  if ClaimHasSpecies(AClaim, 'regulatory') and (Trim(ClaimStr(AClaim, 'regulatoryStatus')) = '') then
    AddReason(v, '[domain] regulatory claim must state register status (listed vs evaluated).');

  if ClaimHasSpecies(AClaim, 'forecast') and (not ClaimBool(AClaim, 'predictionsTested')) then
    AddReason(v, '[domain] forecast/thesis claim must record dated predictions and test them against outcome.');

  Result := v;
end;

end.
