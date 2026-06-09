# Review Rubric — AGENTS.md conformance + thermo-nuclear structural quality

The shared rubric for both review skills (`codex-review`, `review-fix-loop`). Two layers:

- **Layer 1 is the floor** — conformance to `~/.claude/AGENTS.md`. A change that violates it
  is a finding, full stop.
- **Layer 2 is ambition** — push for structural simplification, not just local cleanup.
  Adapted from Cursor's `thermo-nuclear-code-quality-review`.

Apply both to the diff under review. Default to **findings only** unless the skill says otherwise.

---

## Layer 1 — AGENTS.md conformance (the floor)

Check every change against `~/.claude/AGENTS.md`. Flag where the diff breaks these:

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
  reproduces the bug. Respect the repo's existing test strategy.

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
   code toward the package/module/layer that already owns the concept.
7. **Atomicity and avoidable orchestration.** If independent work is serialized for no reason, ask
   whether it should run in parallel. If related updates can leave state half-applied, push for a
   more atomic structure. Don't over-index on micro-optimizations.

---

## Severity scale

Canonical 5-level scale. `codex-review` collapses to three buckets for its output
(CRITICAL+HIGH → **HIGH**, MEDIUM → **MEDIUM**, LOW+CLEANUP → **LOW**).

| Level | Meaning |
|---|---|
| CRITICAL | Silent data loss, unhandled termination, security (secret exposure, injection). |
| HIGH | Incorrect output, race, infinite loop, **structural regression** (1k-line explosion, spaghetti growth, leaked-boundary feature logic). |
| MEDIUM | Latent correctness bug, missing escape, wrong type, unjustified abstraction/wrapper, missing test. |
| LOW | Wrong diagnostic message, observability gap, missed decomposition opportunity. |
| CLEANUP | Duplication, dead code, style — no correctness impact. |

A flag/mode parameter that switches logic (AGENTS.md) is a **presumptive block** regardless of level
until raised with the user.

---

## Output discipline

- **High-conviction over nit-floods.** Prefer a small number of strong findings to a long list of
  cosmetic notes. Do not bury a structural regression under renames.
- **Each finding:** `file:line`, severity, one-line rationale, and a concrete remedy (prefer
  "delete this layer" / "reframe so these branches disappear" over "maybe rename this").
- **Prioritize:** structural regressions → missed simplification (code-judo) → spaghetti/branching
  → boundary/type/contract → file-size/decomposition → modularity → legibility.
- **Tone.** Direct and demanding about quality; not rude. If a change makes the codebase messier,
  say so plainly. Don't soften a major maintainability issue into a mild suggestion.
- **Approval bar.** Not "it works." No structural regression, no obvious missed simplification, no
  unjustified file-size explosion, no spaghetti growth, no hacky/magical abstraction, no
  boundary leak or canonical-helper duplication.
