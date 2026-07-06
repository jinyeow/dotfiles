@{
    # Gate on Error + Warning; Information is noise for dotfiles.
    Severity     = @('Error', 'Warning')

    # Profile/prompt scripts write to the host by design (that IS their output),
    # and the prompt/profile architecture requires cross-scope globals
    # ($global:PromptConst, $global:ProfileModules, deferred-load guards).
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSAvoidGlobalVars'
    )
}
