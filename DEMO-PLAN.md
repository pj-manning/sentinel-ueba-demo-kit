# Microsoft Sentinel UEBA Demonstration Plan

## Objective

Demonstrate how Microsoft Sentinel learns routine identity and cloud behavior,
calculates user peers, enriches supported activity, and helps an analyst
investigate controlled deviations.

Use a dedicated tenant containing synthetic identities and synthetic data.
Never use production users, customer credentials, or customer data.

## Demonstration narrative

The customer should see four stages:

1. **Routine telemetry** - normal sign-ins and Microsoft 365 activity.
2. **Learned context** - user entities, historical activity, and peer mappings.
3. **Controlled deviation** - a safe change in time, device, network, location,
   resource, or peer behavior.
4. **Investigation** - anomaly or incident, UEBA context, raw evidence, entity
   timeline, and response.

Native UEBA is probabilistic. Prepare a deterministic, entity-mapped analytics
rule as a fallback and disclose that it is deterministic rather than a native
UEBA anomaly.

## Success criteria

- Microsoft Sentinel is enabled in a dedicated workspace.
- UEBA, anomalies, and entity analytics are enabled.
- Entra sign-in and audit data reaches the workspace.
- `OfficeActivity` contains Microsoft 365 audit data.
- Six to eight synthetic users are divided across at least three peer groups.
- Each persona has an independent encrypted delegated token cache.
- At least 14 working days of routine activity exist; 3-4 weeks is preferred.
- `UserPeerAnalytics` contains mappings for the personas.
- Supported activities begin to appear in `BehaviorAnalytics` where applicable.
- At least one controlled deviation is captured before the customer session.
- A deterministic fallback incident is rehearsed.

## Reference architecture

```text
Synthetic Entra users
  |
  | device-code enrollment once per user
  v
Windows baseline host
  |-- per-persona DPAPI token cache
  |-- weekday schedules
  |-- scenario probabilities
  |-- daily activity caps
  |
  +--> Microsoft Graph
         |-- profile
         |-- calendar
         |-- OneDrive
         `-- internal mail

Microsoft 365 / Entra audit pipelines
  |
  v
Log Analytics + Microsoft Sentinel
  |-- SigninLogs
  |-- AADNonInteractiveUserSignInLogs
  |-- AuditLogs
  |-- OfficeActivity
  |-- UserPeerAnalytics
  `-- BehaviorAnalytics
```

## Persona model

Use three intentionally different groups:

### Sales

- Three users
- 08:00-18:00 weekdays
- Frequent collaboration
- Profile, calendar, OneDrive, and internal mail

### Finance

- Three users
- 09:00-16:00 weekdays
- Narrower work pattern
- Profile, calendar, OneDrive, and less frequent mail
- No routine Azure control-plane work

### Engineering

- Two users
- 07:00-19:00 weekdays
- Profile, calendar, and OneDrive
- Optionally add safe, recurring Azure control-plane activity later

Keep membership stable during baseline collection. Use lab-specific security
groups if existing business groups contain administrators or unrelated users.

## Build phases

### Phase 1: Safety boundary

1. Select the disposable tenant and subscription.
2. Confirm synthetic users are licensed and nonprivileged.
3. Exclude administrators, executives, resource accounts, and directory-role
   holders from the routine baseline.
4. Define budget, retention, and teardown ownership.

### Phase 2: Sentinel foundation

1. Create a dedicated resource group and Log Analytics workspace.
2. Enable Microsoft Sentinel.
3. Configure Entra sign-in and audit ingestion.
4. Configure Microsoft 365/Office 365 audit ingestion.
5. Enable connector health monitoring.
6. Validate actual table rows, not just connector UI state.

### Phase 3: UEBA

1. Enable UEBA.
2. Enable Entra entity analytics.
3. Enable anomaly processing.
4. Select supported UEBA data sources.
5. Confirm `UserPeerAnalytics` and `BehaviorAnalytics` tables.
6. Install relevant UEBA Essentials content if desired.

### Phase 4: Baseline automation

