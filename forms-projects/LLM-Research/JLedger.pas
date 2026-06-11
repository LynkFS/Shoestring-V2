unit JLedger;

// ═══════════════════════════════════════════════════════════════════════════
//  JLedger — a standalone, append-only research ledger as a state machine.
//
//  A claim is a plain object (variant) with a status:
//      lead -> working -> finding -> published   (-> corrected)
//  The transitions are GUARDED, not advisory:
//    * Promote(lead/working -> finding) runs JGates and refuses on any failure.
//    * Publish(finding -> published) requires a human sign-off — and a thing
//      that is not yet a finding cannot publish at all.
//  These two guards are what make the methodology's gates unskippable by a
//  tired session, by construction rather than by willpower.
//
//  State mirrors to a DataStore (ledger.*) so a console subscribes the way
//  FormLLM does. An append-only event list records who did what — the realized
//  event store, an Actor stamped on every row. Standalone: it borrows Bridge's
//  shape (a knowledge/log) and owns the implementation.
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JDataStore, JGates;

type
  TLedger = class
  private
    FStore:  JW3DataStore;
    FClaims: variant;     // JS array of claim objects
    FEvents: variant;     // JS array of event objects (append-only)
    FPack:   variant;     // the frozen Gate-Compiler pack
    FActor:  String;      // who is operating (human name or agent role id)
    function  NewId: String;
    procedure SetStatus(const AId, AStatus: String);
  public
    constructor Create(AStore: JW3DataStore; APack: variant; const AActor: String);
    function  AddClaim(const AText, ASpecies: String): String;    // -> id, status 'lead'
    procedure AddSpecies(const AId, ASpecies: String);            // claim carries several species
    procedure SetField(const AId, AField: String; AValue: variant);
    procedure AddSource(const AId: String; ATier: Integer;
                        const AOrigin, ARef, AUrl: String);
    procedure AddSourceVerified(const AId: String; ATier: Integer;
                        const AOrigin, ARef, AUrl: String; AVerified: Boolean);
    function  GetClaim(const AId: String): variant;
    function  ClaimCount: Integer;
    function  Promote(const AId: String): TGateVerdict;           // guarded
    function  Publish(const AId, ASignoff: String): Boolean;      // human act
    procedure Correct(const AId, ANote: String);
    procedure LogEvent(const AType, AId, ADetail: String);
    procedure Actor(const AName: String);                         // switch operator
    procedure Sync;
    function  ToJSON: String;
    procedure LoadJSON(const AJson: String);   // rehydrate from a checkpoint file
  end;

implementation

function TLedger.NewId: String;
begin
  asm @Result = 'c' + Date.now().toString(36) + Math.floor(Math.random() * 1000).toString(); end;
end;

constructor TLedger.Create(AStore: JW3DataStore; APack: variant; const AActor: String);
begin
  inherited Create;
  FStore := AStore;
  FPack  := APack;
  FActor := AActor;
  asm @FClaims = []; @FEvents = []; end;
  Sync;
end;

procedure TLedger.Actor(const AName: String);
begin
  FActor := AName;
end;

function TLedger.GetClaim(const AId: String): variant;
begin
  asm
    var a = @FClaims; var r = null;
    for (var i = 0; i < a.length; i++) { if (a[i] && a[i].id === @AId) { r = a[i]; break; } }
    @Result = r;
  end;
end;

function TLedger.ClaimCount: Integer;
begin
  asm @Result = (@FClaims).length; end;
end;

function TLedger.AddClaim(const AText, ASpecies: String): String;
var
  id: String;
begin
  id := NewId;
  asm
    (@FClaims).push({
      id: @id, text: @AText, species: [@ASpecies], status: 'lead',
      claimType: '', causalBasis: 'n/a', riskGrade: 'LOW',
      sources: [], steelman: '', regulatoryStatus: '',
      predictionsTested: false, harmfulInstruction: false,
      signoff: '', actor: @FActor
    });
  end;
  LogEvent('add', id, ASpecies);
  Sync;
  Result := id;
end;

procedure TLedger.SetField(const AId, AField: String; AValue: variant);
var
  c: variant;
begin
  c := GetClaim(AId);
  asm if (@c) { (@c)[@AField] = @AValue; } end;
  Sync;
end;

