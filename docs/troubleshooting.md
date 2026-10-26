# Troubleshooting

## Config file not found

Run commands from the project directory or provide an absolute path:

```powershell
.\run-baseline.ps1 -ConfigPath "C:\path\to\baseline-config.json"
```

## Microsoft.Graph.Authentication is missing

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

Restart PowerShell if module assembly loading remains inconsistent.

## Enrollment requires exactly one persona

Enrollment is intentionally one user at a time:

```powershell
.\run-baseline.ps1 -Enroll -PersonaUpn "user@tenant.onmicrosoft.com"
```

## Device-code flow fails or is canceled

- Use the newly displayed device code.
- Complete the flow before it expires.
- Sign in as the exact requested persona.
- Complete MFA and consent.
- Check whether tenant user consent is restricted.
- If required, have an administrator grant consent to the delegated scopes.

## Authenticated account does not match configured persona

The runner deletes the mismatched cache. Re-run enrollment and ensure the
browser uses the exact requested UPN. A separate browser profile is optional;
it is not required for token-cache isolation.

## ReauthenticationRequired

The persona has no usable encrypted cache or Conditional Access requires new
interaction:

```powershell
.\run-baseline.ps1 -Enroll -PersonaUpn "<PERSONA_UPN>"
```

Re-enroll only the affected persona.

## Persona is skipped outside the run window

Check `peerGroupSchedules` in `baseline-config.json`. Hours use the local time
of the Windows host. The end hour is exclusive.

## No activity occurs on repeated runs

Daily caps may already be reached. Inspect:

```text
%LOCALAPPDATA%\UEBA-Baseline\activity
```

Do not delete daily state merely to increase activity; adjust the documented
configuration if a different volume is required.

## Sign-ins appear but OfficeActivity is empty

This indicates that Graph authentication works but Microsoft 365 audit
ingestion is not reaching the Sentinel workspace.

1. Confirm Microsoft 365 auditing is available.
2. Configure or repair the Microsoft 365/Office 365 connector.
3. Run the workspace-wide `OfficeActivity` health query.
4. Allow for normal audit ingestion delay.

Do not claim that email, calendar, or OneDrive behavior is available to UEBA
until `OfficeActivity` contains records.

## UserPeerAnalytics has data but BehaviorAnalytics is empty

Peer computation and enriched behaviors are different pipelines.

- Confirm UEBA is enabled.
- Confirm supported UEBA data sources are selected.
- Confirm raw source tables contain supported events.
- Accumulate repeated activity over time.
- Allow asynchronous processing.
- Remember that not every raw event produces a `BehaviorAnalytics` row.

## Scheduled task does not run

```powershell
Get-ScheduledTask -TaskName "UEBA Baseline Orchestrator"
Get-ScheduledTaskInfo -TaskName "UEBA Baseline Orchestrator"
```

Confirm:

- The same Windows user who enrolled the personas is signed in.
- The task action points to the current project path.
- `baseline-config.json` exists.
- The peer group is within its configured window.
- The log does not report reauthentication.

## Safe diagnostic collection

Provide only:

- PowerShell version
- Module version
- Sanitized command and error
- Relevant log lines with tenant data removed

Never provide passwords, tokens, device codes, cache files, or an unsanitized
runtime configuration.

