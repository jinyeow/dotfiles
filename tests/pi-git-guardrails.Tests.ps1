#Requires -Version 7
# Behavioural tests for pi/extensions/git-guardrails.ts — the Pi tool_call extension that
# blocks dangerous git commands before the bash tool executes. The extension imports
# @earendil-works/pi-coding-agent (not installed locally), so this suite copies the real .ts
# file next to a tiny stub of that package, loads it with Node's type stripping, and drives
# the real default export's tool_call handler. Rule loading (from the shared
# ai-agents/_shared/destructive-git-rules.json), quote scrubbing and matching are all the
# extension's own code, run end to end.
#
# The extension's documented properties this suite pins:
#   - canonical destructive forms are denied (push, reset --hard, clean -f/-fd, branch -D,
#     checkout ., restore .)
#   - safe siblings are allowed (branch -d, checkout <branch>, restore --staged <file>, status,
#     reset --soft, clean -n, git stash push)
#   - non-git and read-only commands pass through
#   - quote-scrubbing (ported from claude/block-destructive-vcs.ps1, see #177) means a
#     destructive phrase quoted inside a commit message no longer false-matches, and
#     "git stash push" is excluded from the push pattern by name
#   - a real command sitting between two single-quoted strings that each contain a double
#     quote is not scrubbed away (double/single-quote spans are matched in one alternation,
#     not two sequential passes, so quote kinds can't pair across each other)
#   - extra whitespace between "stash" and "push" doesn't defeat the stash-push exclusion
#   - rules come from the shared rules file (runtime-scoped), and a missing or malformed
#     rules file fails closed for git commands only

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:ExtensionFile = Join-Path $script:RepoRoot 'pi/extensions/git-guardrails.ts'
    $script:SharedRules = Join-Path $script:RepoRoot 'ai-agents/_shared/destructive-git-rules.json'

    if (-not (Test-Path $script:ExtensionFile))
    {
        throw "Extension file not found: $script:ExtensionFile"
    }

    $script:Sandbox = Join-Path $TestDrive 'pi-ext'
    $stubDir = Join-Path $script:Sandbox 'node_modules/@earendil-works/pi-coding-agent'
    New-Item -ItemType Directory -Path $stubDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $stubDir 'package.json') -NoNewline -Encoding utf8 -Value '{"name":"@earendil-works/pi-coding-agent","type":"module","main":"index.js"}'
    Set-Content -LiteralPath (Join-Path $stubDir 'index.js') -NoNewline -Encoding utf8 -Value 'export function isToolCallEventType(name, event) { return event.toolName === name; }'
    Set-Content -LiteralPath (Join-Path $script:Sandbox 'package.json') -NoNewline -Encoding utf8 -Value '{"type":"module"}'
    $script:SandboxExtension = Join-Path $script:Sandbox 'git-guardrails.ts'
    Copy-Item -LiteralPath $script:ExtensionFile -Destination $script:SandboxExtension

    $script:NodeHarness = Join-Path $script:Sandbox 'run-guardrails.mjs'
    @'
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const [, , extensionPath, commandsPath] = process.argv;
const { default: register } = await import(pathToFileURL(extensionPath).href);
let handler;
register({ on: (name, fn) => { if (name === "tool_call") handler = fn; } });
if (!handler) {
    throw new Error("extension registered no tool_call handler");
}

const commands = JSON.parse(readFileSync(commandsPath, "utf8"));
const results = [];
for (const command of commands) {
    const outcome = await handler({ toolName: "bash", input: { command } });
    results.push({ command, matched: Boolean(outcome && outcome.block), reason: outcome ? outcome.reason : null });
}
process.stdout.write(JSON.stringify(results));
'@ | Set-Content -Path $script:NodeHarness -NoNewline -Encoding utf8

    # Runs the real extension for a list of commands. Returns a hashtable keyed by command
    # with { matched, reason }. RulesPath overrides the rules file via the extension's own
    # PI_GIT_GUARDRAILS_RULES_PATH env var (default: the repository's shared rules file).
    function Invoke-GuardrailsDetailed
    {
        param([string[]] $Command, [string] $RulesPath = $script:SharedRules)

        $commandsPath = Join-Path $TestDrive "commands-$([guid]::NewGuid()).json"
        ConvertTo-Json -InputObject @($Command) -Compress | Set-Content -LiteralPath $commandsPath -NoNewline -Encoding utf8
        $saved = $env:PI_GIT_GUARDRAILS_RULES_PATH
        $env:PI_GIT_GUARDRAILS_RULES_PATH = $RulesPath
        try
        {
            $output = & node --experimental-strip-types --no-warnings $script:NodeHarness $script:SandboxExtension $commandsPath
        }
        finally
        {
            $env:PI_GIT_GUARDRAILS_RULES_PATH = $saved
        }
        if ($LASTEXITCODE -ne 0)
        {
            throw "node harness failed: $output"
        }
        $results = @{}
        foreach ($entry in ($output | ConvertFrom-Json))
        {
            $results[$entry.command] = $entry
        }
        return $results
    }

    # Returns a hashtable keyed by command with a bool matched value.
    function Invoke-Guardrails
    {
        param([string[]] $Command)
        $results = @{}
        foreach ($entry in (Invoke-GuardrailsDetailed -Command $Command).Values)
        {
            $results[$entry.command] = $entry.matched
        }
        return $results
    }
}

