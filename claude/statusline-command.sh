#!/usr/bin/env bash
input=$(cat)

used=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')

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

if [ -n "$used" ] && [ -n "$total" ]; then
  used_fmt=$(fmt_tokens "$used")
  total_fmt=$(fmt_tokens "$total")
  if [ -n "$used_pct" ]; then
    pct=$(printf "%.0f" "$used_pct")
    printf "%s / %s tokens (%s%%)" "$used_fmt" "$total_fmt" "$pct"
  else
    printf "%s / %s tokens" "$used_fmt" "$total_fmt"
  fi
fi
