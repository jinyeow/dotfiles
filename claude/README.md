# claude

Config for [Claude Code](https://claude.ai/code).

## Binary install method

Install the Claude Code CLI with the **native installer** (`irm
https://claude.ai/install.ps1 | iex` on Windows → `~\.local\bin\claude.exe`),
**not** via Volta/npm-global. A Volta-managed npm-global install conflicts with
Claude Code's own background auto-updater: both mutate the same install, leaving
the PATH shim out of sync with Volta's package dir and printing `'"...\bin\
claude.exe"' is not recognized as an internal or external command` mid-update
(the updater shells through Volta's `claude.cmd` while the 240 MB exe is being
swapped). The native install self-updates cleanly with no Volta in the loop.
Verify with `claude doctor` (install method = native) and `Get-Command claude`
(resolves to `~\.local\bin`, no Volta entries). This repo only tracks the
*config* under `~/.claude`, not the binary.

## Files

| File / Directory | Installed to | Notes |
|---|---|---|
| `settings.json` | `~/.claude/settings.json` | Theme, effort level, editor mode, hooks, statusline, pins `model: "claude-opus-5"` |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude-specific instructions; imports `AGENTS.md` via `@AGENTS.md` |
| `AGENTS.md` | `~/.claude/AGENTS.md` | Shared coding conventions (single source). The `codex` module installs the same file to `~/.codex/AGENTS.md` so Claude Code and Codex CLI agree. See `../codex/README.md`. |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Token usage statusline script |
| `no-claude-session-trailer.sh` | `~/.claude/no-claude-session-trailer.sh` | PreToolUse hook (wired in `settings.json`) that blocks commits carrying the AI session-URL trailer |
| `inject-handoff.ps1` | `~/.claude/inject-handoff.ps1` | SessionStart hook that injects `.claude/handoff.md` (from the `handoff` skill) into a fresh session |
| `block-destructive-vcs.ps1` | `~/.claude/block-destructive-vcs.ps1` | PreToolUse(Bash\|PowerShell) hook that denies destructive git (`push --force`, `reset --hard`, `clean -f`, `branch -D`) |
| `block-pwsh-in-bash.ps1` | `~/.claude/block-pwsh-in-bash.ps1` | PreToolUse(Bash) hook that denies PowerShell mis-sent to the Bash tool, pointing at the PowerShell tool |
| `lint-powershell.ps1` | `~/.claude/lint-powershell.ps1` | PostToolUse(Edit\|Write) hook that runs PSScriptAnalyzer on edited `.ps1/.psm1/.psd1` and feeds findings back |
| `warn-legacy-files.ps1` | `~/.claude/warn-legacy-files.ps1` | PreToolUse(Edit\|Write) hook that asks to confirm before editing legacy/do-not-touch dotfiles (scoped to `$env:DOTFILES`) |
| `warn-hardcoded-secrets.ps1` | `~/.claude/warn-hardcoded-secrets.ps1` | PostToolUse(Edit\|Write) hook that warns when written content looks like a hardcoded secret |
| `warn-reasoning-extraction.ps1` | `~/.claude/warn-reasoning-extraction.ps1` | UserPromptSubmit + PreToolUse(Edit\|Write) hook that flags reasoning-extraction phrasing that trips Fable-5's `reasoning_extraction` → Opus fallback |
| `ai-agents/shared/skills/<name>/` or `ai-agents/claude/skills/<name>/` | `~/.claude/skills/<name>/` | Portable and Claude-only custom skills (only portable skills are also projected into Codex) |
| `ai-agents/shared/agents/<name>.md` | `~/.claude/agents/<name>.md` | User-scope subagents (whole dir junctioned/symlinked) |
| `output-styles/<name>.md` | `~/.claude/output-styles/<name>.md` | Output styles (whole dir junctioned); active style pinned by `outputStyle` in `settings.json` |

**Install method.** `settings.json`, `CLAUDE.md`, `AGENTS.md`,
`statusline-command.sh`, `no-claude-session-trailer.sh`, and the seven pwsh hook scripts
(`inject-handoff.ps1`, `block-destructive-vcs.ps1`, `block-pwsh-in-bash.ps1`, `lint-powershell.ps1`,
`warn-legacy-files.ps1`, `warn-hardcoded-secrets.ps1`, `warn-reasoning-extraction.ps1`) are
**symlinked** into `~/.claude`, and each skill directory is
**junctioned** (Windows) / symlinked (Linux). Windows file symlinks require **Developer
Mode** (Settings → For developers) — junctions don't need it but can't link files. Because
the live files are links to the repo, edits flow both ways and there is **no drift**: Claude
Code writing `settings.json`, or `/memory` appending to `CLAUDE.md`, updates the repo file
directly. Just `git diff` / commit when you want to capture the changes. (This replaces the
old copy-based install + planned live→repo sync.)

## Settings

| Setting | Value | Notes |
|---|---|---|
| `effortLevel` | `medium` | Default thinking effort |
| `outputStyle` | `concise` | Custom style from `output-styles/concise.md` — enforces the AGENTS.md output contract (lead with the answer, no sycophancy/filler, terse mid-turn, self-contained fixed-header wrap-up) at system-prompt level, which is a stronger lever than CLAUDE.md-imported instructions alone. `keep-coding-instructions: true` keeps the default coding behaviour |
| `theme` | `dark-ansi` | Palette-based dark theme — readable under Zellij on Windows Terminal, where `auto` + truecolor diff backgrounds collapse into the pane (see `docs/zellij-windows-terminal-colors.md`) |
| `editorMode` | `vim` | Vim keybindings in the prompt input |
| `defaultShell` | `powershell` | Shell for the input-box **`!` bang** commands. `powershell` → **pwsh 7** (Claude Code auto-detects `pwsh.exe`, falling back to `powershell.exe` 5.1 only if absent), matching this repo's pwsh-native posture. The Claude Code default is `bash` on every platform (no Windows auto-flip), which is why `!` ran bash before. No per-command override exists — `!` always uses this shell, so run a one-off bash line via `! bash -c '…'` |
| `agentPushNotifEnabled` | `true` | Mobile push notifications (cloud/background agents — not local CLI) |
| `teammateMode` | `in-process` | How spawned **teammates** execute (`auto`/`tmux`/`iterm2`/`in-process`). Pinned to `in-process` so agent teams run inline and spawn **no panes**. At `auto`, Claude's backend detection sees `$TMUX` (psmux sets it) and picks the tmux backend, which emits a hardcoded POSIX launch line (`cd . && env VAR=x 'path/to/claude' .`) that is invalid in a pwsh pane — panes open to a bare prompt and the fan-out silently does nothing ([#42848](https://github.com/anthropics/claude-code/issues/42848); psmux-as-a-backend [#34150](https://github.com/anthropics/claude-code/issues/34150) is closed/not-planned). Revisit if upstream ships a shell-aware launch formatter. Note: this pin is global, so it also disables *working* bash panes under real tmux on Linux — move it to an untracked `settings.local.json` if that becomes a problem. Ordinary **subagents** (Agent/Task tool) are unaffected — they always ran in-process |
| `preferredNotifChannel` | `terminal_bell` | Built-in bell on the **needs-input** notification → marks the Zellij tab |
| `hooks` | SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop, Notification | SessionStart: injects a pending `.claude/handoff.md`. UserPromptSubmit: warns on reasoning-extraction phrasing (Fable-5 fallback). PreToolUse: blocks the AI session-URL commit trailer, denies destructive git, denies PowerShell mis-sent to the Bash tool, asks to confirm edits to legacy dotfiles, and asks before writing a reasoning-extraction phrase into config. PostToolUse: PSScriptAnalyzer lint-on-edit and hardcoded-secret warn. Stop/Notification: local completion alert — see Hooks and Notifications |
| `statusLine` | command | Runs `statusline-command.sh` |

## Hooks

Beyond the notification beeps, `settings.json` wires a handoff injector, deterministic
guardrails, and a lint pass. The seven pwsh hooks read the hook JSON on stdin and are invoked
through `bash` (so `~` expands) as `pwsh -NoProfile -File ~/.claude/<script>.ps1`; they need
**pwsh** on PATH, and the lint hook additionally needs the **PSScriptAnalyzer** module (it
self-skips if absent). All allow silently and only emit JSON when they act.

| Event / matcher | Script | Behaviour |
|---|---|---|
| `SessionStart` | `inject-handoff.ps1` | On a fresh session (`startup`/`clear`), injects the workspace's `.claude/handoff.md` (written by the `handoff` skill) via `additionalContext` so the next agent reads it first, then archives it to `handoff-<timestamp>.consumed.md` so it is delivered once (not replayed into every later session). No-ops if the file is absent or the session was resumed/compacted |
| `SessionStart` | `skills/project-brain/scripts/session-start.ps1` | Resolves the session cwd to a project-brain initiative and injects its `core.md` + `STATUS.md` via `additionalContext`. Lives inside the `project-brain` skill directory (junctioned with the skill, not a top-level symlink); fails safe — any error or no match exits 0 with no output |
| `PreToolUse` (Bash\|PowerShell) | `no-claude-session-trailer.sh` | Denies a `git commit` carrying the `Claude-Session:` trailer. Matches `git … commit` allowing global flags to carry an argument (`git -C <path> commit`), so a flag-plus-value pair can't slip between `git` and `commit` and evade the check |
| `PreToolUse` (Bash\|PowerShell) | `block-destructive-vcs.ps1` | Denies destructive **git** — `push --force` (allows `--force-with-lease`), `reset --hard`, `clean -f`, `branch -D`. jj is left ungated (its op-log makes rewrites recoverable). The git-guardrails *skill* only advises; this hook is non-bypassable. Strips quoted substrings before matching (escape-aware, so an escaped quote in a message doesn't mangle the match), except flag-shaped quoted content (`"--force"`) which is unquoted in place rather than deleted, so a quoted flag is still denied |
| `PreToolUse` (Bash) | `block-pwsh-in-bash.ps1` | Denies PowerShell sent to the Bash tool (a segment that *starts* with `pwsh`/`powershell`, `$env:`, or a `Verb-Noun` cmdlet), pointing at the PowerShell tool. Command-position only, so a cmdlet quoted as a search string is allowed. Splits on a lone `&` as well as `&&`/`\|`/`;` (so a backgrounded cmdlet isn't hidden in the second segment) against an extended verb list beyond the common `Get`/`Set`/`New` |
| `PreToolUse` (Edit\|Write) | `warn-legacy-files.ps1` | Emits an `ask` decision (pause-and-confirm) before editing a legacy/do-not-touch dotfile — `config/bspwm\|sxhkd/`. Scoped to `$env:DOTFILES` so it never fires on same-named files in other repos; no-ops if `$env:DOTFILES` is unset |
| `PostToolUse` (Edit\|Write) | `lint-powershell.ps1` | Runs PSScriptAnalyzer on an edited `.ps1/.psm1/.psd1` (using the nearest ruleset — `.vscode/PSScriptAnalyzerSettings.psd1` or the project root's, whichever it hits first walking up; the walk stops at the project boundary `.git`/`.jj`, so a stray ruleset in `$HOME` can't govern every repo) and feeds findings back via `additionalContext`. Fails open silently — no output — even when `Invoke-ScriptAnalyzer` itself throws (e.g. a malformed ruleset file), same as the PSSA-absent no-op |
| `PostToolUse` (Edit\|Write) | `warn-hardcoded-secrets.ps1` | Scans written content (Write `content` / Edit `new_string`) for secret-shaped assignments (api-key/secret/token/password with a quoted literal, private-key blocks, AWS access-key ids) and warns via `additionalContext`. A quoted placeholder value starting with `$` or `{` (e.g. `="$env:X"`, `="{{token}}"`) is excluded, so env-var refs and template placeholders don't false-fire. Global (secrets are bad anywhere); reports only rule names, never values |
| `UserPromptSubmit` | `warn-reasoning-extraction.ps1` | Warns via `additionalContext` (never denies) when the submitted prompt asks for step-by-step reasoning / chain-of-thought — phrasing that can trip Claude Fable 5's `reasoning_extraction` refusal → Opus fallback (Claude Code shows a transcript notice). Nudges Claude to read it as a request for short rationale + assumptions + evidence |
| `PreToolUse` (Edit\|Write) | `warn-reasoning-extraction.ps1` | Same script, config-write guard: emits an `ask` only when a reasoning-extraction phrase is being written into a config/prompt-bearing file (`CLAUDE.md`, `AGENTS.md`, `*SKILL.md`, `agents/*.md`, `codex/**`) — a *standing* instruction persisted into config. Strips quoted substrings before matching (so docs that quote the phrase to ban it don't self-trigger) plus a negation guard; reports rule names only |

**Lint caveat:** the PostToolUse hook lints only the *single edited file* — it is a fast
inner-loop nudge, **not** a substitute for the full `-Recurse` run CI does over the whole
source tree (a per-file pass can miss violations in untouched files). It is non-blocking
(`additionalContext`, not `decision: block`), so findings are surfaced for fixing without
halting the turn.

## Notifications

Alerts when Claude finishes (`Stop`) or is waiting on you (`Notification`), tuned for
the `Claude → Zellij → Windows Terminal` stack:

- **Audible beep** is the most reliable signal. Both hooks run `pwsh -NoProfile -Command
  "[console]::beep()"`, which goes through the system speaker and bypasses Zellij and
  Windows Terminal — so it reaches you even when WT is unfocused or minimized, provided audio
  is on (a muted/absent audio endpoint silences it).
- **Zellij tab mark** is the in-multiplexer indicator. A terminal bell (`BEL`) emitted
  inside a pane is **caught by Zellij** (it flags the tab) and is **not** forwarded out to
  Windows Terminal — so WT's own bell/taskbar-flash style never fires from inside Zellij.
  The tab mark is reliable on **needs-input** (Claude emits the `BEL` itself via
  `preferredNotifChannel: terminal_bell`) and best-effort on **done** (the `Stop` hook
  writes `[char]7`; whether a hook subprocess's `BEL` reaches the pane is not guaranteed).

PowerShell-native by design (this is a pwsh machine) — no `bash`/`printf '\a'`/`/dev/tty`.
For a visual toast on completion, replace the `Stop` hook's beep with
`New-BurntToastNotification -Text 'Claude Code','Done'` (needs `Install-Module BurntToast`);
the `Notification` hook still beeps unless you swap it too.

## Statusline

`statusline-command.sh` reads the JSON context piped by Claude Code and outputs
a statusline of the form
`Opus | 12.4k (1%) | 5h 70% (resets 2h14m) | ±main ↑2 *3 ?1 | PR#1234 ✓`.
Requires `jq` and `git`.

The context segment shows the used-token count and a percentage
(`12.4k (1%)`) — no context-window size or `tokens` label. The percentage is
computed from `used / context_window_size`, the denominator taken straight from
the JSON's `context_window.context_window_size` (200000, or 1000000 for
extended-context models). The JSON's own `used_percentage` is **not** used here:
it reflects Claude Code's internal compaction threshold rather than the model's
actual context limit.

The git segment (from `.workspace.current_dir`) mirrors the PowerShell prompt's
colors: `±branch` red when dirty / yellow when clean (`wt:` prefix in a worktree),
`↑N` ahead (green) / `↓N` behind (red) / `↕` diverged, and per-category file
counts `+N` staged (green), `*N` modified (yellow), `?N` untracked (magenta),
`!N` conflicts (red). Each count is omitted when zero; the whole segment is
absent outside a git repo. The `*N` modified count reads the porcelain worktree
column, so unstaged deletions and type-changes (`D`/`T`) count as modified/dirty
too, not just `M`.

The `5h` segment always shows the 5-hour window usage
(`rate_limits.five_hour.used_percentage`) and appends a countdown to the window
reset (`resets 2h14m`, or `resets 14m` under an hour) derived from `resets_at`.
The 7-day window is not shown.

The PR segment appears only while an open PR exists for the branch (`.pr`):
`PR#N` plus a review-state glyph — `✓` approved (green), `✗` changes_requested
(red), `⋯` pending (yellow), `(draft)` for drafts (plain). Rendered as plain
colored text, not an OSC8 hyperlink, because the Zellij + Windows Terminal stack
mishandles escape sequences (see `docs/zellij-windows-terminal-colors.md`).

## Skills

`ai-agents/shared/skills/` holds portable global skills, while `ai-agents/claude/skills/` holds the small set of Claude Code-only skills. Each subdirectory is a skill:

```
ai-agents/shared/skills/
  my-skill/
    SKILL.md            ← skill definition (frontmatter: name + description)
    commands/           ← optional: slash-command prompt files
    references/         ← optional: progressive-disclosure docs loaded on demand
```

The installer junctions (Windows) or symlinks (Linux) each skill directory into
`~/.claude/skills/`, making it available in every project. To add a portable skill, create its subdirectory under `ai-agents/shared/skills/`; for a
Claude-only skill, use `ai-agents/claude/skills/`. Re-run `setup.ps1 -Module claude` afterward.

The codex module projects only portable shared skill directories into `~/.codex/skills/`,
so Codex CLI reads runtime-neutral skills from the same source. Claude-only skills remain
private to Claude Code. See `../codex/README.md` → Skills, and re-run `setup.ps1 -Module codex`
after adding a skill so Codex picks it up as well.

`azure-boards-organiser` (Azure DevOps Boards management for a Scrum process — PBIs,
sprints, backlog) needs a one-time local setup: copy its `config.example.json` to
`config.json` (gitignored) and fill in your ADO project / team / iteration root; the org
is read from `az devops configure`. It prefers the Azure DevOps MCP server when connected
and falls back to PowerShell-native `az boards` CLI.

`bicep-tdd` (local, offline RED→GREEN loop for Azure Bicep — `bicep build`/`lint`, PSRule
for Azure policy-as-code, a committed `bicep snapshot` compare gate, and Pester golden
fixtures over compiled ARM) needs two prerequisites
on the machine: the **Bicep CLI** on PATH and the **PSRule.Rules.Azure** module
(`Install-Module PSRule.Rules.Azure -Scope CurrentUser`). It deliberately stops at compiled
ARM — no `what-if`/deploy, so it never authenticates to a tenant.

`council` is a shared, cost-bounded prompt orchestration contract for adversarial review
of a **non-diff artifact**. Claude's native isolated workers receive portable critic/chair
contracts; there are no named council custom agents. `/council ...` defaults to quick
(three critics + chair); add `--debate` for four critics plus rebuttals, and `--codex` only
when an external Codex seat is explicitly wanted. Charter seats are limited to 2–5 and
normal calls to 12. The four `/council-code`, `/council-business`, `/council-plan`, and
`/council-doc` aliases pin their panel. Reports use `.agents/council/reports/`. For branch
diffs/PRs use `deep-review`, not council.

`walkthrough` is the post-`implement` mentoring stage of the main flow: it walks the user through
a diff like a senior pairing with a junior (checkpoint tour / overview-then-Q&A / socratic, chosen
at start or via `--mode`), chunked into narrative beats and framed against the driving spec/ticket
when one can be found. It explains rather than judges — findings stay with `code-review` /
`spec-review`. It keeps a two-grain **learner profile** seeded into every tour and updated at
close-out (delta shown for veto): general-skill observations in `~/.claude/learner-profile.md`
(untracked, created on first use), domain-specific ones in the resolved project-brain's
`learner.md`.

The review→fix skills compose around `_shared/` contracts: **`deep-review`** fans out parallel
per-dimension reviewers + Codex over a branch diff/PR, adversarially verifies the findings, and
emits them to a findings store; **`fix-findings`** consumes that store and applies fixes (parallel,
partitioned by conflict-set, one commit per fix-unit); **`review-fix-loop`** is the thin orchestrator
that chains the two each cycle and loops to a deterministic clean gate. `codex-review` is the
standalone lightweight Codex second-opinion pass.

`_shared/` is **not a skill** — it holds resources shared by multiple skills: `review-rubric.md` (the
merged AGENTS.md + thermo-nuclear quality bar), `dimensions.md` (the 7-dimension registry + charters
for `deep-review`), and `findings-schema.md` (the JSONL finding schema, semantic fingerprint, and
store discipline shared by the review→fix skills). It has no `SKILL.md`, so the harness ignores it as
a skill; it is still junctioned so skills can reference it via `../_shared/<file>`.

Built-in Claude Code skills (`code-review`, `compact`, `deep-research`, `security-review`,
`verify`, etc.) are provided by the harness and do not need to be installed. `handoff` is
this repo's own skill (`ai-agents/claude/skills/handoff/`), not a harness built-in — see the Files
table above.

## Agents

`ai-agents/shared/agents/` holds user-scope [subagents](https://code.claude.com/docs/en/subagents) —
each is a single `.md` with YAML frontmatter (`name`, `description`, `tools`, `model`,
`skills`, …) plus a system-prompt body:

```
ai-agents/shared/agents/
  pwsh-implementer.md   ← one agent = one self-contained file
```

Unlike skills (junctioned per-subdirectory), the **whole `agents/` dir is junctioned**
(Windows) / **symlinked** (Linux) into `~/.claude/agents/`. Agent definitions are flat files
in a dir nothing else writes to, so a whole-dir link keeps live == repo *and* lets an agent
created interactively via `/agents` (Personal scope) land straight in the repo — no drift,
no manual relocation. To add an agent, drop a `.md` here and re-run `setup.ps1 -Module claude`
(only needed the first time, to create the junction).

**Gotcha — bodies are self-contained.** A subagent's markdown body is **not** able to
`@import AGENTS.md` the way `CLAUDE.md` does. The only sanctioned way to share content into an
agent is the `skills:` frontmatter field, which injects the listed skill's `SKILL.md` body at
startup. Any convention an agent needs (TDD, linting, error handling) must be either preloaded
via `skills:` or restated in the body — so restated rules carry a maintenance note to update
them alongside `AGENTS.md`.

Seeded agents:

- **`pwsh-implementer`** — TDD specialist/implementer for PowerShell 7+ (Pester first,
  PSScriptAnalyzer, strict typing, enterprise error handling; covers Azure/Graph/CI-CD when
  the work is primarily PowerShell). Preloads the `tdd` skill via `skills: tdd`;
  `model: inherit`.
- **`powershell-module-architect`** — module *design/review* companion to `pwsh-implementer`.
  Owns the skeleton (layout, `.psd1`/`.psm1` manifest, public/private split, `src`/`tests`
  structure) and module-health reviews; reports unwritten behaviour (function bodies +
  Pester tests) for the caller to dispatch to `pwsh-implementer`. No `skills:` preload;
  `model: inherit`.
- **`csharp-implementer`** — TDD specialist/implementer for C# / .NET 8+ (xUnit first,
  dotnet CLI, nullable reference types, structured `ILogger` logging; Microsoft/xUnit
  `src`/`tests/<Proj>.Tests` layout so `<leader>A` resolves counterparts). Preloads the
  `tdd` skill; `model: inherit`.
- **`bicep-implementer`** — Azure Bicep IaC specialist. Preloads the `bicep-tdd` skill and
  runs its full offline gate (build/lint/PSRule/snapshot compare/Pester golden fixtures);
  hard boundary: never authenticates to a tenant, no `what-if`, no deploy. `model: inherit`.
- **`chief-orchestrator`** — coordination-only agent for large/multi-domain tasks: scouts,
  locks the shared contract (schemas, signatures, non-overlapping file ownership),
  dispatches the specialists above in parallel via the `Agent` tool (nesting depth 1 → 2),
  integrates, and verifies once at the end. Deliberately has **no Write/Edit tools** — every
  file change flows through a dispatched worker. `model: inherit`.

## Install

```
.\setup.ps1 -Module claude   # Windows
./setup.sh -m claude         # Linux / WSL
```

**Not tracked** (excluded by design): `.credentials.json`, `history.jsonl`,
`mcp-needs-auth-cache.json`, `stats-cache.json`, per-project state under
`projects/`, and session data.
