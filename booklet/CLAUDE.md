# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ShoeString V2** is a minimalist web UI framework written in Object Pascal (DWScript/QuartexPascal dialect) that compiles to JavaScript. It targets both browser (DOM) and Node.js environments. Core philosophy: *"If the browser does it, don't."* The entire framework core is ~886 lines across 5 units in `core/`.

## Repository Layout

All source lives under `ShoeStringV2/`. The compiled output `ShoeStringV2/index.js` is generated — do not edit it directly.

## Build & Compile

The project uses the **Quartex Pascal compiler** (IDE-based, not CLI). Configuration lives in `ShoeStringV2/app.config.ini`. Output is `ShoeStringV2/index.js` (~724KB generated file).

**Development workflow**: edit `.pas` files → compile in Quartex Pascal IDE → open `ShoeStringV2/index.html` in browser (or `node ShoeStringV2/index.js` for Node.js targets).

To switch which form loads on startup, change the `Application.GoToForm()` call in `app.entrypoint.pas`. Current startup form is **`Kitchensink`**; other targets (`InvoiceList`, `HASLogin`, `SemanticZoom`, `FormBridge`, `FormNoise`, `FormInputs`, `FormBooks`, `FormBooksRaw`, `FormAgents`, `FormIDE`, `FormHousing`, `FormGrants`) are commented out in the same file.

**Targeting Node.js instead of the browser**: replace the DOM entrypoint body with `uses NodeHello;` or `uses NodeHttpServer;` and run `node index.js`. See the trailing comment in `app.entrypoint.pas`.

Key compiler flags (from `app.config.ini`):
- `OptimizeForSize=1`, `SmartLink=1`, `DeVirtualize=1` — production optimizations
- `SupportDelphi=1` — Delphi-compatible syntax
- `ExplicitUnitUses=1` — units must be listed in app.entrypoint.pas

To register a new form or unit, add it to `app.entrypoint.pas`.

## MCP Pascal Dialect Server

This project has a `pascal-dialect` MCP server configured in `.claude/settings.local.json` (with `enableAllProjectMcpServers: true`). Use `mcp__pascal-dialect__*` tools to validate Pascal code, get syntax rules, and suggest improvements when editing `.pas` files.

## Versioned Source Files

Several units exist as numbered snapshots alongside the canonical file — e.g. `Kitchensink-v1..v5.pas`, `FormIde-v2..v7.pas`, `FormAgents-v1..v17.pas`, `FormHousing-v1..v4.pas`, `uHousingModel-v1..v3.pas`, `ThemeStyles-orig.pas`, `JDrawer-orig.pas`. The canonical file is the one **without** a version suffix. Do not edit the numbered snapshots — they are historical.

## Architecture

### Core Layer (`core/`)
Dependency order: `Types.pas` → `Globals.pas` → `JElement.pas` → `JForm.pas` → `JApplication.pas`

- **`Types.pas`**: External class bindings for browser APIs (zero runtime cost — no implementation, just typed interfaces for `JEvent`, `JElement`, `JHTMLElement`, `JXMLHttpRequest`, etc.)
- **`Globals.pas`**: Browser externals (`document`, `window`, `console`), framework stylesheet, auto-incremented element ID generation (`el1`, `el2`…), `AddStyleBlock()` for CSS injection
- **`JElement.pas`**: Base class for all visual components. Manages DOM creation, child tracking, three styling mechanisms, attributes, sizing, visibility, click events. Uses `requestAnimationFrame` for element readiness.
- **`JForm.pas`**: Full-viewport container. Only element that listens for window resize. Calls `InitializeObject()` (override to build component tree) then `Resize()` for layout adjustments.
- **`JApplication.pas`**: Form navigation — lazy form instantiation (created on first `GoToForm()` call), state preserved on return.

### Three Styling Mechanisms (on `TElement`)

1. `SetStyle('property', 'value')` — inline style on the element
2. `SetRule('selector-suffix', 'css')` / `SetRulePseudo(':hover', 'css')` — writes to the framework stylesheet using the element's unique ID
3. `AddClass('name')` — applies a CSS class

