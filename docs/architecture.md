# Architecture

## Components

### Persona identities

Use six to eight synthetic, licensed Microsoft Entra users split across stable
peer groups. The sample uses Sales, Finance, and Engineering.

### Public-client application

`setup-application.ps1` creates or reconciles a tenant-only public-client
application with delegated Microsoft Graph permissions:

- `User.Read`
- `Mail.Send`
- `Calendars.ReadWrite`
- `Files.ReadWrite`

The application has no secret, certificate, or application permissions.

### Authentication and token isolation

Each persona completes one device-code flow. The runner creates a separate
MSAL V3 cache for each UPN and encrypts it with Windows DPAPI using:

- The current Windows user
- The tenant ID
- The client ID
- The lowercase persona UPN

This prevents one persona from replacing another and prevents cache portability
to another Windows account or machine.

### Baseline runner

The runner:

1. Loads configuration.
2. Selects enabled personas.
3. Enforces peer-group work windows.
4. Reads daily per-persona state.
5. Applies scenario group membership, probability, and daily limits.
6. Acquires a token silently from the matching encrypted cache.
7. Executes bounded Microsoft Graph activity.
8. Updates daily state only after success.
9. Logs success, skip, and failure outcomes.

### Sentinel data path

```text
Persona authentication
  -> Entra sign-in pipeline
  -> SigninLogs / AADNonInteractiveUserSignInLogs

Microsoft 365 activity
  -> Unified audit pipeline and Sentinel connector
  -> OfficeActivity

Supported UEBA source events
  -> Entity resolution and peer processing
  -> UserPeerAnalytics / BehaviorAnalytics
```

Successful Graph activity does not prove that `OfficeActivity` ingestion is
configured. Validate each stage independently.

## Trust boundaries

| Boundary | Control |
|---|---|
| Persona to application | Delegated authentication with MFA/CA |
| Persona to cache | Exact UPN match; mismatches are deleted |
| Cache at rest | DPAPI CurrentUser encryption |
| Runner to Graph | Minimum delegated scopes |
| Lab to production | Dedicated tenant, identities, workspace, and synthetic data |
| UEBA to demo claims | Native and deterministic results are explicitly distinguished |

## Availability limitations

- The scheduled task runs only while the cache-owning Windows user is signed in.
- DPAPI caches are intentionally not portable.
- One host provides limited device, browser, network, and geography diversity.
- UEBA processing and Microsoft 365 audit ingestion are asynchronous.

