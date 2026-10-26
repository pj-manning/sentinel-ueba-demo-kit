# Contributing

This project is currently intended for private or internal review. No license
is granted for redistribution.

## Safety requirements

Contributions must:

- Use only synthetic identities and synthetic data.
- Preserve MFA and Conditional Access.
- Avoid passwords, client secrets, certificates, and application permissions.
- Avoid offensive tooling, malware, persistence, credential theft, or
  destructive activity.
- Keep tenant IDs, subscription IDs, UPNs, IP addresses, tokens, device codes,
  logs, and token caches out of commits.
- Clearly distinguish native UEBA output from deterministic analytics rules.
- Keep generated activity bounded by schedules, probabilities, and daily caps.

## Development setup

Use Windows PowerShell 5.1 or PowerShell 7.

Install test dependencies:

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

Run validation:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
Invoke-Pester -Path .\tests -Output Detailed
```

Also parse every PowerShell script and validate the JSON template before
opening a pull request.

## Pull requests

- Keep changes focused.
- Explain user-visible or security behavior changes.
- Add or update tests.
- Update the README and demo plan when setup or behavior changes.
- Do not include runtime files or screenshots containing tenant information.
- Include manual validation details for changes that touch Microsoft Graph,
  Entra application registration, Sentinel connectors, or UEBA.

## Commit messages

Use concise imperative messages, for example:

```text
Add validation for duplicate persona UPNs
Document OfficeActivity connector requirement
```

