unit HASData;

// ═══════════════════════════════════════════════════════════════════════════
//
//  HASData — Global data store, session state, helpers, and seed data
//
//  All in-memory arrays live here. SeedData() is called once on first
//  use (from FormLogin). Helpers are pure functions with no DOM side
//  effects except NowISO/FmtDate which call JS Date.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses HASTypes;

// ── Session state ─────────────────────────────────────────────────────────

var
  CurrentRole:         String;
  CurrentUser:         String;
  CurrentContractorID: String;
  CurrentCustomerID:   String;

// ── Data stores ───────────────────────────────────────────────────────────

var
  HAS_Customers:   array of TCustomer;
  HAS_Contractors: array of TContractor;
  HAS_Activities:  array of TActivity;
  HAS_Enrollments: array of TEnrollment;
  HAS_Quotes:      array of TQuote;
  HAS_Batches:     array of TBatch;
  HAS_Payments:    array of TPayment;
  HAS_AuditLog:    array of TAuditEvent;
  HAS_AuditSeq:    Integer;

// ── Helpers ───────────────────────────────────────────────────────────────

function  NewID(const Prefix: String): String;
function  NowISO: String;
function  FmtDate(const ISO: String): String;
function  FmtCur(Amount: Float): String;
function  StatusBadge(const Status: String): String;

// Lookup helpers (return index in array, or -1)
function FindCustomerIdx(const ID: String): Integer;
function FindContractorIdx(const ID: String): Integer;
function FindActivityIdx(const ID: String): Integer;
function FindEnrollmentIdx(const ID: String): Integer;
function FindQuoteIdx(const ID: String): Integer;
function FindBatchIdx(const ID: String): Integer;
function FindPaymentIdx(const ID: String): Integer;

// Name helpers (for display in tables / forms)
function CustomerFullName(const ID: String): String;
function ContractorBizName(const ID: String): String;
function ActivityName(const ID: String): String;
function EnrollmentForCustomer(const CustomerID: String): String;  // returns EnrollmentID

// Quote actions
function  QuoteRequest(const CustomerID, ContractorID, ActivityID, Notes: String): String;
procedure QuoteSubmit(const QuoteID, Desc: String; Qty: Integer; Price: Float);
procedure QuoteAccept(const QuoteID: String);
procedure QuoteAssess(const QuoteID: String; SubsidyAmt: Float; const Notes: String);
procedure QuoteMarkReady(const QuoteID: String);
procedure QuoteCommence(const QuoteID: String);
procedure QuoteComplete(const QuoteID: String);
procedure QuoteVerify(const QuoteID: String);
procedure QuoteDispute(const QuoteID, Reason: String);
procedure QuoteResolveDispute(const QuoteID, Outcome: String);

// Catalogue actions
procedure CatalogueAddActivity(const Name, Category, Program_: String;
                               MaxSubsidy: Float; const Desc: String);

// Batch actions
function  BatchCreate(const ContractorID: String): String;
procedure BatchSend(const BatchID: String);

// Payment actions
procedure PaymentMarkPaid(const PaymentID, Ref: String);

procedure LogEvent(const EventType, EntityType, EntityID, Details: String);
procedure SeedData;

implementation

// ── NowISO ────────────────────────────────────────────────────────────────

function NowISO: String;
begin
  asm @Result = new Date().toISOString(); end;
end;

// ── NewID ─────────────────────────────────────────────────────────────────

function NewID(const Prefix: String): String;
var ts: String;
begin
  asm @ts = Date.now().toString(36).slice(-5).toUpperCase(); end;
  Result := Prefix + '-' + ts;
end;

// ── FmtDate ───────────────────────────────────────────────────────────────

function FmtDate(const ISO: String): String;
begin
  if ISO = '' then
  begin
    Result := '—';
    exit;
  end;
  asm
    try {
      @Result = new Date(@ISO).toLocaleDateString('en-AU',
        { day: 'numeric', month: 'short', year: 'numeric' });
    } catch(e) {
      @Result = @ISO;
    }
  end;