1. Create the public-client application with `setup-application.ps1`.
2. Insert the tenant GUID, application client ID, and persona UPNs.
3. Validate `baseline-config.json`.
4. Enroll each persona by device code.
5. Run one live scenario batch and verify the local log.
6. Confirm sign-in and Microsoft 365 audit ingestion.
7. Install the scheduled task.
8. Run on working days for 2-4 weeks.

### Phase 5: Controlled deviations

After the baseline is stable, introduce one deviation at a time:

- Sign in outside the persona's normal working hours.
- Use a different browser or clean browser profile.
- Use a separate test device.
- Use a different approved network or ISP.
- Perform a normally Engineering-only action with a Finance user.
- Access a new synthetic resource.
- Perform a safe administrative action from a reserved privileged persona.

Allow only authorized, reversible activity. Do not bypass MFA or Conditional
Access, use offensive tooling, simulate credential theft, or introduce malware.

### Phase 6: Deterministic fallback

Create at least one scheduled analytics rule that:

- Queries a controlled event.
- Maps the user account entity.
- Maps IP or host entities where available.
- Creates a clearly named lab incident.
- Uses a documented threshold and test window.

Label it as deterministic during the presentation.

### Phase 7: Rehearsal

Rehearse:

1. Baseline evidence.
2. Peer mappings.
3. Raw event.
4. UEBA-enriched behavior or anomaly.
5. User entity page and timeline.
6. Investigation graph or related entities.
7. Deterministic fallback incident.
8. Cleanup and cost controls.

## Expected data flow and timing

| Stage | Evidence | Expectation |
|---|---|---|
| Enrollment | `SigninLogs` | Device-code sign-in after normal ingestion delay |
| Silent execution | `AADNonInteractiveUserSignInLogs` | Token use and Microsoft Graph resource |
| Workload action | `OfficeActivity` | Requires working Microsoft 365 connector |
| Peer computation | `UserPeerAnalytics` | Asynchronous and independent of enriched behaviors |
| UEBA enrichment | `BehaviorAnalytics` | Supported events only; requires processing and history |
| Native anomaly | `Anomalies`/incident experiences | Probabilistic; capture in advance |

## Validation gates

### Before baseline collection

- All enabled personas show `ENROLLED`.
- A live run completes without runtime failures.
- Sign-ins appear for the intended users.
- `OfficeActivity` contains at least one workspace record.
- UEBA and entity analytics are enabled.

### Before controlled deviations

- At least 14 working days have elapsed.
- Each persona has repeated activity.
- Peer groups have visibly different patterns.
- `UserPeerAnalytics` includes every persona.
- Connector health is green.

### Before customer presentation

- Native UEBA evidence is captured and bookmarked or screenshotted.
- The deterministic fallback has been tested.
- KQL queries use the correct workspace and time range.
- No stale device codes, tokens, passwords, or customer data are exposed.
- The presenter can explain that `BehaviorAnalytics` is enrichment, not a copy
  of every raw event.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Native anomaly does not appear on demand | Capture native evidence in advance and use a disclosed deterministic fallback |
| `OfficeActivity` remains empty | Repair the Microsoft 365 connector before baseline claims |
| One host reduces device/network diversity | Add occasional approved manual deviations |
| Persona signs into the wrong device-code prompt | Runner rejects and deletes the mismatched cache |
| Token expires or CA requires interaction | Re-enroll only the affected persona |
| Too much synthetic activity | Keep probabilities, schedules, and daily caps |
| Peer groups are contaminated | Use dedicated lab groups and nonprivileged users |
| Scheduled task runs under another account | Install and run it only as the cache-owning Windows user |

## Cleanup

1. Disable and remove the scheduled task.
2. Remove `%LOCALAPPDATA%\UEBA-Baseline`.
3. Remove the public-client application and service principal.
4. Delete synthetic messages, events, and files if required.
5. Disable connectors and UEBA settings created solely for the lab.
6. Delete the lab resource group and workspace when retention is no longer needed.
7. Confirm no shared lab password remains in use.

