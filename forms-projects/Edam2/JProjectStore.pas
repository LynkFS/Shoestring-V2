unit JProjectStore;

// ═══════════════════════════════════════════════════════════════════════════
//
//  Project Store  —  shell-side client for the conversational EDAM2 generator
//
//  Two jobs, deliberately split:
//
//  1. PERSISTENCE.  SaveProject / LoadProject / ListProjects talk to the
//     sscserver /project + /projects endpoints over HttpClient. Same origin
//     as the served shell, so no CORS dance; withCredentials in HttpClient
//     already carries the Cloudflare Access cookie. A project is one JSON
//     file on the Win11 box, in the sibling ./projects folder.
//
//  2. MODEL.  NewProject builds the project object; the accessors read and
//     mutate it. The object IS the source of truth the loop edits in place;
//     persistence just snapshots it. Shape:
//
//       { schema, methodology, name, created, updated, phase,
//         setup:      { businessCase, deployment, style, security },
//         artifacts:  { events|roles|policy|boundary|reporting|
//                       notifications|errors : { format, content, curated } },
//         validation: { lastRun, report, dismissed:[conflictId,...] },
//         generated:  { html, units:[] } }
//
//  Standalone procedures, no class — matching HttpClient / Validators, and
//  sidestepping the unit-name = class-name parse ambiguity entirely.
//
//  NOTE: ExplicitUnitUses=1 — add JProjectStore to app.entrypoint.pas.
//
// ═══════════════════════════════════════════════════════════════════════════

interface

uses HttpClient;

type
  // Fires when LoadProject gets a 404: no such project, start a fresh one.
  TProjectMissing = procedure(const AName: String);

// --- persistence (sscserver, same origin) -----------------------------------

procedure SaveProject(const AName: String; AProject: variant;
  OnSuccess: TJSONCallback; OnError: TErrorCallback);

procedure LoadProject(const AName: String;
  OnLoaded: TJSONCallback; OnMissing: TProjectMissing; OnError: TErrorCallback);

procedure ListProjects(OnSuccess: TJSONCallback; OnError: TErrorCallback);

// --- model construction ------------------------------------------------------

function  NewProject(const AName: String; AMethodology: String = 'edam2'): variant;
function  NowISO: String;

// --- artifact accessors (operate on a project variant in place) --------------

function  ArtifactContent(AProject: variant; const AKey: String): String;
function  ArtifactFormat (AProject: variant; const AKey: String): String;
function  ArtifactCurated(AProject: variant; const AKey: String): Boolean;
procedure SetArtifact    (AProject: variant; const AKey, AContent: String; ACurated: Boolean);

// The next artifact in EDAM2 order whose 'curated' is still false, or '' if
// every artifact is curated. The loop asks this instead of tracking phases.
function  NextArtifact   (AProject: variant): String;

// --- phase / setup / generated / validation ----------------------------------

function  GetPhase(AProject: variant): String;
procedure SetPhase(AProject: variant; const APhase: String);

function  GetSetup(AProject: variant; const AKey: String): String;
procedure SetSetup(AProject: variant; const AKey, AValue: String);

function  GetGeneratedHTML(AProject: variant): String;
procedure SetGeneratedHTML(AProject: variant; const AHtml: String);

procedure SetValidationReport(AProject: variant; const AReport: String);
procedure DismissConflict(AProject: variant; const AConflictId: String);
function  IsDismissed(AProject: variant; const AConflictId: String): Boolean;


implementation

const
  // EDAM2 pack ordering, in dependency order (events first, everything derives
  // from it). The loop reads this via NextArtifact rather than hardcoding
  // 'if phase = events'. When a second methodology arrives, THIS is the thing
  // that gets lifted into a per-pack descriptor — the shell/pack seam, kept
  // drawable but not yet drawn.
  EDAM2_ORDER: array[0..6] of String =
    ('events', 'roles', 'policy', 'boundary',
     'reporting', 'notifications', 'errors');


function NowISO: String;
begin
  asm @Result = new Date().toISOString(); end;
end;


// --- persistence -------------------------------------------------------------

procedure SaveProject(const AName: String; AProject: variant;
  OnSuccess: TJSONCallback; OnError: TErrorCallback);
var
  Body: String;
begin
  asm @Body = JSON.stringify((@AProject)); end;
  PostJSON('/project/' + AName, Body, OnSuccess, OnError);
end;

procedure LoadProject(const AName: String;
  OnLoaded: TJSONCallback; OnMissing: TProjectMissing; OnError: TErrorCallback);