end;

// ── FmtCur ────────────────────────────────────────────────────────────────

function FmtCur(Amount: Float): String;
begin
  asm @Result = '$' + (@Amount).toFixed(2); end;
end;

// ── StatusBadge ───────────────────────────────────────────────────────────

function StatusBadge(const Status: String): String;
var Cls: String;
begin
  if (Status = stActive)    or (Status = stVerified)  or (Status = stCompleted)
  or (Status = stEnrolled)  or (Status = bsCompleted) or (Status = psPaid)
  or (Status = 'Login')
  then Cls := 'has-status-green'
  else if (Status = stRequested)     or (Status = stSubmitted)
       or (Status = stWorkCommenced) or (Status = bsPending)
       or (Status = psPending)       or (Status = stRegistered)
  then Cls := 'has-status-blue'
  else if (Status = stDisputed) or (Status = stSuspended) or (Status = stCancelled)
  then Cls := 'has-status-red'
  else if (Status = stAssessed) or (Status = stReadyForBatch)
       or (Status = stAcceptedByCustomer) or (Status = bsSent)
  then Cls := 'has-status-yellow'
  else Cls := 'has-status-grey';

  Result := '<span class="has-status ' + Cls + '">' + Status + '</span>';
end;

// ── LogEvent ──────────────────────────────────────────────────────────────

procedure LogEvent(const EventType, EntityType, EntityID, Details: String);
var entry: TAuditEvent;
begin
  inc(HAS_AuditSeq);
  entry.ID         := HAS_AuditSeq;
  entry.EventType  := EventType;
  entry.EntityType := EntityType;
  entry.EntityID   := EntityID;
  entry.Actor      := CurrentRole;
  entry.Details    := Details;
  entry.LoggedAt   := NowISO;
  HAS_AuditLog.Add(entry);
end;

// ── SeedData ──────────────────────────────────────────────────────────────

procedure SeedData;
var
  c:  TCustomer;
  ct: TContractor;
  a:  TActivity;
  e:  TEnrollment;
  q:  TQuote;
  li: TLineItem;
  b:  TBatch;
  p:  TPayment;
