# Recipe Sharing Mobile Design System

## Design direction

The interface follows a light, food-first visual language inspired by CookBuzz:
generous food photography, warm olive ink, fresh lime highlights, rounded cards,
and a floating dark navigation bar. It remains an Android Material 3 product UI,
not a direct copy of the reference screens.

## Foundations

- Background: `#F5F6F1`; surfaces: white and `#F2F6DF`.
- Primary olive: `#343B20`; secondary olive: `#667044`.
- Highlight lime: `#D9E88F`; strong highlight: `#C9DC68`.
- Muted copy: `#626657`; hairlines: `#DFE2D4`.
- Spacing follows 4, 8, 12, 16, 20, 24, 32 and 40 dp.
- Radius scale: 12 dp controls, 18 dp cards, 26 dp hero surfaces; pills are
  reserved for search, chips, primary actions and floating navigation.
- Shadows are soft and offset downward. Do not combine a strong border and a
  shadow on the same card.

## Typography

- Roboto is the Android text face. Headlines use weight 800 with compact line
  height; titles use 700; body text uses 400–500 and 1.4–1.45 line height.
- Screen titles must remain readable at large text scale and may wrap. Metadata
  is never encoded by color alone; it includes an icon or explicit label.

## Components

- Recipe cards lead with real backend photography. All cards use the same title,
  time and rating hierarchy, with a minimum 48 dp save target.
- Search fields are white pills with a visible search icon and clear action.
- Section headers use a strong title and optional text action; no decorative
  eyebrow labels.
- Empty and error states use one clear sentence and one recovery action.
- Network images always show loading and failure fallbacks.
- Bottom navigation is a dark floating pill. Selected destinations use a lime
  circular surface and expose selected semantics.

## Screen rules

- Home: greeting → search → category rail → featured photography → latest list.
- Explore: title/search → active filters/result count → adaptive two-column grid.
- Detail: title/author → hero image → description/stats → ingredients → steps →
  rating/comments → related recipes.
- Phone content edges are 20 dp. Interactive targets are at least 48 dp.
- Layouts must work at 360 and 400 dp and with enlarged text. Rows containing
  variable copy or many controls must wrap or restructure rather than overflow.

## Accessibility and states

- Maintain Material contrast and visible focus/pressed/disabled states.
- Images and icon-only actions require semantic labels or tooltips.
- Preserve loading, data, empty, error and retry states for every async screen.
- Respect SafeArea, keyboard insets, Android back behavior and reduced available
  width. Never hide core actions solely to make a compact layout fit.

## Application architecture

The codebase follows a feature-first Flutter architecture. UI dependencies flow
from the app layer into features; REST calls and persistence stay outside widgets.

```text
lib/app       App shell, Material theme and GoRouter routes
lib/core      API configuration, Dio client, token storage and shared providers
lib/features  Feature-owned data, domain, application and presentation code
```

- `app/` starts `MaterialApp.router`, owns the CookBuzz design tokens and defines
  the shell navigation plus standalone routes.
- `core/` owns `ApiConfig`, the Dio-based `ApiClient`, typed `ApiException`,
  secure Bearer-token persistence and cross-feature providers.
- `features/auth/` maps authentication payloads, owns auth state and renders
  login, registration, profile editing and password-reset screens.
- `features/recipes/data/` maps verified REST responses through
  `RecipeRepository`; `domain/` contains framework-light models; `presentation/`
  contains Riverpod controllers, screens and reusable recipe widgets.
- `features/recipes/application/` contains Cooking Mode Socket.IO coordination.

### State, navigation and API flow

```text
Screen → Riverpod controller/provider → repository → ApiClient/Dio → Backend
                                                                  ↓
Screen ← typed AsyncValue/model ← repository JSON mapping ← JSON response
```

- Riverpod keeps remote state, filters, pagination and shared recipe actions
  testable. Temporary visual state stays in the owning widget.
- GoRouter uses a `StatefulShellRoute` for Home, Explore, Cook, Saved and Profile;
  detail, form, authentication and image-search routes sit above that shell.
- `ApiClient` attaches the persisted Bearer token, handles timeout/network/HTTP
  failures as typed errors, and clears invalid credentials after a 401 boundary.
- Backend owns authorization, database access and Gemini credentials. Mobile uses
  `API_BASE_URL` and optional Cloudinary unsigned-upload configuration via
  `--dart-define`; no production secret is stored in source.
