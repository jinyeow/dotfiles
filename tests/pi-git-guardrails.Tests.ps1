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
#   - safe siblings are allowed (branch -d, checkout <branch>, restore --staged <file>, status)
#   - non-git and read-only commands pass through
#   - the extension is a verbatim, unparsed-string port of the source script, so it inherits
#     the same known false positives: a destructive phrase quoted inside a commit message
#     (when whitespace precedes it), and any subcommand whose own name contains a blocked
#     verb substring (e.g. "stash push")

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:ExtensionFile = Join-Path $script:RepoRoot 'pi/extensions/git-guardrails.ts'

    if (-not (Test-Path $script:ExtensionFile)) {
        throw "Extension file not found: $script:ExtensionFile"
    }

    # Node harness: extracts the real BLOCKED_PATTERNS array verbatim from the .ts source
    # text (regex literals only, no TS-specific syntax inside the array), evaluates it,
    # then tests each command from a JSON array passed as argv against every pattern.
    # Prints per-command matched/not-matched JSON to stdout. Throws loudly if the patterns
    # block can't be found, so a source-shape change fails the suite instead of silently
    # testing nothing.
    $script:NodeHarness = Join-Path $TestDrive 'run-guardrails.mjs'
    @'
import { readFileSync } from "node:fs";

const [, , extensionPath, commandsJson] = process.argv;
const source = readFileSync(extensionPath, "utf8");

const match = source.match(/const BLOCKED_PATTERNS: RegExp\[\] = \[([\s\S]*?)\];/);
if (!match) {
    throw new Error("BLOCKED_PATTERNS array not found in " + extensionPath);
}

const patterns = eval("[" + match[1] + "]");
if (!Array.isArray(patterns) || patterns.length === 0) {
    throw new Error("BLOCKED_PATTERNS extraction produced no patterns");
}

const commands = JSON.parse(commandsJson);
const results = commands.map((command) => ({
    command,
    matched: patterns.some((pattern) => pattern.test(command)),
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
        ) {
            param($Command)
            $results = Invoke-Guardrails -Command $Command
            $results[$Command] | Should -BeFalse
        }
    }

    Context 'known inherited false positives (pinned as documentation, not endorsement)' {
        It 'blocks a destructive phrase quoted inside a commit message' {
            # Neither the extension nor its source script parses shell quoting, so a
            # destructive phrase inside a quoted -m message still matches the raw string —
            # as long as whitespace precedes "reset" (the reset pattern requires \s+ right
            # before it, so a phrase immediately after the opening quote, e.g.
            # `-m "reset --hard"`, does NOT match; one with a leading word does).
            $command = 'git commit -m "please reset --hard now"'
            $results = Invoke-Guardrails -Command $command
            $results[$command] | Should -BeTrue
        }

        It 'blocks "git stash push" because "push" is matched as a bare substring' {
            # The push pattern has no subcommand awareness — any trailing "push" token
            # trips it, including git-stash's own "push" subcommand.
            $command = 'git stash push'
            $results = Invoke-Guardrails -Command $command
            $results[$command] | Should -BeTrue
        }
    }
}
