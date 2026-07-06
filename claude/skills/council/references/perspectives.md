# Council perspectives — registry + charters

The seat registry for the `council` skill. Each seat is dispatched as a parallel
`council-critic` subagent with its charter below pasted verbatim into the dispatch prompt.
Charters are data: to add a perspective, add a charter here and a row to the registry —
no agent file changes.

Every charter has four parts: **Mandate** (what this seat exists to protect), **Attack
questions** (the interrogation it runs), **Evidence** (what grounds a finding from this
seat), and **Not yours** (the lane boundary — where to point out-of-lane observations).

---

## Registry

| Panel | Seats (default) |
|---|---|
| `code` (technical designs, ADRs, API/approach docs — **not** branch diffs) | security, architecture, performance-scale, operability, compliance-privacy, simplicity, testability |
| `business` (ideas, product/business cases) | customer-market, unit-economics, competition-moat, go-to-market, legal-regulatory, execution, premortem |
| `plan` (project plans, roadmaps, migrations) | premortem, critical-path, estimation-realism, scope-sequencing, measurability, stakeholder-impact |
| `doc` (presentations, proposals, important docs) | audience-fit, narrative-logic, evidence-audit, clarity-structure, hostile-reader |
| cross-cutting (seatable on any panel via `+seat`) | contrarian, completeness |

Panel size discipline: default panels are ≤7 seats. Perspective **diversity** beats panel
size (identical-lens members add noise, not signal) — prefer swapping a seat over adding one.

---

## Panel: code

### security
- **Mandate:** the design must not widen attack surface or weaken a trust boundary.
- **Attack questions:** Where does untrusted input cross a boundary, and what validates it there? What new secrets/credentials exist, where do they live, and who can read them? What can an authenticated-but-malicious caller do that the author didn't intend? What's the blast radius when this component is compromised? Does any auth/authz decision happen client-side or rely on obscurity?
- **Evidence:** a named attack path (actor → entry → effect); quote the design section that enables it. Cite repo config (file:line) or an external reference (CWE, cloud docs) where it strengthens the claim.
- **Not yours:** regulatory duty (compliance-privacy), availability under load (operability).

### architecture
- **Mandate:** the design must fit the system it lands in and stay evolvable.
- **Attack questions:** Which existing component already owns this concept, and why is that not being extended? What dependency direction does this introduce — does anything low-level now know about something high-level? What breaks the day the requirements double (tenants, regions, teams)? What's the migration/coexistence story with what exists today? Which interface here will be hardest to change once consumers exist?
- **Evidence:** name the real modules/systems affected (file paths where the repo is available); a concrete coupling or ownership violation, not "feels wrong".
- **Not yours:** raw throughput/latency (performance-scale), whether it's over-built (simplicity).

### performance-scale
- **Mandate:** the design must survive its stated load — and its plausible load.
- **Attack questions:** What's the hot path and what does one request cost there (I/O count, fan-out, serialization)? Where's the N+1 or unbounded collection hiding? What's the biggest input this will realistically see, and what happens at 10×? Which resource saturates first (connections, memory, queue depth, rate limits)? What work is serialized that could be independent?
- **Evidence:** arithmetic — counts × costs with stated assumptions; label estimates as estimates. Quote the design's own numbers where they exist and attack them where they don't.
- **Not yours:** operational recovery (operability), architectural coupling (architecture).

### operability
- **Mandate:** the thing must be runnable at 3am by someone who didn't build it.
- **Attack questions:** What are the failure modes, and what does each look like from the outside (alert? silent corruption?)? How does it roll out — and roll *back*, including data/schema changes? What's observable: can you tell it's working, degrading, or lying? What does the on-call runbook step look like for its most likely failure? What limits/timeouts/retries protect its dependencies — and its dependents from it?
- **Evidence:** a named failure scenario with the detection + recovery gap spelled out.
- **Not yours:** attack scenarios (security), long-term fit (architecture).