begin
  FetchJSON('/project/' + AName,
    OnLoaded,
    procedure(Status: Integer; Message: String)
    begin
      if (Status = 404) and Assigned(OnMissing) then
        OnMissing(AName)
      else if Assigned(OnError) then
        OnError(Status, Message);
    end);
end;

procedure ListProjects(OnSuccess: TJSONCallback; OnError: TErrorCallback);
begin
  FetchJSON('/projects', OnSuccess, OnError);
end;


// --- model construction ------------------------------------------------------

function NewProject(const AName: String; AMethodology: String): variant;
var
  iso: String;
begin
  iso := NowISO;
  asm
    @Result = {
      schema:      'shoestring.project/1',
      methodology: @AMethodology,
      name:        @AName,
      created:     @iso,
      updated:     @iso,
      phase:       'events',
      setup: {
        businessCase: '',
        deployment:   'web-spa',
        style:        '',
        security:     'none'
      },
      artifacts: {
        events:        { format: 'json', content: '', curated: false },
        roles:         { format: 'md',   content: '', curated: false },
        policy:        { format: 'md',   content: '', curated: false },
        boundary:      { format: 'md',   content: '', curated: false },
        reporting:     { format: 'md',   content: '', curated: false },
        notifications: { format: 'md',   content: '', curated: false },
        errors:        { format: 'md',   content: '', curated: false }
      },
      validation: { lastRun: '', report: '', dismissed: [] },
      generated:  { html: '', units: [] }
    };
  end;
end;


// --- artifact accessors ------------------------------------------------------

function ArtifactContent(AProject: variant; const AKey: String): String;
begin
  asm
    var a = (@AProject).artifacts[@AKey];
    @Result = a ? a.content : '';
  end;
end;

function ArtifactFormat(AProject: variant; const AKey: String): String;
begin
  asm
    var a = (@AProject).artifacts[@AKey];
    @Result = a ? a.format : '';
  end;
end;

function ArtifactCurated(AProject: variant; const AKey: String): Boolean;
begin
  asm
    var a = (@AProject).artifacts[@AKey];
    @Result = !!(a && a.curated);
  end;
end;

procedure SetArtifact(AProject: variant; const AKey, AContent: String; ACurated: Boolean);
begin
  asm
    var a = (@AProject).artifacts[@AKey];
    if (a) { a.content = @AContent; a.curated = @ACurated; }
    (@AProject).updated = new Date().toISOString();
  end;
end;

function NextArtifact(AProject: variant): String;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(EDAM2_ORDER) do
    if not ArtifactCurated(AProject, EDAM2_ORDER[i]) then
    begin
      Result := EDAM2_ORDER[i];
      Exit;
    end;
end;


// --- phase / setup / generated / validation ----------------------------------

function GetPhase(AProject: variant): String;
begin
  asm @Result = (@AProject).phase || ''; end;
end;

procedure SetPhase(AProject: variant; const APhase: String);
begin
  asm
    (@AProject).phase = @APhase;
    (@AProject).updated = new Date().toISOString();
  end;
end;

function GetSetup(AProject: variant; const AKey: String): String;
begin
  asm
    var s = (@AProject).setup;
    @Result = (s && s[@AKey]) ? s[@AKey] : '';
  end;
end;

procedure SetSetup(AProject: variant; const AKey, AValue: String);
begin
  asm
    (@AProject).setup[@AKey] = @AValue;
    (@AProject).updated = new Date().toISOString();
  end;
end;

function GetGeneratedHTML(AProject: variant): String;
begin
  asm
    var g = (@AProject).generated;
    @Result = (g && g.html) ? g.html : '';
  end;
end;

procedure SetGeneratedHTML(AProject: variant; const AHtml: String);
begin
  asm
    (@AProject).generated.html = @AHtml;
    (@AProject).updated = new Date().toISOString();
  end;
end;

procedure SetValidationReport(AProject: variant; const AReport: String);
begin
  asm
    (@AProject).validation.report = @AReport;
    (@AProject).validation.lastRun = new Date().toISOString();
  end;
end;

procedure DismissConflict(AProject: variant; const AConflictId: String);
begin
  asm
    var d = (@AProject).validation.dismissed;
    if (d && d.indexOf(@AConflictId) < 0) d.push(@AConflictId);
  end;
end;

function IsDismissed(AProject: variant; const AConflictId: String): Boolean;
begin
  asm
    var d = (@AProject).validation.dismissed;
    @Result = !!(d && d.indexOf(@AConflictId) >= 0);
  end;
end;

end.
