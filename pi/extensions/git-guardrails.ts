// git-guardrails.ts
// Pi tool_call extension — blocks dangerous git commands before the bash tool executes.
//
// Originally ported verbatim from claude/skills/git-guardrails-claude-code/scripts/
// block-dangerous-git.sh's naive whole-command-string regex match. That inherited real
// false positives (#177): a destructive phrase quoted inside e.g.
// `git commit -m "reset --hard"` still matched, and "git stash push" tripped the push
// pattern via bare substring match. Fixed by porting the quote-scrubbing approach from
// the more refined, actually-wired claude/block-destructive-vcs.ps1 hook, plus excluding
// git-stash's own "push" subcommand (it touches no remote, so it isn't dangerous).
//
// Discovered automatically by Pi from `~/.pi/agent/extensions/*.ts` (a single file needs
// no package.json/npm dependencies) — see pi/README.md for the projection mechanism.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

// Deletes non-flag quoted content so a destructive phrase in e.g. a commit message can't
// false-match; unquotes flag-shaped quoted content in place so e.g. `git push "--force"`
// (which the shell expands identically to an unquoted flag) still matches. Mirrors the
// scrub in claude/block-destructive-vcs.ps1. Escape-aware double-quote matching so an
// escaped quote inside a message doesn't terminate the match early. Double- and
// single-quoted spans are matched in one alternation (not two sequential passes) so a
// double quote inside one single-quoted string can't pair across to a double quote
// inside a later one and scrub out everything between them, including a real command.
function scrubQuoted(command: string): string {
	const unwrap = (_match: string, inner: string): string =>
		/^-{1,2}[A-Za-z][A-Za-z-]*$/.test(inner) ? inner : "";
	return command.replace(
		/"((?:\\.|[^"\\])*)"|'([^']*)'/g,
		(match: string, doubleQuoted: string | undefined, singleQuoted: string | undefined) =>
			unwrap(match, doubleQuoted !== undefined ? doubleQuoted : singleQuoted ?? ""),
	);
}

// Each pattern is matched against the quote-scrubbed command string. Kept in the same
// order and intent as BLOCKED_PATTERNS in block-dangerous-git.sh; [[:space:]] translates
// to \s. push excludes git-stash's own "push" subcommand via a negative lookbehind
// (`\s+`, not `\s`, so extra whitespace between "stash" and "push" doesn't defeat it).
const BLOCKED_PATTERNS: RegExp[] = [
	// Push (all variants), excluding `git stash push`
	/git\s+(.*\s+)?(?<!stash\s+)push(\s|$)/,

	// Hard reset
	/git\s+(.*\s+)?reset\s.*--hard/,

	// Clean (force)
	/git\s+(.*\s+)?clean\s.*-[a-zA-Z]*f/,

	// Delete branch (force)
	/git\s+(.*\s+)?branch\s.*-D/,

	// Checkout / restore all (wipes working tree)
	/git\s+(.*\s+)?checkout\s+\./,
	/git\s+(.*\s+)?restore\s+\./,
];

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event) => {
		if (!isToolCallEventType("bash", event)) {
			return;
		}

		const command = event.input.command;
		const scrubbed = scrubQuoted(command);
		for (const pattern of BLOCKED_PATTERNS) {
			if (pattern.test(scrubbed)) {
				return {
					block: true,
					reason: `Blocked: does not have authority to run "${command}" — this command matches a dangerous-git-operations blocklist. If you want to run this command, do it yourself in a terminal.`,
				};
			}
		}
	});
}
