unit JBudget;

// ═══════════════════════════════════════════════════════════════════════════
//  JBudget — the meter and the breaker.
//
//  The unit whose absence let an earlier run consume a whole budget in silence.
//  Every model call's usage is recorded here; totals stream to the DataStore
//  (meter.*) so a console always shows the spend; a token ceiling trips a
//  breaker. The run driver records usage from each call's TLLMResult and checks
//  Tripped before the next call.
//
//  M1: usage comes from a non-streaming Send (TLLMResult carries InputTokens /
//  OutputTokens). M2 moves the authoritative breaker into the proxy so an
//  unattended run cannot bypass it by closing a tab.
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JDataStore;

type
  TTripProc = procedure;

  TBudget = class
  private
    FStore:   JW3DataStore;
    FIn:      Integer;
    FOut:     Integer;
    FCalls:   Integer;
    FCeiling: Integer;        // ceiling on total tokens; 0 = unlimited
    FTripped: Boolean;
    FOnTrip:  TTripProc;
    procedure Publish;
  public
    constructor Create(AStore: JW3DataStore; ACeilingTokens: Integer);
    procedure RecordUsage(AInTok, AOutTok: Integer);   // call on each TLLMResult
    function  Total: Integer;
    function  Tripped: Boolean;
    procedure OnTrip(ACb: TTripProc);                  // optional breaker hook
    procedure Reset;
  end;

implementation

constructor TBudget.Create(AStore: JW3DataStore; ACeilingTokens: Integer);
begin
  inherited Create;
  FStore   := AStore;
  FCeiling := ACeilingTokens;
  Reset;
end;

procedure TBudget.Reset;
begin
  FIn := 0; FOut := 0; FCalls := 0; FTripped := False;
  Publish;
  if FStore <> nil then FStore.Put('meter.tripped', 'false');
end;

procedure TBudget.Publish;
begin
  if FStore = nil then Exit;
  FStore.Put('meter.inTokens',  IntToStr(FIn));
  FStore.Put('meter.outTokens', IntToStr(FOut));
  FStore.Put('meter.total',     IntToStr(Total));
  FStore.Put('meter.calls',     IntToStr(FCalls));
  FStore.Put('meter.ceiling',   IntToStr(FCeiling));
end;

procedure TBudget.RecordUsage(AInTok, AOutTok: Integer);
begin
  FIn    := FIn + AInTok;
  FOut   := FOut + AOutTok;
  FCalls := FCalls + 1;
  Publish;
  if (not FTripped) and (FCeiling > 0) and (Total > FCeiling) then
  begin
    FTripped := True;
    if FStore <> nil then FStore.Put('meter.tripped', 'true');
    if Assigned(FOnTrip) then FOnTrip();
  end;
end;

function TBudget.Total: Integer;
begin
  Result := FIn + FOut;
end;

function TBudget.Tripped: Boolean;
begin
  Result := FTripped;
end;

procedure TBudget.OnTrip(ACb: TTripProc);
begin
  FOnTrip := ACb;
end;

end.