Describe 'pi/extensions/git-guardrails.ts' {
    Context 'canonical denies' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = 'git push' }
            @{ Command = 'git push --force origin main' }
            @{ Command = 'git reset --hard HEAD~1' }
            @{ Command = 'git clean -fd' }
            @{ Command = 'git clean -f' }
            @{ Command = 'git branch -D foo' }
            @{ Command = 'git checkout .' }
            @{ Command = 'git restore .' }
            @{ Command = "echo 'a`"b' ; git push ; echo 'c`"d'" }
        ) {
            param($Command)
            $results = Invoke-Guardrails -Command $Command
            $results[$Command] | Should -BeTrue
        }
    }

    Context 'safe siblings allowed' {
        It 'allows <Command>' -TestCases @(
            @{ Command = 'git status' }
            @{ Command = 'git branch -d foo' }
            @{ Command = 'git checkout main' }
            @{ Command = 'git restore --staged file.txt' }
            @{ Command = 'git commit -m "message"' }
            @{ Command = 'echo hello' }
            @{ Command = 'git stash list' }
            @{ Command = 'git stash push' }
            @{ Command = 'git stash push -u' }
            @{ Command = 'git stash  push' }
            @{ Command = 'git reset --soft HEAD~1' }
            @{ Command = 'git clean -n' }
            @{ Command = 'git commit -m "please reset --hard now"' }
            @{ Command = 'git commit -m "say \"reset --hard\" here"' }
            @{ Command = 'git commit -m "push to origin"' }
        ) {
            param($Command)
            $results = Invoke-Guardrails -Command $Command
            $results[$Command] | Should -BeFalse
        }
    }

    Context 'quoted-flag bypass is closed' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = 'git reset "--hard" HEAD' }
            @{ Command = 'git clean "-fd"' }
            @{ Command = 'git branch "-D" feature' }
        ) {
            param($Command)
            # A quoted flag expands identically in the shell, so the deny must still fire.
            $results = Invoke-Guardrails -Command $Command
            $results[$Command] | Should -BeTrue
        }
    }
}

Describe 'pi/extensions/git-guardrails.ts shared rules' {
    Context 'refspec force-push and whole-tree discard bypasses' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = 'git push origin +main' }
            @{ Command = 'git restore -- .' }
            @{ Command = 'git checkout -- .' }
            @{ Command = 'git checkout HEAD -- .' }
            @{ Command = 'git checkout -- "."' }
        ) {
            param($Command)
            $results = Invoke-Guardrails -Command $Command
            $results[$Command] | Should -BeTrue
        }

        It 'allows <Command>' -TestCases @(
            @{ Command = 'git restore --staged .' }
            @{ Command = 'git checkout .gitignore' }
        ) {
            param($Command)
            $results = Invoke-Guardrails -Command $Command
            $results[$Command] | Should -BeFalse
        }
    }

    Context 'rules file' {
        It 'reads its rules from the shared data file, not a hardcoded list' {
            $rulesPath = Join-Path $TestDrive 'fixture-rules.json'
            @{
                keepQuoted = '^$'
                rules = @(@{ id = 'fixture'; runtimes = @('pi'); pattern = '\bgit\b[^\n;|&]*\bfixture-marker\b'; reason = 'fixture rule fired' })
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $rulesPath -NoNewline
            $results = Invoke-GuardrailsDetailed -Command 'git fixture-marker', 'git push' -RulesPath $rulesPath
            $results['git fixture-marker'].matched | Should -BeTrue
            $results['git fixture-marker'].reason | Should -Match 'fixture rule fired'
            $results['git push'].matched | Should -BeFalse
        }

        It 'skips rules scoped to other runtimes' {
            $rulesPath = Join-Path $TestDrive 'claude-only-rules.json'
            @{
                keepQuoted = '^$'
                rules = @(@{ id = 'claude-only'; runtimes = @('claude'); pattern = '\bgit\b'; reason = 'x' })
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $rulesPath -NoNewline
            (Invoke-GuardrailsDetailed -Command 'git status' -RulesPath $rulesPath)['git status'].matched | Should -BeFalse
        }

        It 'fails closed for a git command when the rules file is missing, naming the path' {
            $missing = Join-Path $TestDrive 'missing-rules.json'
            $results = Invoke-GuardrailsDetailed -Command 'git status', 'ls -la' -RulesPath $missing
            $results['git status'].matched | Should -BeTrue
            $results['git status'].reason | Should -Match 'missing-rules\.json'
            $results['ls -la'].matched | Should -BeFalse
        }

        It 'fails closed for a git command when the rules file is malformed' {
            $badPath = Join-Path $TestDrive 'bad-rules.json'
            Set-Content -LiteralPath $badPath -Value '{not json' -NoNewline
            (Invoke-GuardrailsDetailed -Command 'git status' -RulesPath $badPath)['git status'].matched | Should -BeTrue
        }
    }
}