begin

  // ── Customers ────────────────────────────────────────────────────

  c.ID := 'CUST-001'; c.FirstName := 'Margaret'; c.LastName := 'Thornton';
  c.DOB := '1958-03-15'; c.Street := '14 Hibiscus Lane';
  c.Suburb := 'Holloways Beach'; c.Postcode := '4878'; c.Region := 'Cairns North';
  c.Phone := '07 4051 1234'; c.Email := 'margaret@email.com';
  c.EmergencyContact := 'Susan Thornton'; c.EmergencyPhone := '04xx111111';
  c.Status := stEnrolled; c.CreatedAt := '2024-01-15T00:00:00.000Z';
  HAS_Customers.Add(c);

  c.ID := 'CUST-002'; c.FirstName := 'Harold'; c.LastName := 'Patel';
  c.DOB := '1955-07-22'; c.Street := '8 Mango Street';
  c.Suburb := 'Kuranda'; c.Postcode := '4881'; c.Region := 'Kuranda';
  c.Phone := '07 4093 5678'; c.Email := 'harold@email.com';
  c.EmergencyContact := 'Priya Patel'; c.EmergencyPhone := '04xx222222';
  c.Status := stEnrolled; c.CreatedAt := '2024-02-10T00:00:00.000Z';
  HAS_Customers.Add(c);

  c.ID := 'CUST-003'; c.FirstName := 'Jean'; c.LastName := 'McKenzie';
  c.DOB := '1961-11-08'; c.Street := '22 Coral Ave';
  c.Suburb := 'Palm Cove'; c.Postcode := '4879'; c.Region := 'Cairns North';
  c.Phone := '07 4051 9012'; c.Email := 'jean@email.com';
  c.EmergencyContact := 'Tom McKenzie'; c.EmergencyPhone := '04xx333333';
  c.Status := stEnrolled; c.CreatedAt := '2024-03-05T00:00:00.000Z';
  HAS_Customers.Add(c);

  // ── Contractors ──────────────────────────────────────────────────

  ct.ID := 'CONT-001'; ct.BusinessName := 'Cairns Security Solutions';
  ct.ContactName := 'David Nguyen'; ct.Phone := '07 4055 1234';
  ct.Email := 'david@cairnssec.com'; ct.ABN := '12345678901';
  ct.Licence := 'QLD-SEC-44521'; ct.LicenceExpiry := '2025-12-31';
  ct.Categories := 'Locks,Security Doors,Cameras';
  ct.Regions := 'Cairns North,Kuranda';
  ct.Status := stActive; ct.RegisteredAt := '2023-06-01T00:00:00.000Z';
  HAS_Contractors.Add(ct);

  ct.ID := 'CONT-002'; ct.BusinessName := 'Tropical Fencing Co';
  ct.ContactName := 'Sarah Kim'; ct.Phone := '07 4055 5678';
  ct.Email := 'sarah@tropfence.com'; ct.ABN := '98765432101';
  ct.Licence := 'QLD-FEN-33210'; ct.LicenceExpiry := '2025-09-30';
  ct.Categories := 'Fences,Roller Doors';
  ct.Regions := 'Cairns North,Cairns South,Palm Cove';
  ct.Status := stActive; ct.RegisteredAt := '2023-07-15T00:00:00.000Z';
  HAS_Contractors.Add(ct);

  ct.ID := 'CONT-003'; ct.BusinessName := 'FNQ Maintenance';
  ct.ContactName := 'Bob Walker'; ct.Phone := '07 4055 9999';
  ct.Email := 'bob@fnqmaint.com'; ct.ABN := '11223344556';
  ct.Licence := 'QLD-MNT-55001'; ct.LicenceExpiry := '2026-03-15';
  ct.Categories := 'Smoke Alarms,Lawn Mowing,Solar Panel Cleaning,Gutter Cleaning';
  ct.Regions := 'Cairns North,Cairns South,Kuranda,Tablelands';
  ct.Status := stActive; ct.RegisteredAt := '2023-08-20T00:00:00.000Z';
  HAS_Contractors.Add(ct);

  ct.ID := 'CONT-004'; ct.BusinessName := 'Security Glass Specialists';
  ct.ContactName := 'Mei Chen'; ct.Phone := '07 4056 0001';
  ct.Email := 'mei@secglass.com'; ct.ABN := '44556677889';
  ct.Licence := 'QLD-GLZ-22100'; ct.LicenceExpiry := '2025-06-30';
  ct.Categories := 'Security Glass';
  ct.Regions := 'Cairns South';
  ct.Status := stSuspended; ct.RegisteredAt := '2023-09-10T00:00:00.000Z';
  HAS_Contractors.Add(ct);

  // ── Activities ───────────────────────────────────────────────────

  a.ID := 'ACT-001'; a.Name := 'Deadbolt Replacement'; a.Category := 'Locks';
  a.Program := progHSSH; a.MaxSubsidy := 250;
  a.Description := 'Replace existing deadbolt with high-security model';
  HAS_Activities.Add(a);

  a.ID := 'ACT-002'; a.Name := 'Fence Repair'; a.Category := 'Fences';
  a.Program := progHSSH; a.MaxSubsidy := 400;
  a.Description := 'Repair damaged fence sections';
  HAS_Activities.Add(a);

  a.ID := 'ACT-003'; a.Name := 'Security Door Installation'; a.Category := 'Security Doors';
  a.Program := progHSSH; a.MaxSubsidy := 800;
  a.Description := 'Install a security screen door';
  HAS_Activities.Add(a);

  a.ID := 'ACT-004'; a.Name := 'CCTV Camera System'; a.Category := 'Cameras';
  a.Program := progHSSH; a.MaxSubsidy := 600;
  a.Description := 'Install and wire a 4-camera CCTV system';
  HAS_Activities.Add(a);

  a.ID := 'ACT-005'; a.Name := 'Roller Door Replacement'; a.Category := 'Roller Doors';
  a.Program := progHSSH; a.MaxSubsidy := 900;
  a.Description := 'Replace garage roller door with security model';
  HAS_Activities.Add(a);

  a.ID := 'ACT-006'; a.Name := 'Security Glass Upgrade'; a.Category := 'Security Glass';
  a.Program := progHSSH; a.MaxSubsidy := 1200;
  a.Description := 'Replace window glass with laminated security glass';
  HAS_Activities.Add(a);

  a.ID := 'ACT-007'; a.Name := 'Smoke Alarm Check'; a.Category := 'Smoke Alarms';
  a.Program := progHAS; a.MaxSubsidy := 80;
  a.Description := 'Annual smoke alarm inspection and battery replacement';
  HAS_Activities.Add(a);

  a.ID := 'ACT-008'; a.Name := 'Lawn Mowing'; a.Category := 'Lawn Mowing';
  a.Program := progHAS; a.MaxSubsidy := 60;
  a.Description := 'Fortnightly lawn mowing service';
  HAS_Activities.Add(a);

  a.ID := 'ACT-009'; a.Name := 'Solar Panel Cleaning'; a.Category := 'Solar Panel Cleaning';
  a.Program := progHAS; a.MaxSubsidy := 120;
  a.Description := 'Annual solar panel cleaning';
  HAS_Activities.Add(a);

  a.ID := 'ACT-010'; a.Name := 'Gutter Cleaning'; a.Category := 'Gutter Cleaning';
  a.Program := progHAS; a.MaxSubsidy := 90;
  a.Description := 'Annual gutter and downpipe cleaning';
  HAS_Activities.Add(a);

  // ── Enrollments ──────────────────────────────────────────────────

  e.ID := 'ENR-001'; e.CustomerID := 'CUST-001';
  e.Program := progHSSH; e.ProgramLabel := progHSSHLabel;
  e.BudgetAllocated := 9000; e.BudgetSpent := 250;
  e.Status := stActive; e.EnrolledAt := '2024-03-01T00:00:00.000Z';
  HAS_Enrollments.Add(e);

  e.ID := 'ENR-002'; e.CustomerID := 'CUST-001';
  e.Program := progHAS; e.ProgramLabel := progHASLabel;
  e.BudgetAllocated := 500; e.BudgetSpent := 0;
  e.Status := stActive; e.EnrolledAt := '2024-03-01T00:00:00.000Z';
  HAS_Enrollments.Add(e);

  e.ID := 'ENR-003'; e.CustomerID := 'CUST-002';
  e.Program := progHSSH; e.ProgramLabel := progHSSHLabel;
  e.BudgetAllocated := 9000; e.BudgetSpent := 0;
  e.Status := stActive; e.EnrolledAt := '2024-04-10T00:00:00.000Z';
  HAS_Enrollments.Add(e);

  e.ID := 'ENR-004'; e.CustomerID := 'CUST-003';
  e.Program := progHSSH; e.ProgramLabel := progHSSHLabel;
  e.BudgetAllocated := 9000; e.BudgetSpent := 150;
  e.Status := stActive; e.EnrolledAt := '2024-05-20T00:00:00.000Z';
  HAS_Enrollments.Add(e);

  e.ID := 'ENR-005'; e.CustomerID := 'CUST-003';
  e.Program := progHAS; e.ProgramLabel := progHASLabel;
  e.BudgetAllocated := 500; e.BudgetSpent := 75;
  e.Status := stActive; e.EnrolledAt := '2024-05-20T00:00:00.000Z';
  HAS_Enrollments.Add(e);

  // ── Quotes ───────────────────────────────────────────────────────

  q.ID := 'QUO-001'; q.CustomerID := 'CUST-001'; q.ContractorID := 'CONT-001';
  q.EnrollmentID := 'ENR-001'; q.ActivityID := 'ACT-001';
  q.Status := stCompleted;
  q.LineItems.SetLength(0);
  li.Desc := 'High-security deadbolt'; li.Qty := 1; li.Price := 180;
  q.LineItems.Add(li);
  li.Desc := 'Labour'; li.Qty := 1; li.Price := 95;
  q.LineItems.Add(li);
  q.Subtotal := 275; q.GST := 27.50; q.Total := 302.50;
  q.DepositRequired := 0; q.SubsidyAmount := 250; q.CustomerExcess := 52.50;
  q.DepositReceived := 0; q.Notes := 'Front door only';
  q.RequestedAt := '2024-08-20T00:00:00.000Z';
  q.SubmittedAt := '2024-08-22T00:00:00.000Z';
  q.AssessedBy := 'Staff'; q.AssessedAt := '2024-08-24T00:00:00.000Z';
  q.AssessmentNotes := 'Approved — excess $52.50';
  q.CompletedAt := '2024-09-02T00:00:00.000Z';
  q.VerifiedAt := '2024-09-03T00:00:00.000Z';
  q.DisputedAt := ''; q.DisputeReason := '';
  q.DisputeResolvedAt := ''; q.DisputeOutcome := '';
  HAS_Quotes.Add(q);

  q.LineItems.SetLength(0);
  q.ID := 'QUO-002'; q.CustomerID := 'CUST-002'; q.ContractorID := 'CONT-001';
  q.EnrollmentID := 'ENR-003'; q.ActivityID := 'ACT-004';
  q.Status := stSubmitted;
  li.Desc := '4-cam CCTV system'; li.Qty := 1; li.Price := 480;
  q.LineItems.Add(li);
  li.Desc := 'Installation labour'; li.Qty := 1; li.Price := 140;
  q.LineItems.Add(li);
  q.Subtotal := 620; q.GST := 62; q.Total := 682;
  q.DepositRequired := 0; q.SubsidyAmount := 0; q.CustomerExcess := 0;
  q.DepositReceived := 0; q.Notes := 'Front and back coverage';
  q.RequestedAt := '2024-09-01T00:00:00.000Z';
  q.SubmittedAt := '2024-09-05T00:00:00.000Z';
  q.AssessedBy := ''; q.AssessedAt := ''; q.AssessmentNotes := '';
  q.CompletedAt := ''; q.VerifiedAt := '';
  q.DisputedAt := ''; q.DisputeReason := '';
  q.DisputeResolvedAt := ''; q.DisputeOutcome := '';
  HAS_Quotes.Add(q);

  q.LineItems.SetLength(0);
  q.ID := 'QUO-003'; q.CustomerID := 'CUST-003'; q.ContractorID := 'CONT-002';
  q.EnrollmentID := 'ENR-004'; q.ActivityID := 'ACT-002';
  q.Status := stRequested;
  q.Subtotal := 0; q.GST := 0; q.Total := 0;
  q.DepositRequired := 0; q.SubsidyAmount := 0; q.CustomerExcess := 0;
  q.DepositReceived := 0; q.Notes := 'Backyard fence';
  q.RequestedAt := '2024-09-10T00:00:00.000Z';
  q.SubmittedAt := ''; q.AssessedBy := ''; q.AssessedAt := '';
  q.AssessmentNotes := ''; q.CompletedAt := ''; q.VerifiedAt := '';
  q.DisputedAt := ''; q.DisputeReason := '';
  q.DisputeResolvedAt := ''; q.DisputeOutcome := '';
  HAS_Quotes.Add(q);

  // ── Batches ──────────────────────────────────────────────────────

  b.ID := 'BATCH-001'; b.ContractorID := 'CONT-001';
  b.QuoteIDs.SetLength(0);
  b.QuoteIDs.Add('QUO-001');
  b.Status := bsCompleted;
  b.CreatedAt := '2024-08-30T00:00:00.000Z';
  b.SentAt    := '2024-08-30T00:00:00.000Z';
  HAS_Batches.Add(b);

  // ── Payments ─────────────────────────────────────────────────────

  p.ID := 'PAY-001'; p.QuoteID := 'QUO-001'; p.BatchID := 'BATCH-001';
  p.PayType := ptSubsidy; p.Amount := 250; p.Status := psPaid;
  p.InvoiceNumber := 'INV-2024-001';
  p.PaidAt := '2024-09-05T00:00:00.000Z'; p.PaymentRef := 'TXN-PAY-88221';
  HAS_Payments.Add(p);

  p.ID := 'PAY-002'; p.QuoteID := 'QUO-001'; p.BatchID := '';
  p.PayType := ptCustomerExcess; p.Amount := 52.50; p.Status := psPaid;
  p.InvoiceNumber := 'INV-EXC-001';
  p.PaidAt := '2024-09-04T00:00:00.000Z'; p.PaymentRef := 'TXN-EXC-99103';
  HAS_Payments.Add(p);

