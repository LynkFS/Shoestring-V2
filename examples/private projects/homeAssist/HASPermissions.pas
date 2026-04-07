unit HASPermissions;

// ═══════════════════════════════════════════════════════════════════════════
//
//  HASPermissions — Role names and permission lookup
//
//  GetPermissions returns a TPermissions record for a given role string.
//  No DOM dependency.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

// ── Role name constants ───────────────────────────────────────────────────

const
  roleAdministrator  = 'Administrator';
  roleAssessor       = 'Assessor';
  roleCSO            = 'CSO';
  rolePaymentOfficer = 'PaymentOfficer';
  roleContractor     = 'Contractor';
  roleCustomer       = 'Customer';

// ── Permissions record ────────────────────────────────────────────────────

type
  TPermissions = record
    CanRegisterCustomer:  Boolean;
    CanAssess:            Boolean;
    CanEnroll:            Boolean;
    CanManageContractors: Boolean;
    CanManageCatalogue:   Boolean;
    CanRequestQuote:      Boolean;
    CanSubmitQuote:       Boolean;
    CanAcceptQuote:       Boolean;
    CanAssessQuote:       Boolean;
    CanCreateBatch:       Boolean;
    CanSendBatch:         Boolean;
    CanMakePayment:       Boolean;
    CanVerifyWork:        Boolean;
    CanDisputeWork:       Boolean;
    CanResolveDispute:    Boolean;
  end;

function GetPermissions(const Role: String): TPermissions;

implementation

function GetPermissions(const Role: String): TPermissions;
begin
  Result.CanRegisterCustomer  := false;
  Result.CanAssess            := false;
  Result.CanEnroll            := false;
  Result.CanManageContractors := false;
  Result.CanManageCatalogue   := false;
  Result.CanRequestQuote      := false;
  Result.CanSubmitQuote       := false;
  Result.CanAcceptQuote       := false;
  Result.CanAssessQuote       := false;
  Result.CanCreateBatch       := false;
  Result.CanSendBatch         := false;
  Result.CanMakePayment       := false;
  Result.CanVerifyWork        := false;
  Result.CanDisputeWork       := false;
  Result.CanResolveDispute    := false;

  if Role = roleAdministrator then
  begin
    Result.CanRegisterCustomer  := true;
    Result.CanAssess            := true;
    Result.CanEnroll            := true;
    Result.CanManageContractors := true;
    Result.CanManageCatalogue   := true;
    Result.CanAssessQuote       := true;
    Result.CanCreateBatch       := true;
    Result.CanSendBatch         := true;
    Result.CanMakePayment       := true;
    Result.CanResolveDispute    := true;
  end
  else if Role = roleAssessor then
  begin
    Result.CanAssess         := true;
    Result.CanEnroll         := true;
    Result.CanAssessQuote    := true;
    Result.CanResolveDispute := true;
  end
  else if Role = roleCSO then
  begin
    Result.CanRegisterCustomer := true;
    Result.CanRequestQuote     := true;
  end
  else if Role = rolePaymentOfficer then
  begin
    Result.CanCreateBatch := true;
    Result.CanSendBatch   := true;
    Result.CanMakePayment := true;
  end
  else if Role = roleContractor then
  begin
    Result.CanSubmitQuote := true;
  end
  else if Role = roleCustomer then
  begin
    Result.CanRequestQuote := true;
    Result.CanAcceptQuote  := true;
    Result.CanVerifyWork   := true;
    Result.CanDisputeWork  := true;
  end;
end;

end.
