# Reviewer models — the `--reviewers` contract

Shared by the review skills (`quick-review`, `deep-review`, and via the loop, `review-fix-loop`).
It defines one thing: how the `--reviewers` argument resolves to real dispatch parameters.

**Scope note:** this file's alias table and call shapes describe Claude Code's subagent model
aliases and its `mcp__codex__codex` MCP tool — the only two dispatch surfaces this contract
currently covers. It lives under the portable `_shared/` alongside the runtime-neutral
`dimensions.md` / `findings-schema.md` / `review-rubric.md` because the skills that reference it
are portable, but its own content is not yet genericized for Pi — on that runtime, `--reviewers`
selects models through the runtime's own defaults, not this table, until a Pi-native equivalent is
written. **On Codex CLI**, `--reviewers` is unsupported, not a documented no-op: `spawn_agent`'s
confirmed parameters are `agent_type` and the task only (live-tested against codex-cli 0.147.0,
[`../deep-review/DISPATCH.md`](../deep-review/DISPATCH.md)) — there is no per-call model field.
The only settable knobs are Codex's global `agents.default_subagent_model` /
`agents.default_subagent_reasoning_effort`, which are session-wide, not per-invocation — wiring
`--reviewers` to them was rejected because it would mutate model selection for every subsequently
spawned subagent in that Codex session, not just the review participants
(`docs/adr/reviewers-flag-unsupported-on-codex-cli.md`).
When the host runtime is Codex CLI and `--reviewers` is passed, the orchestrating skill must
refuse it with an actionable error rather than silently falling back to defaults. The `sol` /
`codex` external-adapter rows stay Claude-only — Codex CLI has no external Codex adapter to call
when it is itself the host
([`../deep-review/DISPATCH.md`](../deep-review/DISPATCH.md)).

**Reviewer-only.** `--reviewers` selects the models for reviewer subagents — the fan-out participants,
nothing else. It does not select verifier models, and it never touches fixer model selection — see
"Fixer pin" below for that policy. A `--reviewers` value is not a licence to dispatch a fixer on it.

## Grammar

```
--reviewers <model>[,<model>...][:<effort>]
```

- The comma list names the models the reviewer set runs on. Omitting the flag keeps each skill's
  documented default. It selects **models, not participant count** — how a list maps onto a skill's
  reviewers is that skill's business (`quick-review` keeps two participants and rejects a list that
  would add a third; `deep-review` spreads the list round-robin, in listed order, across its seven
  dimensions in the registry order of `dimensions.md`). A repeated alias is harmless; if more than one
  Codex alias appears (`sol`, `codex`), the **last one listed** wins for Codex.
- The optional `:<effort>` trails the **whole** list (`fable,sol:high`) and applies to every listed
  model whose runtime accepts an effort setting. Values: `low`, `medium`, `high`.

## Alias resolution

| Alias | Resolves to | Dispatched as |
|---|---|---|
| `opus` / `sonnet` / `haiku` / `fable` | the Claude Code subagent model aliases | subagent dispatch, `model: <alias>` |
| `sol` | `gpt-5.6-sol` (the Codex model pinned in the dotfiles repo's `codex/config.toml`) | `mcp__codex__codex`, `model: gpt-5.6-sol` |
| `codex` | the Codex MCP server's own configured model | `mcp__codex__codex`, `model` omitted |

An alias not in this table is an error — say which aliases exist and stop; never silently substitute a
model the user did not ask for.

## Fixer pin

This is the single home for fixer-subagent model selection. It applies to `fix-findings` and
`review-fix-loop`'s fixer children, and to any other seat whose child applies and commits code
rather than just reviewing (for example a council seat asked to implement, not just critique).

- Default: **Sonnet 5** (`sonnet`). **Haiku 4.5** (`haiku`) is fine for a fully specified
  single-hunk edit. Never `fable`.
- The intended Opus tier is **Opus 4.8**, never Opus 5, for now. No per-call mechanism dispatches
  that specific build today: the `Agent` tool's `model` param takes only the aliases in the table
  above, and the bare `opus` alias resolves to the current default Opus, Opus 5 today, which this
  pin excludes. Do not dispatch a fixer on `opus`. Use Sonnet 5, or ask which Opus build is meant
  before dispatching one.
- The same alias limit applies to any other seat that wants Opus 4.8 by name, including a council
  reviewer seat: `opus` names whichever Opus build Claude Code currently defaults to, and that
  default moves between releases without guaranteeing a specific point build. Treat any "Opus 4.8"
  reference for such a seat as this same constraint rather than a separate capability.

## Effort

- **Claude subagents have no effort parameter** in this harness — subagent dispatch takes `model` only.
  An effort suffix is therefore recorded but not applied to them; say so once rather than inventing a
  field.
- **Codex** takes it as a config override on the call:
  `config: { model_reasoning_effort: "<effort>" }`. Without the suffix, the MCP registration's pinned
  `medium` applies.

## Codex call shape

Every Codex call from a review skill passes the read-only posture explicitly, as defence in depth over
the MCP registration's `-c sandbox_mode=read-only -c approval_policy=never` (`setup.ps1`):

```
mcp__codex__codex
  approval-policy: never
  sandbox: read-only
  model: gpt-5.6-sol            # only when --reviewers named a Codex model
  config: { model_reasoning_effort: "high" }   # only when an effort suffix was given
  prompt: <charter + rubric + diff>
```

Note the spelling split: the tool's own parameters are hyphenated (`approval-policy`, `sandbox`);
config keys are underscored (`model_reasoning_effort`). The `-c sandbox_mode=…` form belongs to the
server registration, not to a call.

## Recording

Whatever the flag resolves to goes into the snapshot's `reviewers_enabled`
([`findings-schema.md`](findings-schema.md)) alongside the participant set, so a resumed run reproduces
the same reviewers instead of silently reverting to the defaults.