end;

// ── Lookup helpers ────────────────────────────────────────────────────────

function FindCustomerIdx(const ID: String): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to HAS_Customers.Count - 1 do
    if HAS_Customers[I].ID = ID then begin Result := I; exit; end;
end;

function FindContractorIdx(const ID: String): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to HAS_Contractors.Count - 1 do
    if HAS_Contractors[I].ID = ID then begin Result := I; exit; end;
end;

function FindActivityIdx(const ID: String): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to HAS_Activities.Count - 1 do
    if HAS_Activities[I].ID = ID then begin Result := I; exit; end;
end;

function FindEnrollmentIdx(const ID: String): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to HAS_Enrollments.Count - 1 do
    if HAS_Enrollments[I].ID = ID then begin Result := I; exit; end;
end;

function FindQuoteIdx(const ID: String): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to HAS_Quotes.Count - 1 do
    if HAS_Quotes[I].ID = ID then begin Result := I; exit; end;
end;

function FindBatchIdx(const ID: String): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to HAS_Batches.Count - 1 do
    if HAS_Batches[I].ID = ID then begin Result := I; exit; end;
end;

function FindPaymentIdx(const ID: String): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to HAS_Payments.Count - 1 do
    if HAS_Payments[I].ID = ID then begin Result := I; exit; end;
