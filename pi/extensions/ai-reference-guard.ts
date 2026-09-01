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

import { existsSync, readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

// Default wordlist location: a sibling of the junctioned pi/extensions/ directory (NOT
// inside it — that directory is a whole-directory junction straight into this repo's
// pi/extensions/, so a file placed inside it at runtime would show up as an untracked
// file in the repo on every `setup.ps1 -Module pi` run), resolved relative to this
// module's own location (not process.cwd(), which is unrelated to where Pi loaded this
// file from).
//
// Two candidates, tried in order, because Node's ESM loader may or may not resolve
// import.meta.url THROUGH the pi/extensions/ junction (setup.ps1's `-Module pi`
// New-Junction from ~/.pi/agent/extensions to this repo's pi/extensions/):
//   1. RELATIVE_WORDLIST_PATH — "../banned-ai-terms.txt" relative to this module's
//      resolved URL. Correct when the loader preserves the junctioned path
//      (~/.pi/agent/extensions/ai-reference-guard.ts -> ~/.pi/agent/banned-ai-terms.txt,
//      the real symlink setup.ps1 installs there).
//   2. HOMEDIR_WORDLIST_PATH — the same installed path, but built directly from
//      homedir() instead of import.meta.url. Correct when the loader instead resolves
//      the junction to its target (this repo's real pi/extensions/ai-reference-guard.ts),
//      in which case "../banned-ai-terms.txt" would miss entirely (there is no
//      pi/banned-ai-terms.txt in this repo — it is never installed there).
// Overridable via PI_AI_REFERENCE_WORDLIST_PATH so tests can point at a fixture file
// without depending on either candidate — mirrors the
// PI_PROJECT_BRAIN_SESSION_START_SCRIPT override in project-brain-autoload.ts.
const RELATIVE_WORDLIST_PATH = new URL("../banned-ai-terms.txt", import.meta.url);
const HOMEDIR_WORDLIST_PATH = join(homedir(), ".pi", "agent", "banned-ai-terms.txt");
const DEFAULT_WORDLIST_CANDIDATES: (string | URL)[] = [RELATIVE_WORDLIST_PATH, HOMEDIR_WORDLIST_PATH];

// Picks the wordlist path to read: the env override when set, else the first candidate
// that exists on disk, else the first candidate (so a fail-closed error message names a
// real attempted path rather than an empty string).
function resolveWordlistPath(): string | URL {
	const override = process.env.PI_AI_REFERENCE_WORDLIST_PATH;
	if (override) {
		return override;
	}
	for (const candidate of DEFAULT_WORDLIST_CANDIDATES) {
		if (existsSync(candidate)) {
			return candidate;
		}
	}
	return DEFAULT_WORDLIST_CANDIDATES[0];
}

// Extracts a leading `git -C <path>` global flag's value from the raw command, if
// present — quoted or bare. Deliberately does NOT track `cd <path> &&` shell state (out
// of scope: this is a single regex over the command string, not a shell interpreter).
function extractDashCPath(command: string): string | undefined {
	const match = /(?:^|\s)-C(?:=|\s+)("(?:[^"\\]|\\.)*"|'[^']*'|\S+)/.exec(command);
	if (!match) {
		return undefined;
	}
	const raw = match[1];
	const doubleQuoted = /^"(.*)"$/.exec(raw);
	const singleQuoted = /^'(.*)'$/.exec(raw);
	return doubleQuoted ? doubleQuoted[1] : singleQuoted ? singleQuoted[1] : raw;
}

