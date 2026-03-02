unit DataStore;

// ═══════════════════════════════════════════════════════════════════════════
//
//  DataStore
//
//  An observable key-value store. Components subscribe to key changes
//  and get notified when values update. This is the bridge between
//  non-visual data and visual components.
//
//  Usage:
//
//    var Store := TDataStore.Create;
//
//    // Subscribe to changes
//    Store.Subscribe('user.name',
//      procedure(Key: String; Value: variant)
//      begin
//        FNameLabel.SetText(String(Value));
//      end);
//
//    // Setting a value fires all subscribers for that key
//    Store.Put('user.name', 'Nico');
//
//    // Read without subscribing
//    var name := Store.Get('user.name');
//
//    // Bulk update — subscribers fire once per key
//    Store.BeginUpdate;
//    Store.Put('user.name', 'Nico');
//    Store.Put('user.email', 'nico@example.com');
//    Store.EndUpdate;
//
//  The store uses variant values — it can hold strings, integers, floats,
//  booleans, or JavaScript objects/arrays. Subscribers receive the raw
//  variant and cast as needed.
//
//  This is a plain Pascal class. It does not inherit from TElement.
//  It does not touch the DOM. It is a non-visual component.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type
  TStoreCallback = procedure(Key: String; Value: variant);

  TSubscription = record
    Key:      String;
    Callback: TStoreCallback;
  end;

  TDeferredKey = record
    Key: String;
  end;

  TDataStore = class
  private
    FData:         variant;        // JavaScript object used as hash map
    FSubs:         array of TSubscription;
    FUpdateCount:  Integer;
    FDirtyKeys:    array of TDeferredKey;

    procedure Notify(const Key: String; Value: variant);
    procedure FlushDeferred;

  public
    constructor Create;
    destructor  Destroy; override;

    // ── Read / Write ─────────────────────────────────────────────────
    procedure Put(const Key: String; Value: variant);
    function  Get(const Key: String): variant;
    function  Has(const Key: String): Boolean;
    procedure Remove(const Key: String);

    // ── Observation ──────────────────────────────────────────────────
    procedure Subscribe(const Key: String; Callback: TStoreCallback);
    procedure Unsubscribe(const Key: String; Callback: TStoreCallback);

    // ── Batch updates ────────────────────────────────────────────────
    procedure BeginUpdate;
    procedure EndUpdate;

    // ── Utility ──────────────────────────────────────────────────────
    procedure Clear;
  end;

implementation


{ TDataStore }

constructor TDataStore.Create;
begin
  inherited Create;
  FUpdateCount := 0;
  asm @self.FData = {}; end;
end;

destructor TDataStore.Destroy;
begin
  FSubs.Clear;
  FDirtyKeys.Clear;
  inherited;
end;


//=============================================================================
// Read / Write
//=============================================================================

procedure TDataStore.Put(const Key: String; Value: variant);
begin
  asm (@self.FData)[@Key] = @Value; end;

  if FUpdateCount > 0 then
  begin
    // Deferred — record the key, notify on EndUpdate
    var Found := false;
    for var i := 0 to FDirtyKeys.Count - 1 do
      if FDirtyKeys[i].Key = Key then
      begin
        Found := true;
        break;
      end;
    if not Found then
    begin
      var dk: TDeferredKey;
      dk.Key := Key;
      FDirtyKeys.Add(dk);
    end;
  end
  else
    Notify(Key, Value);
end;

function TDataStore.Get(const Key: String): variant;
begin
  asm @Result = (@self.FData)[@Key]; end;
end;

function TDataStore.Has(const Key: String): Boolean;
begin
  asm @Result = (@Key in @self.FData); end;
end;

procedure TDataStore.Remove(const Key: String);
begin
  asm delete (@self.FData)[@Key]; end;
end;


//=============================================================================
// Observation
//=============================================================================

procedure TDataStore.Subscribe(const Key: String; Callback: TStoreCallback);
var
  sub: TSubscription;
begin
  sub.Key      := Key;
  sub.Callback := Callback;
  FSubs.Add(sub);
end;

procedure TDataStore.Unsubscribe(const Key: String; Callback: TStoreCallback);
begin
  for var i := FSubs.Count - 1 downto 0 do
  begin
    if (FSubs[i].Key = Key) and (@FSubs[i].Callback = @Callback) then
    begin
      FSubs.Delete(i);
      exit;
    end;
  end;
end;

procedure TDataStore.Notify(const Key: String; Value: variant);
begin
  for var i := 0 to FSubs.Count - 1 do
  begin
    if FSubs[i].Key = Key then
      FSubs[i].Callback(Key, Value);
  end;
end;


//=============================================================================
// Batch updates
//=============================================================================

procedure TDataStore.BeginUpdate;
begin
  inc(FUpdateCount);
end;

procedure TDataStore.EndUpdate;
begin
  dec(FUpdateCount);
  if FUpdateCount <= 0 then
  begin
    FUpdateCount := 0;
    FlushDeferred;
  end;
end;

procedure TDataStore.FlushDeferred;
begin
  for var i := 0 to FDirtyKeys.Count - 1 do
  begin
    var Key := FDirtyKeys[i].Key;
    Notify(Key, Get(Key));
  end;
  FDirtyKeys.Clear;
end;


//=============================================================================
// Utility
//=============================================================================

procedure TDataStore.Clear;
begin
  asm @self.FData = {}; end;
  FDirtyKeys.Clear;
end;

end.
