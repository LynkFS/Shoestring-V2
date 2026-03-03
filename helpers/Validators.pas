unit Validators;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Validators
//
//  Pure functions for form validation. They take a string value and return
//  true or false. They know nothing about components, the DOM, or the
//  framework. They are non-visual, stateless, and side-effect free.
//
//  Usage:
//
//    if not IsRequired(FEmail.Value) then
//      FEmail.AddClass('invalid');
//
//    if not IsEmail(FEmail.Value) then
//      FEmailError.SetText('Please enter a valid email');
//
//    if not MinLength(FPassword.Value, 8) then
//      FPassError.SetText('At least 8 characters');
//
//  These are shared-layer functions — they compile to both browser and
//  Node.js targets since they have no DOM dependency.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

function IsRequired(const Value: String): Boolean;
function IsEmail(const Value: String): Boolean;
function IsNumeric(const Value: String): Boolean;
function IsInteger(const Value: String): Boolean;
function IsURL(const Value: String): Boolean;
function MinLength(const Value: String; N: Integer): Boolean;
function MaxLength(const Value: String; N: Integer): Boolean;
function ExactLength(const Value: String; N: Integer): Boolean;
function InRange(const Value: String; Min, Max: Float): Boolean;
function Matches(const Value, Pattern: String): Boolean;

implementation


//=============================================================================
// Required — non-empty after trimming
//=============================================================================

function IsRequired(const Value: String): Boolean;
var
  trimmed: String;
begin
  asm @trimmed = (@Value).trim(); end;
  Result := trimmed.Length > 0;
end;


//=============================================================================
// Email — basic structure check, not RFC-complete
//=============================================================================

function IsEmail(const Value: String): Boolean;
begin
  if Value = '' then begin Result := false; exit; end;
  asm
    var re = new RegExp('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$');
    @Result = re.test(@Value);
  end;
end;


//=============================================================================
// Numeric — integer or decimal
//=============================================================================

function IsNumeric(const Value: String): Boolean;
begin
  if Value = '' then begin Result := false; exit; end;
  asm
    @Result = !isNaN(@Value) && !isNaN(parseFloat(@Value));
  end;
end;


//=============================================================================
// Integer — whole number only
//=============================================================================

function IsInteger(const Value: String): Boolean;
begin
  if Value = '' then begin Result := false; exit; end;
  asm
    @Result = /^-?\d+$/.test(@Value);
  end;
end;


//=============================================================================
// URL — basic http/https check
//=============================================================================

function IsURL(const Value: String): Boolean;
begin
  if Value = '' then begin Result := false; exit; end;
  asm
    try {
      var u = new URL(@Value);
      @Result = (u.protocol === 'http:' || u.protocol === 'https:');
    } catch(e) {
      @Result = false;
    }
  end;
end;


//=============================================================================
// Length constraints
//=============================================================================

function MinLength(const Value: String; N: Integer): Boolean;
begin
  Result := Value.Length >= N;
end;

function MaxLength(const Value: String; N: Integer): Boolean;
begin
  Result := Value.Length <= N;
end;

function ExactLength(const Value: String; N: Integer): Boolean;
begin
  Result := Value.Length = N;
end;


//=============================================================================
// Range — value must be numeric and between Min and Max
//=============================================================================

function InRange(const Value: String; Min, Max: Float): Boolean;
var
  n: Float;
begin
  Result := false;
  if not IsNumeric(Value) then exit;
  asm @n = parseFloat(@Value); end;
  Result := (n >= Min) and (n <= Max);
end;


//=============================================================================
// Regex — tests value against a JavaScript regex pattern
//=============================================================================

function Matches(const Value, Pattern: String): Boolean;
begin
  asm
    try {
      @Result = new RegExp(@Pattern).test(@Value);
    } catch(e) {
      @Result = false;
    }
  end;
end;

end.