procedure TLedger.AddSpecies(const AId, ASpecies: String);
var
  c: variant;
begin
  c := GetClaim(AId);
  asm
    if (@c) {
      if (!Array.isArray((@c).species))
        (@c).species = (@c).species ? [(@c).species] : [];
      if ((@c).species.indexOf(@ASpecies) === -1)
        (@c).species.push(@ASpecies);
    }
  end;
  LogEvent('species', AId, ASpecies);
  Sync;
end;

procedure TLedger.SetStatus(const AId, AStatus: String);
var
  c: variant;
begin
  c := GetClaim(AId);
  asm if (@c) { (@c).status = @AStatus; } end;
end;

procedure TLedger.AddSource(const AId: String; ATier: Integer;
                            const AOrigin, ARef, AUrl: String);
var
  c: variant;
begin
  c := GetClaim(AId);
  asm
    if (@c) {
      (@c).sources.push({ tier: @ATier, origin: @AOrigin, ref: @ARef, url: @AUrl });
    }
  end;
  LogEvent('source', AId, AOrigin);
  Sync;
end;

procedure TLedger.AddSourceVerified(const AId: String; ATier: Integer;
                                    const AOrigin, ARef, AUrl: String; AVerified: Boolean);
var
  c: variant;
begin
  c := GetClaim(AId);
  asm
    if (@c) {
      (@c).sources.push({ tier: @ATier, origin: @AOrigin, ref: @ARef, url: @AUrl, verified: @AVerified });
    }
  end;
  if AVerified then LogEvent('source', AId, AOrigin)
  else LogEvent('source-unverified', AId, AOrigin);
  Sync;
end;

function TLedger.Promote(const AId: String): TGateVerdict;
var
  c: variant;
  v: TGateVerdict;
begin
  v.Pass    := False;
  v.Reasons := '';

  c := GetClaim(AId);
  if ClaimStr(c, 'id') = '' then
  begin
    v.Reasons := 'No such claim.';
    Result := v;
    Exit;
  end;

  v := CheckPromote(c, FPack);
  if v.Pass then
  begin
    SetStatus(AId, 'finding');
    LogEvent('promote', AId, 'finding');
  end
  else
  begin
    SetStatus(AId, 'working');
    LogEvent('promote-blocked', AId, v.Reasons);
  end;
  Sync;
  Result := v;
end;

function TLedger.Publish(const AId, ASignoff: String): Boolean;
var
  c: variant;
begin
  Result := False;
  if Trim(ASignoff) = '' then Exit;             // L0: the human publishes

  c := GetClaim(AId);
  if ClaimStr(c, 'status') <> 'finding' then    // L0: nothing publishes at lead/working
    Exit;

  SetField(AId, 'signoff', ASignoff);
  SetStatus(AId, 'published');
  LogEvent('publish', AId, ASignoff);
  Sync;
  Result := True;
end;

procedure TLedger.Correct(const AId, ANote: String);
begin
  SetStatus(AId, 'corrected');
  LogEvent('correct', AId, ANote);
  Sync;
end;

procedure TLedger.LogEvent(const AType, AId, ADetail: String);
begin
  asm
    (@FEvents).push({ ts: Date.now(), actor: @FActor, type: @AType, claim: @AId, detail: @ADetail });
  end;
end;

procedure TLedger.Sync;
var
  cj, ej: String;
begin
  asm @cj = JSON.stringify(@FClaims); end;
  asm @ej = JSON.stringify(@FEvents); end;
  if FStore <> nil then
  begin
    FStore.Put('ledger.claims', cj);
    FStore.Put('ledger.events', ej);
    FStore.Put('ledger.count',  IntToStr(ClaimCount));
  end;
  // standalone persistence; no-ops under Node (no localStorage), browser keeps it
  asm
    try {
      localStorage.setItem('research.ledger', @cj);
      localStorage.setItem('research.events', @ej);
    } catch (e) {}
  end;
end;

function TLedger.ToJSON: String;
begin
  asm @Result = JSON.stringify({ claims: @FClaims, events: @FEvents }, null, 2); end;
end;

procedure TLedger.LoadJSON(const AJson: String);
begin
  asm
    var o = @AJson ? JSON.parse(@AJson) : {};
    @FClaims = o.claims || [];
    @FEvents = o.events || [];
  end;
  Sync;
end;

end.
