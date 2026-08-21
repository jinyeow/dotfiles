#Requires -Version 7
# Behavioural tests for pi/extensions/git-guardrails.ts — the Pi tool_call extension that
# blocks dangerous git commands before the bash tool executes. Since the extension imports
# @earendil-works/pi-coding-agent (not installed locally), this suite cannot import the
# module directly. Instead it extracts the real BLOCKED_PATTERNS array verbatim from the
# .ts source text and evaluates it in node, so a pattern edit in the real file changes
# these results.
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

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:ExtensionFile = Join-Path $script:RepoRoot 'pi/extensions/git-guardrails.ts'

    if (-not (Test-Path $script:ExtensionFile)) {
        throw "Extension file not found: $script:ExtensionFile"
    }

    # Node harness: extracts the real BLOCKED_PATTERNS array and scrubQuoted function
    # verbatim from the .ts source text (regex literals / plain JS only, no TS-specific
    # syntax), evaluates them, then tests each command from a JSON array passed as argv
    # against every pattern after scrubbing — matching what the extension itself does.
    # Prints per-command matched/not-matched JSON to stdout. Throws loudly if either block
    # can't be found, so a source-shape change fails the suite instead of silently testing
    # nothing.
    $script:NodeHarness = Join-Path $TestDrive 'run-guardrails.mjs'
    @'
import { readFileSync } from "node:fs";

const [, , extensionPath, commandsJson] = process.argv;
const source = readFileSync(extensionPath, "utf8");

const patternsMatch = source.match(/const BLOCKED_PATTERNS: RegExp\[\] = \[([\s\S]*?)\];/);
if (!patternsMatch) {
    throw new Error("BLOCKED_PATTERNS array not found in " + extensionPath);
}
const patterns = eval("[" + patternsMatch[1] + "]");
if (!Array.isArray(patterns) || patterns.length === 0) {
    throw new Error("BLOCKED_PATTERNS extraction produced no patterns");
}

const scrubMatch = source.match(/function scrubQuoted\(command: string\): string \{([\s\S]*?)\n\}/);
if (!scrubMatch) {
    throw new Error("scrubQuoted function not found in " + extensionPath);
}
// Strip the one TS-only type annotation in the function body (the inner arrow function's
// params/return type) so plain node can eval it; the regex logic itself is plain JS.
const scrubBody = scrubMatch[1].replace(
    /\(_match: string, inner: string\): string =>/,
    "(_match, inner) =>",
);
const scrubQuoted = new Function("command", scrubBody);

const commands = JSON.parse(commandsJson);
const results = commands.map((command) => ({
    command,
    matched: patterns.some((pattern) => pattern.test(scrubQuoted(command))),
}));

process.stdout.write(JSON.stringify(results));
'@ | Set-Content -Path $script:NodeHarness -NoNewline -Encoding utf8

    # Runs the real BLOCKED_PATTERNS through node for a list of commands. Returns a
    # hashtable keyed by command with a bool matched value.
    function Invoke-Guardrails {
        param([string[]] $Command)

        $commandsJson = $Command | ConvertTo-Json -Compress -AsArray
        $output = & node $script:NodeHarness $script:ExtensionFile $commandsJson
        if ($LASTEXITCODE -ne 0) {
            throw "node harness failed: $output"
        }

        $results = @{}
        foreach ($entry in ($output | ConvertFrom-Json)) {
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
            @{ Command = 'git reset --soft HEAD~1' }
            @{ Command = 'git clean -n' }
            @{ Command = 'git commit -m "please reset --hard now"' }
            @{ Command = 'git commit -m "say \"reset --hard\" here"' }
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
