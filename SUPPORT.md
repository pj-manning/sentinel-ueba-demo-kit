# Support

This project is provided for private and internal evaluation without a support
commitment.

Before requesting help:

1. Run `.\validate-config.ps1`.
2. Run `.\run-baseline.ps1 -Status`.
3. Review the latest entries in `baseline-run.log`.
4. Review `docs/troubleshooting.md`.
5. Run the KQL checks in `queries/validation-queries.kql`.

When reporting a problem, include:

- PowerShell edition and version
- Microsoft.Graph.Authentication version
- The command that failed
- Sanitized error output
- Whether the failure occurred during enrollment, silent authentication,
  Graph activity, scheduling, or Sentinel ingestion

Never attach `baseline-config.json`, token caches, device codes, access tokens,
or unsanitized tenant logs.

