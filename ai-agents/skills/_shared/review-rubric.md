# Review Rubric — AGENTS.md conformance + thermo-nuclear structural quality

The shared quality bar for `code-review`, and through the findings store for `fix-findings` and
`refine-until-ready`. Companion contracts: the lens registry and charters live in
[`lenses.md`](lenses.md); the finding record schema, fingerprint, origin and `fix_verification`
metadata, and store discipline live in [`findings-schema.md`](findings-schema.md). This file is the
bar and the severity rule. Those files map it onto lenses and a store.

Two layers:

- **Layer 1 is the floor** — conformance to the runtime's installed conventions file
  (`~/.claude/AGENTS.md` on Claude Code, `~/.codex/AGENTS.md` on Codex CLI — both sourced from
  this repo's `ai-agents/AGENTS.md`, per `codex/README.md`; on Pi, there is no installed home-dir
  copy, so it is the project's own root `AGENTS.md`, read directly, per this repo's root
  `AGENTS.md`). A change that violates it is a finding, full stop.
- **Layer 2 is ambition** — push for structural simplification, not just local cleanup.
  Adapted from Cursor's `thermo-nuclear-code-quality-review`.

Apply both to the diff under review. Default to **findings only** unless the skill says otherwise.

---

## Layer 1 — AGENTS.md conformance (the floor)

Check every change against the runtime's installed conventions file (see above). Flag where the
diff breaks these:

