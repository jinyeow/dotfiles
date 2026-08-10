# Reviewer models — the `--reviewers` contract

Shared by the review skills (`quick-review`, `deep-review`, and via the loop, `review-fix-loop`).
It defines one thing: how the `--reviewers` argument resolves to real dispatch parameters.

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
