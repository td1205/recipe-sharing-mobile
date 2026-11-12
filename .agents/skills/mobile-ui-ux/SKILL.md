---
name: mobile-ui-ux
description: Design, implement, or review Flutter interfaces for Recipe Sharing Mobile using Material 3, responsive Android layouts, accessibility, navigation, and complete loading/empty/error states. Use for screen, widget, interaction, or mobile UX work rather than non-UI architecture.
---

# Mobile UI/UX

Inspect the existing theme, reusable widgets, navigation, and target screen before
editing. Preserve the current Material 3 visual language and introduce reusable
theme tokens/components only when repetition justifies them. Do not copy Web CSS
or desktop interaction patterns into Flutter.

## Design and implementation

- Use Material 3 components and semantic color roles. Support text scaling, light
  and dark surfaces when in scope, and avoid hardcoded colors that bypass theme.
- Build from available constraints with `LayoutBuilder`, flexible widgets, and
  appropriate breakpoints. Avoid device-model checks and fixed sizes that overflow.
  Respect safe areas, keyboard insets, orientation, and common Android back behavior.
- Give interactive targets adequate size and visible states. Add meaningful
  semantics/labels, logical focus order, sufficient contrast, and non-color cues.
  Test with large text and screen-reader semantics where risk warrants.
- Keep navigation predictable. Preserve user state across ordinary back navigation;
  prevent duplicate submissions and clarify destructive or irreversible actions.
- Every asynchronous screen needs intentional loading, data, empty, and error
  states. Prefer useful skeleton/progress feedback, actionable retry, pull-to-refresh
  where natural, and stable layouts that do not jump unnecessarily.
- Network images need loading/failure fallbacks. User-facing errors should be
  concise and actionable without exposing stack traces or sensitive details.

## Verification

Run widget tests for important states and semantics. For material UI changes,
inspect the rendered app on representative compact and larger widths with text
scaling; check keyboard and Android back behavior when relevant. Report visual or
accessibility checks as NOT VERIFIED if they were not actually performed.

Official references: [Material 3 for Flutter](https://docs.flutter.dev/ui/design/material),
[Flutter adaptive design](https://docs.flutter.dev/ui/adaptive-responsive),
[Flutter accessibility](https://docs.flutter.dev/ui/accessibility), and
[Android accessibility](https://developer.android.com/guide/topics/ui/accessibility).