### Component Pattern

Every widget follows a three-part pattern:
1. **CSS registration** — `AddStyleBlock()` with a guard flag to prevent double-registration (called from unit `initialization` section or constructor)
2. **Pascal class** — inherits `TElement`, constructor < 10 lines, calls `RegisterXxxStyles` then `AddClass(csXxx)`
3. **String constants** — compile-safe class names (e.g., `csBtn = 'btn'`, `csBtnPrimary = 'btn-primary'`)

### Themes and Design Tokens (`themes/`)

`ThemeStyles.pas` defines all CSS variables on `:root` using **oklch() colors** ("Zinc Violet" palette):
- **Primary scale**: `--primary-color` (base) + `--primary-50` … `--primary-900`, `--primary-light`, `--primary-dark`
- **Text**: `--text-color`, `--text-light`, `--text-xlight`
- **Surfaces**: `--bg-color`, `--surface-color`, `--surface-2`, `--surface-3` (three-level layering)
- **Borders**: `--border-color`, `--border-strong`, `--hover-color`
- **Semantic**: `--color-success/warning/danger/info` (each with `-light` and `-bg` variants)
- **Spacing**: `--space-1` (4px) through `--space-20` (80px); includes `--space-5` and `--space-14`
- **Border radius**: `--radius-sm` (4px) through `--radius-3xl` (28px) + `--radius-full`
- **Elevation**: `--shadow-sm` through `--shadow-xl`
- **Typography**: `--text-xs` … `--text-3xl`, `--leading-tight/normal/loose`, `--weight-normal/medium/semi/bold`
- **Animation**: `--anim-fast` (0.1s) / `--anim-normal` (0.2s) / `--anim-slow` (0.35s) / `--anim-ease` (cubic-bezier); `--anim-duration` is an alias for `--anim-normal`
- **Field**: `--field-height` is 44px (touch-friendly); focus ring uses `outline-offset` not a glow halo
- Dark mode: `:root.dark` — true dark zinc background (no navy tint)

Shared utility classes: `.interactive` (hover/focus/active/disabled), `.field`, `.field-label`, `.field-group`, `.field-error`

### Layouts (`themes/LayoutXxx.pas`)

Six pre-built CSS Grid/flexbox layouts — no JavaScript positioning logic:
- **Dashboard** — sidebar + header + auto-filling card grid
- **Document** — fixed header + centered content + optional sidebar
- **Split** — two equal/weighted panels
- **HolyGrail** — header + footer + 3 columns
- **Stacked** — header + vertical sections + footer
- **Kanban** — header + horizontally scrolling columns

### Helpers (`helpers/`)

- **`HttpClient.pas`**: `FetchJSON` / `PostJSON` / `FetchText` with success/error callback pattern. Cross-target (browser + Node).
- **`Validators.pas`**: Pure validation functions — `IsRequired`, `IsEmail`, `IsURL`, `IsInteger`, `IsNumeric`, `MinLength(s,n)`, `MaxLength(s,n)`, `ExactLength(s,n)`, `InRange`, `Matches`. No DOM dependency, works on Node.js too.
- **`JDataStore.pas`**: Observable key-value store (`JW3DataStore` class). `Subscribe(key, cb)` / `Put(key, value)` / `Get` / `Delete` / `Observe` (subscribe + immediate-fire) / wildcard `'*'` / `BeginUpdate` + `EndUpdate` (batched notifications collapse multi-write per key to one).
- **`JDB.pas`**: Thin wrapper around `PostForm` for PHP-backed MySQL endpoints. Exposes `DBQuery(URL, Action, OnData, OnError)` and a `TDBClient` class; both normalise the `{ok, error}` response envelope so form code only handles success data.
- **`JFormulator.pas`**: Declarative form renderer. `TFormulator.BuildFromJSON(Parent, JsonConfig, OnSubmit)` walks a JSON tree and emits the same widgets you'd write by hand. Field types: `text | email | password | number | textarea | select`. Layout: `{row: [...]}` for 2-col grid. Validation: `required: true` + optional `requiredMessage`. Dynamic defaults: `defaultFrom: { switch, cases }` with per-DOM dirty bit. See Chapter 7 of the booklet.