end;

// ── Name helpers ──────────────────────────────────────────────────────────

function CustomerFullName(const ID: String): String;
var I: Integer;
begin
  Result := ID;
  I := FindCustomerIdx(ID);
  if I >= 0 then Result := HAS_Customers[I].FirstName + ' ' + HAS_Customers[I].LastName;
end;

function ContractorBizName(const ID: String): String;
var I: Integer;
begin
  Result := ID;
  I := FindContractorIdx(ID);
  if I >= 0 then Result := HAS_Contractors[I].BusinessName;
end;

function ActivityName(const ID: String): String;
var I: Integer;
begin
  Result := ID;
  I := FindActivityIdx(ID);
  if I >= 0 then Result := HAS_Activities[I].Name;
end;

function EnrollmentForCustomer(const CustomerID: String): String;
var I: Integer;
begin
  Result := '';
  for I := 0 to HAS_Enrollments.Count - 1 do
    if HAS_Enrollments[I].CustomerID = CustomerID then
    begin
      Result := HAS_Enrollments[I].ID;
      exit;
    end;
end;

// ── Quote actions ─────────────────────────────────────────────────────────

function QuoteRequest(const CustomerID, ContractorID, ActivityID, Notes: String): String;
var Q: TQuote;
begin
  Q.ID           := NewID('QUO');
  Q.CustomerID   := CustomerID;
  Q.ContractorID := ContractorID;
  Q.EnrollmentID := EnrollmentForCustomer(CustomerID);
  Q.ActivityID   := ActivityID;
  Q.Status       := stRequested;
  Q.Subtotal     := 0;
  Q.GST          := 0;
  Q.Total        := 0;
  Q.DepositRequired  := 0;
  Q.SubsidyAmount    := 0;
  Q.CustomerExcess   := 0;
  Q.DepositReceived  := 0;
  Q.Notes        := Notes;
  Q.RequestedAt  := NowISO;
  HAS_Quotes.Add(Q);
  LogEvent('QuoteRequest', 'Quote', Q.ID,
    CustomerFullName(CustomerID) + ' / ' + ContractorBizName(ContractorID));
  Result := Q.ID;
