unit InvoiceData;

// ═══════════════════════════════════════════════════════════════════════════
//
//  InvoiceData — domain models and in-memory store
//
//  All business data lives here. No DOM. No widgets. Plain Pascal.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

type

  TInvoiceStatus = (isDraft, isSent, isPaid, isOverdue);

  TClient = record
    ID:      Integer;
    Name:    String;
    Email:   String;
    Phone:   String;
    Address: String;
    City:    String;
    Country: String;
  end;

  TLineItem = record
    Description: String;
    Qty:         Float;
    UnitPrice:   Float;
    TaxRate:     Float;
  end;

  TInvoice = record
    ID:        Integer;
    Number:    String;
    ClientID:  Integer;
    IssueDate: String;
    DueDate:   String;
    Status:    TInvoiceStatus;
    Notes:     String;
    Lines:     array of TLineItem;
  end;

  TInvoiceStore = class
  private
    FClients:        array of TClient;
    FInvoices:       array of TInvoice;
    FNextClientID:   Integer;
    FNextInvoiceID:  Integer;
    FNextNumber:     Integer;

    procedure SeedClient(const Name, Email, Phone, Address, City, Country: String);
    function  SeedInvoice(ClientID: Integer;
                const Issue, Due: String; Status: TInvoiceStatus;
                const Notes: String): Integer; // returns index into FInvoices
    procedure SeedLine(InvIdx: Integer;
                const Desc: String; Qty, Price, Tax: Float);

  public
    constructor Create;

    // ── ID / number helpers ──────────────────────────────────────────
    function AllocClientID: Integer;
    function AllocInvoiceID: Integer;
    function AllocInvoiceNumber: String;

    // ── Clients ──────────────────────────────────────────────────────
    function  ClientCount: Integer;
    function  GetClient(Index: Integer): TClient;
    function  FindClient(ID: Integer): TClient;
    function  FindClientIndex(ID: Integer): Integer;
    procedure SaveClient(var C: TClient);
    procedure DeleteClient(ID: Integer);

    // ── Invoices ─────────────────────────────────────────────────────
    function  InvoiceCount: Integer;
    function  GetInvoice(Index: Integer): TInvoice;
    function  FindInvoice(ID: Integer): TInvoice;
    function  FindInvoiceIndex(ID: Integer): Integer;
    procedure SaveInvoice(var Inv: TInvoice);
    procedure DeleteInvoice(ID: Integer);
    procedure SetStatus(ID: Integer; Status: TInvoiceStatus);

    // ── Calculations ─────────────────────────────────────────────────
    function  InvoiceSubtotal(const Inv: TInvoice): Float;
    function  InvoiceTax(const Inv: TInvoice): Float;
    function  InvoiceTotal(const Inv: TInvoice): Float;

    // ── Summaries ────────────────────────────────────────────────────
    function  TotalOutstanding: Float;
    function  TotalPaid: Float;
    function  CountByStatus(Status: TInvoiceStatus): Integer;

    // ── Helpers ──────────────────────────────────────────────────────
    function  StatusLabel(Status: TInvoiceStatus): String;
    function  StatusBadgeClass(Status: TInvoiceStatus): String;
    function  FormatMoney(Value: Float): String;
    function  NewBlankInvoice: TInvoice;
  end;

function Store: TInvoiceStore;

implementation

var GStore: TInvoiceStore = nil;

function Store: TInvoiceStore;
begin
  if GStore = nil then
    GStore := TInvoiceStore.Create;
  Result := GStore;
end;


// ── ID / number allocation ────────────────────────────────────────────────

function TInvoiceStore.AllocClientID: Integer;
begin
  Result := FNextClientID;
  FNextClientID := FNextClientID + 1;
end;

function TInvoiceStore.AllocInvoiceID: Integer;
begin
  Result := FNextInvoiceID;
  FNextInvoiceID := FNextInvoiceID + 1;
end;