**Deleted from `helpers/`**: `JLLMClaude.pas`, `JLLMDeepSeek.pas` — these were orphan duplicates of the canonical `agents/JClaudeAdapter.pas` / `agents/JDeepSeekAdapter.pas`. Don't recreate them in `helpers/`; LLM adapters are app-level (agent runtime), not framework primitives.

### Typography and Layouts (`themes/`)

In addition to `ThemeStyles.pas`, `themes/` also contains `TypographyStyles.pas` (shared typographic rules) and the six `Layout*.pas` units listed above.

### Node.js Runtime (`node/`)

- **`node/nodeCore/`** — `NodeTypes.pas` (Node API bindings), `NodeHello.pas` (minimal Node entrypoint demo), `NodeHttpServer.pas` (HTTP server demo)
- **`node/examples/mcp-mysql/`** — Node-targeted MCP server example for MySQL access

When the entrypoint `uses` a Node unit, compiling produces an `index.js` that runs under `node index.js` instead of loading in a browser.

## QuartexPascal / DWScript Compiler Rules

Confirmed by compiler errors. Violations cause compile failures.

### Anonymous procedures (closures) — two distinct syntaxes

**For Pascal typed event properties with no explicit parameters** (`TNotifyEvent` — `OnClick`, `OnChange`, `OnExamine`, etc.) — use `lambda`:

```pascal
Btn.OnClick      := lambda DoSave; end;
Item.OnClick     := lambda NavigateTo(CapturedID); end;
Select.OnChange  := lambda HandleChange; end;
```

**For Pascal typed event properties with explicit parameters** — use `procedure(...) begin ... end`. `lambda` cannot express the parameter list:

```pascal
// TOnFormSubmit = procedure(Sender: TObject; Key: String; Values: variant)
Surface.OnFormSubmit := procedure(Sender: TObject; Key: String; Values: variant)
begin
  Toast('Submitted: ' + Key, ttSuccess, 3000);
end;

// TTreeSelectEvent = procedure(Sender: TObject; Node: TTreeNode)
Tree.OnSelect := procedure(Sender: TObject; Node: TTreeNode)
begin
  ShowDetail(Node.Tag);
end;
```

**For raw DOM `addEventListener`** — use `procedure(E: variant) begin ... end`:

```pascal
El.Handle.addEventListener('click',  procedure(E: variant) begin DoSomething; end);
El.Handle.addEventListener('input',  procedure(E: variant) begin RefreshTable; end);
El.Handle.addEventListener('change', procedure(E: variant) begin RefreshTable; end);
```

**NEVER use `lambda` with `addEventListener`** — it calls the body immediately (synchronously during construction) instead of registering it as a callback. This is the confirmed cause of `HierarchyRequestError: The new child element contains the parent` when building pages with filter inputs.

### Constructor `inherited` call

When overriding a constructor that has parameters, you **must** pass the argument explicitly using the parameter name. `inherited;` gives "more arguments expected". `inherited(self)` compiles but passes the new object as its own parent (causes `HierarchyRequestError`).

```pascal
// CORRECT — pass the parameter by name
constructor TMyPage.Create(Parent: TElement);
begin
  inherited(Parent);
  ...
end;

// WRONG — compile error: "more arguments expected"
inherited;

// WRONG — compiles but causes DOM HierarchyRequestError at runtime
inherited(self);
```

### TElement content methods

The actual API methods are `SetText` and `SetHTML` — **not** `SetInnerText` / `SetInnerHTML`:

```pascal
El.SetText('hello');       // sets textContent
El.SetHTML('<b>hi</b>');   // sets innerHTML
```

### ThemeStyles must be in uses when using field constants

`csFieldGroup`, `csFieldLabel`, `csFieldError`, `csField`, `csInteractive` are defined in `ThemeStyles.pas`. Add it to the implementation uses clause of any unit that references them:

```pascal
uses ..., ThemeStyles;
```