### compliance-privacy
- **Mandate:** the design must be defensible to a regulator and honest with people's data.
- **Attack questions:** What personal or sensitive data does this touch — collected, stored, moved, or inferred? Where does data cross a jurisdiction or a third-party boundary? What's the retention/deletion story, and can a deletion request actually be honoured? Who can access what, and is that access logged well enough to answer "who saw this record"? Does this create an outsourcing/material-service-provider dependency that needs assessment? (For AU financial-services artifacts, read through APRA CPS 230/234 and Privacy Act/APPs lenses.)
- **Evidence:** name the data class and the obligation it triggers; cite the regulation/standard clause when making a regulatory claim (search if unsure — say "unknown" over guessing).
- **Not yours:** technical exploitability (security), commercial legal terms (legal-regulatory on the business panel).

### simplicity
- **Mandate:** the design must be the smallest thing that solves the stated problem.
- **Attack questions:** Which requirement justifies each moving part — and which parts have no requirement behind them? What's speculative ("we might need") versus needed now? Could a boring, existing tool do this (a cron, a table, a queue you already run)? What would the half-size version look like, and what exactly is lost? Which abstraction here has only one consumer?
- **Evidence:** map each component to the requirement it serves; components with no mapping are the finding.
- **Not yours:** whether the simple version scales (performance-scale) or fits (architecture) — flag the tension, let the chair weigh it.

### testability
- **Mandate:** the design must be verifiable before and after it ships.
- **Attack questions:** For each behaviour the design promises, what test could prove it — and at which level (unit/integration/e2e)? What can only be validated in production, and is that acceptable? Where are the seams for substituting the expensive/external parts? What's the definition of done — measurable, or vibes? How will a regression in this be caught six months from now?
- **Evidence:** name the promised behaviour and the concrete missing seam or unverifiable claim.
- **Not yours:** operational observability (operability) — you own pre-ship verification.

---

## Panel: business

### customer-market
- **Mandate:** a real customer with a real problem must exist and be reachable.
- **Attack questions:** Who exactly has this problem, and what are they doing about it today? What's the evidence anyone will *pay* — not nod politely? What job is being done, and is it top-3 painful for them or a vitamin? How many of these customers exist (bottom-up, not TAM-slide math)? Why do the losers who tried this before lose?
- **Evidence:** named customer segments and observed behaviour; cite sources for market claims (search); label anecdotes as anecdotes.
- **Not yours:** whether the numbers work (unit-economics), how to reach them (go-to-market).

### unit-economics
- **Mandate:** each unit sold must eventually make money, and the math must be shown.
- **Attack questions:** What's the unit, its price, its marginal cost — and the contribution margin left over? What does acquiring one customer cost, and how many months of margin repay it? Which cost scales linearly with usage that the plan assumes stays flat? What's the payback under pessimistic (not median) assumptions? Where's the working-capital trap?
- **Evidence:** arithmetic with stated assumptions; recompute the artifact's own numbers and report where they don't reproduce.
- **Not yours:** demand existence (customer-market), funding strategy (execution).

### competition-moat
- **Mandate:** the idea must survive competent, funded imitation.
- **Attack questions:** Who does this today (search — name them), and what's genuinely different here? What happens when the incumbent bundles a good-enough version for free? What compounds with time or scale (data, network, switching costs) — and what's just a head start? What's the substitute customers actually compare against (often "do nothing")?
- **Evidence:** named competitors/substitutes with citations; "no competitors" is a finding against the idea (usually means no market), not for it.
- **Not yours:** pricing mechanics (unit-economics).

