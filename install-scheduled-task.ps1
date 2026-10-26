param(
    [Parameter(Mandatory = $false)]
    [string]$TaskName = "UEBA Baseline Orchestrator",

    [Parameter(Mandatory = $false)]
    [string]$StartTime = "07:00",

    [Parameter(Mandatory = $false)]
    [int]$IntervalMinutes = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($IntervalMinutes -lt 15) {
    throw "IntervalMinutes must be at least 15."
}

$runnerPath = Join-Path $PSScriptRoot "run-baseline.ps1"
$configPath = Join-Path $PSScriptRoot "baseline-config.json"
$logPath = Join-Path $PSScriptRoot "baseline-run.log"

foreach ($path in @($runnerPath, $configPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
    }
}

$powerShellPath = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if ([string]::IsNullOrWhiteSpace($powerShellPath)) {
    $powerShellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
}

$arguments = @(
    "-NoLogo"
    "-NoProfile"
    "-NonInteractive"
    "-ExecutionPolicy"
    "Bypass"
    "-File"
    "`"$runnerPath`""
    "-ConfigPath"
    "`"$configPath`""
    "-LogPath"
    "`"$logPath`""
) -join " "

$action = New-ScheduledTaskAction `
    -Execute $powerShellPath `
    -Argument $arguments `
    -WorkingDirectory $PSScriptRoot

$start = [datetime]::Today.Add([timespan]::Parse($StartTime))
if ($start -le (Get-Date)) {
    $start = $start.AddDays(1)
}

$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At $start `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType Interactive `
    -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15) `
    -StartWhenAvailable

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Runs bounded, user-attributed Microsoft Graph activity for the Sentinel UEBA lab."

Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

Write-Host "Registered '$TaskName' for '$currentUser'."
Write-Host "The task starts at '$start', repeats every $IntervalMinutes minutes, and runs only while this Windows user is logged on."
Write-Host "Peer-group schedules in baseline-config.json control when persona activity is allowed."
