# Agent Patterns — v0

ShoeString-V2 · deep-research substrate · 2026-06-10

A **pattern** is a durable, model-agnostic description of how agents cooperate
across roles, models, and time. Patterns are the stable layer; models churn
weekly. One separation makes that survivable:

> **Patterns bind to capability classes, never to model names.**
> A pattern says *gather-class* or *synthesis-class*. A one-file registry maps
> each class to today's concrete model string. A new model shipping is a
> one-line registry edit; the patterns do not change.

---

## The pattern template

Every pattern fills the same ten fields. Field 7 is mandatory everywhere:
a pattern without a budget is not admissible to the library.

| #  | Field                    | Answers                                              |
|----|--------------------------|------------------------------------------------------|
| 1  | Intent                   | What job; when to use; when not                      |
| 2  | Roles & topology         | Which agents; who talks to whom                      |
| 3  | Control flow             | The loop, triggers, stop conditions                  |
| 4  | Capability bindings      | Per role: capability class, resolved via registry    |
| 5  | Placement                | Where each role runs; what it may touch              |
| 6  | State interface          | What it reads/writes; write-scoping                  |
| 7  | Budget & breakers        | Caps, live telemetry, kill conditions — mandatory    |
| 8  | Verification             | Gates, judge, escalation path                        |
| 9  | Failure modes & recovery | Known breakages; the designed response               |
| 10 | Composes with            | Patterns that nest inside or around it               |

## Capability registry (stub)

Model strings live here and only here. Bindings below are suggestions —
verify against what the proxy actually exposes before a run.

| Class           | Requirement                                   | Suggested binding   |
|-----------------|-----------------------------------------------|---------------------|
| plan-class      | decomposition, tool-aware reasoning           | claude-sonnet-4-6   |
| gather-class    | cheap, fast, reliable tool use, summarisation | claude-haiku-4-5    |
| synthesis-class | long context, strong integration and writing  | claude-opus-4-8     |
| judge-class     | checklist discipline, instruction-following   | claude-sonnet-4-6   |
| advisor-class   | strongest available reasoning; rare calls     | claude-opus-4-8     |

---

## P1 — Fan-Out Research (plan → parallel gather → synthesize)

**1. Intent.** The workhorse for any research question too large or too broad
for one context window: decompose, gather breadth-first in parallel, integrate
once. Use when the question splits into independent sub-questions. Do not use
for a single-source lookup (one gather-class call suffices) or for a deep
sequential reasoning chain (fan-out adds cost there, not insight).

**2. Roles & topology.** One Planner; N Gatherers; one Synthesizer. Star, not
mesh: gatherers are mutually invisible and never coordinate with each other —
coordination happens only through the ledger. (Flat peers writing shared state
with locks is the design Cursor tried twice and abandoned; do not rebuild it.)

**3. Control flow.** (a) Planner reads the done-condition file and emits a
question tree to the ledger — depth ≤ 2, open leaves ≤ Q (default 8).
(b) Each open leaf gets one Gatherer run carrying exactly that sub-question
plus the relevant done-condition excerpt; ≤ T tool calls (default 5); writes
finding rows; marks the leaf answered or blocked. (c) The Synthesizer reads
the ledger — findings, never raw pages — and writes the draft plus an explicit
gap list. (d) The Verification Ladder (P2) gates the fan-in. (e) Pass → done.
Gaps remaining and rounds < R (default 3) → Planner converts gaps to new
leaves; next round. Stop conditions: judge pass, round cap, budget breaker,
or no novel leaves emitted (saturation).

**4. Capability bindings.** Planner = plan-class. Gatherer = gather-class —
this is where call volume lives, so the cheapest class that uses tools
reliably. Synthesizer = synthesis-class.

**5. Placement.** The loop is a headless runner process you own (node — the
same target ssc already emits for). All model and tool traffic goes through
your proxy, which meters it. Gatherers run sequentially or in parallel as the
runner pleases: parallelism is a runner setting, not a pattern change.

**6. State interface.** Planner writes the question tree only. Gatherers
append finding rows only: `{leaf_id, claim, quote, url, accessed, confidence}`.
The Synthesizer writes the draft and gap list only. Write-scoping is enforced
by the runner, not by trust.

**7. Budget & breakers.** Per-gatherer cap (≤ T tool calls, token ceiling);
per-round token ceiling; whole-run hard ceiling; live tally on the runner
console, sourced from the event log. A breaker halt writes a handoff (P3)
first, so halting is resumable, never fatal.

**8. Verification.** Deterministic checks on every write (rung 0 of P2);
judge at fan-in only — never per gather.

**9. Failure modes & recovery.** *Query drift* — a gatherer wanders off its
sub-question; bounded by carrying exactly one leaf plus the done-condition
excerpt. *Duplicate effort* — overlapping leaves; the planner must check the
existing tree before emitting, and the judge flags near-duplicate leaves
across rounds. *Shallow rounds* — each round re-asks reworded versions of the
same questions; stop on no-novelty, not only on the round cap.

**10. Composes with.** Runs inside P3; gated by P2. A leaf that itself needs
decomposition gets a sub-planner exactly one level deep — needing more than
that means the question was scoped wrong: fix the done-condition instead.

---

## P2 — Verification Ladder (deterministic gates → milestone judge → advisor)

**1. Intent.** Keep the run honest without paying a judge on every step. The
two motivating examples — a judge at milestones and "I'm done" claims, and
lesser models calling a stronger advisor — are rungs of this one ladder. Use
everywhere; this pattern guards the others.

**2. Roles & topology.** Rung 0: deterministic checks — runner code, no model.
Rung 1: Judge, in a context separate from the worker. Rung 2: Advisor,
strongest class, called rarely and narrowly.

