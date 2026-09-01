// ai-reference-guard.ts
// Pi tool_call extension — blocks AI/Claude/Codex/Copilot/co-authored-by references from
// being written into a commit, PR, or Azure Boards item via Pi (issue #219, layer 5). This
// replaces a prompt-level rule that already failed once: a hard block at the tool-call
// boundary instead of an instruction the model can forget or override.
//
// Sibling to git-guardrails.ts — same tool_call event shape, same isToolCallEventType
// narrowing, same quote-handling problem — but NOT the same solution. git-guardrails.ts's
// scrubQuoted deletes non-flag quoted content so a destructive phrase inside a commit
// MESSAGE can't false-match a command-SHAPE pattern (e.g. "push" inside -m text). This
// extension needs the opposite for the wordlist check: the banned term usually lives
// INSIDE the quoted message/title/body content on purpose (that's the leak this guards
// against), so scrubbing it away before matching would silently defeat the check on its
// own target case (`git commit -m "Generated with Claude"` must still block). So command
// SHAPE is matched against the scrubbed string (ported logic, kept in sync in spirit —
// git-guardrails.ts does not export scrubQuoted, so it is duplicated here), while the
// WORDLIST is matched only against the content of quoted spans collected from the raw,
// unscrubbed command — not the whole raw command string, which would false-positive on
// this repo's own `claude/` and `codex/` directory names (e.g. `cd codex && git commit -m
// "fix"`).
//
// Wordlist: ai-agents/_shared/banned-ai-terms.txt, one case-insensitive ERE per line,
// \b-bounded, '#' comments and blank lines ignored — read fresh from the extension's own
// directory (a Pi-projected sibling file, see pi/README.md), never hardcoded here. Missing
// or unreadable wordlist fails CLOSED (blocks with a reason naming the path); every other
// non-match condition fails open, matching git-guardrails.ts's own posture.
//
// Discovered automatically by Pi from `~/.pi/agent/extensions/*.ts` (a single file needs
// no package.json/npm dependencies) — see pi/README.md for the projection mechanism.
// The wordlist file needs its own New-FileSymlink call in setup.ps1 (not this extension's
// concern — see pi/README.md and the PR description for the exact call).

import { readFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

// Default wordlist location: a sibling file next to this extension module inside the
// junctioned pi/extensions/ directory at runtime, resolved relative to this module's own
// location (not process.cwd(), which is unrelated to where Pi loaded this file from).
// Overridable via PI_AI_REFERENCE_WORDLIST_PATH so tests can point at a fixture file
// without depending on this machine's actual Pi projection under homedir() — mirrors the
// PI_PROJECT_BRAIN_SESSION_START_SCRIPT override in project-brain-autoload.ts.
const DEFAULT_WORDLIST_PATH = new URL("./banned-ai-terms.txt", import.meta.url);

// Parses banned-ai-terms.txt's documented format (one case-insensitive ERE per line,
// '#'-prefixed comments and blank lines ignored) into compiled RegExp patterns. Pure and
// deterministic so a wordlist edit changes behavior without touching this file.
function parseWordlist(text: string): RegExp[] {
	return text
		.split(/\r?\n/)
		.map((line) => line.trim())
		.filter((line) => line.length > 0 && !line.startsWith("#"))
		.map((line) => new RegExp(line, "i"));
}

// Same quote-scrubbing approach as git-guardrails.ts's scrubQuoted, duplicated here (not
// imported — git-guardrails.ts does not export it) and kept in sync in spirit: deletes
// non-flag quoted content so command-SHAPE patterns below can't false-match on prose
// inside a quoted string, while unwrapping flag-shaped quoted content in place so e.g.
// `git commit -m "--no-verify"` still matches shape/no-verify patterns the same way an
// unquoted flag would in the shell.
function scrubQuoted(command: string): string {
	const unwrap = (_match: string, inner: string): string =>
		/^-{1,2}[A-Za-z][A-Za-z-]*$/.test(inner) ? inner : "";
	return command.replace(
		/"((?:\\.|[^"\\])*)"|'([^']*)'/g,
		(match: string, doubleQuoted: string | undefined, singleQuoted: string | undefined) =>
			unwrap(match, doubleQuoted !== undefined ? doubleQuoted : singleQuoted ?? ""),
	);
}

