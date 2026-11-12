---
name: flutter-testing
description: Design, add, run, or review tests for Recipe Sharing Mobile using Flutter unit, widget, and integration testing. Use for test implementation, regression checks, mocking API behavior, or verification with flutter analyze and flutter test.
---

# Flutter Testing

Choose the smallest test level that proves the behavior:

- Unit tests for models, repositories, providers, mapping, and error handling.
- Widget tests for rendering and interaction across loading, data, empty, and
  error states, with dependencies overridden rather than real network calls.
- Integration tests for high-value journeys that require the assembled app,
  emulator/device, platform behavior, or a controlled backend.

## Workflow

Read the implementation path, existing tests, and dependency injection seams.
Define the observable expectation before writing the test. Cover success plus
meaningful boundaries: malformed JSON, timeout, connection failure, relevant HTTP
codes, retry limits, accessibility semantics, and navigation where applicable.

Keep tests deterministic and isolated. Prefer fakes or an injected Dio adapter;
do not call production services, use real credentials, mutate shared backend data,
or rely on test ordering. Use `pumpAndSettle` only when settling is guaranteed;
otherwise pump the expected transition explicitly. An integration environment
must be identified before a test writes data, and cleanup must be defined.

## Verification and reporting

Run `dart format` for changed Dart tests, `flutter analyze`, targeted tests during
iteration, then `flutter test` before handoff when scope permits. Integration tests
run separately with an explicit device and environment. Distinguish:

- PASS: command executed and expectation passed.
- FAIL: executed test disproved the expectation.
- NOT VERIFIED: not run, blocked, or environment unavailable.

Do not call static review, compilation, or file creation a passing runtime test.
Include the exact command and concise result.

Official references: [Flutter testing overview](https://docs.flutter.dev/testing/overview),
[Widget testing](https://docs.flutter.dev/cookbook/testing/widget/introduction), and
[Integration testing](https://docs.flutter.dev/testing/integration-tests).
