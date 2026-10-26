param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "baseline-config.json"),

    [Parameter(Mandatory = $false)]
    [string]$LogPath = (Join-Path $PSScriptRoot "baseline-run.log"),

    [Parameter(Mandatory = $false)]
    [string]$PersonaUpn,

    [Parameter(Mandatory = $false)]
    [switch]$Enroll,

    [Parameter(Mandatory = $false)]
    [switch]$Status,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    Add-Content -LiteralPath $LogPath -Value $line
}

function Get-Config {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }

    $config = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace([string]$config.tenantId)) {
        throw "Config.tenantId is required."
    }

    if (-not $config.authentication) {
        throw "Config.authentication is required."
    }

    if ([string]::IsNullOrWhiteSpace([string]$config.authentication.clientId)) {
        throw "Config.authentication.clientId is required."
    }

    if (-not $config.authentication.scopes -or $config.authentication.scopes.Count -eq 0) {
        throw "Config.authentication.scopes must contain at least one delegated Microsoft Graph scope."
    }

    if (-not $config.users -or $config.users.Count -eq 0) {
        throw "Config.users must contain at least one user."
    }

    if (-not $config.scenarios -or $config.scenarios.Count -eq 0) {
        throw "Config.scenarios must contain at least one scenario."
    }

    return $config
}

function Get-EnabledPersonas {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $false)][string]$Upn
    )

    $personas = @($Config.users | Where-Object { $_.enabled -ne $false })
    if (-not [string]::IsNullOrWhiteSpace($Upn)) {
        $personas = @($personas | Where-Object { [string]$_.upn -ieq $Upn })
    }

    if ($personas.Count -eq 0) {
        throw "No enabled persona matched '$Upn'."
    }

    return $personas
}

function Get-StateRoot {
    param([Parameter(Mandatory = $true)]$Config)

    if ($Config.PSObject.Properties.Name -contains "stateDirectory" -and
        -not [string]::IsNullOrWhiteSpace([string]$Config.stateDirectory)) {
        return [Environment]::ExpandEnvironmentVariables([string]$Config.stateDirectory)
    }

    return Join-Path $env:LOCALAPPDATA "UEBA-Baseline"
}

function ConvertTo-SafeName {
    param([Parameter(Mandatory = $true)][string]$Value)

    return ($Value.ToLowerInvariant() -replace "[^a-z0-9._-]", "_")
}

