---
name: flutter-development
description: Build, refactor, or review Dart and Flutter application code in Recipe Sharing Mobile using its feature-first architecture, Riverpod state, and go_router navigation. Use for Flutter feature work and maintainability decisions; use a specialized skill for testing, API, security, or UI-only reviews.
---

# Flutter Development

Work with the current project before proposing new abstractions. Read `pubspec.yaml`,
`analysis_options.yaml`, the relevant feature, and shared code it actually calls.
Preserve the existing stack unless the user explicitly requests a migration:

- `lib/app/`: application shell and `go_router` configuration.
- `lib/core/`: cross-feature configuration, networking, authentication boundaries,
  and providers.
- `lib/features/<feature>/{data,domain,presentation}`: feature-owned code.
- Riverpod providers expose state and dependencies; widgets render state and
  dispatch intent. Keep parsing and network access out of widgets.

## Implementation guidance

- Follow [Effective Dart](https://dart.dev/effective-dart) and the repository's
  analyzer rules. Prefer small immutable models, explicit nullability, dependency
  injection, and composition over inheritance.
- Put code in `core` only when multiple features genuinely share it. Avoid a
  speculative service/repository layer or a generic `utils` dumping ground.
- Keep domain models independent of Flutter UI where practical. Map backend
  snake_case at the data boundary; do not leak untyped JSON through the feature.
- Use Riverpod for asynchronous/loading/error state and dependency overrides.
  Keep ephemeral widget-only state local when sharing or persistence adds no value.
- Add routes declaratively in the existing `GoRouter`. Pass stable identifiers in
  routes and load mutable data through providers rather than large route extras.
- Preserve public APIs and existing behavior unless the request authorizes change.
  Inspect callers before renaming or moving code.

## Verification

Format changed Dart files, then run targeted tests, `flutter analyze`, and
`flutter test` in proportion to the change. Report commands actually executed and
do not claim runtime or visual verification from source inspection alone.

Official references: [Flutter architecture](https://docs.flutter.dev/app-architecture),
[Flutter navigation](https://docs.flutter.dev/ui/navigation), and
[Riverpod documentation](https://riverpod.dev/).
