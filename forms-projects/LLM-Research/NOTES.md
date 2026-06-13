# ShoeString Deep-Research System — Operating Notes

Working notes for the metered, gated, multi-rung deep-research agent built on
ShoeString-V2 (Object Pascal / DWScript compiled to JS). Keep this in the repo;
it captures hard-won state that does not survive a reboot.

---

## 1. What the system is

A research agent that **owns its own loop** (no managed/opaque agent runtime),
so every model call is visible, metered, and breakable. It mechanises a
human-proven methodology: plan → gather (web search) → verify sources → gate →
judge → advise → human publish.

Core principle: **consistency before endurance** — deterministic gates decide
what may be published; models gather and advise but never lower the bar.

### The verification ladder (chapter 17)
- **Rung 0 — gates** (`JGates.pas`): deterministic, free, run on every promote.
  Provenance (>=1 verified source), corroboration (>=2 independent, by grade,
  floor 2), steelman present, domain rules (scientific needs Tier-1; causal
  disease/therapeutic needs interventional; claimType->required tier).
- **Rung 1 — judge** (`DoJudge` in RschRunner): peer model, runs on every
  claim that passed the gates, reads claim + verified sources (not the
  gatherer's reasoning). Advisory: records `judgeSupported/judgeWording/
  judgeNote`, never blocks.
- **Rung 2 — advisor** (`DoAdvise` runner / `ConsultAdvisor` console): stronger
  model (Opus 4.8 default), consulted rarely — on judge doubt, or
  heading-to-publish — and **cached** on a content hash of claim text + verified
  source URLs (`advisorKey`, stored on the claim, shared across runner+console).
  Advisory: records `advisorSupported/advisorPublishable/advisorWording/
  advisorNote`, never blocks. Cost is O(doubts + publishes), not O(claims).
- **Top of the ladder — the human**: publishes in FormResearch with sign-off,
  with judge + advisor counsel on screen.

### The Gate Compiler
On a fresh session the runner derives a gate pack from the subject by
**harm-first analysis** (name the worst harm a false published claim could do,
then set strictness), including a **domain tier rubric** (`tierGuide`) defining
what Tier-1..5 mean for THIS subject. Cached as `research-pack.json`.
The merge is **tighten-only**: floors mean neither the model nor a hand-edit can
loosen rung 0; garbage/failed output degrades to baseline and the run proceeds.

---

## 2. Components & ports

- **`sscserver`** — the IDE compile-and-serve server. Port **8080**. Routes
  `/compile`, `/project`, `/projects`, `/index.html`. This is the COMPILER,
  not the proxy.
- **LLM proxy** (`JLLMProxy.pas` -> compiled `index.js` + `plugins/claude.js` +
  `providers.json`). Port **3030**. Serves `POST /v1/chat`, `GET /health`,
  `/v1/models`. Holds the API key. Stateless, provider-pluggable.
- **Research runner** (`RschRunner.pas` -> `llmapp.js`). Node program, calls the
  proxy. Writes `research-ledger.json`, `research-synthesis.md`,
  `research-pack.json` in the working directory.
- **FormResearch** (`FormResearch.pas`) — the browser review console. Loads the
  runner's `research-ledger.json` via file picker; human publishes here.

---

## 3. Starting things (post-reboot checklist)

A reboot kills the proxy process and clears any per-shell env vars. Order:

1. **Start the proxy** (durable: uses a `.env` file, leave the terminal open):
   - In the proxy folder (with `index.js`, `providers.json`, `plugins/`):
     - First time only: `Copy-Item .env-example .env`, then edit `.env`:
       ```
       ANTHROPIC_API_KEY=sk-ant-...        # real key, not the placeholder
       PORT=3030                            # MUST be 3030 or runner can't reach it
       CORS_ORIGINS=http://localhost:8080,https://ide.lynkfs.com
       BUDGET_research=500000               # optional server-side breaker (see #6)
       BUDGET_WINDOW_MS=3600000             # optional, default 1h
       ```
     - `npm install` (first time / if node_modules cleared)
     - `node index.js`  -> expect "listening on port 3030"
   - Smoke test: `curl http://localhost:3030/health`
     -> `{"status":"ok","service":"llm-proxy","providers":"claude","budgets":{...}}`
2. **Start sscserver** (8080) if compiling.
3. **Run research** (see #4).

---

## 4. Running a research session

A session = a folder = its own ledger + synthesis + pack. Use a fresh folder
(or move old artifacts aside) to isolate sessions.

```powershell
# fresh subject
$env:RESEARCH_SUBJECT='Your subject here.'
node llmapp.js
# clear when done: $env:RESEARCH_SUBJECT=$null
```

- No `research-ledger.json` present -> fresh run (compiles pack, plans, gathers).
- Present -> resume (loads checkpoint, gathers only `lead`-status claims;
  `working` = blocked, left for human review, NOT re-gathered).
- Keep `research-pack.json` between runs to reuse the compiled pack (cache hit,
  no compiler spend). Delete it to force recompilation.
- Crash/breaker is safe: the checkpoint is the handoff; rerun resumes without
  re-billing completed work.

### Env knobs (all optional; defaults preserve current behaviour)
- `RESEARCH_SUBJECT` — the topic (default: screen-time const).
- `CEILING` — client-side per-run token ceiling (default 200000). Mixed-evidence
  claims search hard (~50-90k per gather); raise to ~300000 for broad topics.
- `MODEL_PLAN` / `MODEL_GATHER` / `MODEL_JUDGE` / `MODEL_SYNTH` /
  `MODEL_ADVISOR` / `MODEL_COMPILER` — per-role models.
- `RESEARCH_PROVIDER` — default `claude`.
- PowerShell gotcha: `VAR=val cmd` (Unix style) does NOT work. Use
  `$env:VAR='val'; node llmapp.js` and clear with `$env:VAR=$null`.

### Model lineup (defaults)
plan=sonnet-4-6, gather=haiku-4-5, judge=sonnet-4-6, synth=sonnet-4-6,
advisor=opus-4-8, compiler=opus-4-8. API strings: `claude-opus-4-8`,
`claude-sonnet-4-6`, `claude-haiku-4-5-20251001`. (Newer tier "Fable 5" =
`claude-fable-5` — switchable via env; model string is pure config, the proxy
passes it through, a wrong one fails fast.)

---

## 5. Reviewing & publishing (FormResearch)

1. Open the form (served by sscserver). **Hard-reload after any recompile**
   (DevTools open -> right-click reload -> "Empty Cache and Hard Reload", or use
   an incognito window). Browser JS caching has bitten us repeatedly.
2. Meter row -> **Choose file** -> the session's `research-ledger.json`.
   Rows render: FINDING (green, judge/advisor badges) and WORKING.
3. Click a FINDING row -> detail panel shows judge + advisor counsel.
4. **Publish (sign off)** -> consults the advisor first (cached -> instant;
   else "Consulting advisor (opus)..." with a 20-60s wait) -> sign-off prompt.
   Counsel never blocks; a failed consult still lets you publish.
5. **Download ledger** writes decisions back to a file you can drop over
   `research-ledger.json`.

Note: the console gates hand re-promotes with its built-in BASELINE pack, not
the session's tightened pack (display/publish unaffected). Console-added sources
count as verified (a human vouches). This is how you repair a blocked claim:
add the authoritative Tier-1 source by hand, then Promote.

---

## 6. The breakers (two layers, defense in depth)

- **Client-side** (`JBudget` in the runner): per-run token meter + breaker, env
  `CEILING`. Trips mid-run, banks the checkpoint, halts cleanly.
- **Server-side** (`JLLMProxy`): scoped, opt-in. Only requests carrying a
  `budgetId` AND with a matching `BUDGET_<id>` env ceiling are metered/capped.
  Untagged callers (EDAM2 generator, FormLLM, the console-without-budget) are
  byte-for-byte unaffected. The runner tags `budgetId: 'research'`. Ceiling
  lives in proxy env, so a dead/buggy client can't raise it. Rolling window
  (`BUDGET_WINDOW_MS`, default 1h), self-recovering, in-memory (resets on proxy
  restart). Shared across all research SESSIONS within the window.
  Observe via `/health` -> `budgets` field. A 429 with `budgetExceeded:true`
  mid-run is the server breaker doing its job, not a bug.

---

## 7. Source verification

After gather, each source URL is fetched (GET, 8s timeout) to confirm it
RESOLVES before it counts toward a gate. **Status-aware**: 2xx = verified;
401/403/405/429 = verified too (the server made an access decision, so the
endpoint exists — authoritative legal/academic sites bot-block with 403);
404/410/timeout/DNS-fail = unverified. Records `verified` and `httpStatus` on
each source. Catches fabricated URLs without discarding real-but-bot-blocked
apex sources. It checks that a URL resolves, NOT that the content supports the
claim — that's the judge's job.

---

## 8. Dialect landmines (DWScript / QuartexPascal -> JS)

These cause failed compiles or silent runtime bugs. All learned the hard way.

- **asm `#` trap**: `#` followed by a non-digit inside an `asm` block fails the
  lexer (char-literal). Use `String.fromCharCode(...)` or `#$23`. `#10` (digit)
  is fine. A `#` inside a quoted JS string ('#') is fine.
- **const never crosses asm**: a Pascal `const` referenced as `@MyConst` in asm
  emits an undefined identifier (it's inlined at Pascal call sites, not emitted
  as a JS var). Use the const in Pascal code (it inlines as a literal), or copy
  to a `var` first, or use a literal directly in the asm. (Same for records;
  `var`/params DO cross.)
- **First deref off a `@var` needs parens**: `(@BudgetMap).get(...)`, not
  `@BudgetMap.get(...)`. Bare assignment `@x = ...` is fine; bracket `(@a)[@i]`
  is fine.
- **No backticks / no JS regex literals in asm**: the lexer scans for quote
  pairing -> "End of string constant not found". Use `.split().join()` instead
  of `.replace(/.../g)`. Single-quoted JS strings are fine.
- **Pascal string escaping**: only `'` needs doubling (`''`). `#`, `<`, `>`,
  backtick, and double-quote `"` are all fine inside single-quoted Pascal.
- **lambda vs procedure for handlers**: `lambda Foo; end;` for NO-ARG handlers
  (OnClick, OnTrip). `procedure(e: variant) begin..end` for parameterised
  callbacks AND for `addEventListener` — NEVER lambda with addEventListener.
- **Loop-variable capture (cost a long debug session)**: a `var x` declared
  inside a `for` loop body is a SINGLE function-scoped slot, NOT fresh per
  iteration. Closures (e.g. click handlers) all capture the same final value.
  Fix: don't rely on per-iteration capture — stash the value on the DOM element
  (`setAttribute('data-...')`) and read it back in the handler via
  `e.currentTarget.getAttribute(...)`. (This was the FormResearch row-select
  bug: every row selected the last claim.)

---

## 9. Operational gotchas seen this session

- **Port collision: `dwc.exe` on 127.0.0.1:3030.** The Quartex compiler process
  (`dwc.exe`) can bind `127.0.0.1:3030` during a compile, shadowing the proxy's
  `0.0.0.0:3030` wildcard for all loopback (localhost) traffic. Symptom: the
  proxy is up but every call gets `{"error":"Not found"}` (the proxy's own
  unknown-route reply) or 404. Diagnose:
  ```powershell
  Get-NetTCPConnection -LocalPort 3030 -State Listen | Select-Object LocalAddress, OwningProcess
  ```
  Two PIDs (one 127.0.0.1, one 0.0.0.0) = collision. Fix: `Stop-Process -Id <dwc-pid> -Force`
  (it's a compiler process; a fresh one spawns next compile). The browser hits
  `localhost` too, so the CONSOLE is exposed to this as well. **If it recurs
  every compile, move the proxy to PORT=3031** (then runner needs a
  `RESEARCH_PROXY_URL` env knob + the FormResearch `PROXY_URL` const changed +
  recompile — not yet done).
- **Stale browser JS.** After recompiling a form, a normal reload can serve
  cached old JS. Always hard-reload (Empty Cache and Hard Reload) or incognito.
- **Stale served index.js.** The BUILD.md skeleton dance must copy the fresh
  `index.js` into the proxy folder; verify the file timestamp changed.
- **localStorage key**: the ledger's browser persistence key is
  `research.ledger` (and `research.events`), NOT `ledger.claims`.
  `ledger.claims` is the in-memory JW3DataStore key the UI reads. Don't confuse
  them when probing in DevTools.
- **Proxy auth is OPEN by default** (no `JWT_SECRET`). Fine on localhost; lock
  down before any non-loopback exposure.

---

## 10. Debugging discipline (the meta-lesson)

When the visible state looks correct AND the code looks correct, stop
theorising and make the running code TELL you what it sees. One
`asm console.log(...)` of the actual values (selected id, status, flags) beat
several rounds of inference. Add the probe early, not late.

---

## 11. Open / not-yet-built

- **Console adopts the session pack**: FormResearch gates hand re-promotes with
  the baseline pack, not the tightened session pack. Wire the pack into the
  checkpoint for the console to read.
- **Verified/httpStatus badges on console source rows**: can't currently see
  WHICH source is unverified in the detail panel.
- **Synth confinement**: tighten the synthesis prompt to use only the finding
  texts ("add no facts") — it currently adds mild framing.
- **Species taxonomy for meta/hypothetical claims**: a claim about scholarly
  debate over a hypothetical (e.g. "evidence is mixed on whether reform WOULD
  help") is labelled `scientific` and demands Tier-1, which structurally can't
  exist for it. Consider a `forecast`/`debate` species or planner relabelling.
- **Streaming-branch proxy budget**: only non-streaming calls are metered
  server-side (the runner is non-streaming, so moot today).
- **Move proxy to 3031** if the dwc collision recurs (see #9).
- **Gate Compiler per-topic packs**: documented; runtime tightening works,
  compile-time pack authoring tool remains a design doc.

---

## 12. File inventory

- `JGates.pas` — rung-0 deterministic gate engine (verified-source aware).
- `JLedger.pas` — append-only ledger state machine (variant-backed, guarded
  transitions, LoadJSON/ToJSON, AddSourceVerified).
- `JBudget.pas` — client-side meter + breaker.
- `JLLMProxy.pas` — stateless LLM proxy skeleton (+ scoped server breaker).
  Compile via BUILD.md dance -> `index.js`.
- `JLLMAdapter.pas` — XHR/stream adapter (browser); streaming-usage patched.
- `RschRunner.pas` — headless research loop: plan/gather/verify/gate/judge/
  advise/synth, Gate Compiler, env knobs. -> `llmapp.js`.
- `FormResearch.pas` — browser review + publish console.
- `RschVBFixture.pas` — acceptance fixture (Vanden Bossche, 12 checks).
- Docs: `ss-v2-ch17-deep-research.md`, `research-system-explained.md`,
  `gate-compiler-v0.md`, `agent-patterns.md`.