function Initialize-Msal {
    $msalType = "Microsoft.Identity.Client.PublicClientApplicationBuilder" -as [type]
    if (-not $msalType) {
        $module = Get-Module -ListAvailable Microsoft.Graph.Authentication |
            Sort-Object Version -Descending |
            Select-Object -First 1

        if (-not $module) {
            throw "Microsoft.Graph.Authentication is required. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        }

        $identityAbstractionsPath = Join-Path $module.ModuleBase "Dependencies\Microsoft.IdentityModel.Abstractions.dll"
        $runtimeFolder = if ($PSVersionTable.PSEdition -eq "Core") { "Core" } else { "Desktop" }
        $msalPath = Join-Path $module.ModuleBase "Dependencies\$runtimeFolder\Microsoft.Identity.Client.dll"

        Add-Type -Path $identityAbstractionsPath
        Add-Type -Path $msalPath
        $msalType = "Microsoft.Identity.Client.PublicClientApplicationBuilder" -as [type]
    } else {
        $msalPath = $msalType.Assembly.Location
    }

    if (-not $msalType) {
        throw "Microsoft.Identity.Client could not be loaded."
    }

    if (-not ("UebaBaselineV2.DeviceCodeCallback" -as [type])) {
        $compilerReferences = @($msalPath)
        if ($PSVersionTable.PSEdition -eq "Core") {
            $compilerReferences += [string[]](
                [AppContext]::GetData("TRUSTED_PLATFORM_ASSEMBLIES") -split [IO.Path]::PathSeparator
            )
        }

        Add-Type -ReferencedAssemblies $compilerReferences -TypeDefinition @"
using System;
using System.IO;
using System.Security.Cryptography;
using System.Threading.Tasks;
using Microsoft.Identity.Client;

namespace UebaBaselineV2
{
    public static class DeviceCodeCallback
    {
        public static readonly Func<DeviceCodeResult, Task> Handler = ShowMessage;

        private static Task ShowMessage(DeviceCodeResult deviceCode)
        {
            Console.WriteLine(deviceCode.Message);
            return Task.CompletedTask;
        }
    }

    public static class TokenCacheHelper
    {
        public static void Configure(ITokenCache tokenCache, string cachePath, byte[] entropy)
        {
            tokenCache.SetBeforeAccess(args =>
            {
                if (!File.Exists(cachePath))
                {
                    return;
                }

                byte[] protectedBytes = File.ReadAllBytes(cachePath);
                byte[] plainBytes = ProtectedData.Unprotect(
                    protectedBytes,
                    entropy,
                    DataProtectionScope.CurrentUser);

                try
                {
                    args.TokenCache.DeserializeMsalV3(plainBytes, true);
                }
                finally
                {
                    Array.Clear(plainBytes, 0, plainBytes.Length);
                }
            });

            tokenCache.SetAfterAccess(args =>
            {
                if (!args.HasStateChanged)
                {
                    return;
                }

                byte[] plainBytes = args.TokenCache.SerializeMsalV3();
                try
                {
                    byte[] protectedBytes = ProtectedData.Protect(
                        plainBytes,
                        entropy,
                        DataProtectionScope.CurrentUser);

                    string cacheDirectory = Path.GetDirectoryName(cachePath);
                    Directory.CreateDirectory(cacheDirectory);
                    string temporaryPath = cachePath + ".tmp";
                    File.WriteAllBytes(temporaryPath, protectedBytes);

                    if (File.Exists(cachePath))
                    {
                        File.Replace(temporaryPath, cachePath, null);
                    }
                    else
                    {
                        File.Move(temporaryPath, cachePath);
                    }
                }
                finally
                {
                    Array.Clear(plainBytes, 0, plainBytes.Length);
                }
            });
        }
    }
}
"@
    }
}

function Get-CacheEntropy {
    param(
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $true)][string]$ClientId,
        [Parameter(Mandatory = $true)][string]$Upn
    )

    $source = [Text.Encoding]::UTF8.GetBytes("$TenantId|$ClientId|$($Upn.ToLowerInvariant())")
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        return $sha256.ComputeHash($source)
    } finally {
        $sha256.Dispose()
    }
}