function TInvoiceStore.AllocInvoiceNumber: String;
var N: String;
begin
  N := IntToStr(FNextNumber);
  while Length(N) < 4 do N := '0' + N;
  Result := 'INV-' + N;
  FNextNumber := FNextNumber + 1;
end;


// ── Seed helpers (regular methods, no nested proc scope issues) ───────────

procedure TInvoiceStore.SeedClient(const Name, Email, Phone,
  Address, City, Country: String);
var C: TClient;
begin
  C.ID      := AllocClientID;
  C.Name    := Name;
  C.Email   := Email;
  C.Phone   := Phone;
  C.Address := Address;
  C.City    := City;
  C.Country := Country;
  FClients.Add(C);
end;

// Returns the index of the new invoice in FInvoices
function TInvoiceStore.SeedInvoice(ClientID: Integer;
  const Issue, Due: String; Status: TInvoiceStatus;
  const Notes: String): Integer;
var Inv: TInvoice;
begin
  // Explicit fresh record — Lines is a new empty array each time
  Inv.ID        := AllocInvoiceID;
  Inv.Number    := AllocInvoiceNumber;
  Inv.ClientID  := ClientID;
  Inv.IssueDate := Issue;
  Inv.DueDate   := Due;
  Inv.Status    := Status;
  Inv.Notes     := Notes;
  FInvoices.Add(Inv);
  Result := FInvoices.Count - 1;
end;

procedure TInvoiceStore.SeedLine(InvIdx: Integer;
  const Desc: String; Qty, Price, Tax: Float);
var L: TLineItem;
begin
  L.Description := Desc;
  L.Qty         := Qty;
  L.UnitPrice   := Price;
  L.TaxRate     := Tax;
  FInvoices[InvIdx].Lines.Add(L);
end;


// ── Constructor ───────────────────────────────────────────────────────────

constructor TInvoiceStore.Create;
var Idx: Integer;
begin
  inherited Create;
  FNextClientID  := 1;
  FNextInvoiceID := 1;
  FNextNumber    := 1;

  // ── Clients ──────────────────────────────────────────────────────

  SeedClient('Acme Corporation',
    'billing@acmecorp.com', '+61 7 4000 1111',
    '42 Industrial Ave', 'Cairns', 'Australia');

  SeedClient('Blue Sky Design',
    'accounts@bluesky.design', '+61 7 4000 2222',
    '7 Palm Street', 'Port Douglas', 'Australia');

  SeedClient('Reef Digital',
    'admin@reefdigital.com.au', '+61 7 4000 3333',
    '101 Esplanade', 'Cairns', 'Australia');

  SeedClient('Tropic Ventures',
    'finance@tropicventures.com.au', '+61 7 4000 4444',
    '55 Sheridan Street', 'Cairns', 'Australia');

  SeedClient('Savanna Systems',
    'pay@savannasys.net', '+61 7 4000 5555',
    '3 Ring Road', 'Atherton', 'Australia');

  // ── Invoices ─────────────────────────────────────────────────────
  // Each SeedInvoice call gets a fresh TInvoice (local var), so
  // Lines is always a new array — no shared-reference contamination.

  Idx := SeedInvoice(1, '2025-09-01','2025-09-15', isPaid,
                     'Website redesign phase 1.');
  SeedLine(Idx, 'UI/UX Design',          10, 150.00, 0.10);
  SeedLine(Idx, 'Frontend Development',  20, 120.00, 0.10);
  SeedLine(Idx, 'Hosting setup',          1,  49.00, 0.10);

  Idx := SeedInvoice(2, '2025-09-10','2025-09-24', isPaid,
                     'Brand identity package.');
  SeedLine(Idx, 'Logo design', 1, 800.00, 0.10);
  SeedLine(Idx, 'Style guide', 1, 350.00, 0.10);

  Idx := SeedInvoice(3, '2025-10-01','2025-10-15', isOverdue,
                     'SEO audit and content strategy.');
  SeedLine(Idx, 'SEO audit',              1, 600.00, 0.10);
  SeedLine(Idx, 'Content strategy doc',   1, 400.00, 0.10);
  SeedLine(Idx, 'Keyword research',       1, 250.00, 0.10);

  Idx := SeedInvoice(4, '2025-11-01','2025-11-30', isSent,
                     'ERP integration consulting.');
  SeedLine(Idx, 'Requirements analysis',   8, 180.00, 0.10);
  SeedLine(Idx, 'Technical specification', 4, 180.00, 0.10);
  SeedLine(Idx, 'Travel expenses',         1, 320.00, 0.00);

  Idx := SeedInvoice(5, '2025-12-01','2025-12-31', isDraft,
                     'Annual support contract renewal.');
  SeedLine(Idx, 'Support — 12 months', 1, 2400.00, 0.10);
  SeedLine(Idx, 'SLA upgrade',         1,  600.00, 0.10);

  Idx := SeedInvoice(1, '2025-12-05','2026-01-04', isSent,
                     'Website redesign phase 2.');
  SeedLine(Idx, 'CMS integration',       16, 120.00, 0.10);
  SeedLine(Idx, 'Responsive layout QA',   8,  90.00, 0.10);
  SeedLine(Idx, 'Copywriting',            4,  95.00, 0.10);

  Idx := SeedInvoice(2, '2026-01-10','2026-02-09', isDraft,
                     'Social media campaign Q1 2026.');
  SeedLine(Idx, 'Campaign strategy',      1,  700.00, 0.10);
  SeedLine(Idx, 'Creative assets (x12)', 1,  960.00, 0.10);
  SeedLine(Idx, 'Scheduling & analytics',1,  400.00, 0.10);
