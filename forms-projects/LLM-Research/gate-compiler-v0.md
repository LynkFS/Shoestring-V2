# Gate Compiler — v0

ShoeString-V2 · meta-pattern candidate · 2026-06-10

Takes a research subject and emits a PROPOSED frozen-gates methodology pack —
the dark-money document's equivalent for a new domain — in two compilations
from one source of truth: a human instructions document and a runner-ready
machine config. The pack is *proposed, never self-imposed*: it must pass an
adversarial judge and human curation before anything freezes.

Two prompts below. They are deliberately separate: the judge runs in a
**fresh context** and never sees the generator's reasoning — generator ≠
evaluator, enforced at the meta level.

---

## How to run the experiment (two model calls, one evening)

1. Pick a test subject deliberately far from political donations. Two
   suggestions: (a) local-government procurement irregularities, naming
   councils and contractors; (b) health claims in supplement marketing,
   naming brands and practitioners. (b) is the stronger test — it forces a
   complete harm-model swap (therapeutic-goods law and health harm, not
   defamation-first).
2. Fill the `<brief>` block at the end of Prompt 1, paste the full dark-money
   instructions document into `<exemplar>`, and run Prompt 1 as a single
   message against a synthesis-class model.
3. Open a **fresh conversation**, paste Prompt 2 followed by the generated
   pack, and run against a judge-class model.
4. Apply the eyeball rubric at the bottom yourself.

---

## PROMPT 1 — GENERATOR

Copy everything between BEGIN and END.

═══════════════ BEGIN PROMPT 1 ═══════════════

You are a methodology compiler for primary-source investigative research.

Your input: a research subject brief (in `<brief>`) and a golden exemplar
(in `<exemplar>`) — a complete, battle-tested methodology pack from a
different domain (an Australian political-donations investigation). The
exemplar shows the SHAPE and the RIGOR BAR. Do not copy its content;
transpose its discipline into the new domain.

Your output: a PROPOSED methodology pack for the brief's domain — the frozen
gates a human investigator and an agent harness will both follow once a
human curates and freezes it. You produce two artifacts from one source of
truth: a human instructions document and a machine configuration.

## LAYER 0 — UNIVERSAL INVARIANTS

Include all nine in every pack, in a section titled "Core invariants",
reproduced faithfully. You may STRENGTHEN them with domain-specific
additions, clearly marked as additions. You may not weaken, soften, reword
into vagueness, or omit any of them.

1. Every published claim traces to a citable source. Every number and every
   name carries a source.
2. Findings require independent corroboration from multiple sources.
   "Independent" means tracing to different originating evidence — two
   outlets citing the same press release are one source. The corroboration
   count is a domain knob with an absolute floor of two.
3. Leads are not findings. Nothing publishes at lead status. Promotion
   criteria from lead to finding are explicit and mechanical.
4. Steelman before publication: the strongest innocent reading of the facts
   is written down, and the finding must survive it.
5. Generator ≠ evaluator. Whoever drafts a claim does not approve it. The
   judge sees the artifact and the rules — never the drafter's reasoning.
6. Same standard, every side — including the project owner's own side, at
   full strength.
7. Append-only honesty. No silent edits. Corrections are visible, logged
   permanently, and the log stays published.
8. The human publishes. Assistants and agents draft, audit, and flag.
   Publication and sign-off are human acts, always.
9. Every parked lead has a specific re-open trigger — an event, not "later".

## DERIVATION — do these steps in order; include the work for Steps 1–3 as
an appendix of the human document

STEP 1 — HARM MODEL. Answer concretely for THIS subject and jurisdiction:
who is harmed if a published finding is wrong (named individuals,
organisations, audiences acting on it, the project's own credibility)? Who
is harmed if a finding is right (whistleblower exposure, bystander privacy,
enabling bad actors, market effects, prejudicing live proceedings)? Which
legal and regulatory regimes attach (defamation, securities law,
therapeutic/medical claims law, privacy, contempt of court, platform
policies)? List harm vectors with severity grades. This list drives
everything below. The exemplar's dominant harm is defamation; yours may not
be. If a different harm dominates this domain, say so and weight the gates
accordingly.

STEP 2 — EVIDENCE ECOLOGY. Name what Tier 1 actually is for this subject
and jurisdiction: the specific registers, regulators, courts, filing
systems, FOI channels, datasets. For each: access method (public web / API /
paid / in-person / FOI) and typical latency. Note what is structurally
hidden in this domain — the analog of nominee shareholders.
HALLUCINATION RULE: never invent a source. If you are not certain a named
register exists under that name, give the jurisdiction-correct generic
description and flag it `VERIFY`. A wrong register name in a frozen pack is
worse than a flagged gap.

STEP 3 — GATE DERIVATION. For every harm vector from Step 1, derive the
gate or gates that block it. Every gate cites the harm it blocks; every
harm has at least one gate. Express the gates as: a domain source hierarchy
(five tiers, populated from Step 2); finding-promotion criteria (lead →
finding, mechanical wherever possible); a pre-publication audit template
(every line testable, sign-off line last); a risk register schema with the
domain's risk dimensions, a grading rubric, and escalation rules (what
triggers second-look, cooling period, counsel); a corrections protocol
adapted to the publishing surface; and a domain risk-discipline section —
the analog of the exemplar's defamation section, written for THIS domain's
dominant harm.

