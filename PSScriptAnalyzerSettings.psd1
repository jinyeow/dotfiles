@{
    # Gate on Error + Warning; Information is noise for dotfiles.
    Severity = @('Error', 'Warning')

    # Rules excluded repo-wide, each justified by a documented convention or a
    # known false-positive class for this codebase. Two security-relevant rules are
    # deliberately NOT excluded and stay live:
    #   - PSPossibleIncorrectComparisonWithNull (fixed in code; $null on the left)
    #   - PSAvoidUsingConvertToSecureStringWithPlainText (suppressed inline at the one
    #     idiomatic env-var site so a hardcoded secret elsewhere is still caught)
    ExcludeRules = @(
        # Profile/prompt scripts write to the host by design (that IS their output),
        # and the prompt/profile architecture requires cross-scope globals
        # ($global:PromptConst, $global:ProfileModules, deferred-load guards).
        'PSAvoidUsingWriteHost',
        'PSAvoidGlobalVars',

        # The repo is UTF-8 / LF with no BOM (.editorconfig charset=utf-8); a BOM
        # breaks the cross-platform bash/LF tooling. Requiring one contradicts that.
        'PSUseBOMForUnicodeEncodedFile',

        # AGENTS.md: gate state-changing operations behind ShouldProcess only when the
        # code actually changes state, not as blanket boilerplate. The flagged
        # functions are internal profile/setup helpers, not reusable -WhatIf cmdlets.
        'PSUseShouldProcessForStateChangingFunctions',

        # The prompt is deliberately fail-open: an empty catch keeps a broken git/jj
        # call from ever taking down the shell (see Set-Prompt.ps1 architecture).
        'PSAvoidUsingEmptyCatchBlock',

        # Fires on API-contract signatures: Register-ArgumentCompleter / PSReadLine
        # key-handler scriptblocks receive fixed positional params, some unused by
        # contract (e.g. $commandName, $cursorPosition) but not removable.
        'PSReviewUnusedParameter',

        # Personal utility scripts, not a published module needing discoverable
        # Verb-Noun cmdlet names (Show-Hotkeys, Remove-OldBackups).
        'PSUseSingularNouns',

        # Required tool-init idiom: `zoxide init powershell --hook none | Out-String`
        # must be run through Invoke-Expression to install the shell integration.
        'PSAvoidUsingInvokeExpression',

        # False positive across ForEach-Object -Begin/-Process: a var assigned in
        # -Begin and read in -Process looks unread to the per-scriptblock analyzer.
        'PSUseDeclaredVarsMoreThanAssignments',

        # Intentional in-script helper (winget/packages.ps1 defines Install-Package as
        # a local wrapper); scoped to that script, never dot-sourced into a session.
        'PSAvoidOverwritingBuiltInCmdlets'
    )

    # Formatting rules: Allman braces. Statement braces (function, if/else,
    # try/catch, class) sit on their own line; scriptblock arguments such as
    # `ForEach-Object {`, hashtables, and one-line blocks stay as written.
    # Invoke-Formatter with these settings fixes every finding.
    Rules = @{
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $false
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }
        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind = 'space'
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            # Off: a native command receives `a,b` as one argument and `a, b` as two, so a
            # space added after a comma can change what an .exe or script is given.
            CheckSeparator = $false
            CheckInnerBrace = $true
            CheckPipe = $true
            CheckParameter = $false
        }
    }
}
