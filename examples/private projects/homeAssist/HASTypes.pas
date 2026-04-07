unit HASTypes;

// ═══════════════════════════════════════════════════════════════════════════
//
//  HASTypes — Home Assist Secure record types and status constants
//
//  All entity types live here. No DOM dependency — safe to import anywhere.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

// ── Status constants ──────────────────────────────────────────────────────

const
  // Customer / enrollment
  stRegistered = 'Registered';
  stEnrolled   = 'Enrolled';

  // Contractor
  stActive    = 'Active';
  stSuspended = 'Suspended';

  // Quote workflow
  stRequested          = 'Requested';
  stSubmitted          = 'Submitted';
  stAcceptedByCustomer = 'AcceptedByCustomer';
  stAssessed           = 'Assessed';
  stReadyForBatch      = 'ReadyForBatch';
  stWorkCommenced      = 'WorkCommenced';
  stCompleted          = 'Completed';
  stVerified           = 'Verified';
  stDisputed           = 'Disputed';
  stCancelled          = 'Cancelled';

  // Batch
  bsPending   = 'Pending';
  bsSent      = 'Sent';
  bsCompleted = 'Completed';

  // Payment
  ptSubsidy        = 'SubsidyPayment';
  ptCustomerExcess = 'CustomerExcess';
  psPending        = 'Pending';
  psPaid           = 'Paid';

  // Programs
  progHSSH      = 'HSSH';
  progHAS       = 'HAS';
  progHSSHLabel = 'Helping Seniors Secure Their Home';
  progHASLabel  = 'Home Assist / Secure';

// ── Record types ──────────────────────────────────────────────────────────

type

  TLineItem = record
    Desc:  String;
    Qty:   Integer;
    Price: Float;
  end;

  TCustomer = record
    ID:               String;
    FirstName:        String;
    LastName:         String;
    DOB:              String;
    Street:           String;
    Suburb:           String;
    Postcode:         String;
    Region:           String;
    Phone:            String;
    Email:            String;
    EmergencyContact: String;
    EmergencyPhone:   String;
    Status:           String;
    CreatedAt:        String;
  end;

  TContractor = record
    ID:            String;
    BusinessName:  String;
    ContactName:   String;
    Phone:         String;
    Email:         String;
    ABN:           String;
    Licence:       String;
    LicenceExpiry: String;
    Categories:    String;   // comma-separated
    Regions:       String;   // comma-separated
    Status:        String;
    RegisteredAt:  String;
  end;

  TActivity = record
    ID:          String;
    Name:        String;
    Category:    String;
    Program:     String;
    MaxSubsidy:  Float;
    Description: String;
  end;

  TEnrollment = record
    ID:              String;
    CustomerID:      String;
    Program:         String;
    ProgramLabel:    String;
    BudgetAllocated: Float;
    BudgetSpent:     Float;
    Status:          String;
    EnrolledAt:      String;
  end;

  TQuote = record
    ID:                String;
    CustomerID:        String;
    ContractorID:      String;
    EnrollmentID:      String;
    ActivityID:        String;
    Status:            String;
    LineItems:         array of TLineItem;
    Subtotal:          Float;
    GST:               Float;
    Total:             Float;
    DepositRequired:   Float;
    SubsidyAmount:     Float;
    CustomerExcess:    Float;
    DepositReceived:   Float;
    Notes:             String;
    RequestedAt:       String;
    SubmittedAt:       String;
    AssessedBy:        String;
    AssessedAt:        String;
    AssessmentNotes:   String;
    CompletedAt:       String;
    VerifiedAt:        String;
    DisputedAt:        String;
    DisputeReason:     String;
    DisputeResolvedAt: String;
    DisputeOutcome:    String;
  end;

  TBatch = record
    ID:           String;
    ContractorID: String;
    QuoteIDs:     array of String;
    Status:       String;
    CreatedAt:    String;
    SentAt:       String;
  end;

  TPayment = record
    ID:            String;
    QuoteID:       String;
    BatchID:       String;
    PayType:       String;
    Amount:        Float;
    Status:        String;
    InvoiceNumber: String;
    PaidAt:        String;
    PaymentRef:    String;
  end;

  TAuditEvent = record
    ID:         Integer;
    EventType:  String;
    EntityType: String;
    EntityID:   String;
    Actor:      String;
    Details:    String;
    LoggedAt:   String;
  end;

implementation

end.
