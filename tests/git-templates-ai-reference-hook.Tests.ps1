#Requires -Version 7
# Behavioural tests for the AI-reference hard-block layer (#219 layer 2):
# git/templates/hooks/commit-msg (new) and the AI-reference section added to the
# existing git/templates/hooks/pre-commit. Both are POSIX sh, so the suite drives
# them directly through a real bash (skip, not false-green, when absent), against
# throwaway repos with an origin remote set to either a Hollard/Azure DevOps URL
# or a GitHub URL — exercising the shipped hooks rather than copies that could
# drift from them.

. (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
$script:TestBash = Resolve-TestBash
$script:HasBash = [bool]$script:TestBash

# A PATH that has git/grep/mktemp (Git for Windows' own mingw64/bin + usr/bin)
# but excludes wherever gitleaks itself is installed (e.g. the WinGet Links
# shim dir) — simulates "gitleaks not on PATH" for the SKIP_GITLEAKS-should-
# not-also-skip-AI-reference-scan test below. Built from $script:TestBash's own
# Git install rather than hardcoded, and 8.3-shortened to dodge the space in
# "Program Files" (bash PATH entries are ':'-joined, not quotable per-entry the
# way Windows PATH is). Rendered as MSYS-style /c/... (not "C:/...") because
# bash's PATH splitter treats ':' as the entry separator, and a drive letter's
# own colon would otherwise fragment the entry. $null (the dependent test
# self-skips) if unavailable. Computed here AND again inside BeforeAll (same
# duplication as $script:TestBash above): an It block's -Skip is evaluated at
# Pester's discovery phase, which runs in a separate scope pass before
# BeforeAll, so a value set only inside BeforeAll wouldn't be seen by -Skip.
$script:NoGitleaksPath = $null
if ($script:TestBash) {
    try {
        $gitBashDir = Split-Path -Path $script:TestBash -Parent
        $gitRoot = Split-Path -Path $gitBashDir -Parent
        $fso = New-Object -ComObject Scripting.FileSystemObject
        $gitRootShort = $fso.GetFolder($gitRoot).ShortPath
        $driveLetter = $gitRootShort.Substring(0, 1).ToLowerInvariant()
        $restOfPath = ($gitRootShort.Substring(2)) -replace '\\', '/'
        $posixRoot = "/$driveLetter$restOfPath"
        $mingwBin = "$posixRoot/mingw64/bin"
        $usrBin = "$posixRoot/usr/bin"
        $script:NoGitleaksPath = "${mingwBin}:${usrBin}"
    } catch {
        $script:NoGitleaksPath = $null
    }
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'Resolve-TestBash.ps1')
    $script:TestBash = Resolve-TestBash
    $script:NoGitleaksPath = $null
    if ($script:TestBash) {
        try {
            $gitBashDir = Split-Path -Path $script:TestBash -Parent
            $gitRoot = Split-Path -Path $gitBashDir -Parent
            $fso = New-Object -ComObject Scripting.FileSystemObject
            $gitRootShort = $fso.GetFolder($gitRoot).ShortPath
            $driveLetter = $gitRootShort.Substring(0, 1).ToLowerInvariant()
            $restOfPath = ($gitRootShort.Substring(2)) -replace '\\', '/'
            $posixRoot = "/$driveLetter$restOfPath"
            $mingwBin = "$posixRoot/mingw64/bin"
            $usrBin = "$posixRoot/usr/bin"
            $script:NoGitleaksPath = "${mingwBin}:${usrBin}"
        } catch {
            $script:NoGitleaksPath = $null
        }
    }

    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:HooksDir = Join-Path $script:RepoRoot 'git/templates/hooks'
    $script:CommitMsgHook = Join-Path $script:HooksDir 'commit-msg'
    $script:PreCommitHook = Join-Path $script:HooksDir 'pre-commit'
    $script:Wordlist = Join-Path $script:RepoRoot 'ai-agents/_shared/banned-ai-terms.txt'

    $script:HollardHttps = 'https://dev.azure.com/HollardInsuranceRetail/Proj/_git/Repo'
    $script:HollardSsh = 'git@ssh.dev.azure.com:v3/HollardInsuranceRetail/Proj/Repo'
    $script:GitHubUrl = 'https://github.com/jinyeow/dotfiles.git'

    function New-TestRepo {
        param([string] $OriginUrl)
        $root = Join-Path ([IO.Path]::GetTempPath()) ('ai-ref-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        & git -C $root init -q . 2>&1 | Out-Null
        & git -C $root config user.email 'test@example.invalid' 2>&1 | Out-Null
        & git -C $root config user.name 'Test' 2>&1 | Out-Null
        if ($OriginUrl) {
            & git -C $root remote add origin $OriginUrl 2>&1 | Out-Null
        }
        return $root
    }

    # Runs the shipped commit-msg hook against a message file, returning exit code + output.
    function Invoke-CommitMsgHook {
        param(
            [string] $Repo,
            [string] $Message,
            [hashtable] $Env = @{}
        )
        $msgFile = Join-Path $Repo 'COMMIT_EDITMSG'
        Set-Content -Path $msgFile -Value $Message -NoNewline

        $envAssignments = ($Env.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
        Push-Location $Repo
        try {
            if ($envAssignments) {
                $out = & $script:TestBash -c "$envAssignments `"$($script:CommitMsgHook -replace '\\', '/')`" `"$($msgFile -replace '\\', '/')`"" 2>&1 | Out-String
            } else {
                $out = & $script:TestBash "$($script:CommitMsgHook -replace '\\', '/')" "$($msgFile -replace '\\', '/')" 2>&1 | Out-String
            }
            $rc = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        return @{ ExitCode = $rc; Output = $out }
    }

    # Stages one file's content, then runs the shipped pre-commit hook.
    function Invoke-PreCommitHook {
        param(
            [string] $Repo,
            [string] $FileContent,
            [string] $FileName = 'code.js',
            [hashtable] $Env = @{}
        )
        $file = Join-Path $Repo $FileName
        Set-Content -Path $file -Value $FileContent -NoNewline
        & git -C $Repo add $FileName 2>&1 | Out-Null

        $envAssignments = ($Env.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
        Push-Location $Repo
        try {
            if ($envAssignments) {
                $out = & $script:TestBash -c "$envAssignments `"$($script:PreCommitHook -replace '\\', '/')`"" 2>&1 | Out-String
            } else {
                $out = & $script:TestBash -c "`"$($script:PreCommitHook -replace '\\', '/')`"" 2>&1 | Out-String
            }
            $rc = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        return @{ ExitCode = $rc; Output = $out }
    }
}

Describe 'git/templates/hooks/commit-msg' -Skip:(-not $script:HasBash) {
    AfterEach {
        Remove-Item -Path $script:Repo -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'blocks a banned term in a Hollard HTTPS-remote repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-CommitMsgHook -Repo $script:Repo -Message 'feat: written by Claude'
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'AI-reference scan blocked'
    }

    It 'blocks a banned term in a Hollard SSH-remote repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardSsh
        $r = Invoke-CommitMsgHook -Repo $script:Repo -Message 'feat: use Codex for this'
        $r.ExitCode | Should -Not -Be 0
    }

    It 'allows a clean message in a Hollard repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-CommitMsgHook -Repo $script:Repo -Message 'feat: add the thing'
        $r.ExitCode | Should -Be 0
    }

    It 'allows a legitimate near-miss phrase the wordlist deliberately excludes' {
        # ai-agents/_shared/banned-ai-terms.txt intentionally does not ban bare "AI" or
        # "Copilot" so real Hollard work can say "Azure AI Search" / "M365 Copilot".
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-CommitMsgHook -Repo $script:Repo -Message 'feat: integrate Azure AI Search and M365 Copilot'
        $r.ExitCode | Should -Be 0
    }

    It 'allows a banned term in a GitHub repo (out of scope)' {
        $script:Repo = New-TestRepo -OriginUrl $script:GitHubUrl
        $r = Invoke-CommitMsgHook -Repo $script:Repo -Message 'feat: written by Claude'
        $r.ExitCode | Should -Be 0
    }

    It 'allows a banned term when there is no origin remote at all' {
        $script:Repo = New-TestRepo -OriginUrl $null
        $r = Invoke-CommitMsgHook -Repo $script:Repo -Message 'feat: written by Claude'
        $r.ExitCode | Should -Be 0
    }

    It 'honours SKIP_AI_REFERENCE_SCAN=1 in a Hollard repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-CommitMsgHook -Repo $script:Repo -Message 'feat: written by Claude' -Env @{ SKIP_AI_REFERENCE_SCAN = '1' }
        $r.ExitCode | Should -Be 0
    }

    It 'fails closed when the wordlist is missing in a Hollard repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        # Simulate a missing wordlist by pointing the hook at a repo copy that has no
        # ai-agents/_shared directory at the resolved location: copy the hooks dir alone
        # into a fake repo tree three levels below a root with no ai-agents/.
        $fakeRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai-ref-nowl-' + [guid]::NewGuid())
        $fakeHooksDir = Join-Path $fakeRoot 'git/templates/hooks'
        New-Item -ItemType Directory -Path $fakeHooksDir -Force | Out-Null
        Copy-Item -Path $script:CommitMsgHook -Destination (Join-Path $fakeHooksDir 'commit-msg')
        try {
            $msgFile = Join-Path $script:Repo 'COMMIT_EDITMSG'
            Set-Content -Path $msgFile -Value 'feat: add the thing' -NoNewline
            Push-Location $script:Repo
            try {
                $hookPath = (Join-Path $fakeHooksDir 'commit-msg') -replace '\\', '/'
                $msgPath = $msgFile -replace '\\', '/'
                $out = & $script:TestBash "$hookPath" "$msgPath" 2>&1 | Out-String
                $rc = $LASTEXITCODE
            } finally {
                Pop-Location
            }
            $rc | Should -Not -Be 0
            $out | Should -Match 'wordlist not found'
        } finally {
            Remove-Item -Path $fakeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'matches a real wordlist term ("Claude") straight off disk, catching CRLF/locale drift' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        Test-Path -LiteralPath $script:Wordlist | Should -BeTrue -Because 'the shared wordlist must exist for this layer to do anything'
        $r = Invoke-CommitMsgHook -Repo $script:Repo -Message 'Claude'
        $r.ExitCode | Should -Not -Be 0
    }

    It 'fails closed when the wordlist exists but is unreadable in a Hollard repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        # Same fake-root layout as the missing-wordlist test above, but this time the
        # wordlist file is actually present at the resolved location with real content,
        # then its ACL is denied read access for the current user via icacls — existence
        # alone (`-f`) must not be enough to treat it as usable.
        $fakeRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai-ref-unreadwl-' + [guid]::NewGuid())
        $fakeHooksDir = Join-Path $fakeRoot 'git/templates/hooks'
        $fakeSharedDir = Join-Path $fakeRoot 'ai-agents/_shared'
        New-Item -ItemType Directory -Path $fakeHooksDir -Force | Out-Null
        New-Item -ItemType Directory -Path $fakeSharedDir -Force | Out-Null
        Copy-Item -Path $script:CommitMsgHook -Destination (Join-Path $fakeHooksDir 'commit-msg')
        $fakeWordlist = Join-Path $fakeSharedDir 'banned-ai-terms.txt'
        Set-Content -Path $fakeWordlist -Value 'claude' -NoNewline
        icacls $fakeWordlist /deny "$($env:USERNAME):(R)" | Out-Null
        try {
            # Precondition: confirm the deny actually blocks a real read through the same
            # bash used to run the hook. If it doesn't bite on this machine, skip rather
            # than false-RED/false-fail on an ACL quirk unrelated to the hook's own logic.
            $probe = & $script:TestBash -c "cat `"$($fakeWordlist -replace '\\', '/')`"" 2>&1
            $probeReadable = ($LASTEXITCODE -eq 0)
            if ($probeReadable) {
                Set-ItResult -Skipped -Because 'the ACL deny did not block a real read on this machine'
                return
            }

            $msgFile = Join-Path $script:Repo 'COMMIT_EDITMSG'
            Set-Content -Path $msgFile -Value 'feat: add the thing' -NoNewline
            Push-Location $script:Repo
            try {
                $hookPath = (Join-Path $fakeHooksDir 'commit-msg') -replace '\\', '/'
                $msgPath = $msgFile -replace '\\', '/'
                $out = & $script:TestBash "$hookPath" "$msgPath" 2>&1 | Out-String
                $rc = $LASTEXITCODE
            } finally {
                Pop-Location
            }
            $rc | Should -Not -Be 0
            $out | Should -Match 'AI-reference scan blocked'
        } finally {
            icacls $fakeWordlist /reset 2>&1 | Out-Null
            Remove-Item -Path $fakeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'git/templates/hooks/pre-commit AI-reference section' -Skip:(-not $script:HasBash) {
    AfterEach {
        Remove-Item -Path $script:Repo -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'blocks a banned term on an ADDED line in a Hollard repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '// written with Claude'
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'AI-reference scan blocked'
    }

    It 'does NOT block a banned term that only appears on a REMOVED line' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        # Commit the banned line first (scan bypassed for setup), then remove it and
        # verify the removal alone does not trip the added-lines-only scan.
        $r0 = Invoke-PreCommitHook -Repo $script:Repo -FileContent '// written with Claude' -Env @{ SKIP_AI_REFERENCE_SCAN = '1' }
        $r0.ExitCode | Should -Be 0
        & git -C $script:Repo commit -q -m init 2>&1 | Out-Null

        Set-Content -Path (Join-Path $script:Repo 'code.js') -Value '// normal comment' -NoNewline
        & git -C $script:Repo add code.js 2>&1 | Out-Null
        Push-Location $script:Repo
        try {
            $out = & $script:TestBash -c "`"$($script:PreCommitHook -replace '\\', '/')`"" 2>&1 | Out-String
            $rc = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $rc | Should -Be 0
    }

    It 'allows a clean added line in a Hollard repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '// normal comment'
        $r.ExitCode | Should -Be 0
    }

    It 'blocks a banned term on an added line whose own content starts with a literal +' {
        # The diff line is "+++i; // written with Claude" — diff-format '+' marker,
        # then the content's own leading '+' from "++i". A regex that excludes any
        # line where the second character is '+' would wrongly skip this line and
        # never check it for a banned term.
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '++i; // written with Claude'
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'AI-reference scan blocked'
    }

    It 'blocks a banned term on an added line that starts with "++ " but is not the real diff file header' {
        # Diff line is "+++ i; // written with Claude" — diff-format '+' marker,
        # then content "++ i; ...". This literally matches a bare '^\+\+\+ '
        # exclusion (three pluses, a space), which would wrongly treat it as the
        # file-header line and skip it. The real header is always immediately
        # followed by 'a/', 'b/', or '/dev/null' — this content isn't, so it must
        # still be scanned.
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '++ i; // written with Claude'
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'AI-reference scan blocked'
    }

    It 'does not false-positive-block on the real "+++" diff file header' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '// normal comment' -FileName 'written-with-claude.js'
        $r.ExitCode | Should -Be 0
    }

    It 'allows a banned term in a GitHub repo (out of scope)' {
        $script:Repo = New-TestRepo -OriginUrl $script:GitHubUrl
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '// written with Claude'
        $r.ExitCode | Should -Be 0
    }

    It 'honours SKIP_AI_REFERENCE_SCAN=1 in a Hollard repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '// written with Claude' -Env @{ SKIP_AI_REFERENCE_SCAN = '1' }
        $r.ExitCode | Should -Be 0
    }

    It 'still blocks via the AI-reference scan when SKIP_GITLEAKS=1 (that var must not also skip it)' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '// written with Claude' -Env @{ SKIP_GITLEAKS = '1' }
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'AI-reference scan blocked'
    }

    It 'still blocks via the AI-reference scan when gitleaks is not on PATH (its absence must not also skip it)' -Skip:(-not $script:NoGitleaksPath) {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '// written with Claude' -Env @{ PATH = $script:NoGitleaksPath }
        $r.ExitCode | Should -Not -Be 0
        $r.Output | Should -Match 'AI-reference scan blocked'
    }

    It 'fails closed when the wordlist is missing in a Hollard repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $fakeRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai-ref-nowl-pc-' + [guid]::NewGuid())
        $fakeHooksDir = Join-Path $fakeRoot 'git/templates/hooks'
        New-Item -ItemType Directory -Path $fakeHooksDir -Force | Out-Null
        Copy-Item -Path $script:PreCommitHook -Destination (Join-Path $fakeHooksDir 'pre-commit')
        try {
            Set-Content -Path (Join-Path $script:Repo 'code.js') -Value '// normal comment' -NoNewline
            & git -C $script:Repo add code.js 2>&1 | Out-Null
            Push-Location $script:Repo
            try {
                $hookPath = (Join-Path $fakeHooksDir 'pre-commit') -replace '\\', '/'
                $out = & $script:TestBash -c "`"$hookPath`"" 2>&1 | Out-String
                $rc = $LASTEXITCODE
            } finally {
                Pop-Location
            }
            $rc | Should -Not -Be 0
            $out | Should -Match 'wordlist not found'
        } finally {
            Remove-Item -Path $fakeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'fails closed when the wordlist exists but is unreadable in a Hollard repo' {
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        $fakeRoot = Join-Path ([IO.Path]::GetTempPath()) ('ai-ref-unreadwl-pc-' + [guid]::NewGuid())
        $fakeHooksDir = Join-Path $fakeRoot 'git/templates/hooks'
        $fakeSharedDir = Join-Path $fakeRoot 'ai-agents/_shared'
        New-Item -ItemType Directory -Path $fakeHooksDir -Force | Out-Null
        New-Item -ItemType Directory -Path $fakeSharedDir -Force | Out-Null
        Copy-Item -Path $script:PreCommitHook -Destination (Join-Path $fakeHooksDir 'pre-commit')
        $fakeWordlist = Join-Path $fakeSharedDir 'banned-ai-terms.txt'
        Set-Content -Path $fakeWordlist -Value 'claude' -NoNewline
        icacls $fakeWordlist /deny "$($env:USERNAME):(R)" | Out-Null
        try {
            $probe = & $script:TestBash -c "cat `"$($fakeWordlist -replace '\\', '/')`"" 2>&1
            $probeReadable = ($LASTEXITCODE -eq 0)
            if ($probeReadable) {
                Set-ItResult -Skipped -Because 'the ACL deny did not block a real read on this machine'
                return
            }

            Set-Content -Path (Join-Path $script:Repo 'code.js') -Value '// normal comment' -NoNewline
            & git -C $script:Repo add code.js 2>&1 | Out-Null
            Push-Location $script:Repo
            try {
                $hookPath = (Join-Path $fakeHooksDir 'pre-commit') -replace '\\', '/'
                $out = & $script:TestBash -c "`"$hookPath`"" 2>&1 | Out-String
                $rc = $LASTEXITCODE
            } finally {
                Pop-Location
            }
            $rc | Should -Not -Be 0
            $out | Should -Match 'AI-reference scan blocked'
        } finally {
            icacls $fakeWordlist /reset 2>&1 | Out-Null
            Remove-Item -Path $fakeRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'does not false-positive-block on the real "+++" diff file header when diff.noprefix is configured' {
        # diff.noprefix=true / diff.mnemonicPrefix strip or change the a/ b/ prefixes the
        # header exclusion regex expects. The hook forces --src-prefix/--dst-prefix on
        # the command line so the exclusion still matches regardless of repo config.
        $script:Repo = New-TestRepo -OriginUrl $script:HollardHttps
        & git -C $script:Repo config diff.noprefix true 2>&1 | Out-Null
        $r = Invoke-PreCommitHook -Repo $script:Repo -FileContent '// normal comment' -FileName 'written-with-claude.js'
        $r.ExitCode | Should -Be 0
    }
}
