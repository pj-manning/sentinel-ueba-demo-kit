BeforeAll {
    $script:projectRoot = Split-Path -Parent $PSScriptRoot
    $script:sampleConfigPath = Join-Path $script:projectRoot "baseline-config.sample.json"
    $script:validatorPath = Join-Path $script:projectRoot "validate-config.ps1"
    $script:runnerPath = Join-Path $script:projectRoot "run-baseline.ps1"

    function New-TestConfig {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Destination,

            [Parameter(Mandatory = $true)]
            [string]$StateDirectory
        )

        $config = Get-Content -LiteralPath $script:sampleConfigPath -Raw | ConvertFrom-Json
        $config.tenantId = "11111111-1111-1111-1111-111111111111"
        $config.authentication.clientId = "22222222-2222-2222-2222-222222222222"
        $config.stateDirectory = $StateDirectory

        foreach ($user in $config.users) {
            $user.upn = ([string]$user.upn).Replace(
                "<TENANT_DOMAIN>",
                "contoso.onmicrosoft.com"
            )
            $user.mailRecipientUpn = ([string]$user.mailRecipientUpn).Replace(
                "<TENANT_DOMAIN>",
                "contoso.onmicrosoft.com"
            )
        }

        $config | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $Destination -Encoding utf8
    }
}

Describe "Repository configuration" {
    It "contains a valid JSON sample" {
        { Get-Content -LiteralPath $script:sampleConfigPath -Raw | ConvertFrom-Json } |
            Should -Not -Throw
    }

    It "defines eight personas in three peer groups" {
        $config = Get-Content -LiteralPath $script:sampleConfigPath -Raw | ConvertFrom-Json

        @($config.users).Count | Should -Be 8
        @($config.users.peerGroup | Sort-Object -Unique).Count | Should -Be 3
    }

    It "does not contain runtime tenant identifiers" {
        $content = Get-Content -LiteralPath $script:sampleConfigPath -Raw

        $content | Should -Not -Match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
        $content | Should -Match "<TENANT_ID>"
        $content | Should -Match "<PUBLIC_CLIENT_APP_ID>"
    }
}

Describe "Configuration validation" {
    BeforeEach {
        $script:configPath = Join-Path $TestDrive "baseline-config.json"
        $script:statePath = Join-Path $TestDrive "state"
        New-TestConfig -Destination $script:configPath -StateDirectory $script:statePath
    }

    It "accepts a complete tenant-neutral configuration" {
        { & $script:validatorPath -ConfigPath $script:configPath } | Should -Not -Throw
    }

    It "rejects unresolved placeholders" {
        Copy-Item -LiteralPath $script:sampleConfigPath -Destination $script:configPath -Force

        { & $script:validatorPath -ConfigPath $script:configPath } | Should -Throw "*Replace all configuration placeholders*"
    }

    It "rejects duplicate persona UPNs" {
        $config = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
        $config.users[1].upn = $config.users[0].upn
        $config | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $script:configPath -Encoding utf8

        { & $script:validatorPath -ConfigPath $script:configPath } | Should -Throw "*Duplicate persona UPNs*"
    }

    It "rejects a mail recipient outside the enabled population" {
        $config = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
        $config.users[0].mailRecipientUpn = "outside@contoso.onmicrosoft.com"
        $config | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $script:configPath -Encoding utf8

        { & $script:validatorPath -ConfigPath $script:configPath } | Should -Throw "*not enabled*"
    }

    It "rejects scenario probabilities outside zero through one" {
        $config = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
        $config.scenarios[0].probability = 1.1
        $config | ConvertTo-Json -Depth 10 |
            Set-Content -LiteralPath $script:configPath -Encoding utf8

        { & $script:validatorPath -ConfigPath $script:configPath } | Should -Throw "*probability must be between 0 and 1*"
    }
}

Describe "Baseline dry run" {
    It "previews all thirty eligible persona and scenario combinations" {
        $configPath = Join-Path $TestDrive "baseline-config.json"
        $statePath = Join-Path $TestDrive "state"
        $logPath = Join-Path $TestDrive "baseline-run.log"
        New-TestConfig -Destination $configPath -StateDirectory $statePath

        & $script:runnerPath -ConfigPath $configPath -LogPath $logPath -DryRun

        $dryRunRecords = @(
            Get-Content -LiteralPath $logPath |
                Where-Object { $_ -match "DRYRUN user=" }
        )
        $dryRunRecords.Count | Should -Be 30
        Test-Path -LiteralPath $statePath | Should -BeFalse
    }
}
