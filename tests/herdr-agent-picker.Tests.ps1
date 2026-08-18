#Requires -Version 7
# Pester tests for the pure logic behind herdr/agent-picker.ps1 (the fzf-backed Herdr
# agent picker, issue #169). The script's entry point calls the live `herdr` CLI at
# top level and isn't dot-sourceable in a test; we lift just the two pure helpers out
# by AST, same approach as tests/fzf-pickers.Tests.ps1.

BeforeAll {
    $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'herdr' 'agent-picker.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
    $wanted = 'ConvertTo-HerdrAgentPickerLines', 'Get-HerdrPaneIdFromSelection'
    $funcs = $ast.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $funcs) {
        if ($wanted | Where-Object { $fn.Name -match $_ }) {
            . ([scriptblock]::Create($fn.Extent.Text))
        }
    }
}

Describe 'ConvertTo-HerdrAgentPickerLines' {
    BeforeAll {
        $agent = [pscustomobject]@{
            agent_status            = 'working'
            agent                   = 'claude'
            workspace_id            = 'w6'
            tab_id                  = 'w6:t1'
            terminal_title_stripped = 'Planning session'
            pane_id                 = 'w6:p1Z'
        }
    }

    It 'formats status, agent kind, workspace, tab, title, with pane_id appended after a tab' {
        $lines = ConvertTo-HerdrAgentPickerLines -Agents @($agent) `
            -WorkspaceLabels @{ w6 = 'personal' } -TabLabels @{ 'w6:t1' = 'dotfiles' }
        $expectedDisplay = '{0,-8} {1,-8} {2} > {3} > {4}' -f 'working', 'claude', 'personal', 'dotfiles', 'Planning session'
        $lines | Should -BeExactly "$expectedDisplay`tw6:p1Z"
    }

    It 'falls back to the raw workspace_id/tab_id when no label is supplied' {
        $lines = ConvertTo-HerdrAgentPickerLines -Agents @($agent)
        $lines | Should -Match ([regex]::Escape('w6 > w6:t1 >'))
    }

    It 'emits one line per agent, in order' {
        $second = [pscustomobject]@{
            agent_status            = 'idle'
            agent                   = 'claude'
            workspace_id            = 'w7'
            tab_id                  = 'w7:tG'
            terminal_title_stripped = 'Claude Code'
            pane_id                 = 'w7:p17'
        }
        $lines = ConvertTo-HerdrAgentPickerLines -Agents @($agent, $second)
        $lines.Count | Should -Be 2
        $lines[1] | Should -Match ([regex]::Escape('w7:p17'))
    }

    It 'returns an empty result for an empty/no agent list' {
        ConvertTo-HerdrAgentPickerLines -Agents @() | Should -BeNullOrEmpty
        ConvertTo-HerdrAgentPickerLines -Agents $null | Should -BeNullOrEmpty
    }
}

Describe 'Get-HerdrPaneIdFromSelection' {
    It 'extracts the pane_id after the last tab' {
        Get-HerdrPaneIdFromSelection -Selection "working  claude  personal > dotfiles > Planning session`tw6:p1Z" |
            Should -BeExactly 'w6:p1Z'
    }

    It 'strips a trailing CRLF added by native-command output capture' {
        Get-HerdrPaneIdFromSelection -Selection "display`tw6:p1Z`r`n" | Should -BeExactly 'w6:p1Z'
    }

    It 'returns $null for an empty selection (cancelled picker)' {
        Get-HerdrPaneIdFromSelection -Selection '' | Should -BeNullOrEmpty
    }

    It 'returns $null for a whitespace-only selection' {
        Get-HerdrPaneIdFromSelection -Selection "  `n" | Should -BeNullOrEmpty
    }

    It 'returns $null when no tab delimiter is present (malformed selection)' {
        Get-HerdrPaneIdFromSelection -Selection 'no-delimiter-here' | Should -BeNullOrEmpty
    }
}
