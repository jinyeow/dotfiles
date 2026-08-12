# Reviewer models — the `--reviewers` contract

Shared by the review skills (`quick-review`, `deep-review`, and via the loop, `review-fix-loop`).
It defines one thing: how the `--reviewers` argument resolves to real dispatch parameters.

**Scope note:** this file's alias table and call shapes describe Claude Code's subagent model
aliases and its `mcp__codex__codex` MCP tool — the only two dispatch surfaces this contract
currently covers. It lives under the portable `_shared/` alongside the runtime-neutral
`dimensions.md` / `findings-schema.md` / `review-rubric.md` because the skills that reference it
are portable, but its own content is not yet genericized for Pi — on that runtime, `--reviewers`
selects models through the runtime's own defaults, not this table, until a Pi-native equivalent is
written. **On Codex CLI**, `--reviewers` currently has no wired resolution: Codex's own config
schema (`AgentsToml`, as of `rust-v0.147.0`) defines `agents.default_subagent_model` and
`agents.default_subagent_reasoning_effort` as a global default-model/effort pair — the fields
exist — but this repo's `codex/config.toml` doesn't set them, and nothing in these skills maps a
`--reviewers` value onto them; it only defines per-role `[agents.<name>]` tables (e.g.
`agents.review_correctness`), which at this version recognize just `config_file` / `description` /
`nickname_candidates`, not a model override. Passing `--reviewers` on Codex CLI therefore falls
back to whatever model/effort each agent's own `developer_instructions` and Codex's global
defaults resolve to — the same as if the flag were never passed. Wiring `--reviewers` through
`agents.default_subagent_model` / `agents.default_subagent_reasoning_effort` is the natural future
mechanism — available but unwired today, not nonexistent. The `sol` / `codex` external-adapter rows stay Claude-only —
Codex CLI has no external Codex adapter to call when it is itself the host
([`../deep-review/DISPATCH.md`](../deep-review/DISPATCH.md)).

**Reviewer-only.** `--reviewers` selects the models for reviewer subagents — the fan-out participants,
nothing else. It does not select verifier models, and it never
touches fixer model selection — `fix-findings` fixers stay pinned by their own skill (Opus 4.8/4.7/4.6
or Sonnet 5 or lower; never Opus 5, never Fable). A `--reviewers` value is not a licence to dispatch a
fixer on it.

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
