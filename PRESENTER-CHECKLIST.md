# UEBA Demo Presenter Checklist

## Two to four weeks before

- [ ] Dedicated Sentinel workspace is onboarded.
- [ ] Entra sign-in and audit data is arriving.
- [ ] Microsoft 365 connector is producing `OfficeActivity`.
- [ ] UEBA, entity analytics, and anomalies are enabled.
- [ ] All synthetic personas are enrolled.
- [ ] Scheduled task is installed under the cache-owning Windows user.
- [ ] Daily execution is producing bounded activity.

## Seventy-two hours before

- [ ] Run `validate-config.ps1`.
- [ ] Run `run-baseline.ps1 -Status`.
- [ ] Check `baseline-run.log` for current `SUCCESS` records.
- [ ] Confirm every persona appears in `UserPeerAnalytics`.
- [ ] Confirm recent events in `SigninLogs`.
- [ ] Confirm recent Microsoft 365 operations in `OfficeActivity`.
- [ ] Review `BehaviorAnalytics` and anomaly results.
- [ ] Capture at least one native UEBA result for the presentation.
- [ ] Test the deterministic analytics-rule fallback.

## Twenty-four hours before

- [ ] Freeze configuration and peer-group membership.
- [ ] Avoid broad new activity that could obscure the storyline.
- [ ] Verify the customer-facing portal pages and saved queries.
- [ ] Verify time zones and query windows.
- [ ] Confirm the synthetic users are enabled and licensed.
- [ ] Re-enroll only personas reporting `ReauthenticationRequired`.

## Immediately before

- [ ] Confirm the correct tenant and workspace.
- [ ] Confirm connector health.
- [ ] Open the user entity page for the primary persona.
- [ ] Open the saved raw-event, peer, and behavior queries.
- [ ] Confirm the fallback incident is available or can be generated.
- [ ] Hide device codes, tokens, administrative account details, and unrelated tenant data.

## Suggested walkthrough

1. Explain the three peer groups and normal schedules.
2. Show raw Entra or Microsoft 365 events.
3. Show `UserPeerAnalytics` mappings.
4. Show the persona entity timeline.
5. Show a native UEBA behavior or anomaly captured in advance.
6. Explain `ActivityInsights` and `InvestigationPriority`.
7. Pivot to the raw record and related entities.
8. Demonstrate the deterministic incident if live UEBA timing is unsuitable.
9. Clearly distinguish native UEBA output from the fallback rule.

## After the demo

- [ ] Stop deliberate deviations.
- [ ] Preserve evidence only as long as required.
- [ ] Disable or remove the scheduled task if collection is complete.
- [ ] Remove local token caches when the lab is retired.
- [ ] Execute tenant and Azure cleanup.