### ChildCount / Children[] are not public

`ChildCount` and `Children[]` are commented out in `JElement.pas`. To remove all children from an element use:

```pascal
El.Clear;   // frees all child TElement objects
```

### asm blocks — variable access and property chaining

Inside `asm` blocks, Pascal variables are referenced with the `@` prefix. When **chaining properties** off a Pascal variable, the variable reference must be wrapped in parentheses, otherwise the `@` operator applies to the entire dotted expression and fails:

```pascal
// CORRECT — parens around the Pascal variable before chaining:
asm
  var tr = (@E).target.closest('tr[data-id]');
  @qid = tr ? tr.getAttribute('data-id') : '';
end;

asm
  @Qty   = Math.max(1, parseInt((@FQtyEl).Handle.value, 10) || 1);
  @Price = parseFloat((@FPriceEl).Handle.value) || 0;
end;

// OK — no chaining, no parens needed:
asm @Result = new Date().toISOString(); end;
```

### asm blocks — `#` is the Pascal character-literal prefix, everywhere

**Any `#` followed by a non-digit anywhere in an asm block fails to compile with "Number expected".** DWScript's Pascal lexer treats `#` as the char-literal prefix (`#10`, `#$0A`) and expects a digit (or `$` for hex) next. This applies regardless of context — regex literals, regex character classes, string literals — the lexer doesn't track JS syntax, it scans Pascal tokens.

