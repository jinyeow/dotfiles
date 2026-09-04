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
#   - `git commit --no-verify`/`-n` (isolated or clustered with another short flag, e.g.
#     `-nm`) and `git push --no-verify` deny unconditionally, with no wordlist match
#     required
#   - a missing/unreadable wordlist fails CLOSED. This is exercised two ways: (1) the
#     synthetic case — parseWordlist fed a nonexistent path throws, verified directly; and
#     (2) genuinely, by extracting resolveWordlistPath/loadWordlistPatterns and the real
#     default export's tool_call handler verbatim from the source and running them in node
#     against a real (non-mocked) filesystem — a fake HOME with no wordlist file produces
#     the handler's real `{ block: true, reason }` shape naming the attempted path, and a
#     fake HOME with the wordlist present at the homedir fallback candidate
#     (`~/.pi/agent/banned-ai-terms.txt`) resolves and loads it successfully even though the
#     relative-to-module candidate is absent — the real-world shape of the pi/extensions/
#     junction-resolution bug this fallback fixes
#   - non-git and unrelated read-only commands pass through
#   - a banned term sitting inside actual commit-message/title/body prose (a quoted span)
#     is still caught — scrubbing must not scrub away a real banned term in the message
#     content itself
#   - `isRepoScopedIn` (repo scoping, mirroring git/templates/hooks/pre-commit's own
#     scoping) allows everything when there is no origin remote or the origin isn't both
#     dev.azure.com AND HollardInsuranceRetail, and only then does matchCommand's own
#     wordlist/no-verify/SKIP-var logic apply — exercised against real throwaway repos
#     (mirroring tests/git-templates-ai-reference-hook.Tests.ps1's New-TestRepo pattern),
#     not mocked, since matchCommand itself has no filesystem/process dependency to mock.
#     This also covers a command carrying its own `git -C <path>` target: scoping follows
#     that path's origin, not process.cwd()'s
#   - `--discussion`, `--text`, and `--query-parameters` are recognized message-flag shapes
#     alongside the existing -m/--title/--body/--fields/--route-parameters set
#   - SKIP_AI_REFERENCE_SCAN=1 / SKIP_GITLEAKS=1 still deny even when the value is quoted
#     (`SKIP_GITLEAKS='1'`), which would otherwise be scrubbed away by scrubQuoted before
#     the old pattern ever saw it, and even when the assignment sits on its own line of a
#     multi-line command string (`"true\nSKIP_AI_REFERENCE_SCAN=1 git commit -m \"clean\""`)

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
        .replace(/:\s*RegExp\[\]/g, "")
        .replace(/\s+as\s+Error/g, "");
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
    collected: collectQuotedContent(command),
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

    # Same node harness, but returns the real collectQuotedContent(command) string keyed
    # by command — used to verify wordlist-VALUE extraction directly (e.g. a clustered
    # -nm's message value), independent of whether NO_VERIFY_PATTERNS also denies the
    # same command outright.
    function Invoke-CollectQuotedContent {
        param([string[]] $Command)

        $commandsPath = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        $Command | ConvertTo-Json -Compress -AsArray | Set-Content -Path $commandsPath -NoNewline -Encoding utf8

        $output = & node $script:NodeHarness $script:ExtensionFile $script:WordlistFile $commandsPath
        if ($LASTEXITCODE -ne 0) {
            throw "node harness failed: $output"
        }

        $results = @{}
        foreach ($entry in ($output | ConvertFrom-Json)) {
            $results[$entry.command] = $entry.collected
        }
        return $results
    }

    # Second node harness: extracts the real isRepoScopedIn AND extractDashCPath function
    # bodies verbatim and evaluates them against a real cwd, using node's own execSync
    # (not a mock) so `git remote get-url origin` (or `git -C <path> remote get-url
    # origin` when the command carries its own -C target) runs for real — mirrors
    # tests/git-templates-ai-reference-hook.Tests.ps1's approach of driving the shipped
    # logic against real throwaway repos rather than mocking git.
    $script:RepoScopeHarness = Join-Path $TestDrive 'run-repo-scoped.mjs'
    @'
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