end;

procedure QuoteSubmit(const QuoteID, Desc: String; Qty: Integer; Price: Float);
var Idx: Integer;
    Item: TLineItem;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  Item.Desc  := Desc;
  Item.Qty   := Qty;
  Item.Price := Price;
  HAS_Quotes[Idx].LineItems.Add(Item);
  HAS_Quotes[Idx].Subtotal    := Price * Qty;
  HAS_Quotes[Idx].GST         := HAS_Quotes[Idx].Subtotal * 0.1;
  HAS_Quotes[Idx].Total       := HAS_Quotes[Idx].Subtotal + HAS_Quotes[Idx].GST;
  HAS_Quotes[Idx].DepositRequired := HAS_Quotes[Idx].Total * 0.1;
  HAS_Quotes[Idx].Status      := stSubmitted;
  HAS_Quotes[Idx].SubmittedAt := NowISO;
  LogEvent('QuoteSubmit', 'Quote', QuoteID,
    Desc + ' x' + IntToStr(Qty) + ' @ $' + FloatToStr(Price));
end;

procedure QuoteAccept(const QuoteID: String);
var Idx: Integer;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  HAS_Quotes[Idx].Status := stAcceptedByCustomer;
  LogEvent('QuoteAccept', 'Quote', QuoteID, 'Accepted by customer');