```pascal
asm t = t.replace(/^#{1,6}\s+(.+)$/gm, ...); end;   // FAILS at `#{`
asm t = t.replace(/^#+\s+(.+)$/gm,     ...); end;   // FAILS at `#+`
asm t = t.replace(/^[#]+\s+(.+)$/gm,   ...); end;   // FAILS at `#]`
asm var s = '...#x...';                      end;   // FAILS at `#x`
```

The only patterns that genuinely survive are ones where the Pascal lexer never sees `#` adjacent to a non-digit. Two reliable approaches:

```pascal
// Build the `#` at JS runtime via fromCharCode — no literal `#` in source:
asm
  var hashCh = String.fromCharCode(35);
  t = t.replace(new RegExp('^' + hashCh + '+\\s+(.+)$', 'gm'), '<h3>$1</h3>');
end;

// Bridge a Pascal-side string into asm via @:
var pat: String;
pat := '^' + #$23 + '+\s+(.+)$';   // #$23 is the char-literal form of '#'
asm
  t = t.replace(new RegExp(@pat, 'gm'), '<h3>$1</h3>');
end;
```

The `#$23` form *does* work in Pascal source because the lexer expects hex digits after `#$` and gets them — that produces the character `#` at compile time, ready to be concatenated as needed.

Braces and character classes on their own are NOT the problem (`JSON.stringify({...})` works fine in asm); only the `#<non-digit>` adjacency is.

### asm blocks — Pascal-keyword names in JS need bracket form

JS method names that collide with Pascal reserved words (`end`, `then`, `with`, etc.) trip the asm parser when used in dot notation. Use bracket access:

```pascal
asm req['end'](); end;       // OK
asm req.end();    end;       // parses `end` as block terminator
```

`&then` is already handled in `NodeTypes.pas` for `Promise.then` because it's a Pascal keyword.

### asm blocks — closure parameters need `@`, bare names ReferenceError

Inside an anonymous procedure passed as a callback, DWScript renames the parameters on JS emission (`req` → `req$1`). Pascal-syntax references map automatically. `asm` references do not:

```pascal
http.createServer(procedure(req, res: variant)
begin
  asm (@res).writeHead(@code, headers); end;   // OK
  asm res.writeHead(code, headers);    end;    // runtime ReferenceError
end);
```

### asm blocks — `@const` doesn't work; copy to a local first

Pascal consts are inlined at compile time and never emitted as JS-scope variables. `@MY_CONST` inside asm produces `ReferenceError` at runtime. Copy to a local `var` first:

```pascal
const MY_PATH = '/etc/foo';

// WRONG — runtime ReferenceError:
asm @x = require('fs').readFileSync(@MY_PATH, 'utf8'); end;

// RIGHT — local var bridges const → asm scope:
var path: String;
path := MY_PATH;
asm @x = require('fs').readFileSync(@path, 'utf8'); end;
```

Same applies when passing a const into a callback whose body uses asm — the callback closes over Pascal locals/params, not consts.

### Non-ASCII string literals — use codepoint escapes, not raw UTF-8

A literal like `'→'` or `'═══'` in Pascal source survives compilation but renders as mojibake (`â†'`, etc.) at runtime — somewhere on the compile/serve/browser chain the UTF-8 bytes get decoded as Latin-1. Same trap shows up in console output. Use Pascal's codepoint syntax, which compiles to `\uNNNN` JS escapes:

```pascal
arrow.SetText(#$2192);                        // → (U+2192)
console.log(#$2550 + ' Title ' + #$2550);     // ═ box-drawing
```

Comments are fine to leave as raw UTF-8 — they don't reach runtime.

### `async` / `await` rules

- `async` is **only valid on unit-level functions/procedures** — never on a class method. Class methods that need `await` must be plain `function ... : JPromise;` and delegate via a 2-line body to a top-level `async` helper that takes `Self` as a parameter.
- `await` is an **expression, not a statement**. Assign to a discard var even when the value isn't needed: `_ := await SomeProc();`. Bare `await SomeProc();` does not compile.
- `JPromise` / `JPromiseResolver` are declared in `node/nodeCore/NodeTypes.pas`. `JPromise.then` is escaped as `&then` because it's a Pascal keyword. Static factories use lowercase JS names (`resolve`, `reject`, `all`, `race`).
- `new JPromise(executor)` is valid; the executor is `procedure(Resolve, Reject: JPromiseResolver)`.
- `try / except on E: Exception do ... raise E; end` **does not actually re-raise** — the exception is logged and execution falls through past the except block. Workaround when supervisor-level propagation matters: explicitly return `JPromise.reject(...)` from the function instead of relying on `raise`.

### Default-valued parameters can't be `const`

`constructor Create(const AKey: String = '');` → "const parameter cannot have a default value". Drop the `const` for any parameter that has a default; non-defaulted parameters can still be `const`.

### Type declarations in implementation sections

Multiple `type` blocks interleaved with function bodies in the implementation section break parsing. Put **all** types in a single block before any function bodies (or move them to the interface section).

### `inherited Clear` is safe; don't `.Free` individual children mid-life

`TElement.Clear` frees every child Pascal object and detaches the DOM. Calling `Child.Free` on one element of a parent's children list leaves a stale reference in the parent's `FChildren`; when the parent is later destroyed it tries to free the stale entry. For widgets that need to hide/show a single child (like JW3ChatPanel's typing row), toggle `display: none/flex` instead of destroy/recreate.

### Constructors — no extra parameters allowed on overrides

DWScript **does not allow** overriding a virtual constructor with a different (extra) parameter. Attempting it gives "parameter list doesn't match the inherited method".

**Solution**: use a standard `Create(Parent: TElement); override;` and add a separate public `Build(...)` method for the extra arguments. The caller invokes both:

```pascal
// Interface:
constructor Create(Parent: TElement); override;
procedure Build(const Filter: String);

// Implementation:
constructor TMyPage.Create(Parent: TElement);
begin
  inherited(Parent);
  SetStyle('gap', 'var(--space-4, 16px)');
  // do NOT call Build here — the caller does it
end;

procedure TMyPage.Build(const Filter: String);
begin
  FFilter := Filter;
  BuildHeader;
  BuildFilters;
  ...
end;

// Caller — use begin..end case arm + typecast:
case PageID of
  'MyPage':
  begin
    Page := TMyPage.Create(FMain);
    TMyPage(Page).Build('somevalue');
  end;
  ...
```

### Key Design Decisions

- **`requestAnimationFrame` for readiness** — more reliable than MutationObserver for layout computation after DOM insertion
- **Lazy click binding** — event listener only attached when `OnClick` is assigned
- **No `stopPropagation` by default** — events bubble naturally; only complex components (DataGrid, TreeView) stop propagation explicitly
- **Validators are target-agnostic** — developer applies results to DOM; validators just return booleans/strings
- **Forms are lazy-instantiated** — `JApplication` creates a form only on first navigation to it

### Complex Components

- **`JDataGrid.pas`** (~1,300 lines): Virtual scrolling with sentinel div, column resize, inline editing, keyboard navigation
- **`JTreeView.pas`** (~600 lines): Lazy loading, keyboard navigation, ARIA roles, CSS-based indentation
- **`JSemanticZoom.pas`** (~1,360 lines): Zoomable knowledge surface. Node types: `AddLevel` (raw HTML), `AddText` (prose), `AddCode` (mono block), `AddForm` (rendered inputs, fires `OnFormSubmit`), `AddWidget` (returns a live `TElement` slot). JSON loading via `LoadFromObject` / `FetchAndLoad`. Depth bar, values bar, breadcrumb, animated card transitions.
- **`JChatPanel.pas`** (~270 lines, class `JW3ChatPanel`): Bubble-style message list with typing indicator and click-to-copy. `AppendUser(text)` / `AppendAssistant(text)` / `ShowTyping` / `HideTyping`. Light markdown only (`**bold**` + newlines); full markdown/syntax-highlighting are app concerns and not bundled. Single lazy typing row toggled by `display`, re-appended to DOM end on every new bubble to stay at the bottom.

### Widget naming convention

Each widget unit is named `J<Name>.pas` and declares unit `J<Name>`, but its class is named `JW3<Name>`. Examples: unit `JButton` → class `JW3Button`; unit `JChatPanel` → class `JW3ChatPanel`. **Using the same name for unit and class causes parse ambiguity** — `JChatPanel.Create(...)` from another unit fails with "Unknown name" because the parser can't tell whether `JChatPanel` is the unit (a namespace) or a class.

## Example Applications (`examples/`)

- **`invoiceDemo/`** — complete CRUD app: list/detail/editor forms backed by `InvoiceData.pas`
- **`db-connect/`** — PHP-backed MySQL demo: `FormBooks.pas` / `FormBooksRaw.pas` talk to `books_api.php` / `raw_api_native.php` / `raw_api_docker.php`; schema in `schema.sql`
- **`SD-housing/`** — system-dynamics housing model: `FormHousing.pas` UI plus `uHousing*.pas` model/regional/scenarios/shocks units; documented in `MODEL.md`, `DIAGRAM.md`, `VALIDATION.md`, `FOR_STUDENTS.md`
- **`FormInputs.pas`** — input-widget showcase
- **`private projects/`** — private demo apps (not necessarily part of the public framework):
  - `homeAssist/` — multi-role SaaS: role-based login (6 roles), 9 dashboard pages, mock data in `HASData.pas`, permissions in `HASPermissions.pas`
  - `semanticZoom/FormZoom.pas` — live demo of `JSemanticZoom`
  - `Noise/FormNoise.pas` — RSS signal-to-noise filter; connects to a local Express API at `http://localhost:3000`
  - `bridge/FormBridge.pas` — Claude bridge demo
  - `agents/FormAgents.pas` — agents demo
  - `ide/FormIde.pas`, `ide/FormGrants.pas` — IDE-style demos

The `forms/Kitchensink.pas` is an interactive component browser and the default startup form.

## Managed Agents Integration

ShoeString-V2 apps that drive Anthropic's Managed Agents API share a single dispatch gateway (`api.php` on the server) and a flat library of versioned skill files (`*.skill.md`). The pattern:

```
ShoeString-V2 form
   ↓ HTTP
api.php?action=run     (single dispatch, by skill_id + task)
   ↓ HTTPS, beta header: managed-agents-2026-04-01
Managed Agents API     (cloud-hosted agent loop)
   ↓ MCP
Local MCP servers      (agents-mcp for save_file/create_pdf, etc.)
   ↑ loads
Skills/*.skill.md      (versioned prompt logic — system prompt + tool guidance)
```

### Per-app directory layout (`ShoeStringV2/managed-agents/<App>/`)

```
managed-agents/
├── README.md                                      ← architecture explainer
└── <AppName>/
    ├── Form<AppName>.pas                          ← ShoeString-V2 form
    └── skills/
        └── <prefix>_<skill_name>.skill.md         ← one or more skills
```

The first app under this pattern is `RCA/` (Root Cause Analysis), ported from a legacy hand-coded HTML app. It uses three skills (`rca_root_cause_analysis`, `rca_root_cause_detail`, `rca_remediation_strategist`) selected by user action.

### Skill files

Each skill is a Markdown file with: **role**, **input**, **method**, **output format**, **honest reasoning**. The skill becomes the agent's system prompt. Output formats can be JSON (with explicit "no markdown fences" instructions; the form strips fences defensively anyway) or Markdown (rendered to HTML by the form).

**Skill filename namespacing**: the server's skills directory is flat. Use a per-app prefix (`rca_`, `news_`, etc.) to avoid collisions.

### Deployment of skills

Skills live in source under `ShoeStringV2/managed-agents/<App>/skills/` and are deployed to a single flat directory on the server:

```
host:      /Users/nicowouterse/Docker/services/static-sites/agents/skills/
container: /var/www/static/agents/skills/                                 ← where api.php reads
```

Currently a manual copy; the source tree is canonical.

### api.php actions

`api.php` lives at `/Users/nicowouterse/Docker/services/static-sites/agents/api.php` (host) / `/var/www/static/agents/api.php` (container), served at `https://lynkfs.com/agents/api.php`. Actions used by ShoeString-V2 apps:

| Action | Method | Purpose |
|---|---|---|
| `?action=run` | POST | Load `skills/<name>.skill.md` as system prompt, create agent + env + session, send task as first user.message. Returns session_id. Body: `{skill, task, name?, model?}` |
| `?action=stream&session=X` | GET | Server-sent-events stream of session events. Polled by the form every ~2s |
| `?action=send-message` | POST | Mid-flight intervention. Body: `{session_id, message}` |
| `?action=create-workflow` | POST | Legacy: free-form agent with qtx-ide + agents-mcp MCPs. Body: `{task, name, model, system}`. Used by FormAgents.pas / FormIde.pas. New apps use `?action=run` instead |
| `?action=qtx-proxy` | POST | **Direct MCP call**, bypasses the LLM. Body: `{tool, args}`. Tools handled: `list_files`, `get_file`, `save_file`, `compile`, plus a pass-through for other qtx-ide tools. Use this for cheap file/compile operations to avoid token cost |
| `?action=save-file` | POST | Atomic write to `data/`, no LLM involved. Body: `{filename, content}`. Filename whitelist `[a-z0-9_.-]+`. Returns public URL |
| `?action=sessions` | GET | Lists past sessions from `data/sessions.json` |
| `?action=replay&session=X` | GET | Local event replay for cancelled/idle sessions |
| `?action=cancel-all` | POST | Nuke all sessions/agents/environments on Anthropic's side. Loops until `more: false` |

### Skill-dispatch flow in the form

1. User triggers an action.
2. Form POSTs `?action=run` with `{skill, task}`, receives `{session_id, ...}`.
3. Form polls `?action=stream&session=X` every 2s, accumulates `data:` lines.
4. Form tracks `FEventsProcessed` (count of seen `data:` lines) for dedup, since each poll returns the whole stream.
5. On `agent.message` events, save the **last** message text into a buffer (intermediate ones are tool-use commentary like "I'll search the web for X"; the final one is the result).
6. On `session.status_idle`, parse the buffered text (strip markdown fences if JSON) and render.
7. On `session.status_error`, surface `evt.error.message`.

See `managed-agents/RCA/FormRCA.pas` for the canonical implementation of this flow.

### MCP `save_file` arg-name gotcha

The qtx-ide MCP server's `set_file` and `save_file` tools take `filename` (a basename), not `path`. `get_file` already uses `filename`; matching that convention is required. `api.php`'s `qtx-proxy` save handler does `basename(str_replace('\\\\','/',$path))` to normalise before forwarding. Sending `path` to MCP silently no-ops (no error, no write) — the success response lies.

### May 2026 Managed Agents capabilities

- **Multi-agent / sub-agents** (beta, research preview): a lead agent delegates to specialist agents, each with its own model, system prompt, and tools. Specialists work in parallel on a shared filesystem.
- **Outcomes** (beta, research preview): structured success criteria evaluated after the session. Claimed +10pt task-success vs plain prompts.
- **Dreaming** (research preview): the agent reviews past sessions for patterns to self-improve.
- All three sit behind the `managed-agents-2026-04-01` beta header (set automatically by the Agent SDK; raw API callers must include it).
- The architectural payoff of skill-dispatch: when these features go GA, `api.php` adds one or two new fields when creating the agent (`sub_agents: [...]`, `outcomes: {...}`). Forms don't change.

### PHP traps that bit us

- **PHP warning text breaks JSON responses.** If anything in `api.php` emits output (warning, notice) before `header('Content-Type: application/json')` runs, the response body has warning text prepended → client-side `JSON.parse` fails. At the top of `api.php`:
  ```php
  ini_set('display_errors', '0');
  ini_set('log_errors',     '1');
  ini_set('error_log',      '/var/log/php-agents.log');
  ```
- **macOS Docker bind-mount extended-attribute trap.** Files opened in Finder/TextEdit on macOS pick up `com.apple.quarantine` and other `@`-flagged xattrs. Docker Desktop's VirtioFS bind-mount blocks the in-container PHP user from overwriting those files. Symptom: "permission denied" on a file that visibly has the right Unix mode. Fix: `xattr -c <file>` to clear, or `mv` it out of the way and let PHP recreate. **Use atomic writes** (`file_put_contents($tmp, …); rename($tmp, $target);`) — fresh files from inside the container don't inherit host xattrs.
- **Cancel-all is destructive.** Per `FormAgents.pas:817`'s "Kill All" button, `?action=cancel-all` deletes sessions, environments, **and agent definitions** on Anthropic's side. After clicking it, `/workspaces/default/agents` is empty until your next launch.

## Apps using the managed-agents pattern

- **`managed-agents/RCA/`** — Root Cause Analysis. Three skills (analysis / detail / counter measures), one form, RTF report via `?action=save-file`. Ported from `experiments/rootcauses/index.html` (legacy hand-coded HTML, ~1870 lines).

Other Managed-Agents-flavoured forms in the tree predate this convention:

- **`examples/private projects/agents-managed/FormAgents.pas`** — generic agent launcher / monitor / history. Free-form prompts (3 templates: general / expert-panel / research). Uses `?action=create-workflow` (the agent has both `qtx-ide` + `agents-mcp` MCPs).
- **`examples/private projects/ide/FormIde.pas`** — IDE-on-the-tunnel. Save/List/Compile/Open use `?action=qtx-proxy` (direct MCP, no LLM); chat with the IDE assistant uses `?action=create-workflow`. ~1158 lines.
- **`examples/private projects/Noise/FormNoise.pas`** — RSS noise filter. Single dial (0.0–1.0) controls a server-side scoring + partitioning pipeline in `static-sites/noise/api.php` (a separate PHP backend, not the agents one). Per-item deep assessment uses a direct call to Anthropic's Messages API via web_search.

## Reference Material

Full framework tutorial with code examples: `ShoeStringV2/booklet/content-v4.md` (~700 lines). Rendered via `ShoeStringV2/booklet/index.html`. Covers async patterns, positioning, theming, typography, layouts, form validation (including the **TFormulator** declarative-form section in Chapter 7), building components, a full **component catalogue** (Chapter 9, 26 widgets including JW3ChatPanel), non-visual components (Chapter 10: Services, HTTP Helper, Validators, Models, DataStore, Adapters, Database Connectivity), Node.js usage, and the invoice demo. **Note**: the booklet has been renamed across versions (`content-v2.md` → `content-v3.md` → `content-v4.md`); `index.html` always fetches the current latest.