// Collects the content of every quoted span in the RAW (unscrubbed) command — the exact
// spans scrubQuoted would delete. The wordlist is matched against this, not the scrubbed
// command and not the whole raw command string: a banned term usually sits deliberately
// inside a -m message / --title / --body / --fields value, and matching the whole raw
// command would false-positive on this repo's own `claude/` and `codex/` path segments.
function collectQuotedContent(command: string): string {
	const spans: string[] = [];
	const pattern = /"((?:\\.|[^"\\])*)"|'([^']*)'/g;
	let match: RegExpExecArray | null = pattern.exec(command);
	while (match !== null) {
		spans.push(match[1] !== undefined ? match[1] : (match[2] ?? ""));
		match = pattern.exec(command);
	}
	return spans.join("\n");
}

// Command shapes where a banned term would land in a durable commit/PR/work-item record.
// Matched against the scrubbed command so shape detection isn't defeated by unrelated
// prose inside quoted content (mirrors git-guardrails.ts's BLOCKED_PATTERNS approach).
const COMMIT_SHAPED_PATTERNS: RegExp[] = [
	/git\s+(.*\s+)?commit(\s|$)/,
	/gh\s+pr\s+(create|edit)(\s|$)/,
	/az\s+repos\s+pr\s+(create|update)(\s|$)/,
	/az\s+boards(\s|$)/,
	/az\s+devops\s+invoke(\s|$)/,
];

// Unconditional denies: these bypass the commit/push hooks that would otherwise catch a
// banned reference, regardless of wordlist content. -n is git commit's own --no-verify
// short flag; git push's own -n means --dry-run, not --no-verify, so the alternation is
// deliberately NOT shared across both commands.
const NO_VERIFY_PATTERNS: RegExp[] = [
	/git\s+(.*\s+)?commit\s.*(--no-verify|-n\b)/,
	/git\s+(.*\s+)?push\s.*--no-verify/,
];

// Pure matcher: given a raw command string and an already-parsed wordlist, returns a
// block reason or undefined to allow. No I/O — the caller owns reading the wordlist file,
// so this stays testable without a filesystem.
function matchCommand(command: string, wordlistPatterns: RegExp[]): string | undefined {
	const scrubbed = scrubQuoted(command);

	for (const pattern of NO_VERIFY_PATTERNS) {
		if (pattern.test(scrubbed)) {
			return `Blocked: does not have authority to run "${command}" — this command bypasses commit/push verification hooks.`;
		}
	}

	const isCommitShaped = COMMIT_SHAPED_PATTERNS.some((pattern) => pattern.test(scrubbed));
	if (!isCommitShaped) {
		return undefined;
	}

	const quotedContent = collectQuotedContent(command);
	const hasBannedTerm = wordlistPatterns.some((pattern) => pattern.test(quotedContent));
	if (!hasBannedTerm) {
		return undefined;
	}

	return `Blocked: does not have authority to run "${command}" — this command's message content matches the AI-reference blocklist.`;
}

let cachedWordlistPatterns: RegExp[] | undefined;

// Reads and parses the wordlist, caching the compiled patterns after the first success.
// Throws on a missing/unreadable file — the caller (the tool_call handler below) is
// responsible for turning that into a fail-closed block, per the locked contract: fail
// closed ONLY when the wordlist itself is missing or unreadable.
function loadWordlistPatterns(): RegExp[] {
	if (cachedWordlistPatterns) {
		return cachedWordlistPatterns;
	}
	const wordlistPath = process.env.PI_AI_REFERENCE_WORDLIST_PATH ?? DEFAULT_WORDLIST_PATH;
	const text = readFileSync(wordlistPath, "utf8");
	cachedWordlistPatterns = parseWordlist(text);
	return cachedWordlistPatterns;
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event) => {
		if (!isToolCallEventType("bash", event)) {
			return;
		}

		const command = event.input.command;

		let wordlistPatterns: RegExp[];
		try {
			wordlistPatterns = loadWordlistPatterns();
		} catch (error) {
			const wordlistPath = process.env.PI_AI_REFERENCE_WORDLIST_PATH ?? DEFAULT_WORDLIST_PATH;
			return {
				block: true,
				reason: `Blocked: AI-reference wordlist unreadable at "${String(wordlistPath)}" (${(error as Error).message}) — failing closed rather than allowing an unscanned commit/PR/work-item command.`,
			};
		}

		const reason = matchCommand(command, wordlistPatterns);
		if (reason) {
			return { block: true, reason };
		}
	});
}
