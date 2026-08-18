# Resources — Stanford's Method Turns Claude Into a PHD Level Research Team

## Files in this folder
- **SKILL.md** — The free Storm Research Claude skill. Runs Stanford's STORM method: five expert lenses (practitioner, academic, skeptic, economist, historian) → contradiction map → synthesized HTML briefing → adversarial peer review + primary-source citation verification.
- **report-template.html** — The HTML report template the skill references so every briefing comes out with the same clean, consistent layout.
- **DISPATCH.md** — The runtime-neutral parallel-dispatch contract: how the five expert lenses and the citation verifiers are spawned on Claude Code vs Pi.

## How to install
In this repo, this skill lives at `ai-agents/skills/storm-research/` and is projected to
Claude Code, Codex CLI, and Pi by `setup.ps1 -Module ai-agents` (or `setup.sh -m ai-agents`).
Outside this repo, copy the whole folder (or all three files — SKILL.md, report-template.html,
DISPATCH.md) into a `storm-research/` folder inside your `.claude/skills/` directory, so SKILL.md's
[DISPATCH.md](DISPATCH.md) links resolve. Then just say "run a storm research on [topic]" — no
slash command needed.

## External links
- **Free Skool community (all YouTube resources):** linked in the video description

## Video
https://youtu.be/Tj3018n5MVg
