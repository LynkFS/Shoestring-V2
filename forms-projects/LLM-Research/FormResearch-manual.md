# FormResearch — User Manual

The review console for the ShoeString deep-research system. The headless runner
(`llmapp.js`) does the autonomous work — planning, gathering, verifying sources,
gating, judging — and writes a `research-ledger.json` checkpoint. FormResearch is
where a **human** reviews that work and decides what gets published. It is the top
of the verification ladder: the runner proposes, the gates and models advise, and
you dispose.

Nothing you do here is destructive to the runner's data unless you choose to
download and overwrite the checkpoint file. The form works on an in-memory copy.

---

## The screen, top to bottom

### 1. Meter row

A single strip across the top showing budget and the session-level actions.

- **meter: N tokens / M ceiling** — live token usage and the client-side ceiling
  for this console session. It updates as the form makes its own model calls (the
  advisor consult and the article writer). It is separate from the runner's meter
  and from the proxy's server-side budget; it is here so console-initiated spend is
  visible.
- **runner checkpoint: [Choose file]** — the load control. Click it and pick the
  runner's `research-ledger.json`. The claims list repopulates immediately with
  everything the runner produced. This is the normal way to start: run research in
  the terminal, then load its checkpoint here. (The browser cannot read the file
  off disk on its own, so you choose it explicitly — that act is itself a small
  gate: you decide which session to review.)
- **[Download ledger]** — writes the current in-memory ledger, including any
  changes you have made here (promotions, sign-offs, edits), back out as
  `research-ledger.json`. Drop it over the runner's file if you want your decisions
  persisted to disk. Nothing is saved automatically; this button is the save.
- **[Write article]** — generates a one-page article from your **published**
  claims (or, if you have not published anything yet, from your **findings**) and
  downloads it as `research-article.md`. It calls the synthesis model, so it costs
  tokens (visible on the meter) and shows "Writing article..." while it works. The
  article is grounded only in claims that cleared the gates; blocked and working
  claims are deliberately excluded. If nothing qualifies, it tells you so and does
  nothing.

### 2. Entry panel

For adding a claim by hand (independent of the runner).

- **New claim text...** — a text box for the claim wording.
- **species [dropdown]** — the claim's kind: `scientific`, `marketing`,
  `regulatory`, or `forecast`. This selects which domain gates will apply when the
  claim is later promoted.
- **[Add claim]** — adds the typed claim to the ledger as a new `lead`/`working`
  entry. Use this to introduce a claim the runner did not generate, or to seed a
  manual investigation.

### 3. Claims list

One row per claim. Each row shows, left to right:

- **Status badge** — the claim's state in the workflow:
  - `LEAD` / `WORKING` (amber) — not yet promotable, or blocked by the gates.
  - `FINDING` (green) — passed all deterministic gates; eligible to publish.
  - `PUBLISHED` (green) — signed off by a human.
- **Claim text** — the wording.
- **species** — the claim's kind (faint, right side).
- **judge: OK / DOUBT** — the rung-1 judge's verdict, present only on claims that
  passed the gates. Green "OK" = the judge found the sources support the claim;
  amber "DOUBT" = it did not. Hover for the judge's note. Advisory only: a DOUBT
  does not block anything.
- **advisor: OK / CONCERN** — the rung-2 advisor's verdict, present only when the
  advisor has been consulted (on judge doubt during the run, or when you click
  Publish). Hover for the note. Also advisory.

Click any row to select it and open it in the detail panel below.

### 4. Detail / editor panel

Opens when you select a row. Shows the full claim and lets you inspect and edit it.

**Read-outs (top):**

