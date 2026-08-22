// project-brain-autoload.ts
// Pi before_agent_start extension — injects the active project-brain initiative's
// core.md + STATUS.md once per session, mirroring Claude Code's SessionStart hook and
// Codex's PreToolUse-adjacent SessionStart hook (#186).
//
// Rather than reimplementing the resolve-and-read procedure (in-repo .claude/brain/ ->
// global brains.json -> registry.json -> initiative) in TypeScript, this shells out to
// the same script Claude Code's and Codex's own hooks run:
// ai-agents/skills/project-brain/scripts/session-start.ps1, projected to
// ~/.pi/agent/skills/project-brain/scripts/session-start.ps1. That script already reads
// a SessionStart-shaped JSON payload ({ cwd }) on stdin and, on a match, writes
// { hookSpecificOutput: { additionalContext } } JSON to stdout; on no match or any error
// it fails safe with empty output. This extension feeds it ctx.cwd and forwards
// additionalContext as a custom message, so the resolver logic has exactly one
// implementation across all three runtimes.
//
// `session_start` alone can't inject context into the conversation (side-effect only per
// #77's research) - only `before_agent_start` can return a message, so injection happens
// there instead, gated by the `injected` flag. The flag is reset on `session_start`
// (fired on new/resume/fork/reload, not just process startup) rather than relying on the
// extension factory being re-invoked per session: the factory closure alone cannot be
// trusted to reset per session boundary, so the gate is scoped explicitly.
//
// Discovered automatically by Pi from `~/.pi/agent/extensions/*.ts` (a single file needs
// no package.json/npm dependencies) — see pi/README.md for the projection mechanism.

import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Overridable via PI_PROJECT_BRAIN_SESSION_START_SCRIPT so tests can point the real
// default-exported handler at a fixture script without depending on this machine's
// actual Pi projection under homedir().
const SESSION_START_SCRIPT =
	process.env.PI_PROJECT_BRAIN_SESSION_START_SCRIPT ??
	join(homedir(), ".pi", "agent", "skills", "project-brain", "scripts", "session-start.ps1");

// Runs session-start.ps1 the same way the Claude Code / Codex hooks do: a SessionStart-
// shaped JSON payload on stdin, hookSpecificOutput.additionalContext parsed from stdout.
// Returns undefined on any failure or no-match (the script's own fail-safe output), so
// the caller can silently skip injection rather than surface a broken session. scriptPath
// is a parameter (not a closed-over constant) so tests can point it at a fixture script
// without depending on this machine's actual Pi projection.
//
// Runs via `-Command` (not `-File`) with an explicit UTF-8 [Console]::OutputEncoding
// preamble: PowerShell 7 on Windows falls back to the legacy OEM codepage for stdout when
// spawned without an attached console (Node's execFile pipes it), silently replacing
// multi-byte characters (e.g. "→") with SUB (0x1A) and breaking ConvertTo-Json's own
// output — invalid JSON with an embedded control character. Scoped to this call site only
// (not a session-start.ps1 change) so Claude Code's and Codex's own hook invocations are
// untouched.
function resolveBrainContext(cwd: string, scriptPath: string): Promise<string | undefined> {
	return new Promise((resolve) => {
		const child = execFile(
			"pwsh",
			[
				"-NoProfile",
				"-Command",
				"[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(); & $env:PROJECT_BRAIN_SESSION_START_SCRIPT",
			],
			{
				timeout: 10_000,
				maxBuffer: 10 * 1024 * 1024,
				env: { ...process.env, PROJECT_BRAIN_SESSION_START_SCRIPT: scriptPath },
			},
			(error, stdout) => {
				if (error || !stdout?.trim()) {
					resolve(undefined);
					return;
				}
				try {
					const parsed = JSON.parse(stdout);
					const context = parsed?.hookSpecificOutput?.additionalContext;
					resolve(typeof context === "string" && context ? context : undefined);
				} catch {
					resolve(undefined);
				}
			},
		);
		// Node emits 'error' on this stream asynchronously if the write is aborted (a
		// destroyed pipe after spawn failure, or EPIPE from a child that exits before
		// reading stdin) - unhandled, that throws an uncaughtException in the host Pi
		// process instead of the fail-safe undefined this function otherwise always
		// resolves. execFile's own callback above already handles the corresponding
		// spawn/exit error; this only silences the separate stream-level event.
		child.stdin?.on("error", () => {});
		child.stdin?.end(JSON.stringify({ cwd }));
	});
}

export default function (pi: ExtensionAPI) {
	let injected = false;

	pi.on("session_start", () => {
		injected = false;
	});

	pi.on("before_agent_start", async (_event, ctx) => {
		if (injected) return;
		injected = true;

		const context = await resolveBrainContext(ctx.cwd, SESSION_START_SCRIPT);
		if (!context) return;

		return {
			message: {
				customType: "project-brain",
				content: context,
				display: true,
			},
		};
	});
}
