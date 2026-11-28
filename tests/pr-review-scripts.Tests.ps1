#Requires -Version 7
# Pester tests for the pr-review skill's Azure DevOps scripts
# (ai-agents/skills/pr-review/scripts). Every test mocks az and Invoke-RestMethod, so no test
# needs the Azure CLI or reaches the network. The example organisation, project and ids are
# neutral placeholders.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSafety.ps1')
    $script:ScriptsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'ai-agents/skills/pr-review/scripts'
    $script:OrgUrl = 'https://dev.azure.com/example-org'

    # Stub so Mock az works where the Azure CLI is not installed. Every test mocks it.
    function az
    {
        throw 'az is not mocked in this test'
    }

    # An error record shaped like the one Invoke-RestMethod throws for an HTTP error status.
    function New-HttpErrorRecord
    {
        param([int]$StatusCode, [string]$Body)
        $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$StatusCode)
        $exception = [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $StatusCode.", $response)
        $record = [System.Management.Automation.ErrorRecord]::new($exception, 'WebCmdletWebResponseException', [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
        if ($Body)
        {
            $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Body)
        }
        return $record
    }

    function Invoke-PrReviewScript
    {
        param([string]$Name, [hashtable]$Parameters, [object[]]$InputItems, [string]$InputParameter)
        $inputFile = Join-Path $TestDrive 'input.json'
        $resultFile = Join-Path $TestDrive 'result.json'
        Remove-Item -LiteralPath $resultFile -ErrorAction Ignore
        ConvertTo-Json -InputObject $InputItems -Depth 10 | Set-Content -LiteralPath $inputFile -Encoding utf8
        $Parameters[$InputParameter] = $inputFile
        $Parameters.ResultFile = $resultFile
        & (Join-Path $script:ScriptsDir $Name) @Parameters 6>$null 3>$null
    }

    function Get-PrReviewResult
    {
        return @(Get-Content -Raw -LiteralPath (Join-Path $TestDrive 'result.json') | ConvertFrom-Json)
    }

    function Get-PostedJson
    {
        param([object]$Body)
        return [System.Text.Encoding]::UTF8.GetString([byte[]]$Body)
    }
}

