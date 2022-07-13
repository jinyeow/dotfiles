Set-PSReadLineOption -EditMode Vi -BellStyle None

# == STARTUP ==
#if (-Not (Get-Module -ListAvailable -Name Pscx)) {
#  Install-Module Pscx -Scope CurrentUser -Force
#} 

# == PROMPT ==
function Prompt {
  try {        
    $history = Get-History -ErrorAction Ignore -Count 1
    if ($history) {
      $ts = New-TimeSpan $history.StartExecutionTime  $history.EndExecutionTime
      switch ($ts) {
        {$_.TotalSeconds -lt 1} { 
          [decimal]$d = $_.TotalMilliseconds
          $fg = "green"
          break
        }
        {$_.totalminutes -lt 1} { 
          [decimal]$d = $_.TotalSeconds
          $fg = "yellow"
          break
        }
        {$_.totalminutes -lt 30} { 
          [decimal]$d = $ts.TotalMinutes
          $fg = "red"
          break
        }
        Default { }
      }
    }
  }
  catch { }
  Write-Host -NoNewline -ForegroundColor $fg "[$(Get-Date -Format 'HH:mm:ss')] "
  Write-Host "$($env:UserName)@$($env:ComputerName)"
  # show the drive and then last 2 directories of current path
  if (($pwd.Path.Split('\').count -gt 2)) {
    $path=$pwd.path.split('\')
    Write-Host "$($path[0], '...', $path[-2], $path[-1] -join ('\'))" -NoNewline
  } else {
    Write-Host "$($pwd.path)" -NoNewline
  }
  "> "
}

# == ALIASES ==
if ($PSVersionTable.PSVersion.Major -eq 5) {
    Remove-Item alias:wget
    Remove-Item alias:curl
}
Set-Alias gcif Get-ChildItem -Force

# == FUNCTIONS ==
function Edit-VimRC {
  vim %HOMEPATH%\_vimrc
}

function Sleep-Computer {
  E:\PSTools\psshutdown -d -t 0 -accepteula
}

function gst {
  git status
}

# == KEYBINDS ==
Set-PSReadlineKeyHandler -Key Ctrl+p -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key Ctrl+n -Function HistorySearchForward
Set-PSReadlineKeyHandler -Key Ctrl+a -Function BeginningOfLine
Set-PSReadlineKeyHandler -Key Ctrl+e -Function EndOfLine
Set-PSReadlineKeyHandler -Key Ctrl+[ -Function ViCommandMode
Set-PSReadlineKeyHandler -Key Ctrl+w -Function BackwardDeleteWord
Set-PSReadlineKeyHandler -Key Ctrl+b -Function BackwardChar
Set-PSReadlineKeyHandler -Key Ctrl+f -Function ForwardChar

# == PSFzf ==
Remove-PSReadlineKeyHandler 'Ctrl+r'
Remove-PSReadlineKeyHandler 'Ctrl+t'
Import-Module PSFzf

# == Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

