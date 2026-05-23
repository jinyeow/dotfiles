#!/usr/bin/env bash
input=$(cat)

used=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

if [ -n "$used" ] && [ -n "$total" ]; then
  used_k=$(awk "BEGIN { printf \"%.1f\", $used / 1000 }")
  total_k=$(awk "BEGIN { printf \"%.0f\", $total / 1000 }")
  if [ -n "$used_pct" ]; then
    pct=$(printf "%.0f" "$used_pct")
    printf "%sk / %sk tokens (%s%%)" "$used_k" "$total_k" "$pct"
  else
    printf "%sk / %sk tokens" "$used_k" "$total_k"
  fi
fi
