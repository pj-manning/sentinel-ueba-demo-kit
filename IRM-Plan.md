# Microsoft Purview Insider Risk Management Demo Plan

## Purpose

Extend the Microsoft Sentinel UEBA lab with a small Microsoft Purview Insider
Risk Management (IRM) demonstration.

The combined story should show:

1. Sentinel records and enriches unusual identity or security behavior.
2. Purview evaluates whether user activity creates organizational data risk.
3. Analysts review risk indicators without assuming malicious intent.

Use only synthetic users, synthetic content, and a disposable tenant. An IRM
alert is a risk indicator, not proof that a user acted maliciously.

## Recommended persona profiles

Use one profile for an initial demo and add the second only after the first is
reliable.

### Profile 1: Departing Finance user

**Suggested account:** `finance.user1@<TENANT_DOMAIN>`

**Normal behavior**

- Works weekdays during the narrower Finance schedule.
- Accesses a small number of Finance documents.
- Collaborates only with internal Finance users.
- Rarely downloads or shares multiple files.

**Controlled deviation**

- Apply an approved synthetic departure trigger.
- Access or download several synthetic Finance documents.
- Share one synthetic sensitive document with a controlled lab guest.

**Demo value**

- Shows how a departure event changes the context of otherwise legitimate file
  access.
- Supports comparison between Purview risk indicators, Microsoft 365 audit
  events, and Sentinel user context.

### Profile 2: Accidental Sales sharer

**Suggested account:** `sales.user1@<TENANT_DOMAIN>`

**Normal behavior**

- Collaborates frequently during the Sales workday.
- Sends internal mail and uses OneDrive regularly.
- Shares routine documents only with internal users.

**Controlled deviation**

- Share a labeled synthetic customer-list document with a controlled lab guest.
- Trigger a test DLP policy match.
- Repeat one similar action later to demonstrate accumulated risk context.

**Demo value**

- Demonstrates negligent or accidental data exposure rather than malicious
  behavior.
- Shows the distinction between an individual DLP event and an IRM alert that
  includes user and activity context.

## Phase 1: Confirm prerequisites

1. Confirm the tenant has the required Microsoft Purview, Microsoft 365, and
   endpoint licenses for the selected policy and indicators.
2. Confirm Microsoft 365 auditing is enabled.
3. Confirm `OfficeActivity` receives Exchange, SharePoint, and OneDrive data in
   the Sentinel workspace.
4. Confirm the selected personas have working Exchange, OneDrive, and
   SharePoint services.
5. If endpoint indicators will be used, onboard only a dedicated lab device to
   Microsoft Defender for Endpoint.
6. If using a departing-user policy, prepare an approved synthetic HR or
   departure signal.
7. Record the tenant owner, lab owner, privacy approver, and cleanup owner.

Do not continue until Microsoft 365 audit events are visible. Successful Graph
activity alone does not prove that the audit and IRM signal pipelines work.

## Phase 2: Establish privacy and role controls

1. Open the Microsoft Purview portal.
2. Review the Insider Risk Management privacy settings.
3. Keep user pseudonymization enabled where supported.
4. Assign only the minimum required Purview role groups.
5. Separate policy administration from alert and case investigation when
   practical.
6. Scope all policies to a dedicated group containing only the selected
   synthetic personas.
7. Document who may reveal a pseudonymized identity or escalate a case.
8. Confirm all policy and case actions are auditable.

Never include real employees merely to create more realistic results.

## Phase 3: Prepare synthetic data

1. Create a dedicated SharePoint site or OneDrive folder for the IRM lab.
2. Create clearly marked synthetic documents, for example:
   - `Synthetic-Customer-List.xlsx`
   - `Synthetic-Financial-Forecast.xlsx`
   - `Synthetic-Product-Roadmap.pptx`
3. Ensure the files contain no real personal, customer, financial, or
   credential data.
4. Create test sensitivity labels such as:
   - `Lab-General`
   - `Lab-Confidential`
   - `Lab-Highly-Confidential`
5. Apply the labels to the synthetic documents.
6. Create a controlled lab guest if external-sharing behavior is required.
7. Record every file, site, label, and guest that must be removed later.

## Phase 4: Configure policy indicators

1. In Purview Insider Risk Management settings, review the available policy
   indicators.
2. Enable only indicators required for the selected scenario.
3. For the initial demo, prefer:
   - SharePoint and OneDrive file activity
   - External sharing
   - Exchange activity
   - DLP policy matches
4. Add endpoint indicators only if the dedicated test device is ready.
5. Avoid enabling broad indicators that are unrelated to the demo.
6. Record each enabled indicator and its data prerequisite.