function New-PersonaApplication {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)][string]$Upn,
        [Parameter(Mandatory = $true)][string]$CachePath
    )

    Initialize-Msal

    $authority = "https://login.microsoftonline.com/$($Config.tenantId)"
    $application = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create(
        [string]$Config.authentication.clientId
    ).WithAuthority($authority).WithDefaultRedirectUri().Build()

    $entropy = Get-CacheEntropy `
        -TenantId ([string]$Config.tenantId) `
        -ClientId ([string]$Config.authentication.clientId) `
        -Upn $Upn

    $cacheHelperType = "UebaBaselineV2.TokenCacheHelper" -as [type]
    if (-not $cacheHelperType) {
        throw "The token-cache helper could not be initialized."
    }

    $configureArguments = [object[]]::new(3)
    $configureArguments.SetValue($application.UserTokenCache, 0)
    $configureArguments.SetValue($CachePath, 1)
    $configureArguments.SetValue([object][byte[]]$entropy, 2)
    $null = $cacheHelperType.GetMethod("Configure").Invoke($null, $configureArguments)

    return $application
}

function Get-PersonaToken {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)]$Persona,
        [Parameter(Mandatory = $true)][string]$CachePath,
        [Parameter(Mandatory = $true)][bool]$AllowDeviceCode
    )

    $upn = [string]$Persona.upn
    $scopes = [string[]]@($Config.authentication.scopes)
    $application = New-PersonaApplication -Config $Config -Upn $upn -CachePath $CachePath

    if ($AllowDeviceCode) {
        $callbackType = "UebaBaselineV2.DeviceCodeCallback" -as [type]
        if (-not $callbackType) {
            throw "The device-code callback could not be initialized."
        }

        $deviceCodeCallback = $callbackType.GetField("Handler").GetValue($null)
        $result = $application.AcquireTokenWithDeviceCode(
            $scopes,
            $deviceCodeCallback
        ).ExecuteAsync().GetAwaiter().GetResult()
    } else {
        $accounts = @($application.GetAccountsAsync().GetAwaiter().GetResult())
        $account = $accounts |
            Where-Object { [string]$_.Username -ieq $upn } |
            Select-Object -First 1

        if (-not $account) {
            throw "ReauthenticationRequired: no encrypted token cache exists for '$upn'. Run with -Enroll -PersonaUpn '$upn'."
        }

        try {
            $result = $application.AcquireTokenSilent($scopes, $account).
                ExecuteAsync().
                GetAwaiter().
                GetResult()
        } catch {
            if ($_.Exception.GetBaseException().GetType().FullName -eq "Microsoft.Identity.Client.MsalUiRequiredException") {
                throw "ReauthenticationRequired: '$upn' must complete device-code authentication again."
            }

            throw
        }
    }

    if ([string]$result.Account.Username -ine $upn) {
        if (Test-Path -LiteralPath $CachePath) {
            Remove-Item -LiteralPath $CachePath -Force
        }

        throw "Authenticated account '$($result.Account.Username)' does not match configured persona '$upn'. The mismatched cache was deleted."
    }

    return $result
}

function Get-PersonaSchedule {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)][string]$PeerGroup
    )

    $schedule = $Config.peerGroupSchedules |
        Where-Object { [string]$_.peerGroup -eq $PeerGroup } |
        Select-Object -First 1

    if (-not $schedule) {
        throw "No schedule is configured for peer group '$PeerGroup'."
    }

    return $schedule
}

function Test-RunWindow {
    param(
        [Parameter(Mandatory = $true)]$Schedule,
        [Parameter(Mandatory = $true)][datetime]$Now
    )

    if ($Schedule.weekdaysOnly -eq $true -and
        $Now.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) {
        return $false
    }

    $startHour = [int]$Schedule.startHourLocal
    $endHour = [int]$Schedule.endHourLocal
    if ($startHour -lt 0 -or $startHour -gt 23 -or $endHour -lt 1 -or $endHour -gt 24) {
        throw "Peer-group schedule hours must be in [0-23] / [1-24]."
    }

    return $Now.Hour -ge $startHour -and $Now.Hour -lt $endHour
}

function Get-ActivityState {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][datetime]$Now
    )

    if (Test-Path -LiteralPath $Path) {
        $state = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if ([string]$state.date -eq $Now.ToString("yyyy-MM-dd")) {
            return $state
        }
    }

    return [pscustomobject]@{
        date = $Now.ToString("yyyy-MM-dd")
        counts = [pscustomobject]@{}
    }
}

function Save-ActivityState {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    $null = New-Item -ItemType Directory -Path $directory -Force
    $State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Get-ScenarioCount {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$ScenarioName
    )

    $property = $State.counts.PSObject.Properties[$ScenarioName]
    if (-not $property) {
        return 0
    }

    return [int]$property.Value
}

function Add-ScenarioCount {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$ScenarioName
    )

    $current = Get-ScenarioCount -State $State -ScenarioName $ScenarioName
    $State.counts | Add-Member -NotePropertyName $ScenarioName -NotePropertyValue ($current + 1) -Force
}

function Test-ScenarioDue {
    param(
        [Parameter(Mandatory = $true)]$Scenario,
        [Parameter(Mandatory = $true)]$Persona,
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][bool]$IsDryRun
    )

    if ($Scenario.enabled -eq $false) {
        return $false
    }

    if ([string]$Persona.peerGroup -notin @($Scenario.peerGroups)) {
        return $false
    }

    $count = Get-ScenarioCount -State $State -ScenarioName ([string]$Scenario.name)
    if ($count -ge [int]$Scenario.maxPerDay) {
        return $false
    }

    if ($IsDryRun) {
        return $true
    }

    $probability = [double]$Scenario.probability
    return (Get-Random -Minimum 0.0 -Maximum 1.0) -le $probability
}

function Invoke-GraphRequest {
    param(
        [Parameter(Mandatory = $true)][string]$AccessToken,
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $false)]$Body,
        [Parameter(Mandatory = $false)][string]$ContentType = "application/json"
    )

    $parameters = @{
        Method = $Method
        Uri = $Uri
        Headers = @{ Authorization = "Bearer $AccessToken" }
        ContentType = $ContentType
    }

    if ($null -ne $Body) {
        $parameters.Body = $Body
    }

    $maximumAttempts = 3
    for ($attempt = 1; $attempt -le $maximumAttempts; $attempt++) {
        try {
            return Invoke-RestMethod @parameters
        } catch {
            $statusCode = 0
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            $isTransient = $statusCode -eq 429 -or $statusCode -ge 500
            if (-not $isTransient -or $attempt -eq $maximumAttempts) {
                throw
            }

            Start-Sleep -Seconds ([math]::Pow(2, $attempt))
        }
    }
}

function Invoke-Scenario {
    param(
        [Parameter(Mandatory = $true)]$Scenario,
        [Parameter(Mandatory = $true)]$Persona,
        [Parameter(Mandatory = $true)][string]$AccessToken,
        [Parameter(Mandatory = $true)][datetime]$Now
    )

    $baseUri = "https://graph.microsoft.com/v1.0"
    $testId = "UEBA-$($Now.ToString('yyyyMMdd'))-$([string]$Persona.peerGroup)"

    switch ([string]$Scenario.type) {
        "profile-read" {
            $null = Invoke-GraphRequest `
                -AccessToken $AccessToken `
                -Method "GET" `
                -Uri "$baseUri/me?`$select=id,displayName,userPrincipalName"
        }
        "calendar-event" {
            $start = $Now.Date.AddDays(1).AddHours(14)
            $body = @{
                subject = "$testId planning"
                body = @{
                    contentType = "Text"
                    content = "Synthetic UEBA lab calendar activity."
                }
                start = @{
                    dateTime = $start.ToString("yyyy-MM-ddTHH:mm:ss")
                    timeZone = "UTC"
                }
                end = @{
                    dateTime = $start.AddMinutes(30).ToString("yyyy-MM-ddTHH:mm:ss")
                    timeZone = "UTC"
                }
            } | ConvertTo-Json -Depth 6

            $null = Invoke-GraphRequest `
                -AccessToken $AccessToken `
                -Method "POST" `
                -Uri "$baseUri/me/events" `
                -Body $body
        }
        "mail-send" {
            $recipient = [string]$Persona.mailRecipientUpn
            if ([string]::IsNullOrWhiteSpace($recipient)) {
                throw "Persona '$($Persona.upn)' has no mailRecipientUpn."
            }

            $body = @{
                message = @{
                    subject = "$testId status"
                    body = @{
                        contentType = "Text"
                        content = "Synthetic UEBA lab message. No response is required."
                    }
                    toRecipients = @(
                        @{
                            emailAddress = @{
                                address = $recipient
                            }
                        }
                    )
                }
                saveToSentItems = $true
            } | ConvertTo-Json -Depth 8

            $null = Invoke-GraphRequest `
                -AccessToken $AccessToken `
                -Method "POST" `
                -Uri "$baseUri/me/sendMail" `
                -Body $body
        }
        "onedrive-file" {
            $safeUpn = ConvertTo-SafeName -Value ([string]$Persona.upn)
            $fileName = "UEBA-Lab-$safeUpn-$($Now.ToString('yyyyMMdd')).txt"
            $content = [Text.Encoding]::UTF8.GetBytes(
                "Synthetic UEBA lab file for $($Persona.peerGroup) on $($Now.ToString('yyyy-MM-dd'))."
            )

            $null = Invoke-GraphRequest `
                -AccessToken $AccessToken `
                -Method "PUT" `
                -Uri "$baseUri/me/drive/root:/$fileName`:/content" `
                -Body $content `
                -ContentType "text/plain"
        }
        default {
            throw "Unsupported scenario type '$($Scenario.type)'."
        }
    }
}

$config = Get-Config -Path $ConfigPath
$personas = Get-EnabledPersonas -Config $config -Upn $PersonaUpn
$stateRoot = Get-StateRoot -Config $config
$tokenDirectory = Join-Path $stateRoot "tokens"
$activityDirectory = Join-Path $stateRoot "activity"
$now = Get-Date

Write-Log -Level "INFO" -Message "Starting UEBA multi-persona orchestrator. Enroll=$Enroll Status=$Status DryRun=$DryRun"
Write-Log -Level "INFO" -Message "Token caches are separated per persona and protected by Windows DPAPI for the current Windows user."

foreach ($persona in $personas) {
    $upn = [string]$persona.upn
    $safeName = ConvertTo-SafeName -Value $upn
    $cachePath = Join-Path $tokenDirectory "$safeName.bin"
    $activityPath = Join-Path $activityDirectory "$safeName.json"

    if ($Status) {
        $cacheStatus = if (Test-Path -LiteralPath $cachePath) { "ENROLLED" } else { "NOT_ENROLLED" }
        Write-Log -Level "INFO" -Message "STATUS user=$upn peerGroup=$($persona.peerGroup) cache=$cacheStatus"
        continue
    }

    if ($Enroll) {
        if ($personas.Count -ne 1) {
            throw "Enrollment requires exactly one -PersonaUpn."
        }

        if ($DryRun) {
            Write-Log -Level "INFO" -Message "DRYRUN enrollment user=$upn cache=$cachePath"
            continue
        }

        try {
            $result = Get-PersonaToken `
                -Config $config `
                -Persona $persona `
                -CachePath $cachePath `
                -AllowDeviceCode $true
        } catch {
            Write-Log -Level "ERROR" -Message "ENROLLMENT_FAILED user=$upn error=$($_.Exception.Message)"
            throw
        }

        Write-Log -Level "INFO" -Message "ENROLLED user=$($result.Account.Username) expires=$($result.ExpiresOn.UtcDateTime.ToString('o'))"
        continue
    }

    $schedule = Get-PersonaSchedule -Config $config -PeerGroup ([string]$persona.peerGroup)
    if (-not (Test-RunWindow -Schedule $schedule -Now $now)) {
        Write-Log -Level "INFO" -Message "SKIP user=$upn reason=outside-run-window"
        continue
    }

    $state = Get-ActivityState -Path $activityPath -Now $now
    $dueScenarios = @(
        $config.scenarios |
            Where-Object {
                Test-ScenarioDue `
                    -Scenario $_ `
                    -Persona $persona `
                    -State $state `
                    -IsDryRun $DryRun
            }
    )

    if ($dueScenarios.Count -eq 0) {
        Write-Log -Level "INFO" -Message "SKIP user=$upn reason=no-due-scenarios"
        continue
    }

    if ($DryRun) {
        foreach ($scenario in $dueScenarios) {
            Write-Log -Level "INFO" -Message "DRYRUN user=$upn peerGroup=$($persona.peerGroup) scenario=$($scenario.name)"
        }
        continue
    }

    try {
        $result = Get-PersonaToken `
            -Config $config `
            -Persona $persona `
            -CachePath $cachePath `
            -AllowDeviceCode $false

        foreach ($scenario in $dueScenarios) {
            Invoke-Scenario `
                -Scenario $scenario `
                -Persona $persona `
                -AccessToken ([string]$result.AccessToken) `
                -Now $now

            Add-ScenarioCount -State $state -ScenarioName ([string]$scenario.name)
            Save-ActivityState -State $state -Path $activityPath
            Write-Log -Level "INFO" -Message "SUCCESS user=$upn peerGroup=$($persona.peerGroup) scenario=$($scenario.name)"
        }
    } catch {
        Write-Log -Level "ERROR" -Message "FAILED user=$upn error=$($_.Exception.Message)"
    }
}

Write-Log -Level "INFO" -Message "UEBA multi-persona orchestrator stopped."
