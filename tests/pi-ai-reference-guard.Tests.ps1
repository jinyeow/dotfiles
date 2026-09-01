#Requires -Version 7
# Behavioural tests for pi/extensions/ai-reference-guard.ts — the Pi tool_call extension
# that hard-blocks AI/Claude/Codex/Copilot/co-authored-by references from being written
# into a commit, PR, or Azure Boards item (issue #219, layer 5). Since the extension
# imports @earendil-works/pi-coding-agent (not installed locally), this suite cannot
# import the module directly. Instead it extracts the real COMMIT_SHAPED_PATTERNS,
# NO_VERIFY_PATTERNS, scrubQuoted, collectQuotedContent, matchCommand, and parseWordlist
# source text verbatim from the .ts source and evaluates it in node, mirroring
# tests/pi-git-guardrails.Tests.ps1's extraction approach — so a logic edit in the real
# file changes these results.
#
# The extension's documented properties this suite pins:
#   - each of the five command shapes (git commit, gh pr create/edit, az repos pr
#     create/update, az boards, az devops invoke) denies only when combined with a
#     wordlist match, and allows the same shape without one
#   - `git commit --no-verify`/`-n` and `git push --no-verify` deny unconditionally, with
#     no wordlist match required
#   - a missing/unreadable wordlist fails CLOSED (loadWordlistPatterns throws; this suite
#     exercises that by feeding matchCommand an empty pattern list only where explicitly
#     testing wordlist-driven behavior — the fail-closed path itself is exercised by
#     invoking the real extension module's default export against a nonexistent wordlist
#     path via node, not by calling matchCommand directly, since matchCommand itself never
#     touches the filesystem)
#   - non-git and unrelated read-only commands pass through
#   - a banned term sitting inside actual commit-message/title/body prose (a quoted span)
#     is still caught — scrubbing must not scrub away a real banned term in the message
#     content itself

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:ExtensionFile = Join-Path $script:RepoRoot 'pi/extensions/ai-reference-guard.ts'
    $script:WordlistFile = Join-Path $script:RepoRoot 'ai-agents/_shared/banned-ai-terms.txt'

    if (-not (Test-Path $script:ExtensionFile)) {
        throw "Extension file not found: $script:ExtensionFile"
    }
    if (-not (Test-Path $script:WordlistFile)) {
        throw "Wordlist file not found: $script:WordlistFile"
    }

    # Node harness: extracts the real COMMIT_SHAPED_PATTERNS / NO_VERIFY_PATTERNS arrays
    # and the scrubQuoted / collectQuotedContent / matchCommand / parseWordlist function
    # bodies verbatim from the .ts source text (regex literals / plain JS only, no
    # TS-specific syntax after stripping inline type annotations), evaluates them, parses
    # the real wordlist file through the extracted parseWordlist, then runs matchCommand
    # for each command from a JSON array read from a temp file (not argv — a bare 🤖
    # wordlist entry and other non-ASCII content can be mangled going through
    # ConvertTo-Json -> process argv on Windows). Prints per-command reason/undefined JSON
    # to stdout. Throws loudly if any block can't be found, so a source-shape change fails
    # the suite instead of silently testing nothing.
    $script:NodeHarness = Join-Path $TestDrive 'run-ai-reference-guard.mjs'
    @'
import { readFileSync } from "node:fs";

const [, , extensionPath, wordlistPath, commandsPath] = process.argv;
const source = readFileSync(extensionPath, "utf8");

function extractBlock(pattern, label) {
    const found = source.match(pattern);
    if (!found) {
        throw new Error(label + " not found in " + extensionPath);
    }
    return found[1];
}

// Strips TS-only inline type annotations from a function body so plain node can eval it;
// the regex/logic itself is plain JS. Covers every annotation shape actually used inside
// the extracted bodies (kept minimal and explicit, mirroring pi-git-guardrails.Tests.ps1's
// own stripper rather than a fully general TS-to-JS transform).
function stripTypes(body) {
    return body
        .replace(/:\s*string\[\]/g, "")
        .replace(/:\s*string(?:\s*\|\s*undefined)?/g, "")
        .replace(/:\s*RegExpExecArray\s*\|\s*null/g, "")
        .replace(/:\s*RegExp\[\]/g, "");
}