// The command is read from a JSON file (not argv) — a malicious -C payload built for the
// command-injection regression test contains quotes and `&`, which Windows/PowerShell
// argv passing mangles before node ever sees it, unlike the well-formed inputs the other
// argv-based calls in this suite carry.
const [, , extensionPath, cwd, commandPath] = process.argv;
const source = readFileSync(extensionPath, "utf8");
const command = JSON.parse(readFileSync(commandPath, "utf8"));

function extractBlock(pattern, label) {
    const found = source.match(pattern);
    if (!found) {
        throw new Error(label + " not found in " + extensionPath);
    }
    return found[1];
}

const dashCPathBody = extractBlock(/function extractDashCPath\(command: string\): string \| undefined \{([\s\S]*?)\n\}/, "extractDashCPath")
    .replace(/:\s*string/g, "");
const isRepoScopedInBody = extractBlock(/function isRepoScopedIn\(cwd: string, command: string\): boolean \{([\s\S]*?)\n\}/, "isRepoScopedIn")
    .replace(/:\s*string/g, "");

const extractDashCPath = new Function("command", dashCPathBody);
const isRepoScopedIn = new Function("cwd", "command", "execFileSync", "extractDashCPath", isRepoScopedInBody);

process.stdout.write(JSON.stringify(isRepoScopedIn(cwd, command ?? "", execFileSync, extractDashCPath)));
'@ | Set-Content -Path $script:RepoScopeHarness -NoNewline -Encoding utf8

    function Invoke-IsRepoScopedIn {
        param([string] $Cwd, [string] $Command = 'git commit -m "fix"')
        $commandPath = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        $Command | ConvertTo-Json -Compress | Set-Content -Path $commandPath -NoNewline -Encoding utf8
        $output = & node $script:RepoScopeHarness $script:ExtensionFile $Cwd $commandPath
        if ($LASTEXITCODE -ne 0) {
            throw "node harness failed: $output"
        }
        return [bool]($output | ConvertFrom-Json)
    }

    # Mirrors tests/git-templates-ai-reference-hook.Tests.ps1's New-TestRepo: a throwaway
    # repo with an origin remote set (or not) to exercise real `git remote get-url origin`.
    function New-TestRepo {
        param([string] $OriginUrl)
        $root = Join-Path $TestDrive ('ai-ref-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        & git -C $root init -q . 2>&1 | Out-Null
        if ($OriginUrl) {
            & git -C $root remote add origin $OriginUrl 2>&1 | Out-Null
        }
        return $root
    }

    $script:HollardHttps = 'https://dev.azure.com/HollardInsuranceRetail/Proj/_git/Repo'
    $script:HollardSsh = 'git@ssh.dev.azure.com:v3/HollardInsuranceRetail/Proj/Repo'
    $script:GitHubUrl = 'https://github.com/jinyeow/dotfiles.git'

    # Third node harness: exercises the real DEFAULT_WORDLIST_PATH-resolution fallback and
    # the real default export's tool_call handler verbatim from the source, against a real
    # (non-mocked) filesystem and a real, controllable HOME — this is what makes it a
    # genuine test of item 4's fix rather than a synthetic missing-file case. It:
    #   - reconstructs RELATIVE_WORDLIST_PATH the same way the real source does
    #     (`new URL("../banned-ai-terms.txt", import.meta.url)`), but rooted at the real
    #     extension file's own path (accurate for running the file directly, un-junctioned
    #     — this repo genuinely ships no pi/banned-ai-terms.txt, so this candidate always
    #     misses here, faithfully reproducing the junction-broken scenario without having
    #     to fake a Windows junction)
    #   - reconstructs HOMEDIR_WORDLIST_PATH from node's own (possibly HOME/USERPROFILE-
    #     overridden) homedir(), exactly as the real source does
    #   - extracts resolveWordlistPath, loadWordlistPatterns, isToolCallEventType-stubbed
    #     tool_call handler (the arrow function body inside the real default export),
    #     parseWordlist, scrubQuoted, collectQuotedContent, matchCommand, and the pattern
    #     arrays verbatim from the source, and runs the real handler against a stubbed
    #     always-in-scope isRepoScopedIn (repo scoping itself is exercised separately above)
    #   - returns the resolved wordlist path plus the handler's real return value, so a
    #     test can assert on the actual `{ block: true, reason }` shape or `undefined`
    $script:WordlistResolutionHarness = Join-Path $TestDrive 'run-wordlist-resolution.mjs'
    @'
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [, , extensionPath, homeOverride, command] = process.argv;
if (homeOverride) {
    process.env.HOME = homeOverride;
    process.env.USERPROFILE = homeOverride;
}

const source = readFileSync(extensionPath, "utf8");

function extractBlock(pattern, label) {
    const found = source.match(pattern);
    if (!found) {
        throw new Error(label + " not found in " + extensionPath);
    }
    return found[1];
}

function stripTypes(body) {
    return body
        .replace(/:\s*string\[\]/g, "")
        .replace(/:\s*string(?:\s*\|\s*undefined)?/g, "")
        .replace(/:\s*RegExpExecArray\s*\|\s*null/g, "")
        .replace(/:\s*RegExp\[\]/g, "")
        .replace(/\s+as\s+Error/g, "");
}

// Mirrors the real source's own construction (see ai-reference-guard.ts's
// DEFAULT_WORDLIST_CANDIDATES block) exactly, just rooted at this process's real
// extensionPath/homedir() instead of an ES module's own import.meta.url.
const RELATIVE_WORDLIST_PATH = new URL("../banned-ai-terms.txt", pathToFileURL(extensionPath));
const HOMEDIR_WORDLIST_PATH = join(homedir(), ".pi", "agent", "banned-ai-terms.txt");
const DEFAULT_WORDLIST_CANDIDATES = [RELATIVE_WORDLIST_PATH, HOMEDIR_WORDLIST_PATH];

const resolveWordlistPathBody = stripTypes(extractBlock(/function resolveWordlistPath\(\): string \| URL \{([\s\S]*?)\n\}/, "resolveWordlistPath"));
const loadWordlistPatternsBody = stripTypes(extractBlock(/function loadWordlistPatterns\(\): RegExp\[\] \{([\s\S]*?)\n\}/, "loadWordlistPatterns"));
const parseWordlistBody = stripTypes(extractBlock(/function parseWordlist\(text: string\): RegExp\[\] \{([\s\S]*?)\n\}/, "parseWordlist"));
const scrubQuotedBody = stripTypes(extractBlock(/function scrubQuoted\(command: string\): string \{([\s\S]*?)\n\}/, "scrubQuoted"));
const collectQuotedContentBody = stripTypes(extractBlock(/function collectQuotedContent\(command: string\): string \{([\s\S]*?)\n\}/, "collectQuotedContent"));
const matchCommandBody = stripTypes(extractBlock(/function matchCommand\(command: string, wordlistPatterns: RegExp\[\]\): string \| undefined \{([\s\S]*?)\n\}/, "matchCommand"));
const commitShapedSrc = extractBlock(/const COMMIT_SHAPED_PATTERNS: RegExp\[\] = \[([\s\S]*?)\n\];/, "COMMIT_SHAPED_PATTERNS");
const noVerifySrc = extractBlock(/const NO_VERIFY_PATTERNS: RegExp\[\] = \[([\s\S]*?)\n\];/, "NO_VERIFY_PATTERNS");

const handlerStart = "export default function (pi: ExtensionAPI) {";
const startIdx = source.indexOf(handlerStart);
if (startIdx === -1) {
    throw new Error("default export not found in " + extensionPath);
}
const onCallMatch = source
    .slice(startIdx)
    .match(/pi\.on\("tool_call", async \(event\) => \{([\s\S]*?)\n\t\}\);/);
if (!onCallMatch) {
    throw new Error("tool_call handler body not found in " + extensionPath);
}
const handlerBody = stripTypes(onCallMatch[1]);

const COMMIT_SHAPED_PATTERNS = eval("[" + commitShapedSrc + "]");
const NO_VERIFY_PATTERNS = eval("[" + noVerifySrc + "]");

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
const resolveWordlistPath = new Function("existsSync", "DEFAULT_WORDLIST_CANDIDATES", "process", resolveWordlistPathBody);
const loadWordlistPatterns = new Function(
    "resolveWordlistPath",
    "readFileSync",
    "parseWordlist",
    "let cachedWordlistPatterns;\n" + loadWordlistPatternsBody,
);
// isRepoScopedIn is stubbed always-true here — repo scoping itself is exercised
// separately (see Invoke-IsRepoScopedIn above) against real throwaway repos.
const isToolCallEventType = () => true;
const isRepoScopedIn = () => true;
const handler = new Function(
    "isToolCallEventType",
    "isRepoScopedIn",
    "loadWordlistPatterns",
    "resolveWordlistPath",
    "matchCommand",
    "process",
    "event",
    handlerBody,
);

const resolvedPath = String(
    resolveWordlistPath(existsSync, DEFAULT_WORDLIST_CANDIDATES, process),
);
const boundResolveWordlistPath = () => resolveWordlistPath(existsSync, DEFAULT_WORDLIST_CANDIDATES, process);
const boundLoadWordlistPatterns = () => loadWordlistPatterns(boundResolveWordlistPath, readFileSync, parseWordlist);
const boundMatchCommand = (cmd, wordlistPatterns) =>
    matchCommand(cmd, wordlistPatterns, scrubQuoted, collectQuotedContent, COMMIT_SHAPED_PATTERNS, NO_VERIFY_PATTERNS);
const result = handler(
    isToolCallEventType,
    isRepoScopedIn,
    boundLoadWordlistPatterns,
    boundResolveWordlistPath,
    boundMatchCommand,
    process,
    { input: { command } },
);

process.stdout.write(JSON.stringify({ resolvedPath, result: result ?? null }));
'@ | Set-Content -Path $script:WordlistResolutionHarness -NoNewline -Encoding utf8

    function Invoke-WordlistResolutionHandler {
        param([string] $HomeOverride, [string] $Command = 'git commit -m "fix"')
        $output = & node $script:WordlistResolutionHarness $script:ExtensionFile $HomeOverride $Command
        if ($LASTEXITCODE -ne 0) {
            throw "node harness failed: $output"
        }
        return $output | ConvertFrom-Json
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
            @{ Command = 'git commit -nm "Generated with Claude"' }
            @{ Command = 'git push --no-verify origin main' }
            @{ Command = 'SKIP_AI_REFERENCE_SCAN=1 git commit -m "fix"' }
            @{ Command = 'SKIP_GITLEAKS=1 git commit -m "fix"' }
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

        It 'does not regress a clean -am clustered short flag (no n present)' {
            $command = 'git commit -am "fix the login bug"'
            $results = Invoke-AiReferenceGuard -Command $command
            $results[$command] | Should -BeFalse
        }

        It 'allows a chained command where -n belongs to a different subcommand across a real embedded newline' {
            # An actual newline character (not literal backslash-n text) separating two
            # independent commands — the shape a newline-chained sequential command
            # actually takes. The second line's -n belongs to `git log`, not `git commit`,
            # so this must be allowed, not treated as commit -n/--no-verify.
            $command = "git commit -m ""fix""`ngit log -n 1"
            $results = Invoke-AiReferenceGuard -Command $command
            $results[$command] | Should -BeFalse
        }

        It 'still denies a genuine -n on the same line as commit, immediately before a newline' {
            $command = "git commit -m ""fix"" -n`necho done"
            $results = Invoke-AiReferenceGuard -Command $command
            $results[$command] | Should -BeTrue
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

    Context 'isRepoScopedIn repo scoping (real throwaway repos, mirroring pre-commit)' {
        It 'is scoped in for a Hollard HTTPS origin' {
            $repo = New-TestRepo -OriginUrl $script:HollardHttps
            Invoke-IsRepoScopedIn -Cwd $repo | Should -BeTrue
        }

        It 'is scoped in for a Hollard SSH origin' {
            $repo = New-TestRepo -OriginUrl $script:HollardSsh
            Invoke-IsRepoScopedIn -Cwd $repo | Should -BeTrue
        }

        It 'is scoped out for a GitHub origin' {
            $repo = New-TestRepo -OriginUrl $script:GitHubUrl
            Invoke-IsRepoScopedIn -Cwd $repo | Should -BeFalse
        }

        It 'is scoped out when there is no origin remote at all' {
            $repo = New-TestRepo -OriginUrl $null
            Invoke-IsRepoScopedIn -Cwd $repo | Should -BeFalse
        }

        It 'is scoped out when cwd is not a git repo' {
            $notARepo = Join-Path $TestDrive ('not-a-repo-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $notARepo -Force | Out-Null
            Invoke-IsRepoScopedIn -Cwd $notARepo | Should -BeFalse
        }
    }

    Context 'newly-recognized message flags (--discussion / --text / --query-parameters)' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = 'az boards work-item update --id 5 --discussion "Generated with Claude"' }
            @{ Command = 'az boards work-item comment add --id 5 --text "Written by Claude"' }
            @{ Command = 'az devops invoke --area wit --resource workitems --query-parameters "System.Description=Generated with Claude"' }
            @{ Command = 'az devops invoke --area wit --resource workitems --query-parameters System.Description=Generated-with-Claude' }
        ) {
            param($Command)
            $results = Invoke-AiReferenceGuard -Command $Command
            $results[$Command] | Should -BeTrue
        }

        It 'allows <Command>' -TestCases @(
            @{ Command = 'az boards work-item update --id 5 --discussion "Looks good"' }
            @{ Command = 'az boards work-item comment add --id 5 --text "Reviewed and approved"' }
            @{ Command = 'az devops invoke --area wit --resource workitems --query-parameters "System.Description=Normal work"' }
        ) {
            param($Command)
            $results = Invoke-AiReferenceGuard -Command $Command
            $results[$Command] | Should -BeFalse
        }
    }

    Context 'SKIP-var deny survives quoting the value' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = "SKIP_GITLEAKS='1' git commit -m ""fix""" }
            @{ Command = 'SKIP_GITLEAKS="1" git commit -m "fix"' }
            @{ Command = "SKIP_AI_REFERENCE_SCAN='1' git commit -m ""fix""" }
            @{ Command = 'export SKIP_GITLEAKS=1; git commit -m "fix"' }
        ) {
            param($Command)
            $results = Invoke-AiReferenceGuard -Command $Command
            $results[$Command] | Should -BeTrue
        }
    }

    Context 'SKIP-var deny survives a newline-separated segment' {
        It 'blocks <Command>' -TestCases @(
            @{ Command = "true`nSKIP_AI_REFERENCE_SCAN=1 git commit -m ""clean""" }
            @{ Command = "true`nSKIP_GITLEAKS=1 git commit -m ""clean""" }
        ) {
            param($Command)
            $results = Invoke-AiReferenceGuard -Command $Command
            $results[$Command] | Should -BeTrue
        }

        It 'does not false-positive on prose that mentions the var name across a newline without an assignment' {
            $command = "This fixes the login bug`nrelated to SKIP_GITLEAKS handling elsewhere"
            $results = Invoke-AiReferenceGuard -Command $command
            $results[$command] | Should -BeFalse
        }
    }

    Context 'clustered -n short flag (e.g. -nm) is detected as --no-verify' {
        It 'still finds the clustered -m message value via collectQuotedContent, matching -am' {
            $commands = @('git commit -nm "msg"', 'git commit -am "msg"')
            $collected = Invoke-CollectQuotedContent -Command $commands
            $collected['git commit -nm "msg"'] | Should -Match 'msg'
            $collected['git commit -am "msg"'] | Should -Match 'msg'
        }
    }

    Context 'isRepoScopedIn follows a command''s own -C target over process.cwd()' {
        It 'is scoped in via -C when cwd itself is unscoped' {
            $hollardRepo = New-TestRepo -OriginUrl $script:HollardHttps
            $unscopedCwd = New-TestRepo -OriginUrl $script:GitHubUrl
            $command = "git -C ""$hollardRepo"" commit -m ""Generated with Claude"""
            Invoke-IsRepoScopedIn -Cwd $unscopedCwd -Command $command | Should -BeTrue
        }

        It 'is scoped out via -C when the -C target is not Hollard, even if cwd is' {
            $githubRepo = New-TestRepo -OriginUrl $script:GitHubUrl
            $hollardCwd = New-TestRepo -OriginUrl $script:HollardHttps
            $command = "git -C ""$githubRepo"" commit -m ""fix"""
            Invoke-IsRepoScopedIn -Cwd $hollardCwd -Command $command | Should -BeFalse
        }

        It 'falls back to cwd when the command carries no -C flag' {
            $hollardCwd = New-TestRepo -OriginUrl $script:HollardHttps
            Invoke-IsRepoScopedIn -Cwd $hollardCwd -Command 'git commit -m "fix"' | Should -BeTrue
        }
    }

    Context 'isRepoScopedIn does not execute shell metacharacters in a malicious -C path (command injection)' {
        It 'treats a crafted -C value as a literal non-existent path, executing no injected command' {
            $repo = New-TestRepo -OriginUrl $script:HollardHttps
            $marker = Join-Path $TestDrive ('pwned-' + [guid]::NewGuid() + '.txt')
            # Breaks out of the `git -C "${dashCPath}" ...` double-quoted shell interpolation
            # the vulnerable code used to build: closes the quote, chains an `echo` that
            # writes a marker file via cmd.exe's `&` separator, then reopens/closes a dummy
            # quoted span so the rest of the injected command string still parses. Wrapped in
            # single quotes in the SCANNED command so extractDashCPath's own regex (which
            # allows any non-single-quote content, including embedded double quotes and `&`,
            # inside a single-quoted -C value) extracts it whole.
            $malicious = "x`" & echo INJECTED > `"$marker`" & echo `""
            $command = "git -C '$malicious' commit -m ""fix"""

            Invoke-IsRepoScopedIn -Cwd $repo -Command $command | Should -BeFalse
            Test-Path $marker | Should -BeFalse
        }
    }

    Context 'DEFAULT_WORDLIST_PATH resolution falls back past the junction-broken relative candidate' {
        It 'fails closed with the real {block, reason} shape when neither candidate exists' {
            $emptyHome = Join-Path $TestDrive ('empty-home-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $emptyHome -Force | Out-Null

            $outcome = Invoke-WordlistResolutionHandler -HomeOverride $emptyHome -Command 'git commit -m "fix"'

            $outcome.result | Should -Not -BeNullOrEmpty
            $outcome.result.block | Should -BeTrue
            $outcome.result.reason | Should -Match 'wordlist unreadable'
        }

        It 'resolves and loads the wordlist from the homedir fallback candidate when the relative one is missing' {
            $fakeHome = Join-Path $TestDrive ('fake-home-' + [guid]::NewGuid())
            $wordlistDir = Join-Path $fakeHome '.pi/agent'
            New-Item -ItemType Directory -Path $wordlistDir -Force | Out-Null
            Copy-Item -Path $script:WordlistFile -Destination (Join-Path $wordlistDir 'banned-ai-terms.txt')

            $outcome = Invoke-WordlistResolutionHandler -HomeOverride $fakeHome -Command 'git commit -m "Generated with Claude"'

            $outcome.resolvedPath | Should -Match 'fake-home.*\.pi[/\\]agent[/\\]banned-ai-terms\.txt'
            $outcome.result | Should -Not -BeNullOrEmpty
            $outcome.result.block | Should -BeTrue
            $outcome.result.reason | Should -Match 'blocklist'
        }

        It 'allows a clean command when the homedir-fallback wordlist has no match' {
            $fakeHome = Join-Path $TestDrive ('fake-home-clean-' + [guid]::NewGuid())
            $wordlistDir = Join-Path $fakeHome '.pi/agent'
            New-Item -ItemType Directory -Path $wordlistDir -Force | Out-Null
            Copy-Item -Path $script:WordlistFile -Destination (Join-Path $wordlistDir 'banned-ai-terms.txt')

            $outcome = Invoke-WordlistResolutionHandler -HomeOverride $fakeHome -Command 'git commit -m "fix the login bug"'

            $outcome.result | Should -BeNullOrEmpty
        }
    }
}