end;

procedure QuoteAssess(const QuoteID: String; SubsidyAmt: Float; const Notes: String);
var Idx: Integer;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  HAS_Quotes[Idx].SubsidyAmount  := SubsidyAmt;
  HAS_Quotes[Idx].CustomerExcess := HAS_Quotes[Idx].Total - SubsidyAmt;
  HAS_Quotes[Idx].AssessedBy     := CurrentUser;
  HAS_Quotes[Idx].AssessedAt     := NowISO;
  HAS_Quotes[Idx].AssessmentNotes := Notes;
  HAS_Quotes[Idx].Status         := stAssessed;
  LogEvent('QuoteAssess', 'Quote', QuoteID,
    'Subsidy: ' + FmtCur(SubsidyAmt) + '  Notes: ' + Notes);
end;

procedure QuoteMarkReady(const QuoteID: String);
var Idx: Integer;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  HAS_Quotes[Idx].Status := stReadyForBatch;
  LogEvent('QuoteMarkReady', 'Quote', QuoteID, 'Ready for payment batch');
end;

procedure QuoteCommence(const QuoteID: String);
var Idx: Integer;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  HAS_Quotes[Idx].Status := stWorkCommenced;
  LogEvent('QuoteCommence', 'Quote', QuoteID, 'Work commenced');
end;

procedure QuoteComplete(const QuoteID: String);
var Idx: Integer;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  HAS_Quotes[Idx].Status      := stCompleted;
  HAS_Quotes[Idx].CompletedAt := NowISO;
  LogEvent('QuoteComplete', 'Quote', QuoteID, 'Work completed');
end;

procedure QuoteVerify(const QuoteID: String);
var Idx: Integer;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  HAS_Quotes[Idx].Status     := stVerified;
  HAS_Quotes[Idx].VerifiedAt := NowISO;
  LogEvent('QuoteVerify', 'Quote', QuoteID, 'Work verified by customer');
end;

procedure QuoteDispute(const QuoteID, Reason: String);
var Idx: Integer;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  HAS_Quotes[Idx].Status        := stDisputed;
  HAS_Quotes[Idx].DisputedAt    := NowISO;
  HAS_Quotes[Idx].DisputeReason := Reason;
  LogEvent('QuoteDispute', 'Quote', QuoteID, 'Disputed: ' + Reason);
end;