Describe 'Post-PrThreads' {
    BeforeAll {
        function Invoke-PostPrThreads
        {
            param([object[]]$Comments, [int]$DelaySeconds = 0, [switch]$DryRun)
            $parameters = @{
                OrganizationUrl = $script:OrgUrl
                Project = 'Example Project'
                RepositoryId = 'repo-guid'
                PullRequestId = 42
                DelaySeconds = $DelaySeconds
                DryRun = $DryRun
            }
            Invoke-PrReviewScript -Name 'Post-PrThreads.ps1' -Parameters $parameters -InputItems $Comments -InputParameter 'CommentsFile'
        }
    }

    BeforeEach {
        $Posts = [System.Collections.Generic.List[hashtable]]::new()
        $ExistingThreads = @()
        $PostFailures = @{}
        Mock az { 'fake-token' }
        Mock Start-Sleep {}
        Mock Invoke-RestMethod {
            if ($Method -eq 'GET' -and $Uri -match '/iterations\?')
            {
                return [pscustomobject]@{ value = @([pscustomobject]@{ id = 1 }, [pscustomobject]@{ id = 3 }) }
            }
            if ($Method -eq 'GET' -and $Uri -match '/changes\?')
            {
                return [pscustomobject]@{
                    changeEntries = @([pscustomobject]@{ changeTrackingId = 7; item = [pscustomobject]@{ path = '/src/app.ps1' } })
                    nextSkip = 0
                }
            }
            if ($Method -eq 'GET' -and $Uri -match '/threads\?')
            {
                return [pscustomobject]@{ value = $ExistingThreads }
            }
            if ($Method -eq 'POST')
            {
                $Posts.Add(@{ Uri = ([uri]$Uri).AbsoluteUri; Body = (Get-PostedJson -Body $Body | ConvertFrom-Json -AsHashtable) })
                if ($PostFailures.ContainsKey($Posts.Count))
                {
                    throw (New-HttpErrorRecord -StatusCode $PostFailures[$Posts.Count] -Body '{"message":"rejected"}')
                }
                return [pscustomobject]@{ id = 100 + $Posts.Count }
            }
            throw "Unexpected call: $Method $Uri"
        }
    }

    It 'anchors a comment with a start line to those lines of the latest iteration' {
        Invoke-PostPrThreads -Comments @(@{ key = 'c1'; filePath = 'src/app.ps1'; startLine = 10; endLine = 12; content = 'text' })

        $Posts.Count | Should -Be 1
        $Posts[0].Uri | Should -Be 'https://dev.azure.com/example-org/Example%20Project/_apis/git/repositories/repo-guid/pullRequests/42/threads?api-version=7.1'
        $Posts[0].Body.status | Should -Be 1
        $Posts[0].Body.threadContext.filePath | Should -Be '/src/app.ps1'
        $Posts[0].Body.threadContext.rightFileStart.line | Should -Be 10
        $Posts[0].Body.threadContext.rightFileEnd.line | Should -Be 12
        $Posts[0].Body.pullRequestThreadContext.iterationContext.secondComparingIteration | Should -Be 3
        $Posts[0].Body.pullRequestThreadContext.changeTrackingId | Should -Be 7
        $result = Get-PrReviewResult
        $result[0].threadId | Should -Be 101
        $result[0].anchor | Should -Be '/src/app.ps1 R10-12'
    }

    It 'posts a file-level thread when the comment has a file but no start line' {
        Invoke-PostPrThreads -Comments @(@{ key = 'c1'; filePath = '/src/app.ps1'; content = 'text' })

        $Posts[0].Body.threadContext.filePath | Should -Be '/src/app.ps1'
        $Posts[0].Body.threadContext.ContainsKey('rightFileStart') | Should -BeFalse
        (Get-PrReviewResult)[0].anchor | Should -Be '/src/app.ps1 (file)'
    }

    It 'posts a general PR comment when the comment has no file' {
        Invoke-PostPrThreads -Comments @(@{ key = 'c1'; content = 'text' })

        $Posts[0].Body.ContainsKey('threadContext') | Should -BeFalse
        (Get-PrReviewResult)[0].anchor | Should -Be 'general'
    }

    It 'maps status closed to 4 and writes properties as typed string values' {
        Invoke-PostPrThreads -Comments @(@{ key = 'c1'; content = 'text'; status = 'closed'; properties = @{ 'prReview.deferredWorkItem' = '123' } })

        $Posts[0].Body.status | Should -Be 4
        $Posts[0].Body.properties['prReview.deferredWorkItem']['$type'] | Should -Be 'System.String'
        $Posts[0].Body.properties['prReview.deferredWorkItem']['$value'] | Should -Be '123'
    }

    It 'rejects an unknown status before any network call' {
        $comments = @(@{ key = 'c1'; content = 'ok' }, @{ key = 'c2'; content = 'text'; status = 'fixed' })

        { Invoke-PostPrThreads -Comments $comments } | Should -Throw '*c2*fixed*'

        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        Should -Invoke az -Times 0 -Exactly
    }

    It 'skips a comment whose file, start line and first line match an existing thread' {
        $thread = [pscustomobject]@{
            id = 55
            threadContext = [pscustomobject]@{ filePath = '/src/app.ps1'; rightFileStart = [pscustomobject]@{ line = 10 } }
            comments = @([pscustomobject]@{ content = "**issue (blocking):** the loop never ends`n`nOlder wording." })
        }
        $ExistingThreads = @($thread)
        $comments = @(
            @{ key = 'c1'; filePath = '/src/app.ps1'; startLine = 10; content = "**issue (blocking):** the loop never ends`n`nNew wording." }
            @{ key = 'c2'; filePath = '/src/app.ps1'; startLine = 20; content = '**issue (blocking):** another problem' }
        )

        Invoke-PostPrThreads -Comments $comments

        $Posts.Count | Should -Be 1
        $Posts[0].Body.threadContext.rightFileStart.line | Should -Be 20
        $result = Get-PrReviewResult
        $result[0].skipped | Should -BeTrue
        $result[0].threadId | Should -Be 55
        $result[1].skipped | Should -BeFalse
        $result[1].threadId | Should -Be 101
    }

    It 'retries a 429 response and records the thread from the retry' {
        $PostFailures = @{ 1 = 429 }

        Invoke-PostPrThreads -Comments @(@{ key = 'c1'; content = 'text' })

        $Posts.Count | Should -Be 2
        $result = Get-PrReviewResult
        $result[0].threadId | Should -Be 102
        $result[0].error | Should -BeNullOrEmpty
    }

    It 'gives up after the last retry of a 5xx response and fails the run' {
        $PostFailures = @{ 1 = 503; 2 = 503; 3 = 503; 4 = 503 }

        { Invoke-PostPrThreads -Comments @(@{ key = 'c1'; content = 'text' }) } | Should -Throw '*1 of 1*'

        $Posts.Count | Should -Be 4
        (Get-PrReviewResult)[0].error | Should -BeLike '*503*'
    }

    It 'records a 400 without retrying, continues with the next comment, and fails the run' {
        $PostFailures = @{ 1 = 400 }
        $comments = @(@{ key = 'c1'; content = 'a' }, @{ key = 'c2'; content = 'b' })

        { Invoke-PostPrThreads -Comments $comments } | Should -Throw '*1 of 2*'

        $Posts.Count | Should -Be 2
        $result = Get-PrReviewResult
        $result[0].threadId | Should -BeNullOrEmpty
        $result[0].error | Should -BeLike '*400*Body:*rejected*'
        $result[1].threadId | Should -Be 102
    }

    It 'marks every comment with the error and fails when the setup reads fail' {
        Mock Invoke-RestMethod { throw (New-HttpErrorRecord -StatusCode 401) } -ParameterFilter { $Method -eq 'GET' }
        $comments = @(@{ key = 'c1'; content = 'a' }, @{ key = 'c2'; content = 'b' })

        { Invoke-PostPrThreads -Comments $comments } | Should -Throw '*401*'

        $result = Get-PrReviewResult
        $result.Count | Should -Be 2
        $result | ForEach-Object { $_.threadId | Should -BeNullOrEmpty }
        $result | ForEach-Object { $_.error | Should -BeLike '*Nothing was posted*401*' }
    }

    It 'waits DelaySeconds between posts and keeps completed comments when the run stops' {
        Mock Start-Sleep { throw 'run stopped' } -ParameterFilter { $Seconds -eq 9 }
        $comments = @(@{ key = 'c1'; content = 'a' }, @{ key = 'c2'; content = 'b' })

        { Invoke-PostPrThreads -Comments $comments -DelaySeconds 9 } | Should -Throw '*run stopped*'

        $result = Get-PrReviewResult
        $result.Count | Should -Be 1
        $result[0].key | Should -Be 'c1'
        $result[0].threadId | Should -Be 101
    }

    It 'gets no token and makes no network call under -DryRun' {
        Invoke-PostPrThreads -Comments @(@{ key = 'c1'; filePath = '/src/app.ps1'; startLine = 3; content = 'text'; status = 'closed' }) -DryRun

        Should -Invoke az -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        $result = Get-PrReviewResult
        $result[0].threadId | Should -Be 'dry-run'
        $result[0].status | Should -Be 'closed'
    }
}