end;


// ── Clients ───────────────────────────────────────────────────────────────

function TInvoiceStore.ClientCount: Integer;
begin Result := FClients.Count; end;

function TInvoiceStore.GetClient(Index: Integer): TClient;
begin Result := FClients[Index]; end;

function TInvoiceStore.FindClientIndex(ID: Integer): Integer;
begin
  Result := -1;
  for var i := 0 to FClients.Count - 1 do
    if FClients[i].ID = ID then begin Result := i; exit; end;
end;

function TInvoiceStore.FindClient(ID: Integer): TClient;
var idx: Integer;
begin
  idx := FindClientIndex(ID);
  if idx >= 0 then Result := FClients[idx];
end;

procedure TInvoiceStore.SaveClient(var C: TClient);
var idx: Integer;
begin
  if C.ID = 0 then
  begin
    C.ID := AllocClientID;
    FClients.Add(C);
  end
  else
  begin
    idx := FindClientIndex(C.ID);
    if idx >= 0 then FClients[idx] := C;
  end;
end;

procedure TInvoiceStore.DeleteClient(ID: Integer);
var idx: Integer;
begin
  idx := FindClientIndex(ID);
  if idx >= 0 then FClients.Delete(idx);
end;


// ── Invoices ──────────────────────────────────────────────────────────────

function TInvoiceStore.InvoiceCount: Integer;
begin Result := FInvoices.Count; end;

function TInvoiceStore.GetInvoice(Index: Integer): TInvoice;
begin Result := FInvoices[Index]; end;

function TInvoiceStore.FindInvoiceIndex(ID: Integer): Integer;
begin
  Result := -1;
  for var i := 0 to FInvoices.Count - 1 do
    if FInvoices[i].ID = ID then begin Result := i; exit; end;
end;

function TInvoiceStore.FindInvoice(ID: Integer): TInvoice;
var idx: Integer;
begin
  idx := FindInvoiceIndex(ID);
  if idx >= 0 then Result := FInvoices[idx];
end;

