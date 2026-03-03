unit JDataStore;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JW3DataStore — Observable Key-Value Store
//
//  A simple reactive data layer. Components subscribe to keys and get
//  notified when values change. Decouples data producers from consumers.
//
//  Usage:
//
//    var Store := JW3DataStore.Create;
//
//    // Subscribe — returns a subscription ID for unsubscribe
//    var SubId := Store.Subscribe('user.name', procedure(Key: String; Value: variant)
//    begin
//      NameLabel.SetText(Value);
//    end);
//
//    // Put fires all subscribers for that key
//    Store.Put('user.name', 'Nico');
//
//    // Get retrieves current value
//    var Name := Store.Get('user.name');
//
//    // Unsubscribe when done
//    Store.Unsubscribe(SubId);
//
//    // Subscribe to ALL changes (wildcard)
//    Store.Subscribe('*', procedure(Key: String; Value: variant)
//    begin
//      Console.Log('Changed: ' + Key);
//    end);
//
//    // Batch: defer notifications until EndUpdate
//    Store.BeginUpdate;
//    Store.Put('x', 1);
//    Store.Put('y', 2);
//    Store.Put('z', 3);
//    Store.EndUpdate;   // fires all subscribers once per changed key
//
//    // Delete a key
//    Store.Delete('user.name');
//
//    // Observe: subscribe + immediately fire with current value
//    Store.Observe('user.name', MyCallback);
//
//  Design:
//
//    - Keys are dot-notation strings (convention, not enforced)
//    - Values are variant (any JS value)
//    - Subscriptions are per-key or wildcard ('*')
//    - Subscription IDs are integers for easy unsubscribe
//    - BeginUpdate/EndUpdate batches notifications
//    - FKeys array tracks existence — avoids JS undefined checks
//    - Zero asm blocks
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type
  TStoreNotify = procedure(const Key: String; Value: variant);

  TSubscription = record
    Id:       Integer;
    Key:      String;
    Callback: TStoreNotify;
  end;

  JW3DataStore = class
  private
    FStore:       variant;
    FKeys:        array of String;
    FSubs:        array of TSubscription;
    FNextId:      Integer;
    FUpdateCount: Integer;
    FChanged:     array of String;

    procedure Notify(const Key: String; Value: variant);
    procedure FlushChanged;
    function  IndexOfSub(Id: Integer): Integer;
    function  IndexOfKey(const Key: String): Integer;
    procedure RecordChange(const Key: String);

  public
    constructor Create;
    destructor  Destroy; override;

    // ── Data access ──────────────────────────────────────────────────
    procedure Put(const Key: String; Value: variant);
    function  Get(const Key: String): variant;
    function  Has(const Key: String): Boolean;
    procedure Delete(const Key: String);
    procedure Clear;
    function  Keys: array of String;
    function  Count: Integer;

    // ── Subscriptions ────────────────────────────────────────────────
    function  Subscribe(const Key: String; Callback: TStoreNotify): Integer;
    procedure Unsubscribe(Id: Integer);
    function  Observe(const Key: String; Callback: TStoreNotify): Integer;

    // ── Batching ─────────────────────────────────────────────────────
    procedure BeginUpdate;
    procedure EndUpdate;
  end;

implementation


// ═════════════════════════════════════════════════════════════════════════
// Constructor
// ═════════════════════════════════════════════════════════════════════════

constructor JW3DataStore.Create;
begin
  inherited Create;
  FStore       := variant(TObject.Create);
  FNextId      := 1;
  FUpdateCount := 0;
end;

destructor JW3DataStore.Destroy;
begin
  FSubs.Clear;
  FKeys.Clear;
  FChanged.Clear;
  inherited;
end;


// ═════════════════════════════════════════════════════════════════════════
// Key tracking
// ═════════════════════════════════════════════════════════════════════════

function JW3DataStore.IndexOfKey(const Key: String): Integer;
begin
  Result := -1;
  for var i := 0 to FKeys.Count - 1 do
    if FKeys[i] = Key then begin Result := i; exit; end;