Describe 'New-DeferredWorkItem' {
    BeforeAll {
        function Invoke-NewDeferredWorkItem
        {
            param([object[]]$Items, [switch]$DryRun)
            $parameters = @{
                OrganizationUrl = $script:OrgUrl
                ParentId = 1000
                WorkItemType = 'Product Backlog Item'
                DryRun = $DryRun
            }
            Invoke-PrReviewScript -Name 'New-DeferredWorkItem.ps1' -Parameters $parameters -InputItems $Items -InputParameter 'InputFile'
        }
    }

    BeforeEach {
        $Posts = [System.Collections.Generic.List[hashtable]]::new()
        $ChildTitles = @{}
        $FailPostNumber = 0
        Mock az { 'fake-token' }
        Mock Start-Sleep {}
        Mock Invoke-RestMethod {
            if ($Method -eq 'GET' -and $Uri -match '/workitems/1000\?')
            {
                return [pscustomobject]@{
                    id = 1000
                    url = 'https://dev.azure.com/example-org/project-guid/_apis/wit/workItems/1000'
                    fields = [pscustomobject]@{
                        'System.TeamProject' = 'Example Project'
                        'System.AreaPath' = 'Example Project\Area'
                        'System.IterationPath' = 'Example Project\Sprint 1'
                    }
                    relations = @($ChildTitles.Keys | ForEach-Object { [pscustomobject]@{ rel = 'System.LinkTypes.Hierarchy-Forward'; url = "https://dev.azure.com/example-org/_apis/wit/workItems/$_" } })
                }
            }
            if ($Method -eq 'GET' -and $Uri -match '/workitems\?ids=')
            {
                return [pscustomobject]@{
                    value = @($ChildTitles.Keys | ForEach-Object { [pscustomobject]@{ id = $_; fields = [pscustomobject]@{ 'System.Title' = $ChildTitles[$_] } } })
                }
            }
            if ($Method -eq 'POST')
            {
                $json = Get-PostedJson -Body $Body
                $Posts.Add(@{ Uri = ([uri]$Uri).AbsoluteUri; ContentType = $ContentType; Json = $json; Body = ($json | ConvertFrom-Json -AsHashtable -NoEnumerate) })
                if ($Posts.Count -eq $FailPostNumber)
                {
                    throw (New-HttpErrorRecord -StatusCode 400)
                }
                return [pscustomobject]@{ id = 900 + $Posts.Count }
            }
            throw "Unexpected call: $Method $Uri"
        }
    }

    It 'creates the given work item type in the parent''s project as a JSON patch' {
        Invoke-NewDeferredWorkItem -Items @(@{ key = 'c3'; title = 'T'; descriptionHtml = '<p>D</p>' })

        $Posts.Count | Should -Be 1
        $Posts[0].Uri | Should -BeExactly 'https://dev.azure.com/example-org/Example%20Project/_apis/wit/workitems/$Product%20Backlog%20Item?api-version=7.1'
        $Posts[0].ContentType | Should -BeLike 'application/json-patch+json*'
        $Posts[0].Json.TrimStart() | Should -BeLike '`[*'
    }

    It 'takes area and iteration from the parent and adds only a parent relation' {
        Invoke-NewDeferredWorkItem -Items @(@{ key = 'c3'; title = 'Fix the thing'; descriptionHtml = '<p>Why</p>' })

        $ops = $Posts[0].Body
        ($ops | Where-Object { $_.path -eq '/fields/System.Title' }).value | Should -Be 'Fix the thing'
        ($ops | Where-Object { $_.path -eq '/fields/System.AreaPath' }).value | Should -Be 'Example Project\Area'
        ($ops | Where-Object { $_.path -eq '/fields/System.IterationPath' }).value | Should -Be 'Example Project\Sprint 1'
        $relations = @($ops | Where-Object { $_.path -eq '/relations/-' })
        $relations.Count | Should -Be 1
        $relations[0].value.rel | Should -Be 'System.LinkTypes.Hierarchy-Reverse'
        $Posts[0].Json | Should -Not -Match 'ArtifactLink|Hyperlink|System\.Tags|AssignedTo'
        $result = Get-PrReviewResult
        $result[0].workItemId | Should -Be 901
        $result[0].workItemUrl | Should -Be 'https://dev.azure.com/example-org/Example%20Project/_workitems/edit/901'
    }

    It 'skips an item whose title matches an existing child of the parent' {
        $ChildTitles = @{ 950 = 'Fix the thing' }
        $items = @(
            @{ key = 'c3'; title = 'Fix the thing'; descriptionHtml = '<p>A</p>' }
            @{ key = 'c4'; title = 'Another thing'; descriptionHtml = '<p>B</p>' }
        )

        Invoke-NewDeferredWorkItem -Items $items

        $Posts.Count | Should -Be 1
        $result = Get-PrReviewResult
        $result[0].skipped | Should -BeTrue
        $result[0].workItemId | Should -Be 950
        $result[1].workItemId | Should -Be 901
    }

    It 'records a failed item, continues with the next one, and fails the run' {
        $FailPostNumber = 1
        $items = @(
            @{ key = 'c3'; title = 'A'; descriptionHtml = '<p>A</p>' }
            @{ key = 'c4'; title = 'B'; descriptionHtml = '<p>B</p>' }
        )

        { Invoke-NewDeferredWorkItem -Items $items } | Should -Throw '*1 of 2*'

        $result = Get-PrReviewResult
        $result[0].workItemId | Should -BeNullOrEmpty
        $result[0].error | Should -BeLike '*400*'
        $result[1].workItemId | Should -Be 902
    }

    It 'gets no token and makes no network call under -DryRun' {
        Invoke-NewDeferredWorkItem -Items @(@{ key = 'c3'; title = 'T'; descriptionHtml = '<p>D</p>' }) -DryRun

        Should -Invoke az -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        (Get-PrReviewResult)[0].workItemId | Should -Be 'dry-run'
    }
}

