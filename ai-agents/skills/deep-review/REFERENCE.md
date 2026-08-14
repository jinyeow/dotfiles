# Deep Review — Reference

## Scope resolution

Default: diff of the current branch against its merge-base with `main`.

```powershell
$base = git merge-base main HEAD   # base_sha — capture ONCE at run start
$head = git rev-parse HEAD         # head_sha
git --no-pager diff "$base...HEAD"
```

`git refs are the contract` — a PR is sugar that resolves to refs. Keep the resolver thin and outside
the review logic; on failure, surface the exact command + auth error, don't fall back silently.

### `--pr <n>` resolution

| Remote | Resolve to refs |
|---|---|
| GitHub | `gh pr diff <n>` for the diff; `gh pr view <n> --json baseRefName,headRefName` for refs |
| Azure DevOps | `az repos pr show --id <n>` → read `sourceRefName` / `targetRefName` → `git diff <target>...<source>` |

If neither CLI is available or authenticated, stop and report which is missing — do not guess the diff.

### Explicit ref / range

A bare arg is passed through as a git ref or range (e.g. `main...HEAD`, `<sha>..<sha>`). The
merge-base of the range is `base_sha`.

---

## Args

| Arg | Default | Meaning |
|---|---|---|
| `ref-or-range` | `main...HEAD` (merge-base) | git refs to review |
| `--pr <n>` | — | resolve a PR to refs (GitHub/ADO) |
| `--floor <sev>` | `MEDIUM` | severity floor for verify + reporting (not for what's stored) |
| `--reviewers <spec>` | skill defaults | reviewer models + effort ([`../_shared/reviewer-models.md`](../_shared/reviewer-models.md)); unsupported on Codex CLI |

`--floor` and `--reviewers` are scoping inputs (which findings are verified/reported, and which models
the reviewers run on), not logic switches. `--reviewers` unsupported on Codex CLI applies here too — if
the host runtime is Codex CLI and `--reviewers` was passed, stop and report an actionable error instead
of proceeding.

This scope + store reference is shared with [`quick-review`](../quick-review/SKILL.md), which resolves
refs, PRs, and the store identically.

---

## Reviewer dispatch

One isolated worker per enabled reviewer, launched together when parallel dispatch is available (see
[DISPATCH.md](DISPATCH.md) for per-runtime mechanics and per-dimension tool scoping). Each gets:

1. Its charter from [`../_shared/dimensions.md`](../_shared/dimensions.md).
2. The quality bar from [`../_shared/review-rubric.md`](../_shared/review-rubric.md).
3. The output schema from [`../_shared/findings-schema.md`](../_shared/findings-schema.md) — the
   worker returns findings as structured records; the orchestrator validates each against the schema
   before writing.

`codex` participates when an external Codex adapter is available (its MCP, on Claude Code — see
DISPATCH.md for other runtimes), as a full-rubric cross-model reviewer and a second voice in verify.
Record whether it ran in the snapshot's `reviewers_enabled`.

---

## Store

Per [`../_shared/findings-schema.md`](../_shared/findings-schema.md): central dir under the runtime's
own config home (`~/.claude/`, `~/.codex/`, or `~/.pi/`), one snapshot per session keyed by the frozen
`review_session_id = repo + base_sha + initial_head_sha + worktree-path`, current-session pointer per
repo. On resume, check `HEAD` against the latest ledger `head_sha`; HEAD advancing from the loop's own
commits is expected — only out-of-loop drift requires an explicit choice.
