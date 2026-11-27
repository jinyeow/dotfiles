// git-guardrails.ts
// Pi tool_call extension — blocks dangerous git commands before the bash tool executes.
//
// Originally a verbatim port of a naive whole-command-string regex match (the Codex
// block-dangerous-git.sh blocklist). That inherited real false positives (#177): a destructive phrase quoted inside e.g.
// `git commit -m "reset --hard"` still matched, and "git stash push" tripped the push
// pattern via bare substring match. Fixed by porting the quote-scrubbing approach from
// the more refined, actually-wired claude/block-destructive-vcs.ps1 hook, plus excluding
// git-stash's own "push" subcommand (it touches no remote, so it isn't dangerous).
//
// The rules live in ai-agents/_shared/destructive-git-rules.json, shared with the Claude
// (claude/block-destructive-vcs.ps1) and Codex (codex/block-dangerous-git.sh) guards so the
// three runtimes cannot drift. Only rules whose `runtimes` list includes "pi" apply here. The
// file is read fresh on every bash tool call. Non-git commands always pass; a missing,
// unreadable or invalid rules file fails CLOSED for commands that mention git, so a broken
// install cannot silently disable the guard.
//
// Discovered automatically by Pi from `~/.pi/agent/extensions/*.ts` (a single file needs
// no package.json/npm dependencies) — see pi/README.md for the projection mechanism.

import { existsSync, readFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

const RUNTIME = "pi";
const RULES_NAME = "destructive-git-rules.json";

interface GuardRule {
	id: string;
	runtimes: string[];
	pattern: string;
	reason: string;
}

interface CompiledRules {
	keepQuoted: RegExp;
	rules: { pattern: RegExp; reason: string }[];
}

// Rules file candidates, in order. PI_GIT_GUARDRAILS_RULES_PATH overrides them all (tests).
//   1. "../destructive-git-rules.json" relative to this module's URL — the installed sibling
//      (~/.pi/agent/destructive-git-rules.json) when the loader keeps the junctioned path.
//   2. The repository copy, found from this file's real path (realpathSync resolves the
//      ~/.pi/agent/extensions junction to this repo's pi/extensions/).
//   3. ~/.pi/agent/destructive-git-rules.json built from homedir(), for a loader that
//      resolved the junction itself (so candidate 1 points inside the repo instead).
//   4. $DOTFILES/ai-agents/_shared/destructive-git-rules.json.
function rulesCandidates(): string[] {
	const override = process.env.PI_GIT_GUARDRAILS_RULES_PATH;
	if (override) {
		return [override];
	}
	const modulePath = fileURLToPath(import.meta.url);
	const candidates: string[] = [join(dirname(modulePath), "..", RULES_NAME)];
	try {
		candidates.push(join(dirname(realpathSync(modulePath)), "..", "..", "ai-agents", "_shared", RULES_NAME));
	} catch {
		// The module path itself is unresolvable; the remaining candidates still apply.
	}
	candidates.push(join(homedir(), ".pi", "agent", RULES_NAME));
	if (process.env.DOTFILES) {
		candidates.push(join(process.env.DOTFILES, "ai-agents", "_shared", RULES_NAME));
	}
	return candidates;
}

// Loads and compiles the rules for this runtime. Throws an Error naming the path(s) tried
// when no candidate exists or the file is unreadable or invalid.
function loadRules(): CompiledRules {
	const candidates = rulesCandidates();
	const path = candidates.find((candidate: string) => existsSync(candidate));
	if (!path) {
		throw new Error(`${RULES_NAME} not found (tried ${candidates.join(", ")})`);
	}
	try {
		const data = JSON.parse(readFileSync(path, "utf8")) as { keepQuoted: string; rules: GuardRule[] };
		return {
			keepQuoted: new RegExp(data.keepQuoted),
			rules: data.rules
				.filter((rule: GuardRule) => rule.runtimes.includes(RUNTIME))
				.map((rule: GuardRule) => ({ pattern: new RegExp(rule.pattern), reason: rule.reason })),
		};
	} catch (error) {
		throw new Error(`${path} is unreadable or invalid: ${(error as Error).message}`);
	}
}

// Deletes quoted content so a destructive phrase in e.g. a commit message can't
// false-match; unquotes content matching the shared keepQuoted pattern in place so e.g.
// `git push "--force"` or `git checkout -- "."` (which the shell expands identically to the
// bare token) still matches. Mirrors the scrub in claude/block-destructive-vcs.ps1.
// Escape-aware double-quote matching so an escaped quote inside a message doesn't terminate
// the match early. Double- and single-quoted spans are matched in one alternation (not two
// sequential passes) so a double quote inside one single-quoted string can't pair across to
// a double quote inside a later one and scrub out everything between them, including a real
// command.
function scrubQuoted(command: string, keepQuoted: RegExp): string {
	return command.replace(
		/"((?:\\.|[^"\\])*)"|'([^']*)'/g,
		(_match: string, doubleQuoted: string | undefined, singleQuoted: string | undefined) => {
			const inner = doubleQuoted !== undefined ? doubleQuoted : singleQuoted ?? "";
			return keepQuoted.test(inner) ? inner : "";
		},
	);
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event) => {
		if (!isToolCallEventType("bash", event)) {
			return;
		}

		const command = event.input.command;
		let compiled: CompiledRules;
		try {
			compiled = loadRules();
		} catch (error) {
			if (/\bgit\b/.test(command)) {
				return {
					block: true,
					reason: `Blocked: the dangerous-git guardrail cannot load its rules (${(error as Error).message}), so "${command}" is refused until it is restored. If you want to run this command, do it yourself in a terminal.`,
				};
			}
			return;
		}

		const scrubbed = scrubQuoted(command, compiled.keepQuoted);
		for (const rule of compiled.rules) {
			if (rule.pattern.test(scrubbed)) {
				return {
					block: true,
					reason: `Blocked: does not have authority to run "${command}" — ${rule.reason} If you want to run this command, do it yourself in a terminal.`,
				};
			}
		}
	});
}