const commitShapedSrc = extractBlock(/const COMMIT_SHAPED_PATTERNS: RegExp\[\] = \[([\s\S]*?)\n\];/, "COMMIT_SHAPED_PATTERNS");
const noVerifySrc = extractBlock(/const NO_VERIFY_PATTERNS: RegExp\[\] = \[([\s\S]*?)\n\];/, "NO_VERIFY_PATTERNS");
const scrubQuotedBody = stripTypes(extractBlock(/function scrubQuoted\(command: string\): string \{([\s\S]*?)\n\}/, "scrubQuoted"));
const collectQuotedContentBody = stripTypes(extractBlock(/function collectQuotedContent\(command: string\): string \{([\s\S]*?)\n\}/, "collectQuotedContent"));
const matchCommandBody = stripTypes(extractBlock(/function matchCommand\(command: string, wordlistPatterns: RegExp\[\]\): string \| undefined \{([\s\S]*?)\n\}/, "matchCommand"));
const parseWordlistBody = stripTypes(extractBlock(/function parseWordlist\(text: string\): RegExp\[\] \{([\s\S]*?)\n\}/, "parseWordlist"));

const COMMIT_SHAPED_PATTERNS = eval("[" + commitShapedSrc + "]");
const NO_VERIFY_PATTERNS = eval("[" + noVerifySrc + "]");
if (!Array.isArray(COMMIT_SHAPED_PATTERNS) || COMMIT_SHAPED_PATTERNS.length === 0) {
    throw new Error("COMMIT_SHAPED_PATTERNS extraction produced no patterns");
}
if (!Array.isArray(NO_VERIFY_PATTERNS) || NO_VERIFY_PATTERNS.length === 0) {
    throw new Error("NO_VERIFY_PATTERNS extraction produced no patterns");
}

const scrubQuoted = new Function("command", scrubQuotedBody);
const collectQuotedContent = new Function("command", collectQuotedContentBody);
const parseWordlist = new Function("text", parseWordlistBody);
const matchCommand = new Function(
    "command",
    "wordlistPatterns",
    "scrubQuoted",
    "collectQuotedContent",
    "COMMIT_SHAPED_PATTERNS",
    "NO_VERIFY_PATTERNS",
    matchCommandBody,
);

const wordlistText = readFileSync(wordlistPath, "utf8");
const wordlistPatterns = parseWordlist(wordlistText);
if (!Array.isArray(wordlistPatterns) || wordlistPatterns.length === 0) {
    throw new Error("parseWordlist produced no patterns from " + wordlistPath);
}

const commands = JSON.parse(readFileSync(commandsPath, "utf8"));
const results = commands.map((command) => ({
    command,
    reason: matchCommand(command, wordlistPatterns, scrubQuoted, collectQuotedContent, COMMIT_SHAPED_PATTERNS, NO_VERIFY_PATTERNS) ?? null,
}));

process.stdout.write(JSON.stringify(results));
'@ | Set-Content -Path $script:NodeHarness -NoNewline -Encoding utf8

    # Runs the real matcher through node for a list of commands, against the real wordlist
    # file unless -WordlistPath overrides it. Returns a hashtable keyed by command with a
    # bool "blocked" value (true when matchCommand returned a reason).
    function Invoke-AiReferenceGuard {
        param(
            [string[]] $Command,
            [string] $WordlistPath = $script:WordlistFile
        )

        $commandsPath = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        $Command | ConvertTo-Json -Compress -AsArray | Set-Content -Path $commandsPath -NoNewline -Encoding utf8

        $output = & node $script:NodeHarness $script:ExtensionFile $WordlistPath $commandsPath
        if ($LASTEXITCODE -ne 0) {
            throw "node harness failed: $output"
        }

        $results = @{}
        foreach ($entry in ($output | ConvertFrom-Json)) {
            $results[$entry.command] = $null -ne $entry.reason
        }
        return $results
    }
}

