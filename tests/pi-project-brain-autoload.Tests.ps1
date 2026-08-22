#Requires -Version 7
# Behavioural tests for pi/extensions/project-brain-autoload.ts — the Pi before_agent_start
# extension that injects the active project-brain initiative's core.md + STATUS.md once per
# session (#187), by shelling out to the same session-start.ps1 the Claude Code and Codex
# hooks run (ai-agents/skills/project-brain/scripts/session-start.ps1).
#
# Only `import type { ExtensionAPI }` is non-erasable-at-runtime, so unlike
# pi-git-guardrails.Tests.ps1 (which imports a real, non-type-only symbol from
# @earendil-works/pi-coding-agent) this file can be imported directly by node's built-in
# TypeScript type-stripping (--experimental-strip-types) without the package installed as
# a project dependency.
#
# resolveBrainContext takes its script path as a parameter specifically so these tests can
# point it at fixture pwsh scripts instead of depending on this machine's real Pi
# projection (~/.pi/agent/skills/project-brain/scripts/session-start.ps1) or a registered
# project-brain (~/.claude/project-brain/brains.json) — this suite pins the stdin/stdout
# JSON contract the real script honors, not this machine's brain state.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:ExtensionFile = Join-Path $script:RepoRoot 'pi/extensions/project-brain-autoload.ts'

    if (-not (Test-Path $script:ExtensionFile)) {
        throw "Extension file not found: $script:ExtensionFile"
    }

    # Node harness: imports the real extension module (type-stripped, no external package
    # needed since the only non-builtin import is type-only), registers a fake `pi` object
    # to capture the before_agent_start handler, then invokes it with a fixture ctx.cwd and
    # a fixture scriptPath monkey-patched in place of the module's hardcoded
    # SESSION_START_SCRIPT via a query-string trick is not possible for a const, so instead
    # this harness re-implements the call by importing resolveBrainContext indirectly: it
    # invokes the handler twice against the *real* SESSION_START_SCRIPT path (which may not
    # exist on this machine) purely to pin the once-per-session gate, and separately drives
    # resolveBrainContext's stdin/stdout JSON contract directly against fixture scripts by
    # requiring the module and reaching into its non-exported function is not possible in
    # ESM — so the contract is instead pinned by extracting resolveBrainContext's source
    # text verbatim (plain JS after stripping TS annotations) and evaluating it against
    # fixture scripts, matching the extraction approach in pi-git-guardrails.Tests.ps1.
    $script:ContractHarness = Join-Path $TestDrive 'run-resolve.mjs'
    @'
import { readFileSync } from "node:fs";
import { execFile } from "node:child_process";

const [, , extensionPath, cwd, scriptPath] = process.argv;
const source = readFileSync(extensionPath, "utf8");

const fnMatch = source.match(/function resolveBrainContext\(cwd: string, scriptPath: string\): Promise<string \| undefined> \{([\s\S]*?)\n\}\n\nexport default/);
if (!fnMatch) {
    throw new Error("resolveBrainContext function not found in " + extensionPath);
}
// Strip TS-only type annotations so plain node can eval the body.
const body = fnMatch[1]
    .replace(/: string/g, "")
    .replace(/: Promise<string \| undefined>/g, "");
const resolveBrainContext = new Function("cwd", "scriptPath", "execFile", "return " + `(function (cwd, scriptPath) {${body}})(cwd, scriptPath)`);

const result = await resolveBrainContext(cwd, scriptPath, execFile);
process.stdout.write(JSON.stringify({ result: result === undefined ? null : result }));
'@ | Set-Content -Path $script:ContractHarness -NoNewline -Encoding utf8

    function Invoke-ResolveBrainContext {
        param([string] $Cwd, [string] $ScriptPath)

        $output = & node --experimental-strip-types $script:ContractHarness $script:ExtensionFile $Cwd $ScriptPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "node harness failed: $output"
        }
        return ($output | ConvertFrom-Json).result
    }

    # Fixture scripts mimicking session-start.ps1's own contract shapes.
    $script:MatchScript = Join-Path $TestDrive 'match.ps1'
    @'
$null = [Console]::In.ReadToEnd()
@{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = '[project-brain] fixture context' } } | ConvertTo-Json -Compress
'@ | Set-Content -Path $script:MatchScript -NoNewline -Encoding utf8

    $script:NoMatchScript = Join-Path $TestDrive 'nomatch.ps1'
    @'