end;

procedure JW3DataStore.RecordChange(const Key: String);
begin
  for var i := 0 to FChanged.Count - 1 do
    if FChanged[i] = Key then exit;
  FChanged.Add(Key);
end;


// ═════════════════════════════════════════════════════════════════════════
// Data access
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataStore.Put(const Key: String; Value: variant);
begin
  var isNew := not Has(Key);
  FStore[Key] := Value;

  if isNew then
    FKeys.Add(Key);

  if FUpdateCount > 0 then
    RecordChange(Key)
  else
    Notify(Key, Value);
end;

function JW3DataStore.Get(const Key: String): variant;
begin
  if Has(Key) then
    Result := FStore[Key]
  else
    Result := nil;
end;

function JW3DataStore.Has(const Key: String): Boolean;
begin
  Result := Boolean(FStore.hasOwnProperty(Key));
end;

procedure JW3DataStore.Delete(const Key: String);
var
  idx: Integer;
begin
  idx := IndexOfKey(Key);
  if idx < 0 then exit;
  FKeys.Delete(idx);

  if FUpdateCount > 0 then
    RecordChange(Key)
  else
    Notify(Key, nil);
end;

procedure JW3DataStore.Clear;
var
  snapshot: array of String;
begin
  snapshot := FKeys;
  FStore   := variant(TObject.Create);
  FKeys.Clear;
  for var i := 0 to snapshot.Count - 1 do
    Notify(snapshot[i], nil);
end;

function JW3DataStore.Keys: array of String;
begin
  Result := FKeys;
end;

function JW3DataStore.Count: Integer;
begin
  Result := FKeys.Count;
end;


// ═════════════════════════════════════════════════════════════════════════
// Subscriptions
// ═════════════════════════════════════════════════════════════════════════

function JW3DataStore.Subscribe(const Key: String; Callback: TStoreNotify): Integer;
var
  Sub: TSubscription;
begin
  Sub.Id       := FNextId;
  Sub.Key      := Key;
  Sub.Callback := Callback;
  FSubs.Add(Sub);

  Result  := FNextId;
  FNextId := FNextId + 1;
end;

procedure JW3DataStore.Unsubscribe(Id: Integer);
var
  idx: Integer;
begin
  idx := IndexOfSub(Id);
  if idx >= 0 then
    FSubs.Delete(idx);
end;

function JW3DataStore.Observe(const Key: String; Callback: TStoreNotify): Integer;
begin
  Result := Subscribe(Key, Callback);
  if Has(Key) then
    Callback(Key, Get(Key));
end;

function JW3DataStore.IndexOfSub(Id: Integer): Integer;
begin
  Result := -1;
  for var i := 0 to FSubs.Count - 1 do
    if FSubs[i].Id = Id then begin Result := i; exit; end;
end;


// ═════════════════════════════════════════════════════════════════════════
// Notification
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataStore.Notify(const Key: String; Value: variant);
begin
  for var i := 0 to FSubs.Count - 1 do
    if (FSubs[i].Key = Key) or (FSubs[i].Key = '*') then
      FSubs[i].Callback(Key, Value);
end;


// ═════════════════════════════════════════════════════════════════════════
// Batching
// ═════════════════════════════════════════════════════════════════════════

procedure JW3DataStore.BeginUpdate;
begin
  FUpdateCount := FUpdateCount + 1;
end;

procedure JW3DataStore.EndUpdate;
begin
  if FUpdateCount > 0 then
    FUpdateCount := FUpdateCount - 1;
  if FUpdateCount = 0 then
    FlushChanged;
end;

procedure JW3DataStore.FlushChanged;
var
  val: variant;
begin
  for var i := 0 to FChanged.Count - 1 do
  begin
    if Has(FChanged[i]) then
      val := Get(FChanged[i])
    else
      val := nil;
    Notify(FChanged[i], val);
  end;
  FChanged.Clear;
end;

end.
