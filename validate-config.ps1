param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "baseline-config.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Configuration file not found: $ConfigPath"
}

$raw = Get-Content -LiteralPath $ConfigPath -Raw
if ($raw -match "<[A-Z0-9_]+>") {
    $placeholders = [regex]::Matches($raw, "<[A-Z0-9_]+>") |
        ForEach-Object Value |
        Sort-Object -Unique
    throw "Replace all configuration placeholders: $($placeholders -join ', ')"
}

$config = $raw | ConvertFrom-Json
$guidValue = [guid]::Empty
if (-not [guid]::TryParse([string]$config.tenantId, [ref]$guidValue)) {
    throw "tenantId must be a GUID."
}
if (-not [guid]::TryParse([string]$config.authentication.clientId, [ref]$guidValue)) {
    throw "authentication.clientId must be a GUID."
}

$users = @($config.users | Where-Object { $_.enabled -ne $false })
if ($users.Count -lt 6) {
    throw "At least six enabled personas are recommended; found $($users.Count)."
}

$duplicateUpns = $users |
    Group-Object { ([string]$_.upn).ToLowerInvariant() } |
    Where-Object Count -gt 1
if ($duplicateUpns) {
    throw "Duplicate persona UPNs: $(($duplicateUpns.Name) -join ', ')"
}

$enabledUpns = @($users | ForEach-Object { ([string]$_.upn).ToLowerInvariant() })
foreach ($user in $users) {
    if ([string]::IsNullOrWhiteSpace([string]$user.upn) -or [string]$user.upn -notmatch "^[^@\s]+@[^@\s]+$") {
        throw "Invalid persona UPN '$($user.upn)'."
    }
    if ([string]::IsNullOrWhiteSpace([string]$user.peerGroup)) {
        throw "Persona '$($user.upn)' has no peerGroup."
    }
    if ([string]$user.mailRecipientUpn -and
        ([string]$user.mailRecipientUpn).ToLowerInvariant() -notin $enabledUpns) {
        throw "Persona '$($user.upn)' references a mail recipient that is not enabled: '$($user.mailRecipientUpn)'."
    }
}

foreach ($scenario in @($config.scenarios)) {
    $probability = [double]$scenario.probability
    if ($probability -lt 0 -or $probability -gt 1) {
        throw "Scenario '$($scenario.name)' probability must be between 0 and 1."
    }
    if ([int]$scenario.maxPerDay -lt 1) {
        throw "Scenario '$($scenario.name)' maxPerDay must be at least 1."
    }
}

$groups = $users | Group-Object peerGroup | Sort-Object Name
Write-Host "Configuration is valid."
Write-Host "Tenant: $($config.tenantId)"
Write-Host "Client: $($config.authentication.clientId)"
Write-Host "Enabled personas: $($users.Count)"
$groups | ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" }