$null = [Console]::In.ReadToEnd()
exit 0
'@ | Set-Content -Path $script:NoMatchScript -NoNewline -Encoding utf8

    $script:MalformedScript = Join-Path $TestDrive 'malformed.ps1'
    @'
$null = [Console]::In.ReadToEnd()
Write-Output 'not json'
'@ | Set-Content -Path $script:MalformedScript -NoNewline -Encoding utf8

    $script:ErrorScript = Join-Path $TestDrive 'error.ps1'
    @'
$null = [Console]::In.ReadToEnd()
exit 1
'@ | Set-Content -Path $script:ErrorScript -NoNewline -Encoding utf8
}

Describe 'pi/extensions/project-brain-autoload.ts' {
    Context 'resolveBrainContext contract' {
        It 'returns additionalContext when the script matches an initiative' {
            $result = Invoke-ResolveBrainContext -Cwd 'C:/some/dir' -ScriptPath $script:MatchScript
            $result | Should -Be '[project-brain] fixture context'
        }

        It 'round-trips multi-byte characters read from disk' {
            # Pins the fix for a real bug found manually while implementing this extension:
            # PowerShell 7 falls back to the legacy OEM codepage for stdout when pwsh is
            # spawned with no attached console (as Node's execFile does), silently replacing
            # multi-byte characters (e.g. "→", read via Get-Content -Raw off a UTF-8 file —
            # a PowerShell string literal round-trips fine regardless and would not
            # reproduce it) with SUB (0x1A), corrupting ConvertTo-Json's own output into
            # invalid JSON. Confirmed manually (not reliably reproducible in *this* suite):
            # a pwsh child inherits an already-UTF-8 console codepage from this test run's
            # own pwsh-hosted Pester process, so reverting resolveBrainContext's explicit
            # [Console]::OutputEncoding preamble does not fail this assertion here even
            # though it does fail in Pi's actual runtime (no attached console). This test
            # still pins the correct end-to-end behavior; it just isn't a hermetic proof of
            # the regression by itself.
            $unicodeContentFile = Join-Path $TestDrive 'unicode-content.md'
            "edit -> commit: $([char]0x2192) done`n" | Set-Content -Path $unicodeContentFile -NoNewline -Encoding utf8

            $unicodeScript = Join-Path $TestDrive 'unicode.ps1'
            @'
$content = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'unicode-content.md') -Raw
$null = [Console]::In.ReadToEnd()
@{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $content } } | ConvertTo-Json -Compress
'@ | Set-Content -Path $unicodeScript -NoNewline -Encoding utf8

            $result = Invoke-ResolveBrainContext -Cwd 'C:/some/dir' -ScriptPath $unicodeScript
            $result | Should -Be "edit -> commit: $([char]0x2192) done`n"
        }

        It 'returns nothing when the script has no match (empty output, exit 0)' {
            $result = Invoke-ResolveBrainContext -Cwd 'C:/some/dir' -ScriptPath $script:NoMatchScript
            $result | Should -BeNullOrEmpty
        }

        It 'returns nothing when the script outputs malformed JSON' {
            $result = Invoke-ResolveBrainContext -Cwd 'C:/some/dir' -ScriptPath $script:MalformedScript
            $result | Should -BeNullOrEmpty
        }

        It 'returns nothing when the script exits non-zero' {
            $result = Invoke-ResolveBrainContext -Cwd 'C:/some/dir' -ScriptPath $script:ErrorScript
            $result | Should -BeNullOrEmpty
        }

        It 'returns nothing when the script path does not exist' {
            $missing = Join-Path $TestDrive 'does-not-exist.ps1'
            $result = Invoke-ResolveBrainContext -Cwd 'C:/some/dir' -ScriptPath $missing
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'session-start.ps1 stdin contract' {
        It 'passes cwd to the script as SessionStart-shaped JSON on stdin' {
            $echoScript = Join-Path $TestDrive 'echo-cwd.ps1'
            @'
$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
@{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = "cwd was: $($payload.cwd)" } } | ConvertTo-Json -Compress
'@ | Set-Content -Path $echoScript -NoNewline -Encoding utf8

            $result = Invoke-ResolveBrainContext -Cwd 'E:/Personal Projects/dotfiles/main' -ScriptPath $echoScript
            $result | Should -Be 'cwd was: E:/Personal Projects/dotfiles/main'
        }
    }

    Context 'extension handler behavior (real import, not source-text matching)' {
        # Imports the real default-exported factory (node --experimental-strip-types, per
        # the file header) against a fixture script pointed to via
        # PI_PROJECT_BRAIN_SESSION_START_SCRIPT, so these tests exercise the actual
        # before_agent_start/session_start handlers and the real returned message shape,
        # not a regex over the source text (issue found in review: a handler that changed
        # behavior while keeping the matched substrings would previously still pass).
        BeforeAll {
            $script:HandlerHarness = Join-Path $TestDrive 'run-handler.mjs'
            @'
import { pathToFileURL } from "node:url";

const [, , extensionPath, cwdArg] = process.argv;
// A giant cwd is requested via a sentinel rather than passed literally, since a real
// 200KB argument would blow past the Windows command-line length limit for node.exe
// itself (unrelated to the pwsh child this is meant to stress).
const cwd = cwdArg === "__LONG_CWD__" ? `C:/${"x".repeat(200000)}` : cwdArg;
const mod = (await import(pathToFileURL(extensionPath).href)).default;

const handlers = {};
const fakePi = {
    on(event, handler) {
        (handlers[event] ??= []).push(handler);
    },
};
mod(fakePi);

const beforeAgentStart = handlers.before_agent_start?.[0];
const sessionStart = handlers.session_start?.[0];

const ctx = { cwd };
const call = () => beforeAgentStart({ type: "before_agent_start" }, ctx);

const result1 = (await call()) ?? null;
const result2 = (await call()) ?? null;
if (sessionStart) {
    await sessionStart({ type: "session_start", reason: "new" }, ctx);
}
const result3 = (await call()) ?? null;

process.stdout.write(JSON.stringify({
    sessionStartRegistered: Boolean(sessionStart),
    result1,
    result2,
    result3,
}));
'@ | Set-Content -Path $script:HandlerHarness -NoNewline -Encoding utf8

            # Fixture project-brain script: always matches, echoing which cwd it saw.
            $script:FixtureBrainScript = Join-Path $TestDrive 'fixture-session-start.ps1'
            @'
$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
@{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = "[project-brain] fixture for $($payload.cwd)" } } | ConvertTo-Json -Compress
'@ | Set-Content -Path $script:FixtureBrainScript -NoNewline -Encoding utf8

            function Invoke-Handler {
                param([string] $Cwd, [string] $ScriptPath)

                $env:PI_PROJECT_BRAIN_SESSION_START_SCRIPT = $ScriptPath
                try {
                    $output = & node --experimental-strip-types $script:HandlerHarness $script:ExtensionFile $Cwd
                    if ($LASTEXITCODE -ne 0) {
                        throw "node harness failed (exit $LASTEXITCODE): $output"
                    }
                    return ($output | ConvertFrom-Json)
                } finally {
                    Clear-Item Env:\PI_PROJECT_BRAIN_SESSION_START_SCRIPT -ErrorAction SilentlyContinue
                }
            }
        }

        It 'injects once, gates the rest of the session, then injects again after a new session_start' {
            $r = Invoke-Handler -Cwd 'C:/some/dir' -ScriptPath $script:FixtureBrainScript

            $r.result1.message.customType | Should -Be 'project-brain'
            $r.result1.message.content | Should -Be '[project-brain] fixture for C:/some/dir'
            $r.result1.message.display | Should -BeTrue

            $r.result2 | Should -BeNullOrEmpty

            $r.sessionStartRegistered | Should -BeTrue
            $r.result3 | Should -Not -BeNullOrEmpty
            $r.result3.message.customType | Should -Be 'project-brain'
        }

        It 'does not crash the host process when the script exits before reading stdin (EPIPE on a large payload)' {
            $fastExitScript = Join-Path $TestDrive 'fast-exit.ps1'
            'exit 0' | Set-Content -Path $fastExitScript -NoNewline -Encoding utf8

            # A long cwd increases the odds the write hits the pipe after the child has
            # already exited without draining stdin, reproducing the EPIPE this pins. The
            # harness expands this sentinel internally to avoid a 200KB CLI argument.
            { Invoke-Handler -Cwd '__LONG_CWD__' -ScriptPath $fastExitScript } | Should -Not -Throw
        }
    }
}
