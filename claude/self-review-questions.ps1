# SessionEnd/PreCompact hook: reminds Claude of a two-question self-review before a
# session-ending event (/clear, /quit, logout) or a context compaction (/compact).
# Inspired by an r/ClaudeAI end-of-session ritual ("what are you least confident about" /
# "what am I missing").
#
# Non-blocking by design: SessionEnd hooks cannot block session termination, and PreCompact
# blocking only halts compaction (via stderr) without granting Claude another turn to answer -
# so this surfaces as a systemMessage to the user rather than forcing a reply.

$systemMessage = @'
Self-review reminder: what are you least confident about in your recent work, and what's the biggest thing you're probably missing that you haven't thought to ask?
'@

@{
    systemMessage = $systemMessage
} | ConvertTo-Json -Compress
