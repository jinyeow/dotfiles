// git-guardrails.ts
// Pi tool_call extension — blocks dangerous git commands before the bash tool executes.
//
// Ported from claude/skills/git-guardrails-claude-code/scripts/block-dangerous-git.sh,
// close to verbatim: same blocklist, same matching approach (whole-command-string regex
// match, no shell parsing). This means it inherits the same known false positive as the
// source script — a destructive phrase quoted inside e.g. `git commit -m "reset --hard"`
// still matches, since neither script parses quoting. Port as-is, not a rewrite.
//
// Discovered automatically by Pi from `~/.pi/agent/extensions/*.ts` (a single file needs
// no package.json/npm dependencies) — see pi/README.md for the projection mechanism.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

// Each pattern is matched against the full bash command string. Kept in the same order
// and intent as BLOCKED_PATTERNS in block-dangerous-git.sh; [[:space:]] translates to \s.
const BLOCKED_PATTERNS: RegExp[] = [
	// Push (all variants)
	/git\s+(.*\s+)?push(\s|$)/,

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
		for (const pattern of BLOCKED_PATTERNS) {
			if (pattern.test(command)) {
				return {
					block: true,
					reason: `Blocked: does not have authority to run "${command}" — this command matches a dangerous-git-operations blocklist. If you want to run this command, do it yourself in a terminal.`,
				};
			}
		}
	});
}
