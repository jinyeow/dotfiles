# Shared Azure DevOps REST helpers for the pr-review scripts. Dot-source this file; it only
# defines functions. Every network call goes through Invoke-AdoRequest, which retries a 429 or
# a 5xx response with exponential backoff and then raises the last error.

function Get-AdoAccessToken
{
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # 499b84ac-1321-427f-aa17-267ca6975798 is the well-known Azure DevOps resource id.
    [string]$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
    if (-not $token)
    {
        throw [System.InvalidOperationException]::new('Could not get an Azure DevOps access token from az. Run az login.')
    }
    return $token
}

function Get-AdoStatusCode
{
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response)
    {
        return 0
    }
    return [int]$response.StatusCode
}

function Get-AdoErrorText
{
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)

    [string]$text = $ErrorRecord.Exception.Message
    [int]$status = Get-AdoStatusCode -ErrorRecord $ErrorRecord
    if ($status -gt 0)
    {
        $text += " Status: $status."
    }
    if ($ErrorRecord.ErrorDetails.Message)
    {
        $text += " Body: $($ErrorRecord.ErrorDetails.Message)"
    }
    return $text
}

function Invoke-AdoRequest
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][hashtable]$Headers,
        [object]$Body,
        [string]$ContentType = 'application/json; charset=utf-8',
        [ValidateRange(1, 10)][int]$MaxAttempts = 4,
        [ValidateRange(0, 60)][int]$RetryDelaySeconds = 2
    )

    $request = @{ Method = $Method; Uri = $Uri; Headers = $Headers }
    if ($null -ne $Body)
    {
        $request.ContentType = $ContentType
        $request.Body = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Depth 20))
    }

    for ([int]$attempt = 1; ; $attempt++)
    {
        try
        {
            return Invoke-RestMethod @request
        }
        catch
        {
            [int]$status = Get-AdoStatusCode -ErrorRecord $_
            [bool]$retryable = $status -eq 429 -or $status -ge 500
            if (-not $retryable -or $attempt -ge $MaxAttempts)
            {
                throw
            }
            [int]$delay = $RetryDelaySeconds * [math]::Pow(2, $attempt - 1)
            Write-Warning ('Retrying Azure DevOps request. method={0} status={1} attempt={2} maxAttempts={3} delaySeconds={4}' -f $Method, $status, $attempt, $MaxAttempts, $delay)
            Start-Sleep -Seconds $delay
        }
    }
}

function Save-AdoResult
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[pscustomobject]]$Results,
        [Parameter(Mandatory)][string]$Path
    )

    ConvertTo-Json -InputObject $Results.ToArray() -Depth 5 | Set-Content -LiteralPath $Path -Encoding utf8
}