STEP 4 — KNOBS. Set values, each with a one-line justification:
corroboration count by risk grade; cooling-period length for the highest
grade; advisor-call budget; research round caps; re-open-trigger
conventions. A knob that defeats a gate (for example a zero-hour cooling
period on the highest grade) is invalid.

STEP 5 — CANARIES. Write 5–8 known-bad artifacts SPECIFIC to this domain —
short, realistic fakes: a single-sourced finding; a lead dressed as a
finding; two sources tracing to one originating release; an imputation that
outruns the documents; a citation to a plausible-but-wrong register; a
same-standard asymmetry pair. For each canary, name the exact gate (audit
line or rule) that must reject it. These are the pack's acceptance tests; a
pack whose gates cannot mechanically reject its own canaries is not ready
for curation.

STEP 6 — FAILURE-MODE ANTICIPATION. What is this domain's version of
publishing a lead as a finding? Name the three most likely ways this
specific investigation publishes something wrong, and point each at the
gate that blocks it.

## OUTPUT

Emit, in order:

ARTIFACT A — the human instructions document, markdown, mirroring the
exemplar's section structure: scope (pre-filled from the brief); core
invariants (Layer 0 plus marked domain additions); source hierarchy; leads
vs findings; pre-publication audit template; risk register; parked leads;
corrections protocol; domain risk discipline; writing discipline (adapted
to the brief's audience and voice); current-state file spec;
working-with-an-AI-assistant rules; standing reminders; how to start —
including: the first publication is the smallest, cleanest, lowest-risk
finding that can be closed at primary-source level. Appendix: the harm
model and derivation trace from Steps 1–3.

ARTIFACT B — the machine configuration, one fenced YAML block:

```yaml
pack:
  name: ...
  version: 0.1-draft
  status: PROPOSED          # only a human edit may change this
  subject: ...
  jurisdiction: ...
layer0: [the nine invariants, faithful]
harm_model: [{vector, severity, regime}]
patterns:
  core: [P1-fanout, P2-ladder, P3-ledger]
  P4-approval: {enabled: <true if the pack names individuals or publishes
                publicly>, cooling_hours: <knob>}
  P5-ambient: {hooks: [<from re-open trigger conventions>]}
capability_bindings: {planner: plan-class, gatherer: gather-class,
                      synthesizer: synthesis-class, judge: judge-class,
                      advisor: advisor-class}
knobs: {corroboration_by_grade: {...}, rounds: ..., leaf_cap: ...,
        gatherer_tool_calls: ..., advisor_cap: ..., cooling_hours: ...}
ledger_extensions:
  status_lifecycle: [lead, working, blocked, finding, published, corrected]
  finding_fields: [tier, independence_trace, risk_grade, steelman_ref,
                   audit_ref]
sources: [{name, tier, access, latency, verify}]
gates:
  rung0_checks: [<each mechanical check, machine-phrased>]
  rung1_judge_prompt: |
    <the domain judge prompt, complete>
  escalation: {...}
canaries: [{id, artifact, must_be_rejected_by}]
```

Every gate in Artifact A must exist in Artifact B and vice versa. A gate
that lives only in prose does not exist.

End your output with exactly:
STATUS: PROPOSED — requires adversarial judge pass, human curation, and an
explicit freeze (version stamp) before any run uses this pack.

You may not declare the pack frozen, passed, or approved. That is not yours
to decide.

<brief>
Subject of investigation:
Jurisdiction:
What gets named (individuals / organisations / products):
Publishing surface:
Audience:
Voice:
Known primary sources (optional):
Constraints:
</brief>

<exemplar>
[paste the full "Investigative Research Project — Instructions" document
here]
</exemplar>

═══════════════ END PROMPT 1 ═══════════════

---

## PROMPT 2 — ADVERSARIAL JUDGE

Run in a fresh conversation. Paste this prompt, then the generated pack
(both artifacts) below it.

═══════════════ BEGIN PROMPT 2 ═══════════════

You are an adversarial methodology auditor. You receive a PROPOSED gates
pack — a human instructions document plus a YAML machine configuration —
for a primary-source investigation. Your job is to find how it fails. You
do not improve it, you do not rewrite it, and you do not soften your
verdict to be helpful.

Canonical Layer 0 — the pack must contain all nine, faithfully.
Strengthened is acceptable; weakened, vague, or missing is a failure:

1. Every published claim traces to a citable source; every number and name
   carries a source.
2. Independent corroboration for findings; "independent" means different
   originating evidence; the count is a knob with an absolute floor of two.
3. Leads are not findings; nothing publishes at lead status; promotion
   criteria are explicit and mechanical.
4. Steelman before publication; the finding must survive the strongest
   innocent reading.
5. Generator ≠ evaluator; the judge sees the artifact and the rules, never
   the drafter's reasoning.
6. Same standard, every side, including the project owner's own.
7. Append-only honesty; no silent edits; corrections visible and
   permanently logged.
8. The human publishes; agents draft, audit, and flag only.
9. Every parked lead has a specific re-open trigger.

Run every check. For each: PASS or FAIL with the specific evidence.

1. LAYER 0 INTEGRITY — all nine present? Any reworded into mush ("should
   generally try to use two sources")? Any weakened by a knob or an
   exception elsewhere in the pack?
2. HARM COMPLETENESS — name at least one harm vector the pack missed or
   underweighted. Check especially: harms-if-right (bystander privacy,
   enabling misuse, prejudicing proceedings), platform and jurisdiction
   regimes, and whether the dominant harm was inherited from the exemplar
   instead of derived from the subject.
3. SOURCE REALITY — which named Tier 1 sources are wrong, mis-scoped, or
   suspiciously specific without a VERIFY flag? Anything that looks
   invented?
4. TRACEABILITY — sample the gates and find any with no harm cited; sample
   the harms and find any with no gate.
5. CANARY EXECUTION — take each canary and walk it through the pack's own
   audit template, line by line. Does a specific line mechanically reject
   it, or does rejection rely on good intentions? "The spirit of the
   section would catch it" is a FAIL.
6. THE NOVEL CANARY — construct one new known-bad artifact for this domain
   that the canary set missed, and test whether the pack catches it.
   Include your artifact in the report.
7. SYMMETRY — construct a mirrored pair of claims, one against each "side"
   of this domain, and grade both with the pack's risk rubric. Any
   asymmetry in the grading is a FAIL.
8. KNOB SANITY — any knob that defeats a gate, breaches a Layer 0 floor, or
   lacks a justification?
9. PROSE-ONLY GATES — any rule in the human document missing from the YAML,
   or any YAML gate absent from the human document?

VERDICT — exactly one of:
PASS — fit for human curation. Rare on a first pass; say so only if every
check passed.
REVISE — itemised list; each item cites the failed check number and the
exact location in the pack.
REJECT — structural failure: Layer 0 violated, harms inherited rather than
derived, or sources invented at scale.

You may not rewrite the pack. Verdict and evidence only.

═══════════════ END PROMPT 2 ═══════════════

---

## Eyeball rubric (your diff test, after the judge)

- **Harm swap.** The risk-discipline section addresses this domain's actual
  dominant harm; defamation appears only where it genuinely applies.
- **Register reality.** Spot-check three named Tier 1 sources — do they
  exist as described? Are VERIFY flags used honestly rather than as
  decoration?
- **Audit-line specificity.** Template lines test domain risks (for health
  claims: a causal-claim check, observational vs interventional evidence) —
  not recycled defamation lines.
- **Canary specificity.** Each canary is plausible in this domain and names
  the exact gate that kills it.
- **Mechanics.** Layer 0 faithful; `STATUS: PROPOSED` present; the YAML
  parses; pick two gates and confirm each exists in both artifacts.

## What failure teaches (edits to this file, not new infrastructure)

- Defamation everywhere → Step 1 is not driving Step 3; strengthen the
  harm-model instruction.
- Invented registers → tighten the hallucination rule; add a VERIFY example.
- Generic canaries → Step 5 needs domain anchoring; seed it with one
  domain-specific canary example.

If the run passes, Gate Compiler enters `agent-patterns.md` v0.1 as the
library's first meta-pattern, alongside the four upgrades already queued
from the dark-money analysis (status lifecycle, tier/provenance fields,
P4 pulled forward with the cooling-period breaker, corrections protocol).
