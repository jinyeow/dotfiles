#!/usr/bin/env bash
input=$(cat)

# Extract every field in a single jq pass (one process, not one per field).
# jq emits one value per line; readarray preserves blank lines, so an absent
# field keeps its slot and later fields don't shift when rate/pr are missing.
readarray -t F < <(echo "$input" | jq -r '
  .context_window.total_input_tokens,
  .context_window.context_window_size,
  .model.display_name,
  .rate_limits.five_hour.used_percentage,
  .rate_limits.five_hour.resets_at,
  (.workspace.current_dir // .cwd),
  .workspace.git_worktree,
  .pr.number,
  .pr.review_state,
  ([.tasks[]? | select(.status == "in_progress")] | length),
  ([.tasks[]? | select(.status == "failed")] | length)
  | if . == null then "" else . end' | tr -d '\r')
used=${F[0]}
total=${F[1]}
model_name=${F[2]}
rate_5h=${F[3]}
rate_5h_reset=${F[4]}
dir=${F[5]}
worktree=${F[6]}
pr_number=${F[7]}
pr_review=${F[8]}
running=${F[9]}
failed=${F[10]}

# Colors (match Set-Prompt.ps1)
RED=$'\033[91m'
GREEN=$'\033[92m'
YELLOW=$'\033[93m'
MAGENTA=$'\033[95m'
RESET=$'\033[0m'

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
  pct=$(awk "BEGIN { printf \"%.0f\", $used / $total * 100 }")
  parts+=("${used_fmt} (${pct}%)")
fi

# Always show 5-hour window usage (percentage used, plus time until it resets)
if [ -n "$rate_5h" ]; then
  rate_pct=$(printf "%.0f" "$rate_5h")
  rate_seg="5h ${rate_pct}%"
  # Append time until the 5h window resets (resets_at is Unix epoch seconds)
  if [[ "$rate_5h_reset" =~ ^[0-9]+$ ]]; then
    remain=$(( rate_5h_reset - $(date +%s) ))
    if [ "$remain" -gt 0 ]; then
      rh=$((remain / 3600))
      rm=$(((remain % 3600) / 60))
      if [ "$rh" -gt 0 ]; then
        rate_seg+=" (resets ${rh}h${rm}m)"
      else
        rate_seg+=" (resets ${rm}m)"
      fi
    fi
  fi
  parts+=("$rate_seg")
fi

# Git segment: branch, upstream ahead/behind, per-category file counts (colored)
if [ -n "$dir" ] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)

  # Count file states from a single porcelain pass
  staged=0; modified=0; untracked=0; conflicts=0
  while IFS= read -r line; do
    x=${line:0:1}
    y=${line:1:1}
    if [ "$x$y" = "??" ]; then
      untracked=$((untracked + 1))
    elif [ "$x$y" = "AA" ] || [ "$x$y" = "DD" ] || [ "$x" = "U" ] || [ "$y" = "U" ]; then
      conflicts=$((conflicts + 1))
    else
      case "$x" in [MADRC]) staged=$((staged + 1)) ;; esac
      [ "$y" = "M" ] && modified=$((modified + 1))
    fi
  done < <(git -C "$dir" status --porcelain 2>/dev/null)

  dirty=$((staged + modified + untracked + conflicts))
  branch_color=$YELLOW
  [ "$dirty" -gt 0 ] && branch_color=$RED

  if [ -n "$worktree" ]; then
    git_seg="${branch_color}wt:${branch}${RESET}"
  else
    git_seg="${branch_color}±${branch}${RESET}"
  fi

  # Ahead/behind vs upstream (left=behind, right=ahead)
  if ab=$(git -C "$dir" rev-list --left-right --count @{u}...HEAD 2>/dev/null); then
    behind=$(echo "$ab" | awk '{print $1}')
    ahead=$(echo "$ab" | awk '{print $2}')
    if [ "${ahead:-0}" -gt 0 ] && [ "${behind:-0}" -gt 0 ]; then
      git_seg+=" ${YELLOW}↕${RESET}"
    elif [ "${ahead:-0}" -gt 0 ]; then
      git_seg+=" ${GREEN}↑${ahead}${RESET}"
    elif [ "${behind:-0}" -gt 0 ]; then
      git_seg+=" ${RED}↓${behind}${RESET}"
    fi
  fi

  [ "$staged" -gt 0 ]    && git_seg+=" ${GREEN}+${staged}${RESET}"
  [ "$modified" -gt 0 ]  && git_seg+=" ${YELLOW}*${modified}${RESET}"
  [ "$untracked" -gt 0 ] && git_seg+=" ${MAGENTA}?${untracked}${RESET}"
  [ "$conflicts" -gt 0 ] && git_seg+=" ${RED}!${conflicts}${RESET}"

  parts+=("$git_seg")
fi

# PR segment: number + review state (present only while an open PR exists for the branch)
if [ -n "$pr_number" ]; then
  case "$pr_review" in
    approved)          pr_seg="${GREEN}PR#${pr_number} ✓${RESET}" ;;
    changes_requested) pr_seg="${RED}PR#${pr_number} ✗${RESET}" ;;
    pending)           pr_seg="${YELLOW}PR#${pr_number} ⋯${RESET}" ;;
    draft)             pr_seg="PR#${pr_number} (draft)" ;;
    *)                 pr_seg="PR#${pr_number}" ;;
  esac
  parts+=("$pr_seg")
fi

# Show task summary when there are running or failed tasks (counts from the batched read)
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