Describe 'Add-WorkItemComments' {
    BeforeAll {
        function Invoke-AddWorkItemComment
        {
            param([object[]]$Items, [switch]$DryRun)
            $parameters = @{
                OrganizationUrl = $script:OrgUrl
                Project = 'Example Project'
                DryRun = $DryRun
            }
            Invoke-PrReviewScript -Name 'Add-WorkItemComments.ps1' -Parameters $parameters -InputItems $Items -InputParameter 'InputFile'
        }
    }

    BeforeEach {
        $Posts = [System.Collections.Generic.List[hashtable]]::new()
        $ExistingComments = @()
        Mock az { 'fake-token' }
        Mock Start-Sleep {}
        Mock Invoke-RestMethod {
            if ($Method -eq 'GET' -and $Uri -match '/comments\?')
            {
                return [pscustomobject]@{ comments = $ExistingComments }
            }
            if ($Method -eq 'POST')
            {
                $Posts.Add(@{ Uri = ([uri]$Uri).AbsoluteUri; Body = (Get-PostedJson -Body $Body | ConvertFrom-Json -AsHashtable) })
                return [pscustomobject]@{ id = 500 + $Posts.Count }
            }
            throw "Unexpected call: $Method $Uri"
        }
    }

    It 'POSTs the comment text to the work item comments endpoint' {
        Invoke-AddWorkItemComment -Items @(@{ key = 'c3'; workItemId = 123; text = '<p>See the PR</p>' })

        $Posts.Count | Should -Be 1
        $Posts[0].Uri | Should -BeExactly 'https://dev.azure.com/example-org/Example%20Project/_apis/wit/workItems/123/comments?api-version=7.1-preview.4'
        $Posts[0].Body.text | Should -Be '<p>See the PR</p>'
        (Get-PrReviewResult)[0].commentId | Should -Be 501
    }

    It 'skips a work item that already has the same comment' {
        $ExistingComments = @([pscustomobject]@{ id = 77; text = '<p>See the PR</p>' })

        Invoke-AddWorkItemComment -Items @(@{ key = 'c3'; workItemId = 123; text = '<p>See the PR</p>' })

        $Posts.Count | Should -Be 0
        $result = Get-PrReviewResult
        $result[0].skipped | Should -BeTrue
        $result[0].commentId | Should -Be 77
    }

    It 'records a non-integer workItemId, continues with the next item, and fails the run' {
        $items = @(
            @{ key = 'c3'; workItemId = 'dry-run'; text = '<p>a</p>' }
            @{ key = 'c4'; workItemId = 124; text = '<p>b</p>' }
        )

        { Invoke-AddWorkItemComment -Items $items } | Should -Throw '*1 of 2*'

        $result = Get-PrReviewResult
        $result[0].error | Should -BeLike '*dry-run*'
        $result[1].commentId | Should -Be 501
    }

    It 'gets no token and makes no network call under -DryRun' {
        Invoke-AddWorkItemComment -Items @(@{ key = 'c3'; workItemId = 123; text = '<p>x</p>' }) -DryRun

        Should -Invoke az -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
        (Get-PrReviewResult)[0].commentId | Should -Be 'dry-run'
    }
}
