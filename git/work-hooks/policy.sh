#!/bin/sh
# EXAMPLE work-only pre-commit policy check (POSIX fallback; see policy.ps1 for
# the pwsh variant). Wired via [hook "work-policy"] in gitconfig-work, so it runs
# ONLY in repos matched by that file's [includeIf] conditions.
#
# Placeholder: it looks for a generic policy scanner and, finding none, warns and
# allows the commit. Replace the scan block with a real check when you have one.
#
# Fails OPEN when the scanner is absent (warn, allow) — same posture as the
# gitleaks pre-commit hook.
# Bypass one commit:  SKIP_WORK_POLICY=1 git commit ...

[ "$SKIP_WORK_POLICY" = "1" ] && exit 0

TOOL="${WORK_POLICY_TOOL:-work-policy-scan}"

if ! command -v "$TOOL" >/dev/null 2>&1; then
    echo "work-policy: '$TOOL' not on PATH — skipping policy scan (placeholder hook, nothing enforced)." >&2
    exit 0
fi

"$TOOL" --staged
status=$?
if [ "$status" -ne 0 ]; then
    echo "" >&2
    echo "work-policy blocked this commit: a staged change failed the policy scan (see above)." >&2
    echo "Fix it, or bypass this one commit with:  SKIP_WORK_POLICY=1 git commit ..." >&2
fi
exit "$status"
