---
name: rest-api-integration
description: Implement or review REST API integration in Recipe Sharing Mobile, including Dio requests, JSON mapping, Bearer authentication, timeouts, and typed failures. Use whenever Flutter communicates with the sibling Express backend; never invent endpoints or response shapes.
---

# REST API Integration

Treat `../recipe-sharing-web` as the source of truth. Before changing a request or
model, trace the mounted Express route through middleware, controller, validation,
and repository/serializer; compare the Web frontend only as a caller example.
Record the verified HTTP method, path, query/body, authentication, status codes,
and JSON envelope. If the sibling repository is unavailable, stop guessing and
mark the contract unverified.

## Project conventions

- Reuse `lib/core/network/api_client.dart`, `ApiException`, `ApiConfig`, and the
  feature repository. Do not create a second HTTP client per feature.
- Keep `API_BASE_URL` environment-driven. Android Emulator defaults to
  `10.0.2.2`; a physical device needs the development machine's reachable LAN
  address; production must use HTTPS. Never commit environment secrets.
- Deserialize JSON into typed models at the data boundary. Validate required
  fields and tolerate only nullable/optional fields proven by the backend.
- Attach `Authorization: Bearer <token>` through the shared interceptor and token
  boundary. Never log tokens, passwords, cookies, or complete sensitive payloads.
- Map connection, timeout, malformed JSON, backend error envelopes, and relevant
  HTTP status codes to typed failures that the presentation layer can display.
- Retry only idempotent operations when failure is plausibly transient. Use a
  bounded attempt count and backoff; never silently retry writes or authentication.

## Verification

Unit-test request parameters, headers, parsing, timeouts, network failures, error
envelopes, and status mapping using an injected/mocked Dio path. When authorized
and safe, make a read-only call to the real development backend and report a
redacted response summary. A mocked test does not prove the live contract.

Official references: [Dart JSON](https://dart.dev/libraries/convert/json),
[Android network security](https://developer.android.com/privacy-and-security/security-config),
and [HTTP semantics](https://www.rfc-editor.org/rfc/rfc9110).