procedure TInvoiceStore.SaveInvoice(var Inv: TInvoice);
var idx: Integer;
begin
  if Inv.ID = 0 then
  begin
    Inv.ID     := AllocInvoiceID;
    Inv.Number := AllocInvoiceNumber;
    FInvoices.Add(Inv);
  end
  else
  begin
    idx := FindInvoiceIndex(Inv.ID);
    if idx >= 0 then FInvoices[idx] := Inv;
  end;
end;

procedure TInvoiceStore.DeleteInvoice(ID: Integer);
var idx: Integer;
begin
  idx := FindInvoiceIndex(ID);
  if idx >= 0 then FInvoices.Delete(idx);
end;

procedure TInvoiceStore.SetStatus(ID: Integer; Status: TInvoiceStatus);
var idx: Integer;
begin
  idx := FindInvoiceIndex(ID);
  if idx >= 0 then FInvoices[idx].Status := Status;
end;


// ── Calculations ──────────────────────────────────────────────────────────

function TInvoiceStore.InvoiceSubtotal(const Inv: TInvoice): Float;
begin
  Result := 0;
  for var i := 0 to Inv.Lines.Count - 1 do
    Result := Result + Inv.Lines[i].Qty * Inv.Lines[i].UnitPrice;
end;

function TInvoiceStore.InvoiceTax(const Inv: TInvoice): Float;
begin
  Result := 0;
  for var i := 0 to Inv.Lines.Count - 1 do
    Result := Result +
      Inv.Lines[i].Qty * Inv.Lines[i].UnitPrice * Inv.Lines[i].TaxRate;
end;

function TInvoiceStore.InvoiceTotal(const Inv: TInvoice): Float;
begin
  Result := InvoiceSubtotal(Inv) + InvoiceTax(Inv);
end;


// ── Summaries ─────────────────────────────────────────────────────────────

function TInvoiceStore.TotalOutstanding: Float;
begin
  Result := 0;
  for var i := 0 to FInvoices.Count - 1 do
    if FInvoices[i].Status in [isSent, isOverdue] then
      Result := Result + InvoiceTotal(FInvoices[i]);
end;

function TInvoiceStore.TotalPaid: Float;
begin
  Result := 0;
  for var i := 0 to FInvoices.Count - 1 do
    if FInvoices[i].Status = isPaid then
      Result := Result + InvoiceTotal(FInvoices[i]);
end;

function TInvoiceStore.CountByStatus(Status: TInvoiceStatus): Integer;
begin
  Result := 0;
  for var i := 0 to FInvoices.Count - 1 do
    if FInvoices[i].Status = Status then
      Result := Result + 1;
end;


// ── Helpers ───────────────────────────────────────────────────────────────

function TInvoiceStore.StatusLabel(Status: TInvoiceStatus): String;
begin
  case Status of
    isDraft:   Result := 'Draft';
    isSent:    Result := 'Sent';
    isPaid:    Result := 'Paid';
    isOverdue: Result := 'Overdue';
  end;
end;

function TInvoiceStore.StatusBadgeClass(Status: TInvoiceStatus): String;
begin
  case Status of
    isDraft:   Result := 'badge-secondary';
    isSent:    Result := 'badge-info';
    isPaid:    Result := 'badge-success';
    isOverdue: Result := 'badge-danger';
  end;
end;

function TInvoiceStore.FormatMoney(Value: Float): String;
var S: String;
begin
  asm
    var n = Math.round(@Value * 100) / 100;
    @S = '$' + n.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  end;
  Result := S;
end;

function TInvoiceStore.NewBlankInvoice: TInvoice;
begin
  Result.ID       := 0;
  Result.Number   := '';
  Result.ClientID := 0;
  Result.Status   := isDraft;
  Result.Notes    := '';
  asm
    var d = new Date();
    var fmt = function(d2) { return d2.toISOString().substring(0,10); };
    @Result.IssueDate = fmt(d);
    d.setDate(d.getDate() + 30);
    @Result.DueDate = fmt(d);
  end;
end;

initialization
end.
