param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [string]$DisplayName = "UEBA Baseline Orchestrator",

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "baseline-config.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$module = Get-Module -ListAvailable Microsoft.Graph.Authentication |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $module) {
    throw "Microsoft.Graph.Authentication is required. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
}

Import-Module Microsoft.Graph.Authentication

$graphScopes = @{
    "User.Read" = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
    "Mail.Send" = "e383f46e-2787-4529-855e-0e479a3ffac0"
    "Calendars.ReadWrite" = "1ec239c2-d7c9-4623-a91a-a9775856bb36"
    "Files.ReadWrite" = "5c28f0bf-8a70-41f1-8ab2-9032436ddb65"
}

$graphAppId = "00000003-0000-0000-c000-000000000000"
$templatePath = Join-Path $PSScriptRoot "baseline-config.sample.json"

if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "Configuration template not found: $templatePath"
}

Connect-MgGraph -TenantId $TenantId -Scopes "Application.ReadWrite.All" -UseDeviceCode -NoWelcome

try {
    $escapedFilterName = $DisplayName.Replace("'", "''")
    $encodedFilter = [Uri]::EscapeDataString("displayName eq '$escapedFilterName'")
    $existing = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=$encodedFilter&`$select=id,appId,displayName"

    if (@($existing.value).Count -gt 1) {
        throw "More than one application is named '$DisplayName'. Rename or remove duplicates before continuing."
    }

    $applicationConfiguration = @{
        displayName = $DisplayName
        signInAudience = "AzureADMyOrg"
        isFallbackPublicClient = $true
        publicClient = @{
            redirectUris = @("http://localhost")
        }
        requiredResourceAccess = @(
            @{
                resourceAppId = $graphAppId
                resourceAccess = @(
                    $graphScopes.Values | ForEach-Object {
                        @{
                            id = $_
                            type = "Scope"
                        }
                    }
                )
            }
        )
    }

    if (@($existing.value).Count -eq 1) {
        $application = $existing.value[0]
        $null = Invoke-MgGraphRequest `
            -Method PATCH `
            -Uri "https://graph.microsoft.com/v1.0/applications/$($application.id)" `
            -Body ($applicationConfiguration | ConvertTo-Json -Depth 8) `
            -ContentType "application/json"
        Write-Host "Using existing application '$DisplayName' ($($application.appId))."
    } else {
        $application = Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/applications" `
            -Body ($applicationConfiguration | ConvertTo-Json -Depth 8) `
            -ContentType "application/json"

        Write-Host "Created application '$DisplayName' ($($application.appId))."
    }

    $servicePrincipals = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId%20eq%20'$($application.appId)'&`$select=id,appId"

    if (@($servicePrincipals.value).Count -eq 0) {
        $null = Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" `
            -Body (@{ appId = $application.appId } | ConvertTo-Json) `
            -ContentType "application/json"
        Write-Host "Created the tenant service principal."
    }

    $config = Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json
    $config.tenantId = $TenantId
    $config.authentication.clientId = $application.appId
    $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigPath -Encoding utf8

    Write-Host "Wrote '$ConfigPath'."
    Write-Host "Next: replace every <TENANT_DOMAIN> user placeholder, then run .\validate-config.ps1."
    Write-Host "If tenant user consent is restricted, an administrator must grant consent to the four delegated Graph permissions."
} finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