procedure QuoteResolveDispute(const QuoteID, Outcome: String);
var Idx: Integer;
begin
  Idx := FindQuoteIdx(QuoteID);
  if Idx < 0 then exit;
  HAS_Quotes[Idx].Status             := stVerified;
  HAS_Quotes[Idx].DisputeResolvedAt  := NowISO;
  HAS_Quotes[Idx].DisputeOutcome     := Outcome;
  LogEvent('QuoteResolve', 'Quote', QuoteID, 'Resolved: ' + Outcome);
end;

// ── Catalogue actions ─────────────────────────────────────────────────────

procedure CatalogueAddActivity(const Name, Category, Program_: String;
                               MaxSubsidy: Float; const Desc: String);
var A: TActivity;
begin
  A.ID          := NewID('ACT');
  A.Name        := Name;
  A.Category    := Category;
  A.Program     := Program_;
  A.MaxSubsidy  := MaxSubsidy;
  A.Description := Desc;
  HAS_Activities.Add(A);
  LogEvent('CatalogueAdd', 'Activity', A.ID, Name + ' (' + Program_ + ')');
end;

// ── Batch actions ─────────────────────────────────────────────────────────

function BatchCreate(const ContractorID: String): String;
var B: TBatch;
    P: TPayment;
    I: Integer;
begin
  B.ID           := NewID('BAT');
  B.ContractorID := ContractorID;
  B.Status       := bsPending;
  B.CreatedAt    := NowISO;
  B.SentAt       := '';

  for I := 0 to HAS_Quotes.Count - 1 do
    if (HAS_Quotes[I].Status = stReadyForBatch) and
       (HAS_Quotes[I].ContractorID = ContractorID) then
    begin
      B.QuoteIDs.Add(HAS_Quotes[I].ID);
      // Mark as work commenced
      HAS_Quotes[I].Status := stWorkCommenced;

      // Create subsidy payment
      P.ID            := NewID('PAY');
      P.QuoteID       := HAS_Quotes[I].ID;
      P.BatchID       := B.ID;
      P.PayType       := ptSubsidy;
      P.Amount        := HAS_Quotes[I].SubsidyAmount;
      P.Status        := psPending;
      P.InvoiceNumber := '';
      P.PaidAt        := '';
      P.PaymentRef    := '';
      HAS_Payments.Add(P);

      // Create customer excess payment if applicable
      if HAS_Quotes[I].CustomerExcess > 0 then
      begin
        P.ID       := NewID('PAY');
        P.PayType  := ptCustomerExcess;
        P.Amount   := HAS_Quotes[I].CustomerExcess;
        P.Status   := psPending;
        P.PaidAt   := '';
        P.PaymentRef := '';
        HAS_Payments.Add(P);
      end;
    end;

  HAS_Batches.Add(B);
  LogEvent('BatchCreate', 'Batch', B.ID,
    'Contractor: ' + ContractorBizName(ContractorID) +
    ' (' + IntToStr(B.QuoteIDs.Count) + ' quotes)');
  Result := B.ID;
end;

procedure BatchSend(const BatchID: String);
var Idx: Integer;
begin
  Idx := FindBatchIdx(BatchID);
  if Idx < 0 then exit;
  HAS_Batches[Idx].Status := bsSent;
  HAS_Batches[Idx].SentAt := NowISO;
  LogEvent('BatchSend', 'Batch', BatchID, 'Batch sent to contractor');
end;

// ── Payment actions ───────────────────────────────────────────────────────

procedure PaymentMarkPaid(const PaymentID, Ref: String);
var Idx: Integer;
begin
  Idx := FindPaymentIdx(PaymentID);
  if Idx < 0 then exit;
  HAS_Payments[Idx].Status     := psPaid;
  HAS_Payments[Idx].PaidAt     := NowISO;
  HAS_Payments[Idx].PaymentRef := Ref;
  // If batch payment, check if all batch payments are now paid
  LogEvent('PaymentPaid', 'Payment', PaymentID,
    'Ref: ' + Ref + '  Amount: ' + FmtCur(HAS_Payments[Idx].Amount));
end;

initialization
  HAS_AuditSeq := 0;
end.
