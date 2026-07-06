# NOTE: Requires the following environment variables to be set:
# - SP_CLIENT_ID
# - SP_CLIENT_SECRET
# - AZURE_TENANT_ID
# Use PS-Dotenv to load .env files

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Secret is read from $env:SP_CLIENT_SECRET (never hardcoded); ConvertTo-SecureString -AsPlainText is the only supported way to build a service-principal PSCredential from an env var.')]
param()

$clientSecret = Write-Output $env:SP_CLIENT_SECRET | ConvertTo-SecureString -AsPlainText -Force

$login = New-Object -TypeName System.Management.Automation.PSCredential  -ArgumentList $env:SP_CLIENT_ID, $clientSecret

Connect-AzAccount -ServicePrincipal -Credential $login -Tenant $env:AZURE_TENANT_ID
