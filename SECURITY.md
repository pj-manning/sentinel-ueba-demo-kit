# Security Policy

## Supported versions

This project has not reached a stable release. Only the latest commit on the
default branch is supported during private or internal evaluation.

## Reporting a vulnerability

Do not open a public issue containing sensitive information.

Report vulnerabilities through the owning organization's approved private
security channel. Repository owners must replace this paragraph with a named
security contact or enable GitHub private vulnerability reporting before
broader distribution.

Include:

- Affected file and version or commit
- Reproduction steps
- Security impact
- Suggested remediation, if known

Do not include:

- Access or refresh tokens
- Device codes
- Passwords
- Tenant or subscription secrets
- Persona token-cache files
- Real customer or production data

## Security boundaries

- This project is for disposable lab tenants.
- It is not production automation.
- The public-client application must not have a client secret or application
  permissions.
- Token caches are bound to one Windows user through DPAPI.
- The runner must continue rejecting account/cache mismatches.
- Microsoft Graph and Sentinel permissions should remain least privilege.

