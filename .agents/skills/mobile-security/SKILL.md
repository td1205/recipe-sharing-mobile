---
name: mobile-security
description: Threat-model, implement, or review security controls for Recipe Sharing Mobile authentication, token storage, sensitive data, transport, and Android configuration. Use for security-sensitive mobile changes or audits; do not treat this skill as a compliance certification.
---

# Mobile Security

Start from trust boundaries: Flutter UI, device storage, logs/clipboard, Android
platform, network transport, and the Express backend. Trace the actual data flow
before recommending controls. Prioritize exploitable issues and distinguish source
review from device/runtime verification.

## Required decisions

- Store issued credentials only with a maintained platform-backed secure storage
  solution after reviewing its Android configuration and threat model. Do not put
  Bearer tokens in source, assets, plain preferences, analytics, crash reports, or
  logs. Do not add a package until the user authorizes the dependency change.
- Keep authorization enforced by the backend. Client route guards and hidden UI
  are usability controls, never proof of authorization.
- Handle `401` as invalid/expired/revoked authentication: clear local credentials
  safely and transition to an unauthenticated state without retry loops. Treat
  `403` as insufficient permission, not a signal to refresh credentials.
- Use HTTPS in production and validate Android Network Security Configuration.
  Limit cleartext exceptions to development builds and narrow domains where
  practical. Never disable TLS verification or accept-all certificates.
- Minimize cached personal data; define deletion/logout behavior. Redact secrets
  and personal data from diagnostics. Avoid screenshots/clipboard exposure for
  sensitive views when their risk justifies platform controls.
- Validate input for UX, but rely on server validation and authorization. Keep
  dependencies pinned, maintained, and reviewed before adoption.

## Review and verification

Use [OWASP MASVS](https://mas.owasp.org/MASVS/) and the relevant
[MASTG](https://mas.owasp.org/MASTG/) tests as risk-based references, especially
STORAGE, CRYPTO, AUTH, NETWORK, PLATFORM, CODE, RESILIENCE, and PRIVACY. Also use
[Android security best practices](https://developer.android.com/privacy-and-security/security-best-practices).
Report finding, evidence, impact, remediation, and PASS/FAIL/NOT VERIFIED. Do not
claim MASVS compliance without the required static and device-level evidence.