// Repo scoping, mirroring git/templates/hooks/pre-commit's own scoping (see that file's
// AI-reference section): this whole extension only applies inside a Hollard/Azure DevOps
// remote repo. `git remote get-url origin` runs against the command's own `-C <path>`
// target when the command carries one (e.g. `git -C E:/work/HollardRepo commit ...`
// run from an unscoped cwd) — otherwise against cwd (the extension's own inherited
// working directory, same as the bash ports use their inherited cwd). If it throws (not
// a repo, no origin) or the URL isn't both dev.azure.com AND HollardInsuranceRetail
// (case-insensitive), the repo is out of scope — a GitHub repo like dotfiles/wiki/brain
// legitimately says "Claude"/"Codex" in its own subject matter and must stay unscanned.
//
// SECURITY: dashCPath comes straight out of the model-controlled command string this
// whole extension exists to gate, so it must never be interpolated into a shell-
// interpreting exec call — a crafted `-C` value containing shell metacharacters (`"`,
// `&`, `;`, backticks, `$()`) would otherwise execute arbitrary commands BEFORE the tool
// call this hook is supposed to authorize has even run. execFileSync with an argv array
// never invokes a shell, so no metacharacter in dashCPath (or cwd) can be interpreted
// specially, regardless of quoting — used for both branches, including the non -C path,
// for consistency and defense-in-depth even though cwd isn't attacker-controlled the
// same way.
function isRepoScopedIn(cwd: string, command: string): boolean {
	const dashCPath = extractDashCPath(command);
	let originUrl: string;
	try {
		originUrl = dashCPath
			? execFileSync("git", ["-C", dashCPath, "remote", "get-url", "origin"], { cwd, encoding: "utf8" })
			: execFileSync("git", ["remote", "get-url", "origin"], { cwd, encoding: "utf8" });
	} catch {
		return false;
	}
	return /dev\.azure\.com/i.test(originUrl) && /HollardInsuranceRetail/i.test(originUrl);
}

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
// spans scrubQuoted would delete — plus the VALUE(s) of -m/--message/--title/--body/
// --description/--fields/--route-parameters arguments even when unquoted. The wordlist is
// matched against this, not the scrubbed command and not the whole raw command string: a
// banned term usually sits deliberately inside one of these values, and shell quoting is
// often unnecessary for it (a hyphenated value like `Generated-with-Claude`, or a `key=value`
// pair like `--fields System.Description=Generated-with-Claude`), so scanning only quoted
// spans misses that case entirely. Matching the whole raw command instead would false-
// positive on this repo's own `claude/` and `codex/` path segments, so the unquoted scan
// stays scoped to these named flags' values, not the whole command.
function collectQuotedContent(command: string): string {
	const spans: string[] = [];
	const quotePattern = /"((?:\\.|[^"\\])*)"|'([^']*)'/g;
	let match: RegExpExecArray | null = quotePattern.exec(command);
	while (match !== null) {
		spans.push(match[1] !== undefined ? match[1] : (match[2] ?? ""));
		match = quotePattern.exec(command);
	}

	const unquote = (raw: string): string => {
		const doubleQuoted = /^"(.*)"$/.exec(raw);
		const singleQuoted = /^'(.*)'$/.exec(raw);
		return doubleQuoted ? doubleQuoted[1] : singleQuoted ? singleQuoted[1] : raw;
	};

	// Single-value flags. `-[A-Za-z]*m` covers git's -m short flag alone or clustered with
	// other short flags (`-am`, `-sm`). `-t`/`-b` are gh's short forms of --title/--body,
	// scoped to `gh pr create|edit` commands only (isGhPr below) — those letters mean
	// something else for other commands (e.g. git commit -t <template-file>), so scanning
	// them everywhere would risk an unrelated false positive.
	const isGhPr = /(^|\s)gh\s+pr\s+(create|edit)(\s|$)/.test(command);
	const singleValueFlags = [
		"-[A-Za-z]*m",
		"--message",
		"--title",
		"--body",
		"--description",
		"--discussion",
		"--text",
	];
	if (isGhPr) {
		singleValueFlags.push("-t", "-b");
	}
	const singleValuePattern = new RegExp(
		`(?:^|\\s)(?:${singleValueFlags.join("|")})(?=[=\\s])(?:=|\\s+)("(?:\\\\.|[^"\\\\])*"|'[^']*'|[^\\s"']+)`,
		"g",
	);
	let singleMatch: RegExpExecArray | null = singleValuePattern.exec(command);
	while (singleMatch !== null) {
		spans.push(unquote(singleMatch[1]));
		singleMatch = singleValuePattern.exec(command);
	}

	// Multi-value flags: --fields/--route-parameters/--query-parameters take a run of
	// space-separated `key=value` pairs (e.g. `az boards work-item update --fields
	// System.Title=Fix System.Description=Generated-with-Claude`), so the whole run is
	// scanned, not just the first pair — stopping at the next `-`-prefixed flag, a shell
	// separator (`;`/`&`/`|`), or end of command.
	const multiValuePattern =
		/(?:^|\s)(?:--fields|--route-parameters|--query-parameters)(?=[=\s])(?:=|\s+)((?:"(?:\\.|[^"\\])*"|'[^']*'|[^\s"';&|-]\S*)(?:\s+(?:"(?:\\.|[^"\\])*"|'[^']*'|[^\s"';&|-]\S*))*)/g;
	let multiMatch: RegExpExecArray | null = multiValuePattern.exec(command);
	while (multiMatch !== null) {
		spans.push(multiMatch[1]);
		multiMatch = multiValuePattern.exec(command);
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
// deliberately NOT shared across both commands. `-n` is detected as part of ANY
// dash-prefixed short-flag cluster containing the letter n (`-(?!-)[A-Za-z]*n[A-Za-z]*\b`
// — a single leading `-`, not `--`), not just an isolated `-n`, so `git commit -nm
// "Generated with Claude"` (-n clustered with -m) is caught the same way an isolated -n
// is. The `[^;&|\n]*` gap between the subcommand and the flag keeps the match scoped to
// the same shell segment (mirrors codex/ai-reference-guard.sh's sibling bound and its
// regression test) — without excluding `;`/`&`/`|`, a chained `git commit -m "fix" &&
// git log -n 1` would match `-n` from the unrelated `log` segment and deny a perfectly
// clean chained command. Newline is excluded from the gap alongside those shell
// separators for the same reason: in JS a negated character class matches a literal
// newline unless explicitly excluded, so a real embedded newline
// (`git commit -m "fix"\ngit log -n 1`, not literal backslash-n text) would otherwise let
// the gap cross from `commit` on one line all the way to an unrelated `-n` on the next.
const NO_VERIFY_PATTERNS: RegExp[] = [
	/git\s+(.*\s+)?commit\s[^;&|\n]*(--no-verify|-(?!-)[A-Za-z]*n[A-Za-z]*\b)/,
	/git\s+(.*\s+)?push\s[^;&|\n]*--no-verify/,
];

// Pure matcher: given a raw command string and an already-parsed wordlist, returns a
// block reason or undefined to allow. No I/O — the caller owns reading the wordlist file,
// so this stays testable without a filesystem.
function matchCommand(command: string, wordlistPatterns: RegExp[]): string | undefined {
	// SKIP_AI_REFERENCE_SCAN/SKIP_GITLEAKS=1 is git/templates/hooks/{commit-msg,pre-commit}'s
	// own human bypass hatch (matching the existing SKIP_GITLEAKS convention those hooks
	// already ship). Pi invoking a bash command can set either var just as easily as a
	// human, silently defeating layer 2's scan — denied outright here, same unconditional
	// treatment as --no-verify below. Checked against the RAW command, not scrubbed:
	// scrubQuoted deletes non-flag quoted content, so a quoted value
	// (`SKIP_GITLEAKS='1' git commit ...`) would otherwise have its "1" scrubbed away
	// before this pattern ever saw it, even though the underlying shell hook still sees the
	// unquoted value (the shell strips the quotes). Anchored to an actual shell-assignment
	// shape so it doesn't false-match unrelated prose containing this text. The `m` flag
	// plus `\n` in the anchor class makes `^` (and the explicit `\n` alternative) match
	// after a newline too — a real multi-line command string
	// (`"true\nSKIP_AI_REFERENCE_SCAN=1 git commit -m \"clean\""`) starts a new segment at
	// each line the same way `;`/`&`/`|` do, so an assignment on its own line must still
	// deny. The assignment shape itself (`SKIP_X=1` with no intervening text) is unchanged,
	// so prose that merely mentions the variable name after a newline still doesn't match.
	const skipVarPattern = /(^|[;&|]\s*|export\s+|env\s+|\n)SKIP_(AI_REFERENCE_SCAN|GITLEAKS)=['"]?1['"]?\b/m;
	if (skipVarPattern.test(command)) {
		return `Blocked: does not have authority to run "${command}" — this command bypasses commit/push verification hooks.`;
	}

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
	const wordlistPath = resolveWordlistPath();
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

		if (!isRepoScopedIn(process.cwd(), command)) {
			return;
		}

		let wordlistPatterns: RegExp[];
		try {
			wordlistPatterns = loadWordlistPatterns();
		} catch (error) {
			const wordlistPath = resolveWordlistPath();
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
