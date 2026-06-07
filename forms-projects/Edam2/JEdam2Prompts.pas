unit JEdam2Prompts;

// ═══════════════════════════════════════════════════════════════════════════
//
//  JEdam2Prompts — the EDAM2 prompt scaffold (build step 3)
//
//  Everything EDAM2-specific about *what to say to the model* lives here, so
//  the shell (MyFormEDAM2) stays methodology-agnostic. One entry point:
//
//      Edam2SystemPrompt(AProject, AKey) : String
//
//  It assembles the per-turn system prompt from three parts:
//
//    1. ArtifactInstruction(key)  — what this artifact is and must contain.
//       The improved form of the nine EDAM2_Prompts.md SYS prompts: same
//       proven content, phrased for a conversation rather than a one-shot.
//
//    2. DependencyContext(project, key) — the business case plus the curated
//       upstream artifacts this one derives from (roles needs events; policy
//       needs events+roles; and so on). This is the EDAM2 dependency map; it
//       mirrors the keys in JProjectStore.EDAM2_ORDER.
//
//    3. ScaffoldWrap(...) — the shared envelope: the propose/curate contract
//       and the <artifact name="…"> output rule the loop's streaming split
//       depends on.
//
//  MODE is inferred, not tracked: an empty artifact means first-pass PROPOSE;
//  non-empty means the designer's message is a CURATE change request. No UI
//  state, no extra flags.
//
//  Pure string building — no asm, no closures, nothing to trip the dialect.
//
//  Wiring: ExplicitUnitUses=1 — add JEdam2Prompts to app.entrypoint.pas.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses JProjectStore;

// The whole per-turn system prompt for the artifact AKey of AProject.
function Edam2SystemPrompt(AProject: variant; const AKey: String): String;

// A one-shot validation system prompt: all curated artifacts plus instructions
// to return a JSON array of cross-artifact inconsistencies. Semantic, not
// string-matching — the model knows a policy outcome from a missing event.
function Edam2ValidationPrompt(AProject: variant): String;

// One-line human description of what an artifact is, for the phase header.
function Edam2ArtifactSummary(const AKey: String): String;

implementation

const
  LF = #10;


// What each artifact is and must contain. The EDAM2_Prompts.md SYS content,
// tightened; the conversational framing is added by ScaffoldWrap.
function ArtifactInstruction(const AKey: String): String;
begin
  if AKey = 'events' then
    Result :=
      'This is the EVENT STORE — the source of truth the whole system derives ' +
      'from. Produce a JSON array of events. Each event has: "type" (PascalCase), ' +
      '"payload" (an object of field names with example values), "description" ' +
      '(one sentence), and "triggers" (an array of event types this may follow; ' +
      'empty for a root event). Cover the FULL lifecycle of every entity in the domain.'

  else if AKey = 'roles' then
    Result :=
      'Produce ROLES & PERMISSIONS as Markdown with three sections: ' +
      '(1) a Roles table — name, description, typical user count; ' +
      '(2) a Permissions matrix — rows are roles, columns are event types, ' +
      'cells ALLOW / DENY / CONDITIONAL (state the condition); ' +
      '(3) a Visibility matrix — rows are roles, columns are entity types, ' +
      'cells ALL / OWN / NONE. Be precise for this domain.'

  else if AKey = 'policy' then
    Result :=
      'Produce POLICY RULES as Markdown: decision tables with IF/THEN and ' +
      'numeric thresholds; per-entity validation constraints (required fields, ' +
      'formats, value ranges); SLA definitions; approval workflows; and any ' +
      'compliance rules the domain implies. Be specific — no vague statements.'

  else if AKey = 'boundary' then
    Result :=
      'Produce a BOUNDARY MAP as Markdown. For each external system: name, ' +
      'purpose, the events that cross the boundary, direction (inbound/outbound), ' +
      'protocol, and failure behaviour. Include an ASCII boundary diagram.'

  else if AKey = 'reporting' then
    Result :=
      'Produce REPORTING REQUIREMENTS as Markdown. For each role: the dashboard ' +
      'KPI widgets and their data sources, default list views with filters, ' +
      'drill-down paths, and export requirements. Be specific about metrics ' +
      'and groupings.'

  else if AKey = 'notifications' then
    Result :=
      'Produce NOTIFICATION RULES as Markdown. For each notification: the ' +
      'triggering event(s), recipient role(s), channel (in-app/email/SMS), a ' +
      'message template with placeholders, delay/batching rules, and priority. ' +
      'Be exhaustive.'

  else if AKey = 'errors' then
    Result :=
      'Produce ERROR & RECOVERY policies as Markdown. For each failure scenario: ' +
      'the trigger, affected process/entity, user-facing error message, ' +
      'auto-recovery action, retry policy, and escalation path. Cover validation, ' +
      'external timeouts, concurrency, integrity, and auth failures.'

  else
    Result := 'Produce the ' + AKey + ' artifact for this domain, in full.';