- **Claim text** — the full wording.
- **Blocked — gates not satisfied:** (red) — appears only when the claim is not a
  finding. Lists exactly which gates failed (e.g. "a scientific verdict needs a
  Tier-1 source", "needs 2 independent sources, has 1"). This is your repair
  checklist: it tells you precisely what is missing.
- **Judge: supported / DOUBT — <note>** — the rung-1 verdict in full, with the
  note. May add "wording mismatch" if the judge thought the claim overstated its
  evidence.
- **Advisor: supported / CONCERN — <note>** — the rung-2 verdict in full. If the
  advisor suggested better wording, a "suggested wording: ..." line appears beneath.
  Read this before signing off; it is a senior second opinion on a claim you are
  about to publish.

**Editable fields (the editor):**

- **species [current] [dropdown] [+ species]** — a claim can carry more than one
  species; add additional ones here. Gates fire per species (e.g. a claim that is
  both `marketing` and `regulatory` must satisfy both).
- **type [dropdown]** — the claim type (`disease`, `therapeutic`,
  `structure-function`, or none). Drives which evidence tier the gates demand.
- **causal [dropdown]** — the causal basis (`interventional`, `observational`,
  `mechanism`, `none`, `n/a`). A causal medical claim resting on merely
  observational evidence will be blocked.
- **risk [dropdown]** — risk grade (`LOW` / `MEDIUM` / `HIGH`), which sets the
  corroboration bar (how many independent sources are required).
- **predictions tested / harmful instruction [checkboxes]** — flags used by the
  gates (a forecast claim needs its predictions tested; a harmful-instruction claim
  is blocked outright).
- **reg status [text]** — regulatory status, required for a `regulatory` claim.
- **steelman [text area]** — the strongest opposing reading. The gates require a
  non-empty steelman before a claim can be promoted; this enforces that you have
  considered the other side.
- **sources** — the list of attached sources, each shown as `Tier N · origin`.
  Sources the runner verified (URL resolved) count toward the gates; unverified
  ones are recorded but do not count.
- **tier [dropdown] / origin / url [+ source]** — add a source by hand. Set its
  tier, an independence key (origin), and the URL, then **+ source**.
  *Sources you add here count as verified* — a human entering a source vouches for
  it. This is how you repair a claim the runner left blocked for lack of a
  qualifying source: add the authoritative one yourself, then promote.

**Action buttons (bottom):**

- **[Promote to finding]** — re-runs the deterministic gates against the claim as
  it now stands. If all gates pass, the status becomes `FINDING`; if not, it stays
  `WORKING` and the red "Blocked" list updates with the current reasons. Enabled
  only for claims that are not already findings/published. Use this after editing a
  claim or adding a source, to test whether it now clears.
- **[Publish (sign off)]** — enabled **only when the claim is a finding**. Clicking
  it first **consults the advisor** (rung 2): you will see "Consulting advisor..."
  and a short wait while a senior model gives final counsel, which then appears in
  the panel. Then a prompt asks for a sign-off name. Enter your name to publish
  (status becomes `PUBLISHED`); cancel or leave it blank to abort. If the advisor
  was already consulted on this exact claim and sources, its counsel is reused with
  no new call (and no wait). A failed advisor call does not block you — you can
  still sign off.

---

## Typical workflows

**Review a completed run.**
Choose file → `research-ledger.json` → scan the list. Findings are green with judge
(and possibly advisor) badges; working/blocked claims are amber. Click a finding,
read its judge/advisor counsel, click **Publish (sign off)**, read the advisor's
final word, enter your name. Repeat for each finding you endorse. Then **Write
article** for a one-page write-up of what you published, and **Download ledger** to
persist your decisions.

**Repair a blocked claim.**
Click the amber claim → read the red "Blocked" list. If it needs a qualifying
source, add it in the source row (it counts as verified). If it needs a steelman or
a corrected type/causal/risk value, edit those fields. Click **Promote to finding**.
If the gates now pass, it turns green and becomes publishable.

**Add your own claim.**
Type it in the entry panel, pick a species, **Add claim**. Fill in its fields and
sources in the editor, then **Promote to finding** and **Publish** as above.

---

## Things worth knowing

- **The gates are not negotiable here.** Promote always re-runs the full
  deterministic check; the panel will not let a claim become a finding unless it
  genuinely passes. The editor lets you supply what is missing, not bypass the bar.
- **Judge and advisor are advisory.** Their verdicts inform you; they never block a
  promotion or a publish. The decision is yours — that is the point of the form.
- **Console-added sources are trusted.** Unlike the runner's fetched sources, a
  source you type here is treated as verified, because you are vouching for it.
- **Nothing persists until you download.** The form edits an in-memory copy. Use
  **Download ledger** to write your changes back to the checkpoint file.
- **Two model-calling buttons cost tokens** — Publish (the advisor consult) and
  Write article (the synthesis). Both show progress in the status line and update
  the meter. Both fail soft if the proxy is unreachable.
- **After recompiling the form, hard-reload the browser** (Empty Cache and Hard
  Reload, or an incognito window) so you are running the new code, not a cached
  copy.
