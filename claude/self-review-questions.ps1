# Stop hook: forces a two-question self-review before Claude ends a turn.
# Inspired by https://www.reddit.com/r/ClaudeAI/ - the "what are you least confident
# about" / "what am I missing" end-of-session ritual.
#
# stop_hook_active is set by Claude Code when this is a second Stop attempt after a
# previous Stop hook already blocked once - honor it to avoid an infinite block loop.

$hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json

if ($hookInput.stop_hook_active) {
    exit 0
}

$reason = @'
Before ending this turn, answer two questions in your reply (briefly, a sentence or two each):
1. What are you least confident about in what you just did?
2. What's the biggest thing you're probably missing about this that you haven't thought to ask?
'@

@{
    decision = 'block'
    reason   = $reason
} | ConvertTo-Json -Compress