**3. Control flow.** *Rung 0* fires on every artifact write: finding rows
schema-valid; a citation present for every claim; ≥ 2 independent sources for
load-bearing claims; URLs resolve; the quote actually appears in the fetched
page; coverage checklist against the done-condition. Free, instant, and it
answers most "is it done?" questions. *Rung 1* fires only at milestones:
fan-in, any "I'm done" claim, round boundaries. The judge receives the
artifact, the done-condition, and rung-0 results — never the worker's
transcript, so it cannot be talked into a pass. Verdict ∈ {pass,
revise(reasons), escalate}; at most 2 revise cycles per milestone, then
escalate or halt-and-ask-human. *Rung 2* fires on judge escalation or a
worker's self-reported low confidence: one narrow question to advisor-class
("is this inference from these two sources valid?"), answer cached in the
ledger keyed by question hash so it is never asked twice.

**4. Capability bindings.** Rung 0: none. Judge = judge-class — checklist
discipline matters more than brilliance. Advisor = advisor-class.

**5. Placement.** Rung 0 inside the runner process; rungs 1–2 through the
proxy like any model call — they are metered too.

**6. State interface.** Verdicts and advisor answers are ledger rows. Every
verdict cites the checklist line it rests on — an audit trail of *why*
something passed, not just that it did.

**7. Budget & breakers.** Judge calls are O(milestones), never O(steps).
Advisor calls capped per run (default 5) and cached. The revise-cycle cap
doubles as a cost breaker.

**8. Verification.** Self-referential rung: the judge's own output is rung-0
checked — verdict present, reasons reference real checklist items.

**9. Failure modes & recovery.** *Rubber-stamping* — the judge passes
everything; mitigated by per-line citations and by canaries: occasionally feed
the judge a known-bad artifact and alarm if it passes. *Gaming rung 0* — a
worker fabricates citations to satisfy the counters; caught by quote-in-page
verification at rung 0 and source spot-checks at rung 1. *Ladder thrash* —
revise→fail loops; capped at 2, then escalate.

**10. Composes with.** Gates P1's fan-in and the final done; verdicts persist
through P3.

---

## P3 — Durable Ledger & Handoff (state outside context; checkpoint, resume)

**1. Intent.** The time dimension: survive context limits, crashes, closed
laptops, and multi-day spans, and make every conclusion reconstructible
afterwards. Without this pattern the system is a long shell script that
happens to call an LLM; with it, kill −9 mid-run costs one checkpoint.

**2. Roles & topology.** No agents of its own — it is the substrate the other
patterns stand on. One writer at a time per store; the runner serialises.

**3. Control flow / structure.** Four stores per run.
(a) `done-condition.md` — written first, immutable for the run, always loaded
verbatim and never summarised: the agent cannot quietly redefine done, and
goal drift across resets is structurally prevented.
(b) `ledger` (sqlite or json) — question tree, finding rows, verdicts, advisor
cache: the queryable working memory.
(c) `events.log` — append-only: every model call, tool call, and verdict,
**with token counts and cost**: the audit trail and the meter, in one place.
(d) `handoff.md` — written at each checkpoint: a state summary within a hard
size budget, open threads, next actions, and pointers into the ledger.
Checkpoints land at unit-of-work boundaries — after each gatherer completes,
after synthesis, after each verdict — not every step, not only at the end.
Session boot: load the done-condition verbatim, the latest handoff, and query
the ledger on demand. Between sessions do a **full context reset** — rebuild
from files rather than summarising a dying conversation in place; rolling
summaries lose the goal, resets do not.

**4. Capability bindings.** Handoff authorship = plan-class. Everything else
is runner code.

**5. Placement.** Files/sqlite under the runner's project directory — your
filesystem, your backup. This is the part of Bridge that was right in shape
(KNOWLEDGE.md, the agent log) and wrong in execution: reuse the shape, own
the implementation.

**6. State interface.** It *is* the state interface — the other patterns
declare their reads and writes against these four stores.

**7. Budget & breakers.** The live token tally is derived from `events.log`;
the breaker reads it; the console renders it. A budget halt writes a handoff
before stopping, so the run resumes when the ceiling is raised. This is
exactly the instrumentation whose absence made the Bridge burn invisible —
no warnings because no meter, no diagnosis because no log.

**8. Verification.** A run is auditable iff every claim in the final report
traces through ledger rows to logged fetches. Rung 0 includes this trace
check before the final pass.

**9. Failure modes & recovery.** *Handoff bloat* — handoffs grow until they
are the context problem again; hard size budget, detail stays in the ledger
and is retrieved on demand. *Crash between work and checkpoint* — replay the
gap from `events.log` on boot. *Goal drift across resets* — prevented by the
done-condition's immutability plus verbatim load.

**10. Composes with.** Hosts P1; persists P2's verdicts; future patterns
(approval pause, ambient triggers) checkpoint into the same stores.

---

## How they compose

One deep-research run:

```
┌────────────── P3 Durable Ledger hosts the run ───────────────────┐
│  done-condition.md   ledger   events.log   handoff.md            │
│                                                                  │
│  P1 round:  plan ──► gather ×N ──► synthesize ──► P2 gate        │
│                                                     │            │
│        pass ──► final report (trace-checked)        │            │
│        gaps & rounds left ──► next P1 round  ◄──────┘            │
└──────────────────────────────────────────────────────────────────┘
```

## Future library entries (when a task demands them, not before)

- **P4 Delegated approval** — pause-in-place at consequential actions, resume
  on human verdict; Bridge's `approve_task` already had this shape.
- **P5 Ambient watch** — standing research triggered by schedule or events,
  same stores, no human in the loop per run.
- **P6 Fleet orchestration** — only when there are genuinely parallel
  *workstreams*, not just parallel fetches.