end;


// One upstream artifact as a labelled context block, or '' if not yet curated.
function UpstreamBlock(AProject: variant; const UKey, ULabel: String): String;
var
  c: String;
begin
  c := ArtifactContent(AProject, UKey);
  if c <> '' then
    Result := LF + ULabel + ':' + LF + c + LF
  else
    Result := '';
end;


// The curated upstream artifacts AKey derives from. EDAM2 dependency map:
//   roles<-events  policy<-events,roles  boundary<-events
//   reporting<-events,roles,policy  notifications<-events,roles,policy
//   errors<-events,boundary,policy   (events: business case only)
function DependencyContext(AProject: variant; const AKey: String): String;
begin
  if AKey = 'roles' then
    Result := UpstreamBlock(AProject, 'events', 'Event store')

  else if AKey = 'policy' then
    Result := UpstreamBlock(AProject, 'events', 'Event store')
            + UpstreamBlock(AProject, 'roles',  'Roles & permissions')

  else if AKey = 'boundary' then
    Result := UpstreamBlock(AProject, 'events', 'Event store')

  else if AKey = 'reporting' then
    Result := UpstreamBlock(AProject, 'events', 'Event store')
            + UpstreamBlock(AProject, 'roles',  'Roles & permissions')
            + UpstreamBlock(AProject, 'policy', 'Policy rules')

  else if AKey = 'notifications' then
    Result := UpstreamBlock(AProject, 'events', 'Event store')
            + UpstreamBlock(AProject, 'roles',  'Roles & permissions')
            + UpstreamBlock(AProject, 'policy', 'Policy rules')

  else if AKey = 'errors' then
    Result := UpstreamBlock(AProject, 'events',   'Event store')
            + UpstreamBlock(AProject, 'boundary', 'Boundary map')
            + UpstreamBlock(AProject, 'policy',   'Policy rules')

  else
    Result := '';   // events: business case only
end;


// The shared envelope: methodology framing, the instruction, the context, and
// the propose/curate contract with the <artifact> output rule.
function ScaffoldWrap(const AKey, AMode, AInstruction, AContext,
                      AFormat, ACurrent: String): String;
var
  s, fmtName: String;
begin
  if AFormat = 'json' then fmtName := 'a JSON array' else fmtName := 'Markdown';

  s := 'You are an EDAM2 design partner. EDAM2 designs governed business ' +
       'systems where events are the source of truth; every later artifact ' +
       'derives from the event store. You and the designer build one artifact ' +
       'at a time, by conversation: you propose, the designer curates.' + LF + LF;

  s := s + 'CURRENT ARTIFACT: ' + AKey + LF;
  s := s + AInstruction + LF + LF;

  if AContext <> '' then
    s := s + 'CONTEXT (defer to these — they are already curated):' + LF +
             AContext + LF;

  if AMode = 'propose' then
    s := s + 'This is the first pass. Open with one or two plain sentences ' +
             'naming the one or two decisions the designer should check, then ' +
             'output the COMPLETE artifact'
  else
    s := s + 'The designer''s message is a change request against the current ' +
             'artifact below. Apply ONLY what they ask, preserve everything ' +
             'else verbatim, acknowledge in one sentence, then output the ' +
             'COMPLETE revised artifact';

  s := s + ' between <artifact name="' + AKey + '"> and </artifact> as ' +
           fmtName + '. Put nothing after </artifact>.' + LF;

  if (AMode = 'curate') and (ACurrent <> '') then
    s := s + LF + 'Current ' + AKey + ':' + LF + ACurrent + LF;

  Result := s;
end;


