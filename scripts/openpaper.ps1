[CmdletBinding()]
param(
    [ValidateSet('Status', 'Start', 'Open', 'Stop')]
    [string]$Action = 'Open',

    [ValidateRange(1, 65535)]
    [int]$Port = 8787
)

$ErrorActionPreference = 'Stop'

$appRoot = 'D:\DSH_Desktop\dsh_learn\lit-search-app'
$serverScript = Join-Path $appRoot 'server.py'
$healthUrl = "http://127.0.0.1:$Port/api/health"
$appUrl = "http://127.0.0.1:$Port/"
$logRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'openpaper-lit-search'
$stdoutLog = Join-Path $logRoot "openpaper-$Port.out.log"
$stderrLog = Join-Path $logRoot "openpaper-$Port.err.log"

function Get-Health {
    try {
        $response = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 2
        if ($response.ok -eq $true -and $response.workflow -contains 'undermind_deep_search') {
            return $response
        }
        return $null
    }
    catch {
        return $null
    }
}

function Get-Listener {
    return Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

function Get-PythonCommand {
    $windowsPy = Join-Path $env:WINDIR 'py.exe'
    if (Test-Path -LiteralPath $windowsPy) {
        return [pscustomobject]@{ FilePath = $windowsPy; Prefix = @('-3') }
    }

    $knownPython = 'D:\Python312\python.exe'
    if (Test-Path -LiteralPath $knownPython) {
        return [pscustomobject]@{ FilePath = $knownPython; Prefix = @() }
    }

    $python = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($python) {
        return [pscustomobject]@{ FilePath = $python.Source; Prefix = @() }
    }

    throw 'Python 3 was not found. Install Python 3.10+ or add python.exe to PATH.'
}

function Write-Status {
    $health = Get-Health
    if ($health) {
        [pscustomobject]@{
            state = 'running'
            url = $appUrl
            health = $health
        } | ConvertTo-Json -Depth 8
        return
    }

    $listener = Get-Listener
    if ($listener) {
        [pscustomobject]@{
            state = 'port-conflict'
            url = $appUrl
            pid = $listener.OwningProcess
        } | ConvertTo-Json
        return
    }

    [pscustomobject]@{
        state = 'stopped'
        url = $appUrl
    } | ConvertTo-Json
}

function Start-OpenPaper {
    $health = Get-Health
    if ($health) {
        return 'already-running'
    }

    $listener = Get-Listener
    if ($listener) {
        throw "Port $Port is already in use by PID $($listener.OwningProcess); nothing was stopped."
    }

    if (-not (Test-Path -LiteralPath $serverScript -PathType Leaf)) {
        throw "OpenPaper server was not found at $serverScript"
    }

    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    $python = Get-PythonCommand
    $arguments = @($python.Prefix) + @('-B', $serverScript, '--port', $Port, '--no-browser')
    $process = Start-Process -FilePath $python.FilePath `
        -ArgumentList $arguments `
        -WorkingDirectory $appRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -PassThru

    $deadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 300
        $health = Get-Health
        if ($health) {
            return 'started'
        }
        if ($process.HasExited) {
            $details = if (Test-Path -LiteralPath $stderrLog) {
                (Get-Content -LiteralPath $stderrLog -Tail 20) -join [Environment]::NewLine
            } else {
                'No error log was produced.'
            }
            throw "OpenPaper exited during startup. $details"
        }
    } while ((Get-Date) -lt $deadline)

    throw "OpenPaper did not become healthy within 20 seconds. Check $stderrLog"
}

function Stop-OpenPaper {
    $listener = Get-Listener
    if (-not $listener) {
        return 'already-stopped'
    }

    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)"
    if (-not $process) {
        throw "Refusing to stop PID $($listener.OwningProcess): process details are unavailable."
    }
    $normalizedCommand = ($process.CommandLine -replace '/', '\').ToLowerInvariant()
    $normalizedServer = $serverScript.ToLowerInvariant()
    if ($process.Name -notmatch '^python(w)?\.exe$' -or -not $normalizedCommand.Contains($normalizedServer)) {
        throw "Refusing to stop PID $($listener.OwningProcess): it is not the exact OpenPaper server launched from $serverScript"
    }

    Stop-Process -Id $listener.OwningProcess
    return 'stopped'
}

switch ($Action) {
    'Status' {
        Write-Status
    }
    'Start' {
        $state = Start-OpenPaper
        [pscustomobject]@{ state = $state; url = $appUrl; stdout = $stdoutLog; stderr = $stderrLog } |
            ConvertTo-Json
    }
    'Open' {
        $state = Start-OpenPaper
        Start-Process -FilePath $appUrl | Out-Null
        [pscustomobject]@{ state = $state; url = $appUrl; stdout = $stdoutLog; stderr = $stderrLog } |
            ConvertTo-Json
    }
    'Stop' {
        $state = Stop-OpenPaper
        [pscustomobject]@{ state = $state; url = $appUrl } | ConvertTo-Json
    }
}
