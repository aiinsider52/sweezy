# Sweezy — visual and UX audit

Updated: 2026-08-24

## Baseline

- 189 SwiftUI source files.
- 97 files define local fonts.
- 367 explicit rounded-font overrides conflicted with current SF Pro design system.
- 1,575 hard-coded font sizes bypassed shared typography tokens.
- 869 fixed numeric frames require device-level regression coverage.
- 114 intentional safe-area extensions; content layers must remain inside safe areas.
- Shared empty/loading/error components existed, but visual treatment and accessibility were inconsistent.

## Main issues

1. Display headlines were too large on narrow phones and used negative line spacing.
2. Local `.rounded` overrides made hierarchy look heavy and inconsistent.
3. Some guest and hero screens used fixed-height layouts without a scroll fallback.
4. Several compact action controls were below the 44 pt touch target.
5. Full-screen custom navigation required consistent left-edge dismissal.
6. Bottom navigation needed explicit safe-area ownership and full-row hit targets.
7. Loading, empty, error, retry, and pressed states needed one shared visual language.

## Applied direction

- SF Pro Default across app; monospaced remains only for codes and numeric technical data.
- Compact display scale: 34 / 29 / 24 / 20 / 17; body scale: 16 / 15 / 14 / 13 / 12.
- Positive title line spacing and tighter visual weight instead of oversized text.
- Adaptive horizontal padding: 16 pt compact, 20 pt phone, 28 pt regular width.
- 44 pt minimum interaction target.
- Scroll fallback for constrained-height hero and authentication screens.
- Shared state components with readable copy width, clear icon container, and retry CTA.
- Native interactive pop for navigation stacks; edge-only fallback dismissal for presented screens.
- Semantic light/dark surfaces for Journey, Friends, Swiss Network, public profiles, chat, and business views.
- Shared entrance, selection, press, and content-swap motion with `Reduce Motion` fallbacks.
- Static ambient geometry instead of per-frame random noise; animated backgrounds capped at 30 fps and particle count reduced.
- Compact Friends swipe deck with viewport-bound PASS/LIKE actions and clipped card layers.

## Device verification matrix

- Adaptive token tests: 320, 360, 390, 430, and 768 pt widths.
- Live UI run: iPhone 17 portrait in light appearance.
- Static source audit: every custom hidden-back-button screen has interactive swipe support.
- iPhone 16e cold UI-test runner stalled before app launch inside Xcode 26 (`waiting for workers to materialize`). Build remained valid; this device-level UI pass remains required before release.

## Verification results

- iOS Simulator arm64 build: passed after current theme and motion changes.
- Responsive layout/theme tests: 4 passed (320–768 pt typography/spacing, 44 pt targets, semantic light/dark palette).
- Focused Friends UI flow on iPhone 17: passed; title and PASS/LIKE controls stayed inside viewport, controls were hittable, profile detail opened.
- Light-theme screenshot review caught and fixed oversized swipe controls, card-layer overflow, and non-semantic profile/network surfaces.
- `git diff --check`: passed.
- Remaining unsigned-simulator warnings: KVS entitlement unavailable and StoreKit has no active sandbox account.

Build and UI-test results are recorded after implementation; passing local checks do not replace release-device QA.