// ── entry point ─────────────────────────────────────────────────────────────

function Edam2SystemPrompt(AProject: variant; const AKey: String): String;
var
  mode, ctx, bc: String;
begin
  if ArtifactContent(AProject, AKey) = '' then
    mode := 'propose'
  else
    mode := 'curate';

  ctx := '';
  bc := GetSetup(AProject, 'businessCase');
  if bc <> '' then
    ctx := 'Business case:' + LF + bc + LF;
  ctx := ctx + DependencyContext(AProject, AKey);

  Result := ScaffoldWrap(
    AKey,
    mode,
    ArtifactInstruction(AKey),
    ctx,
    ArtifactFormat(AProject, AKey),
    ArtifactContent(AProject, AKey));
end;


// ── validation ────────────────────────────────────────────────────────────

function Edam2ArtifactSummary(const AKey: String): String;
begin
  if AKey = 'events' then
    Result := 'Define the events that are the system''s single source of truth.'
  else if AKey = 'roles' then
    Result := 'Define roles, their permissions over events, and what each can see.'
  else if AKey = 'policy' then
    Result := 'Define business rules, thresholds, validations and approval workflows.'
  else if AKey = 'boundary' then
    Result := 'Map the external systems and what crosses each boundary.'
  else if AKey = 'reporting' then
    Result := 'Define dashboards, list views and exports for each role.'
  else if AKey = 'notifications' then
    Result := 'Define who is notified of what, and on which channel.'
  else if AKey = 'errors' then
    Result := 'Define failure scenarios, messages, recovery and escalation.'
  else
    Result := '';
end;

function Edam2ValidationPrompt(AProject: variant): String;
var
  s: String;
begin
  s := 'You are validating an EDAM2 artifact set for cross-artifact ' +
       'consistency. In EDAM2 the event store is the source of truth and every ' +
       'other artifact must be consistent with it and with each other.' + LF + LF;

  s := s + 'Look for genuine inconsistencies such as: an event type referenced ' +
       'in a downstream artifact (roles, policy, boundary, reporting, ' +
       'notifications, errors) that does NOT exist in the event store; a role ' +
       'used in one artifact but absent from the roles artifact; an entity or ' +
       'field referenced but never defined upstream; a policy threshold ' +
       'contradicted elsewhere; or a derivation that does not follow from the ' +
       'events. Do NOT flag stylistic issues, and do NOT treat decision-table ' +
       'outcome labels (e.g. NoActionRequired) or status values as missing ' +
       'events. Only report things a designer would want to fix.' + LF + LF;

  s := s + 'Be thorough: work through EVERY downstream artifact (roles, policy, ' +
       'boundary, reporting, notifications, errors) one by one and check each ' +
       'event, role and entity it names against the event store before you ' +
       'conclude. An artifact set of this size almost always has several ' +
       'inconsistencies; an empty result is rare and means you have checked ' +
       'systematically and are genuinely confident none remain.' + LF + LF;

  s := s + 'THE ARTIFACTS:' + LF;
  s := s + UpstreamBlock(AProject, 'events',        'Event store');
  s := s + UpstreamBlock(AProject, 'roles',         'Roles & permissions');
  s := s + UpstreamBlock(AProject, 'policy',        'Policy rules');
  s := s + UpstreamBlock(AProject, 'boundary',      'Boundary map');
  s := s + UpstreamBlock(AProject, 'reporting',     'Reporting');
  s := s + UpstreamBlock(AProject, 'notifications', 'Notifications');
  s := s + UpstreamBlock(AProject, 'errors',        'Errors & recovery');

  s := s + LF +
       'Return ONLY a JSON array, no prose and no markdown fences. Each element: ' +
       '{"id": "kind:entity", "severity": "high"|"medium"|"low", ' +
       '"artifacts": ["..."], "issue": "one sentence", "suggestion": "one sentence"}. ' +
       'The id MUST be a stable slug built from the issue kind and the specific ' +
       'entity involved — lowercase kind, exact entity name, e.g. ' +
       '"missing-event:QuoteRequestLapsed" — so the same underlying issue always ' +
       'produces the same id across runs. Return [] only if you have ' +
       'systematically checked and are confident there are genuinely no ' +
       'inconsistencies.';

  Result := s;
end;

end.
