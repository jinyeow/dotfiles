# NOTE: Requires the following environment variables to be set:
# - SP_CLIENT_ID
# - SP_CLIENT_SECRET
# - AZURE_TENANT_ID
# Use PS-Dotenv to load .env files

$clientSecret = Write-Output $env:SP_CLIENT_SECRET | ConvertTo-SecureString -AsPlainText -Force

$login = New-Object -TypeName System.Management.Automation.PSCredential  -ArgumentList $env:SP_CLIENT_ID, $clientSecret

Connect-AzAccount -ServicePrincipal -Credential $login -Tenant $env:AZURE_TENANT_ID