### go-to-market
- **Mandate:** there must be a repeatable, affordable path to the customer.
- **Attack questions:** What's the first channel, and why will it work for *this* buyer? Who decides, who pays, who uses — and who blocks (procurement, security review, IT)? What's the realistic sales cycle, and can the runway survive it? What does the 10th sale look like versus the 1st (founder magic doesn't scale)? What's the wedge — the small, urgent entry point — versus the platform dream?
- **Evidence:** channel economics or comparable-company motion, cited; buyer-role mapping for B2B.
- **Not yours:** CAC math details (unit-economics), product-market fit evidence (customer-market).

### legal-regulatory
- **Mandate:** the idea must be legal to operate and not build on borrowed permission.
- **Attack questions:** What licence, registration, or regulated status does operating this require, where? Whose data/content/API does this depend on, and what happens when terms change? What liability lands on us when the product is wrong or misused? Which jurisdiction's rules bite first (privacy, consumer, financial services)? What contractual promises (SLAs, indemnities) will enterprise buyers force?
- **Evidence:** cite the regulation/licence regime by name (search; "needs counsel" is a valid finding — dressed-up guessing is not).
- **Not yours:** data-handling design details (compliance-privacy on the code panel).

### execution
- **Mandate:** this team, with these resources, must actually be able to build and run it.
- **Attack questions:** What's the hardest thing this requires that the team hasn't done before? What must be true operationally at 100 customers that's hand-waved today (support, onboarding, trust & safety)? What are the 2–3 hires without which this stalls, and how findable are they? What dependency (partner, platform, key person) is a single point of failure? What's the honest time-to-first-revenue?
- **Evidence:** map claims to demonstrated capability; name the gap, not vibes about the team.
- **Not yours:** whether the market wants it (customer-market).

### premortem
- **Mandate:** assume it's 18 months later and this failed — explain why, convincingly.
- **Attack questions:** Write the 3 most probable failure narratives (not the most dramatic). Which shared assumption, if wrong, kills every version of the plan? What early signal would each failure emit, and would anyone be watching for it? What's the reversibility story — how much is lost if we stop at month 6? Which failure mode is nobody in the artifact even acknowledging?
- **Evidence:** each narrative must trace to a specific assumption in the artifact (quote it).
- **Not yours:** you don't propose fixes — you make failure vivid; mitigation is the author's job.

---

## Panel: plan

### premortem
Same charter as the business-panel premortem, aimed at the plan: three probable failure
narratives, the shared kill-assumption, early signals, reversibility, the unacknowledged
failure mode. Quote the plan.

### critical-path
- **Mandate:** the dependency structure must be explicit and survivable.
- **Attack questions:** What's the true critical path, and does the plan know it? Which tasks are secretly serialized (shared person, shared environment, approval gate) that the plan shows as parallel? Which external dependency (team, vendor, access request) has a lead time nobody started? What slips when the longest task doubles — and what's the plan's actual buffer? Where's the integration crunch hiding (usually "week before launch")?
- **Evidence:** reconstruct the dependency chain from the plan's own items; name the edge the plan is missing.
- **Not yours:** whether estimates are honest (estimation-realism).

### estimation-realism
- **Mandate:** the numbers must reflect how long things actually take here.
- **Attack questions:** Which estimates have reference-class evidence (last time we did X it took Y) versus optimism? Where is the plan assuming 100% allocation of people who are 60% allocated? What's estimated at the task level but missing at the plan level (review cycles, environments, sign-offs, holidays)? Which single estimate, if 3× wrong, breaks the date? Does anything here have the shape of "90% done" work — long tail, unclear done?
- **Evidence:** comparable past work when known; otherwise flag the estimate as evidence-free (that's the finding).
- **Not yours:** ordering (critical-path), whether the scope is right (scope-sequencing).

### scope-sequencing
- **Mandate:** the plan must ship value early and cut cleanly under pressure.
- **Attack questions:** What's the smallest slice that's independently valuable, and why isn't it first? When (not if) time runs out at 60%, what got delivered — anything? Which items are must/should/could, and does the sequence match that or match interest? What's being built before it's needed? Where does a dependency force big-bang delivery, and is that forced or chosen?
- **Evidence:** re-order the plan's own items to show a better cut-line exists (or confirm there isn't one).
- **Not yours:** task duration honesty (estimation-realism).

### measurability
- **Mandate:** "done" and "working" must be checkable by someone outside the team.
- **Attack questions:** What's the observable success criterion for the plan overall — number, date, behaviour? Which milestones are verifiable events versus activities ("engage stakeholders")? What's the leading indicator that it's off-track by week 2, not month 3? Who reviews progress, against what, how often? If this succeeds, what changed that a sceptic could measure?
- **Evidence:** quote each unverifiable milestone; propose the checkable form it should take.
- **Not yours:** whether the milestones are the right ones (scope-sequencing).

### stakeholder-impact
- **Mandate:** everyone the plan needs, blocks, or breaks must be accounted for.
- **Attack questions:** Whose approval/capacity does this need who hasn't agreed yet? Who is disrupted by the change (workflow, ownership, headcount) and what's their incentive to resist? What communication is load-bearing (users, customers, regulators) and where is it in the plan? Who owns the thing after the project ends? Which stakeholder does the plan model as cooperative who historically isn't?
- **Evidence:** name roles/teams (or note the plan doesn't); trace each dependency-on-a-person to an actual commitment.
- **Not yours:** schedule mechanics (critical-path).

---

## Panel: doc

### audience-fit
- **Mandate:** the document must work for its actual readers, not its author.
- **Attack questions:** Who is the primary reader, what do they already know, and what do they need to decide? What does the reader need in the first 30 seconds that's currently on page 4? Which sections serve the author's process rather than the reader's decision? What jargon/context is assumed that the named audience won't have? What will a skimming executive take away — is that the intended message?
- **Evidence:** quote the passages; state the mismatch against the named audience (if no audience is named, that's finding #1).
- **Not yours:** whether the argument is valid (narrative-logic).

### narrative-logic
- **Mandate:** the argument must actually follow — each conclusion supported, each step connected.
- **Attack questions:** What's the one-sentence claim of the doc, and does every section serve it? Where does a conclusion appear that no prior section established? Which "therefore" is really an "and then"? What's the strongest counter-argument, and does the doc engage it or hope? Does the structure lead with the answer (pyramid) or make the reader excavate it?
- **Evidence:** reconstruct the argument as premises → conclusion; show the broken link.
- **Not yours:** the truth of individual factual claims (evidence-audit).

### evidence-audit
- **Mandate:** every load-bearing claim must be sourced, current, and honestly framed.
- **Attack questions:** Which claims are load-bearing, and what's the source for each? Which numbers have no origin, stale origins, or origins that don't say what's claimed? Where are error bars/confidence hidden ("up to", "as much as")? What contrary evidence exists that the doc omits (search)? Which chart's framing (axis, baseline, cherry-picked window) flatters the argument?
- **Evidence:** per claim — the citation given (or its absence) and what checking it revealed; cite your own sources.
- **Not yours:** whether the argument structure holds (narrative-logic).

### clarity-structure
- **Mandate:** a busy reader must be able to navigate, absorb, and quote it.
- **Attack questions:** Can each section's point be gotten from its heading + first sentence? Where does one paragraph do three jobs? What's the reading burden (length, density, walls of prose) versus the decision's weight? Which tables/figures would replace paragraphs of prose — and which decorative ones should die? Is there a summary that actually summarizes (decisions + asks, not topics)?
- **Evidence:** quote the worst offenders; show the tightened rewrite for one of them (one, not all — you critique, not copy-edit).
- **Not yours:** content selection for the audience (audience-fit).

### hostile-reader
- **Mandate:** the document must survive the least charitable person in the room.
- **Attack questions:** What will the sceptic seize on first — the weakest claim stated most confidently? Which sentence, quoted out of context, is damaging? What question will be asked in the meeting that the doc leaves unanswered? Where does the doc overclaim ("will" where "should" is honest) or hedge where it must commit? What's the political reading — who looks bad, and did the author notice?
- **Evidence:** the quotable line + the attack it invites, verbatim.
- **Not yours:** general clarity (clarity-structure) — you simulate the adversarial reading only.

---

## Cross-cutting seats

### contrarian
- **Mandate:** argue the premise itself is wrong — the strongest good-faith case for *not doing this at all*.
- **Attack questions:** What problem does this claim to solve, and what's the case that the problem is misdiagnosed or not worth solving? What's the do-nothing baseline actually like? What would the smartest person who opposes this say? Which sacred assumption does everyone on the council share that deserves attack? What's the alternative that makes this whole framing obsolete?
- **Evidence:** the case must be arguable from the artifact and real-world evidence — a position, not a mood.
- **Not yours:** in-frame improvement suggestions; you attack the frame.

### completeness
- **Mandate:** find what isn't there — the missing section, scenario, or stakeholder.
- **Attack questions:** What would a standard treatment of this artifact type contain that this one lacks? Which obvious scenario/edge case has no mention (not a bad answer — *no* answer)? Who/what is affected but absent? What question would a domain expert ask first that the artifact can't answer? What's conspicuously unquantified?
- **Evidence:** name the gap and why it's load-bearing for this artifact; not a wishlist — each gap must matter to the decision.
- **Not yours:** judging the quality of what *is* present (the rest of the panel owns that).
