#!/usr/bin/env pwsh
# EXAMPLE work-only pre-commit policy check (pwsh variant; see policy.sh for the
# POSIX fallback). Wired via [hook "work-policy"] in gitconfig-work, so it runs
# ONLY in repos matched by that file's [includeIf] conditions.
#
# Placeholder: it looks for a generic policy scanner and, finding none, warns and
# allows the commit. Replace the scan block with a real check when you have one.
#
# Fails OPEN when the scanner is absent (warn, allow) — same posture as the
# gitleaks pre-commit hook.
# Bypass one commit:  SKIP_WORK_POLICY=1 git commit ...

Set-StrictMode -Version Latest

if ($env:SKIP_WORK_POLICY -eq '1') { exit 0 }

[string] $tool = if ($env:WORK_POLICY_TOOL) { $env:WORK_POLICY_TOOL } else { 'work-policy-scan' }

if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("work-policy: '$tool' not on PATH — skipping policy scan (placeholder hook, nothing enforced).")
    exit 0
}

& $tool --staged
[int] $status = $LASTEXITCODE
if ($status -ne 0) {
    [Console]::Error.WriteLine('')
    [Console]::Error.WriteLine('work-policy blocked this commit: a staged change failed the policy scan (see above).')
    [Console]::Error.WriteLine('Fix it, or bypass this one commit with:  SKIP_WORK_POLICY=1 git commit ...')
}
exit $status
