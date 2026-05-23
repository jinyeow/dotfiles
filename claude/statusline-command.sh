#!/usr/bin/env bash
input=$(cat)

used=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# Derive max from model ID; fall back to context_window_size from JSON
case "$model_id" in
  *opus-4-7*|*opus-4-6*|*sonnet-4-6*)
    model_max=1000000 ;;
  *haiku-4-5*)
    model_max=200000 ;;
  *)
    model_max="" ;;
esac
[ -n "$model_max" ] && total="$model_max"

fmt_tokens() {
  awk "BEGIN {
    v = $1
    if (v >= 1000000) { printf \"%.4gM\", v / 1000000 }
    else { printf \"%.1fk\", v / 1000 }
  }"
}

parts=()

[ -n "$model_name" ] && parts+=("$model_name")

if [ -n "$used" ] && [ -n "$total" ]; then
  used_fmt=$(fmt_tokens "$used")
  total_fmt=$(fmt_tokens "$total")
  if [ -n "$used_pct" ]; then
    pct=$(printf "%.0f" "$used_pct")
    parts+=("${used_fmt} / ${total_fmt} tokens (${pct}%)")
  else
    parts+=("${used_fmt} / ${total_fmt} tokens")
  fi
fi

# Only show rate limit when pressure is meaningful (>= 50%)
if [ -n "$rate_5h" ]; then
  rate_pct=$(printf "%.0f" "$rate_5h")
  if [ "$rate_pct" -ge 50 ]; then
    parts+=("rate ${rate_pct}%")
  fi
fi

# Show task summary when there are running or failed tasks
running=$(echo "$input" | jq '[.tasks[]? | select(.status == "in_progress")] | length')
failed=$(echo "$input" | jq '[.tasks[]? | select(.status == "failed")] | length')
task_parts=()
[ "${running:-0}" -gt 0 ] && task_parts+=("${running} running")
[ "${failed:-0}" -gt 0 ] && task_parts+=("${failed} failed")
if [ "${#task_parts[@]}" -gt 0 ]; then
  task_str=""
  for tp in "${task_parts[@]}"; do
    [ -n "$task_str" ] && task_str+=", "
    task_str+="$tp"
  done
  parts+=("tasks: ${task_str}")
fi

out=""
for part in "${parts[@]}"; do
  [ -n "$out" ] && out+=" | "
  out+="$part"
done
printf "%s" "$out"