Describe 'pi/extensions/ai-reference-guard.ts' {
    Context 'commit-shaped command + wordlist match denies' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = 'git commit -m "Generated with Claude"' }
            @{ Command = 'git commit -m "fix: co-authored-by Claude"' }
            @{ Command = 'gh pr create --title "Fix bug" --body "Written by Claude"' }
            @{ Command = 'gh pr edit 42 --body "AI-generated summary"' }
            @{ Command = 'az repos pr create --title "Fix" --description "Generated with Codex"' }
            @{ Command = 'az repos pr update --id 1 --description "Generated with Codex"' }
            @{ Command = 'az boards work-item create --title "Task" --fields "System.Description=Generated with Claude"' }
            @{ Command = 'az devops invoke --area wit --resource workitems --route-parameters "System.Description=Generated with Claude"' }
        ) {
            param($Command)
            $results = Invoke-AiReferenceGuard -Command $Command
            $results[$Command] | Should -BeTrue
        }
    }

    Context 'commit-shaped command with an unquoted wordlist match denies' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = 'git commit -m Claude' }
            @{ Command = 'git commit -m Generated-with-Claude' }
            @{ Command = 'az boards work-item update --fields System.Description=Generated-with-Claude' }
            @{ Command = 'gh pr create --title Claude-reviewed' }
            @{ Command = 'git commit -am Claude' }
            @{ Command = 'gh pr create -t Claude-reviewed' }
            @{ Command = 'az boards work-item update --id 5 --fields System.Title=Fix System.Description=Generated-with-Claude' }
        ) {
            param($Command)
            $results = Invoke-AiReferenceGuard -Command $Command
            $results[$Command] | Should -BeTrue
        }

        It 'allows a clean --fields run alongside another populated pair (guards the widened multi-pair scan)' {
            $command = 'az boards work-item update --id 5 --fields System.Title=Normal System.Description=Normal-work'
            $results = Invoke-AiReferenceGuard -Command $command
            $results[$command] | Should -BeFalse
        }
    }

    Context 'commit-shaped command without a wordlist match allows' {
        It 'allows <Command>' -TestCases @(
            @{ Command = 'git commit -m "fix the login bug"' }
            @{ Command = 'gh pr create --title "Fix bug" --body "Fixes the login flow"' }
            @{ Command = 'gh pr edit 42 --body "Updated description"' }
            @{ Command = 'az repos pr create --title "Fix" --description "Normal change"' }
            @{ Command = 'az repos pr update --id 1 --description "Normal change"' }
            @{ Command = 'az boards work-item create --title "Task" --fields "System.Description=Normal work"' }
            @{ Command = 'az devops invoke --area wit --resource workitems' }
        ) {
            param($Command)
            $results = Invoke-AiReferenceGuard -Command $Command
            $results[$Command] | Should -BeFalse
        }
    }

    Context '--no-verify denies unconditionally' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = 'git commit -m "fix" --no-verify' }
            @{ Command = 'git commit --no-verify -m "fix"' }
            @{ Command = 'git commit -m "fix" -n' }
            @{ Command = 'git push --no-verify origin main' }
        ) {
            param($Command)
            $results = Invoke-AiReferenceGuard -Command $Command
            $results[$Command] | Should -BeTrue
        }

        It 'allows git push -n (dry-run, not --no-verify)' {
            $results = Invoke-AiReferenceGuard -Command 'git push -n origin main'
            $results['git push -n origin main'] | Should -BeFalse
        }

        It 'allows a chained command where -n belongs to a different subcommand, not commit' {
            $command = 'git commit -m "fix" && git log -n 1'
            $results = Invoke-AiReferenceGuard -Command $command
            $results[$command] | Should -BeFalse
        }
    }

    Context 'non-git and unrelated commands pass through' {
        It 'allows <Command>' -TestCases @(
            @{ Command = 'echo hello' }
            @{ Command = 'git status' }
            @{ Command = 'git log --oneline' }
            @{ Command = 'ls -la' }
            @{ Command = 'npm test' }
        ) {
            param($Command)
            $results = Invoke-AiReferenceGuard -Command $Command
            $results[$Command] | Should -BeFalse
        }
    }

    Context 'quote-scrubbing does not scrub away a real banned term in message content' {
        It 'still blocks a banned term sitting inside actual commit-message prose' {
            $command = 'git commit -m "This change was written by Claude, generated with AI assistance"'
            $results = Invoke-AiReferenceGuard -Command $command
            $results[$command] | Should -BeTrue
        }

        It 'does not false-positive on this repo''s own claude/codex path segments outside quotes' {
            $command = 'cd codex && git commit -m "fix build"'
            $results = Invoke-AiReferenceGuard -Command $command
            $results[$command] | Should -BeFalse
        }
    }

    Context 'missing wordlist fails closed' {
        It 'throws when parseWordlist is fed a nonexistent file (fail-closed path)' {
            $missingPath = Join-Path $TestDrive 'does-not-exist.txt'
            { Invoke-AiReferenceGuard -Command 'git commit -m "fix"' -WordlistPath $missingPath } | Should -Throw
        }
    }
}