Current indicator options are documented in
[Configure policy indicators in Insider Risk Management](https://learn.microsoft.com/purview/insider-risk-management-settings-policy-indicators).

## Phase 5: Create one IRM policy

Start with one policy.

### Option A: Departing Finance user

1. Choose the departing-user or data-theft policy template.
2. Scope the policy to the synthetic Finance profile only.
3. Configure the approved synthetic departure trigger.
4. Select only the file access, download, sharing, and DLP indicators needed
   for the scenario.
5. Use conservative thresholds suitable for a lab.
6. Name the policy clearly, for example:
   `LAB - Departing Finance User`.

### Option B: Accidental Sales sharer

1. Choose a data-leak policy template.
2. Scope the policy to the synthetic Sales profile only.
3. Select external sharing and DLP indicators.
4. Use a test DLP policy tied to synthetic labeled data.
5. Name the policy clearly, for example:
   `LAB - Accidental Sales Sharing`.

Review current policy options in
[Create and manage Insider Risk Management policies](https://learn.microsoft.com/purview/insider-risk-management-policies).

## Phase 6: Build normal behavior

1. Continue running the Sentinel baseline generator on working days.
2. Keep the selected IRM persona within their normal schedule.
3. Use routine internal collaboration only.
4. Avoid deliberate sharing, bulk access, or DLP violations during this phase.
5. Confirm the persona appears in:
   - Entra sign-in logs
   - Microsoft 365 audit data
   - Sentinel peer analytics
6. Allow the Purview policy and analytics processes time to establish context.

Use at least two weeks of baseline activity where schedule permits. Three to
four weeks is preferable for the combined demo.

## Phase 7: Run the controlled scenario

1. Obtain approval from the lab and privacy owners.
2. Record the scenario start time.
3. Perform only the actions listed in the selected runbook.
4. Use copies of synthetic files rather than deleting or modifying originals.
5. Stop after the planned actions; do not add unplanned risky behavior.
6. Record the expected evidence:
   - Purview policy alert
   - DLP event, if used
   - Microsoft 365 audit event
   - Entra sign-in activity
   - Sentinel user and peer context
7. Allow for normal processing delays before judging the result.

Do not use real personal email, uncontrolled cloud storage, production USB
devices, offensive tools, malware, or attempts to bypass security controls.

## Phase 8: Investigate and present

Use this order during the customer demonstration:

1. Explain the persona's normal role and behavior.
2. Show the synthetic file classification and policy scope.
3. Show the Purview alert and its contributing risk indicators.
4. Explain that risk scoring does not prove malicious intent.
5. Review the pseudonymized user and reveal identity only under the documented
   lab process.
6. Create or review the IRM case.
7. Pivot to Microsoft 365 audit evidence.
8. Show the same user's sign-ins, peers, or enriched behavior in Sentinel.
9. Explain the difference between:
   - Raw activity
   - DLP enforcement
   - Purview insider-risk correlation
   - Sentinel UEBA context
10. Close or dismiss the lab alert using a documented disposition.

## Phase 9: Optional Adaptive Protection

Add Adaptive Protection only after the basic IRM scenario is reliable.

1. Target only synthetic users.
2. Start in simulation or audit mode where available.
3. Use a low-impact DLP control.
4. Verify how the user enters and exits each risk level.
5. Test rollback before a customer session.
6. Do not allow the policy to affect production users or the presenter account.

See
[Adaptive Protection in Microsoft Purview](https://learn.microsoft.com/purview/insider-risk-management-adaptive-protection?tabs=purview-portal).

## Validation checklist

- [ ] Policy scope contains only synthetic users.
- [ ] Privacy settings and role separation are documented.
- [ ] Synthetic labeled files contain no real data.
- [ ] Microsoft 365 auditing is active.
- [ ] `OfficeActivity` contains relevant workspace records.
- [ ] Required IRM indicators are enabled.
- [ ] The normal behavior period is complete.
- [ ] The controlled action has an approval and cleanup plan.
- [ ] A Purview alert or case is captured before the live demo.
- [ ] Related Sentinel evidence is available.
- [ ] The presenter distinguishes risk indicators from proof of misconduct.
- [ ] The presenter distinguishes Purview IRM from Sentinel UEBA.

## Cleanup

1. Stop controlled risk activity.
2. Revoke test sharing links.
3. Remove the controlled guest if no longer required.
4. Remove synthetic files and SharePoint sites according to the lab plan.
5. Disable or remove test DLP and IRM policies.
6. Remove synthetic departure or HR records.
7. Remove the lab device from endpoint management if applicable.
8. Close or dismiss test alerts and cases with a lab disposition.
9. Verify retention and deletion requirements.
10. Record completion and any remaining artifacts.

## Primary risks

| Risk | Mitigation |
|---|---|
| Real user is monitored | Dedicated synthetic group and preflight membership review |
| Alert is treated as proof of wrongdoing | Presenter and runbook state that it is a risk indicator |
| Real sensitive data is used | Clearly marked synthetic files only |
| Policy is too broad | One persona, one scenario, minimum indicators |
| Baseline is contaminated | Run normal behavior first; schedule risk actions later |
| Alert does not appear live | Capture native evidence before the customer session |
| Adaptive control disrupts access | Simulation first, synthetic users, tested rollback |
| Purview and Sentinel outputs are conflated | Present them as separate but complementary pipelines |

