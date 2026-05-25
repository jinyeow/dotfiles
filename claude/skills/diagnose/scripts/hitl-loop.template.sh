#!/usr/bin/env bash
# HITL (Human-in-the-Loop) feedback loop template
# Use this when a bug requires human interaction to reproduce.
# The human performs the steps; this script captures their observations
# and feeds them back to the agent in a structured format.
#
# Usage:
#   1. Copy this file to scripts/hitl-loop.sh in the project
#   2. Fill in STEPS and SIGNAL_QUESTION for the specific bug
#   3. Run it: bash scripts/hitl-loop.sh
#   4. Paste the captured output back to the agent

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
# Fill these in for the specific bug being diagnosed.

BUG_DESCRIPTION="<describe the bug in one sentence>"

STEPS=(
  "<step 1: what the human should do>"
  "<step 2: what the human should do>"
  "<step 3: what the human should observe>"
)

SIGNAL_QUESTION="Did the bug reproduce? (y/n/partial)"

# ── Helpers ──────────────────────────────────────────────────────────────────

BOLD=$'\e[1m'
DIM=$'\e[2m'
RESET=$'\e[0m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
RED=$'\e[31m'

divider() { printf '%s\n' "────────────────────────────────────────────────────────────"; }
header()  { echo; echo "${BOLD}$*${RESET}"; divider; }

# ── Main loop ────────────────────────────────────────────────────────────────

ITERATION=0
OUTPUT_FILE="${TMPDIR:-/tmp}/hitl-loop-output-$$.txt"

echo "${BOLD}HITL Debug Loop${RESET}"
echo "${DIM}Bug: ${BUG_DESCRIPTION}${RESET}"
echo "${DIM}Output will be saved to: ${OUTPUT_FILE}${RESET}"
echo

while true; do
  ITERATION=$(( ITERATION + 1 ))
  header "Iteration ${ITERATION}"

  # Print steps
  echo "${BOLD}Steps to perform:${RESET}"
  for i in "${!STEPS[@]}"; do
    echo "  $((i+1)). ${STEPS[$i]}"
  done
  echo

  # Collect environment / state snapshot before
  echo "${DIM}Collecting environment snapshot...${RESET}"
  SNAPSHOT_BEFORE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Wait for human to perform steps
  echo "${YELLOW}Perform the steps above, then press Enter to continue.${RESET}"
  read -r _

  # Ask signal question
  echo
  printf "${BOLD}%s${RESET} " "${SIGNAL_QUESTION}"
  read -r SIGNAL

  # Collect observations
  echo
  echo "${BOLD}Describe what you observed (press Enter twice when done):${RESET}"
  OBSERVATION=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && break
    OBSERVATION+="$line"$'\n'
  done

  # Optional: paste any error output
  echo "${BOLD}Paste any error messages or logs (press Enter twice when done, or just Enter to skip):${RESET}"
  ERROR_OUTPUT=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && break
    ERROR_OUTPUT+="$line"$'\n'
  done

  # Write structured output
  {
    echo "=== HITL Loop Result: Iteration ${ITERATION} ==="
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Bug: ${BUG_DESCRIPTION}"
    echo ""
    echo "Signal (${SIGNAL_QUESTION}): ${SIGNAL}"
    echo ""
    echo "Observation:"
    echo "${OBSERVATION}"
    if [[ -n "${ERROR_OUTPUT}" ]]; then
      echo "Error output / logs:"
      echo "${ERROR_OUTPUT}"
    fi
    echo "=== End Iteration ${ITERATION} ==="
    echo ""
  } | tee -a "${OUTPUT_FILE}"

  # Ask whether to loop again
  echo
  case "${SIGNAL,,}" in
    y|yes)
      echo "${GREEN}Bug reproduced.${RESET}"
      echo "${DIM}Copy the output above (or the file at ${OUTPUT_FILE}) back to the agent.${RESET}"
      break
      ;;
    n|no)
      echo "${YELLOW}Bug did not reproduce this iteration.${RESET}"
      printf "Run another iteration? (y/n) "
      read -r AGAIN
      [[ "${AGAIN,,}" == "n" ]] && break
      ;;
    partial)
      echo "${YELLOW}Partial reproduction.${RESET}"
      printf "Run another iteration to try to get a full repro? (y/n) "
      read -r AGAIN
      [[ "${AGAIN,,}" == "n" ]] && break
      ;;
    *)
      echo "${RED}Unrecognised signal '${SIGNAL}'. Continuing loop.${RESET}"
      ;;
  esac
done

echo
echo "${BOLD}Loop complete after ${ITERATION} iteration(s).${RESET}"
echo "${DIM}Full output saved to: ${OUTPUT_FILE}${RESET}"
echo
echo "Paste the contents of ${OUTPUT_FILE} back to the agent:"
echo
cat "${OUTPUT_FILE}"