- **Surgical changes.** Lines that don't trace to the stated request. Unrelated refactors,
  reformatting, or "improvements" to untouched code. Deletion of unrelated dead code (note it,
  don't delete). Orphaned imports/vars/functions the change left behind.
- **Code style / over-engineering.** Speculative code or abstractions for single-use. Error
  handling for impossible scenarios. 200 lines that could be 50. Cleverness over readable, boring code.
- **Flag / mode parameters.** A new parameter that *switches logic* — presumptive block. AGENTS.md
  requires this be raised with the user, not silently added or silently contorted around. (An
  optional *output* side-channel param does not count.)
- **Strict typing.** `Any` / `unknown` / `List[Dict[str, Any]]` / loose dicts where a strict type
  or structured model fits. Missing return, variable, or collection types.
- **Error handling.** Silent ignores; catch-all handlers that hide the root cause; fallbacks not
  explicitly requested; missing path-exists validation before read; symptom fixes instead of root
  cause; external calls without retry-then-raise; log messages that interpolate dynamic values
  instead of using structured fields.
- **DRY.** Logic duplicated instead of reusing an existing helper that already does the job.
- **Imports.** Not all at the top of the file.
- **Linting.** A change that would fail the project linter. For PSScriptAnalyzer, the check must run
  `-Recurse` over the whole source tree with the project settings file (`-Settings
  .vscode/PSScriptAnalyzerSettings.psd1`) — CI does, so a per-file run can pass while CI fails. Never
  suppress a rule to make the check pass.
- **Documentation.** Behavior changed but the relevant docstring / README / CLAUDE.md not updated
  in the same change. Duplicated docs across files. Changelog-style docs instead of current-state.
- **Testing (TDD).** New code or bug fix without a test-first slice; a bug fix without a test that
  reproduces the bug. A test asserting on mock invocations (`Should -Invoke`, `toHaveBeenCalled`)
  where a result/state assertion would prove the behaviour; both returning a value from a mock and
  verifying its invocation for the same behaviour. Respect the repo's existing test strategy.

---

## Layer 2 — Thermo-nuclear structural quality (ambition)

Do not stop at "this could be a bit cleaner." Actively search for **code-judo** moves:
restructurings that preserve behavior while making the code dramatically simpler, smaller, and more
direct. Prefer deleting complexity over rearranging it.

1. **Be ambitious about structural simplification.** Look for reframings that make whole branches,
   helpers, modes, conditionals, or layers disappear. Prefer the solution that feels inevitable in
   hindsight. If you can delete complexity rather than move it, push hard for that.
2. **1000-line smell.** A diff that pushes a file from under 1k lines to over 1k is a strong smell.
   Ask whether it should be decomposed first (extract helpers, subcomponents, modules). Waive only
   with a compelling structural reason and a still-clearly-organized result.
3. **No spaghetti growth.** Be suspicious of new ad-hoc conditionals, scattered special cases, or
   one-off branches bolted into unrelated flows. Push the logic into a dedicated helper / state
   machine / policy object / module instead of tangling an existing path. A change that makes
   surrounding code harder to reason about is a design problem even if it works.
4. **Direct, boring, maintainable over magical.** Flag brittle / ad-hoc / "magic" behavior, generic
   mechanisms that hide simple data-shape assumptions, and thin wrappers / identity abstractions /
   pass-through helpers that add indirection without buying clarity.
5. **Type and boundary cleanliness.** Question unnecessary optionality, casts, `any`/`unknown`, or
   silent fallbacks that paper over an unclear invariant. Prefer explicit typed models / shared
   contracts and explicit boundaries. (Reinforces Layer 1 strict-typing.)
6. **Canonical layer + reuse.** Call out feature logic leaking into shared paths, implementation
   details leaking through APIs, and bespoke one-offs where a canonical utility already exists. Push
   code toward the package/module/layer that already owns the concept. *(Owned by the Architecture
   lens in `lenses.md`. The Standards lens reports it only when Architecture does not run.)*
7. **Atomicity and avoidable orchestration.** If independent work is serialized for no reason, ask
   whether it should run in parallel. If related updates can leave state half-applied, push for a
   more atomic structure. Don't over-index on micro-optimizations.

### Named smell baseline (Fowler, *Refactoring* ch.3)

A supplement to the code-judo moves above — named smells to match against the diff. Two rules bind
them: a **documented repo standard always overrides**, and each is a **judgement call** ("possible
Feature Envy"), never a hard violation. **Skip anything tooling already enforces.** *(Owned by the
Standards lens in `lenses.md`.)*

- **Mysterious Name** — a name that doesn't reveal what it does or holds → rename; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape in more than one hunk or file → extract it, call from both.
- **Feature Envy** — a method reaching into another object's data more than its own → move it onto the data it envies.
- **Data Clumps** — the same few fields or params always travelling together → bundle them into one type.
- **Primitive Obsession** — a primitive or string standing in for a domain concept → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on one type recurring across the change → polymorphism, or one shared map.
- **Shotgun Surgery** — one logical change forcing scattered edits across many files → gather what changes together.
- **Divergent Change** — one module edited for several unrelated reasons → split so each changes for one reason.
- **Speculative Generality** — abstraction, params, or hooks for needs the spec doesn't have → delete it, inline back.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on → hide the walk behind one method.
- **Middle Man** — a class or function that mostly just delegates onward → cut it, call the target direct.
- **Refused Bequest** — a subclass ignoring or overriding most of what it inherits → drop the inheritance, use composition.

---

## Severity: likelihood × impact

Rate every finding on two axes. Each axis is HIGH, MED or LOW.

Likelihood is how often the problem happens. For a security finding, likelihood is
exploitability.

| Likelihood | Meaning |
|---|---|
| HIGH | Happens in normal use. |
| MED | A plausible edge case, or a specific configuration. |
| LOW | Needs unusual conditions. |

Impact is how bad it is when it happens.

| Impact | Meaning |
|---|---|
| HIGH | Data loss, a security breach, an outage, silently wrong results, or a broken deploy. |
| MED | A degraded feature, a misleading error, or a maintainability cost that will bite soon. |
| LOW | Cosmetic, or a minor maintainability cost. |

Severity comes from the matrix. Read the likelihood row, then the impact column.

| Likelihood \ Impact | HIGH | MED | LOW |
|---|---|---|---|
| HIGH | HIGH | HIGH | MED |
| MED | HIGH | MED | LOW |
| LOW | MED | LOW | LOW |

A structural regression (a file pushed past 1k lines, spaghetti growth, a leaked boundary) costs
every later change, so its likelihood is HIGH.

### Blocking rule

Severity and blocking are separate. Only `introduced` findings block: a `pre-existing` finding
is reported separately and never blocks. An introduced finding blocks when one of these
criteria holds. Record the first that applies as its `blocking_criterion`:

| Criterion | Blocks when |
|---|---|
| `severity` | its severity is HIGH or MED. |
| `spec` | the change fails a requirement or acceptance criterion of the linked spec, issue or work item. With several, check against all of them. An `after merge` criterion never counts. With no spec, this criterion does not apply. |
| `convention` | it breaks a documented convention from a valid convention source (see `code-review` step 3) and the fix is quick: a lint, coding-standard or convention fix. The finding cites the source file and rule. A named smell is a judgement call and never meets this criterion. |
| `untested-logic` | it adds or changes production logic (a branch, a calculation, externally visible behaviour) and no test in the change exercises it. Exempt: config (pipeline triggers, conditions, parameters and job or stage wiring included), docs, generated code, string-only changes, and pure refactors that existing tests cover. |
| `mode-parameter` | it adds a flag or mode parameter that switches logic (AGENTS.md). It blocks until it is raised with the user. |

When none holds, the criterion is `none` and the finding is non-blocking, so a LOW finding can
still block and a MED finding always does. A blocking finding stops blocking when the user
explicitly accepts it as a documented trade-off.

Each confirmed, introduced finding gets one disposition:

- `blocking`: a blocking criterion holds.
- `note`: the finding is about documentation, a code comment, help text, or the PR description
  being inaccurate, incomplete or out of date. Its severity is always LOW and its criterion is
  always `none`, whatever the lens or validator rated it, and even when a convention covers it.
- `deferred`: every other non-blocking finding. In others' PR mode it can become a follow-up
  work item when the user asks.

---

## Do not flag

- Pre-existing issues outside the diff. Report them separately as `pre-existing`.
- Anything a linter, type-checker or test run already reports.
- Pedantry, and style points the repo does not document.
- Speculation about code the reviewer has not seen.
- Generic hygiene advice with no concrete trigger in the diff.

---

## Output discipline

- **High-conviction over nit-floods.** Prefer a small number of strong findings to a long list of
  cosmetic notes. Do not bury a structural regression under renames.
- **Each finding:** `file:line`, likelihood × impact, one-line rationale, and a concrete remedy (prefer
  "delete this layer" / "reframe so these branches disappear" over "maybe rename this").
- **Prioritize:** structural regressions → missed simplification (code-judo) → spaghetti/branching
  → boundary/type/contract → file-size/decomposition → modularity → legibility.
- **Tone.** Direct and demanding about quality; not rude. If a change makes the codebase messier,
  say so plainly. Don't soften a major maintainability issue into a mild suggestion.
- **Approval bar.** Not "it works." No structural regression, no obvious missed simplification, no
  unjustified file-size explosion, no spaghetti growth, no hacky/magical abstraction, no
  boundary leak or canonical-helper duplication.
