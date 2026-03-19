# APP FULL AUDIT FOR CLAUDE

Date: 2026-03-13

Scope: Full reverse-engineering audit of the `SWEEEZY` repository with emphasis on the iOS app, but including backend, release tooling, App Review context, privacy/compliance, and implementation drift.

Method:
- Searched the full repo, including `sweezy/`, `backend/`, `fastlane/`, `.github/`, and docs.
- Traced actual call sites and mounted app entry points, not just definitions.
- Cross-checked product behavior against implementation comments, release metadata, and backend routes.
- Marked uncertain points as inferred instead of pretending they are confirmed.

---

# 1. Executive Summary

## What this app is
`Sweezy` is a SwiftUI iOS app intended to help Ukrainians and other newcomers integrate into life in Switzerland. It combines informational content, checklists, templates, service discovery, jobs/CV tooling, and lightweight personalization.

## Who it is for
Primary audience:
- Ukrainians living in or relocating to Switzerland
- New arrivals dealing with permits, housing, insurance, healthcare, work, banking, and official paperwork

Secondary audience:
- Other migrants/newcomers who can benefit from Swiss integration guidance

## Core purpose of the product
The product aims to reduce friction in adaptation to Switzerland by combining:
- Localized guides
- Practical step-by-step checklists
- Document templates
- Map of relevant services
- Job and CV assistance
- Optional account-based personalization

## Current release status
Confirmed from repo and recent operator context:
- App target version is `1.0`
- Current build number is `8`
- Bundle ID is `com.sweezy.mobile`
- The app is in pre-launch / App Review state, not a mature public release

## Whether the app is already in production / App Store
Best assessment:
- Not confirmed as publicly live on the App Store
- Strongly indicated to be pre-release / under review
- App Store metadata exists and release workflows exist
- README still says “App Store Coming Soon”

## Current monetization status
Confirmed:
- Monetization is effectively disabled in the iOS build under review
- `SubscriptionManager` is stubbed to always return premium access
- `SubscriptionView` explicitly says there are no subscriptions and no IAP in this build
- StoreKit is not currently referenced in Swift code

Important nuance:
- The old subscription architecture still exists in backend routes, API client, model fields, remote config, docs, and legal copy
- So monetization is not cleanly removed, only bypassed/stubbed on iOS

## Current login / guest mode behavior
Confirmed:
- The active app shell is guest-first
- Users complete onboarding, then go directly into the main tab app without mandatory account creation
- Login/register exists, but it is not required for general content access
- Profile editing is the clearest account-gated screen

## High-level product maturity assessment
Overall assessment: mid-stage product with real breadth, but not architecturally settled.

Strengths:
- Broad feature set already implemented
- Real backend exists
- Strong visual/design effort
- Public content experience is substantial

Weaknesses:
- Significant drift between old and current product assumptions
- Dead/legacy root architecture remains in repo
- Monetization was disabled quickly for review, not cleanly redesigned out
- Backend/client schemas and docs are partially inconsistent
- Several features exist but are unreachable or only partially wired

Bottom line:
- This is not a prototype, but it is also not a clean production system
- It is a real app in transition between product directions

---

# 2. Product Overview

## What problem the app solves
The app reduces the complexity of adapting to Swiss life by centralizing practical information and task-oriented guidance in one mobile product. Instead of forcing users to search fragmented web sources, it bundles:
- Guides by life domain
- Interactive checklists
- Service locations
- Templates for formal communication
- Career/job support

## Main user personas
- New arrival with urgent integration needs: registration, healthcare, insurance, housing
- Job seeker who needs CV help, job search, and application drafting
- Family user who needs benefits, school/family guidance, healthcare and appointments
- Returning user who wants reminders, progress, and saved personalized state

## Key use cases
- Read a guide about a Swiss life topic
- Complete a checklist for a process
- Find nearby services on a map
- Generate and export a letter/template
- Build a CV and get AI help
- Search jobs and draft application text
- Track personal progress/gamification
- Manage a profile and local app data

## What the user can do in the app today
Confirmed working or substantially implemented:
- Onboard into the app
- Use the app without account creation
- Browse Home dashboard
- Browse guides and checklists
- Use service map
- Open settings/privacy/about/data management
- Open CV Builder
- Open Templates
- Open Roadmap
- Open Jobs from Home if routed there

Partially implemented or inconsistently surfaced:
- Benefits calculator
- Appointments/reminders
- Biometric lock flow
- Deep-link based navigation
- First-week onboarding task system

## What features are public vs account-based
Public in current active shell:
- Home
- Guides
- Checklists
- Map
- Settings shell
- Templates
- CV Builder
- Most content browsing

Account-based:
- Profile edit/personalization flow
- Account deletion
- True backend-authenticated session

Hybrid:
- Content can come from backend when authenticated, but most experience still works off local seed/cache data

## Which features were previously premium / gated and what the current state is
Previously premium or designed for premium:
- AI CV text generation
- AI job application drafting
- Some guides/content gating
- PDF export and unlimited saves
- Jobs favorites limits
- Premium roadmap tips
- Paywall analytics / trial reminders / plan defaults

Current state:
- iOS behaves as “all features unlocked”
- Premium checks are bypassed or hardcoded true in multiple views
- UI paywalls are removed or neutralized
- Backend premium requirements still exist on some endpoints

## Whether IAP / subscriptions are currently active, disabled, stubbed, or removed
Most accurate description:
- Disabled in user-facing iOS behavior
- Stubbed in iOS architecture
- Still present in backend architecture
- Still referenced in stale docs/metadata/legal copy

They are not safely “removed”; they are “temporarily bypassed for review.”

---

# 3. Feature Inventory

## Authentication

### Login
- What it does: backend login using email/password; stores access and refresh tokens in Keychain
- Where: `sweezy/sweezy/Features/Auth/LoginView.swift`, `sweezy/sweezy/Core/Networking/APIClient.swift`, `sweezy/sweezy/Core/Security/KeychainStore.swift`
- Access path: Settings or account-related protected flows
- Status: working
- Caveats:
  - Login is backend-dependent
  - No robust session validation at startup
  - Guest mode is preferred in active shell

### Registration
- What it does: attempts backend registration and login, then falls back to local-only registration if backend fails or times out
- Where: `sweezy/sweezy/Features/Auth/RegistrationView.swift`
- Access path: Settings or old auth flows
- Status: partially working but conceptually messy
- Caveats:
  - It can create a “registered” local user without a real backend account
  - This creates ambiguity between “authenticated” and “locally marked registered”

### Password Reset
- What it does: forgot/reset password flow via backend
- Where: `sweezy/sweezy/Features/Auth/LoginView.swift`, `sweezy/sweezy/Core/Networking/APIClient.swift`
- Access path: Login screen
- Status: likely working if backend/email flow is configured
- Caveats:
  - Depends on backend SMTP configuration

## Guest Mode
- What it does: allows full access to general app content without account creation
- Where: `sweezy/sweezy/ContentView.swift`, `sweezy/sweezy/Core/Services/SessionManager.swift`
- Access path: default app flow after onboarding
- Status: active and important for App Store compliance
- Caveats:
  - Some older flows/screens still assume registration-first architecture

## Home / Dashboard
- What it does:
  - Entry dashboard
  - Shows greeting, stats, roadmap entry, featured guides/news, quick actions, Telegram/community block
  - Opens CV Builder, Templates, Jobs, old onboarding, and some other modals
- Where: `sweezy/sweezy/Features/Home/HomeViewRedesigned.swift`
- Access path: Tab 0 in `MainTabView`
- Status: core working feature
- Caveats:
  - Contains temporary App Store review behavior
  - Has quick action to calculator via `DeepLinkService` that likely does nothing in current shell
  - Uses old `OnboardingView` as a modal even though active onboarding is `OnboardingViewRedesigned`

## Guides
- What it does:
  - Searchable guide library
  - Filter by category
  - Show detailed article content
  - Share/open links
- Where: `sweezy/sweezy/Features/Guides/GuidesView.swift`, `sweezy/sweezy/Features/Dovidnyk/DovidnykView.swift`, `sweezy/sweezy/Core/Models/Guide.swift`
- Access path: Dovidnyk tab
- Status: working
- Caveats:
  - Backend guide IDs are discarded when mapped into local `Guide` models, causing identity drift
  - Legacy `GuidesViewRedesigned.swift` still contains locked/register logic that does not match current public-access behavior

## Checklists
- What it does:
  - Step-based progress tracking
  - Local completion persistence
  - Used as practical action-oriented guidance
- Where: `sweezy/sweezy/Features/Checklists/ChecklistsView.swift`, `sweezy/sweezy/Core/Models/Checklist.swift`
- Access path: Dovidnyk tab
- Status: working
- Caveats:
  - Progress persistence is view-driven with `UserDefaults`, not repository-driven
  - Remote checklist identity can drift because backend IDs are not preserved

## Roadmap
- What it does:
  - Mountain-themed progression roadmap
  - Levels/tasks/progress
  - Premium-era “premiumTips” still exist in models
- Where: `sweezy/sweezy/Features/Roadmap/MountainRoadmapView.swift`, `sweezy/sweezy/Features/Roadmap/RoadmapModels.swift`, `sweezy/sweezy/Features/Roadmap/RoadmapService.swift`
- Access path: Home section and modal navigation
- Status: working with legacy premium remnants
- Caveats:
  - Monetization-era terminology still present
  - Fully unlocked in current build

## Jobs
- What it does:
  - Search Swiss jobs
  - Filter by canton/city/employment
  - AI Match profile
  - AI drafted application text
  - Local favorites
- Where: `sweezy/sweezy/Features/Jobs/JobsView.swift`, `sweezy/sweezy/Core/Networking/APIClient.swift`
- Access path: full-screen cover from Home
- Status: substantial implementation exists
- Caveats:
  - In active Home UI, the product messaging around jobs is inconsistent and was recently review-adjusted
  - Local favorites are stored in `UserDefaults`; backend favorites exist but are not primary in current UI
  - AI drafting endpoint still depends on backend premium enforcement

## CV Builder
- What it does:
  - Multi-step CV wizard
  - Summary/experience/education/skills
  - Preview
  - “Translate to German” workflow
  - AI enhancement
- Where: `sweezy/sweezy/Features/CV/CVBuilderView.swift`, `sweezy/sweezy/Core/Models/CV.swift`, `sweezy/sweezy/Core/Networking/APIClient.swift`
- Access path: Home quick action / modal
- Status: working but monetization/auth assumptions are bypassed
- Caveats:
  - AI flows assume access but backend may still require premium
  - Uses local persistence and backend AI hybrid behavior

## Templates
- What it does:
  - Browse document templates
  - Fill placeholders
  - Generate final text
  - Export/share
- Where: `sweezy/sweezy/Features/Templates/TemplatesView.swift`, `sweezy/sweezy/Core/Models/Template.swift`
- Access path: Home quick action / modal
- Status: functionality appears implemented
- Caveats:
  - `TemplatesView` requires `@EnvironmentObject AccountManager`
  - Home opens `TemplatesView` with only `AppContainer` and `AppLockManager`
  - No app-wide `AccountManager` injection was found
  - Confirmed missing injection; inferred runtime crash if this screen is opened from current Home path

## Map / Services
- What it does:
  - Map-based service discovery
  - Nearby/all services
  - Place detail sheets
  - Open phone, website, directions
  - Optional live place status enrichment
- Where: `sweezy/sweezy/Features/Map/MapView.swift`, active tab mount via `OptimizedMapView` inside `MainTabView`
- Access path: Tab 2
- Status: working core feature
- Caveats:
  - Base place catalog is local JSON
  - “Live” place status is backend overlay, not canonical place data

## Settings
- What it does:
  - Profile card
  - Language picker
  - Privacy/about/legal
  - Biometrics toggle
  - Data export/import/delete
  - Register/login/logout
  - Account deletion
- Where: `sweezy/sweezy/Features/Settings/SettingsView.swift`
- Access path: Tab 3
- Status: working but overloaded
- Caveats:
  - Biometrics toggle sets lock state, but active root shell does not enforce lock screen
  - Contains “Unlocked” status chip due review-time monetization bypass

## Appointments
- What it does:
  - Displays upcoming/past appointments
  - Add appointment sheet
  - Appointment reminder model exists
- Where: `sweezy/sweezy/Features/Appointments/AppointmentsView.swift`, `sweezy/sweezy/Core/Models/Appointment.swift`, `sweezy/sweezy/Core/Services/NotificationService.swift`
- Access path: not clearly exposed in active shell
- Status: partial / local-only
- Caveats:
  - Loads mock appointments
  - Added appointments live only in view state
  - Backend appointments exist, but iOS app does not appear to use them

## Benefits Calculator
- What it does:
  - Calculates possible benefits from local rules and user inputs
- Where: `sweezy/sweezy/Features/Calculator/BenefitsCalculatorView.swift`, `sweezy/sweezy/Core/Services/CalculatorService.swift`
- Access path: intended from Home quick action
- Status: partial
- Caveats:
  - Uses simulated delay and a mock profile
  - “Apply now” button is empty
  - Current quick-action routing likely broken in active shell

## Onboarding
- What it does:
  - Active onboarding: intro pages + language picker + theme picker + success page
  - Legacy onboarding: collects profile/goals and seeds first-week tasks/reminders
- Where:
  - Active: `sweezy/sweezy/Features/Onboarding/OnboardingViewRedesigned.swift`
  - Legacy: `sweezy/sweezy/Features/Onboarding/OnboardingView.swift`
- Access path:
  - Active at app launch before onboarding completion
  - Legacy still callable from Home modal
- Status:
  - Active onboarding works
  - Legacy onboarding still matters because it seeds systems the active onboarding no longer seeds
- Caveats:
  - This split is one of the most important product-state inconsistencies in the codebase

## First Week Checklist / Reminder Engine
- What it does:
  - Generates deadline-oriented onboarding tasks from profile data
  - Schedules reminders
  - Emits gamification events
- Where: `sweezy/sweezy/Core/Services/FirstWeekChecklistService.swift`
- Access path: seeded by legacy onboarding, surfaced in parts of Home
- Status: partial because active onboarding no longer seeds it
- Caveats:
  - Home still references it, so new users from active onboarding may get empty/underpowered widgets

## Gamification
- What it does:
  - XP, level, streaks, badges, event-driven rewards
- Where: `sweezy/sweezy/Core/Services/Gamification/GamificationService.swift`, `sweezy/sweezy/Core/Services/Gamification/EventBus.swift`, some UI in Home/Settings, `QuestsView`, `AchievementsView`
- Access path: visible in Home and Settings; dedicated views not clearly mounted
- Status: working infrastructure, partial surfacing
- Caveats:
  - Dedicated gamification screens may not be reachable in active shell

## News
- What it does:
  - Displays news cards and detail
  - Opens external URLs when needed
- Where: `sweezy/sweezy/Features/News/NewsDetailView.swift`, `ContentService`
- Access path: Home
- Status: working
- Caveats:
  - Backend and local seed/news import systems both exist

## Hidden / Admin / Debug
- `AdminSyncService`: can import local seed content into backend in debug flows
- Backend demo seeding: optional demo user for App Review / QA
- `/debug/openapi` backend endpoint
- Several stale or preview-only views/components exist

---

# 4. User Flows

## First launch flow
1. `SweezyApp` launches and creates `AppContainer`, `ThemeManager`, `AppLockManager`, and `SessionManager`.
2. The app requests notification permission on appearance, starts crash reporting if configured, starts performance monitoring, and logs TTI telemetry.
3. `MainAppContent` checks only `appContainer.isOnboardingCompleted`.
4. If onboarding is incomplete, the user sees `OnboardingViewRedesigned`.
5. In active onboarding, the user goes through:
   - intro page 1
   - intro page 2
   - language picker
   - theme picker
   - success page
6. Skip completes onboarding immediately.
7. After completion, the app enters `MainTabView`.

## Guest flow
1. User finishes onboarding or skips it.
2. User lands in `MainTabView` without being asked to register.
3. User can browse Home, Dovidnyk, Map, and Settings.
4. User can open general content features and most modal tools.
5. If the user attempts profile editing, they are prompted to log in.

## Login flow
1. User opens login from Settings or an account-gated screen.
2. User enters email/password.
3. `APIClient.login()` calls backend auth endpoint.
4. Access and refresh tokens are stored in Keychain.
5. Local registration markers are updated and `SessionManager` becomes authenticated.
6. App continues from the same guest-friendly shell; there is no separate authenticated root experience.

## Register flow
1. User opens registration.
2. User enters name/email/password.
3. App tries backend register and immediate login with a 5-second timeout.
4. If backend succeeds, tokens are stored.
5. If backend fails or times out, app still writes local user state and marks registration complete.
6. User exits into main app.

Important implication:
- “Registered” does not always mean “real backend-authenticated account.”

## Main navigation flow
Tab structure:
1. Home
2. Dovidnyk
3. Map
4. Settings

Home modal/navigation flow:
- CV Builder via sheet
- Templates via sheet
- Jobs via full-screen cover
- Roadmap via embedded navigation/modals
- Old onboarding can still open from Home
- Calculator appears intended via deep-link trigger, but active deep-link handling is likely missing

## Protected feature flow
Most content is not protected.

Primary actual protected flow:
1. User taps profile edit from Settings
2. If authenticated, full profile editor opens
3. If guest, a guest gate appears and login is auto-presented
4. If user dismisses login without authenticating, the profile editor dismisses

## Settings flow
1. User opens Settings tab
2. Sees profile card, gamification card, language/privacy/biometrics/about entries
3. Can open Data Management sheet
4. In Data Management:
   - export backup
   - import backup
   - delete all local data
   - if registered, delete account
   - login/register/logout area varies by local session state

## Onboarding / modal / close-button flow
- Most feature screens use `NavigationStack` in sheets or full-screen covers
- Close actions are generally present
- There are many modal entry points from Home and Settings
- Some modal flows are old/legacy and no longer aligned with main architecture

## Payment / premium flow remnants
Current visible behavior:
- No active paywall
- Settings shows “Unlocked”
- Subscription placeholder says all features are unlocked

Under the hood:
- Subscription endpoints still exist
- Trial reminder notification code still exists
- Paywall analytics route still exists
- Remote config still contains paywall defaults

---

# 5. Current Access Model

## What guests can access
Confirmed:
- Onboarding
- Home dashboard
- Guides
- Checklists
- Map
- Settings shell
- Templates
- CV Builder
- Most informational/productive features in the active shell

## What authenticated users can access
Authenticated users get:
- Everything guests get
- Profile editing/personalization
- Account deletion path
- Token-backed backend interactions where applicable

## Whether anything is still account-locked
Yes, but much less than older architecture intended.

Clearly locked:
- Profile edit/personalization

Weakly or inconsistently locked:
- Some backend-backed flows may behave differently depending on token presence

## Whether there are still premium checks in code
Yes, many.

Examples:
- `Guide.isPremium`
- `RoadmapLevel.premiumTips`
- Subscription DTOs and endpoints in `APIClient`
- Backend `subscriptions` router
- Backend AI routes guarded with `require_premium()`
- Paywall defaults in `RemoteConfigService`
- Trial/reminder notification code

## Whether any old paywall remnants remain
Yes, many remnants remain, even if not visible to end users:
- `SubscriptionManager`
- `SubscriptionLiveService`
- `SubscriptionView`
- Remote config paywall defaults
- Analytics/paywall route
- Backend Stripe subscription handling
- Legal terms page mentioning auto-renewing subscriptions
- Docs mentioning paywall plans and trial behavior

## Whether the app currently behaves as “all features unlocked”
Yes, on the iOS side that is the current intended behavior.

Important nuance:
- This is implemented by bypass/stub behavior, not by full architectural cleanup
- Backend premium requirements can still conflict with this assumption

---

# 6. Technical Architecture

## App entry point
Active app entry is `SweezyApp` in `sweezy/sweezy/ContentView.swift`.

This is the true mounted root, not `AppRootView`.

## Root views
Mounted root:
- `SweezyApp`
- `MainAppContent`
- `MainTabView`

Dead/legacy root:
- `AppRootView`

This is a critical distinction. `AppRootView` still contains real logic for:
- biometric lock gating
- scene phase lock handling
- deep-link/password reset routing
- registration-first branching

But it is not mounted by the app.

## Navigation structure
Primary navigation:
- `TabView` with Home, Dovidnyk, Map, Settings

Secondary navigation:
- `NavigationStack` inside tabs and sheets
- Sheets and full-screen covers heavily used from Home and Settings
- Some older flows rely on global notification/deep-link mechanisms

## App state management
The app uses a mixed state model:
- `@StateObject` globals at app level
- `EnvironmentObject` propagation
- local view state in many screens
- singleton services for some concerns
- `AppStorage` and `UserDefaults` for persistence-backed state

This is pragmatic but not cohesive.

## Session/auth management
`SessionManager` derives current session state from `AppLockManager`.

Key behavior:
- If `lockManager.isRegistered` is true, `SessionManager` considers user authenticated
- It does not validate tokens or fetch current user on launch
- Sign-out clears tokens and returns user to guest mode

There are effectively multiple overlapping auth/session concepts:
- `SessionManager`
- `AppLockManager`
- old `AccountManager`

## Dependency injection / service container
`AppContainer` is the closest thing to a DI container / service locator.

It owns:
- content service
- localization
- analytics
- telemetry
- gamification
- remote config
- location
- notifications
- calculator
- first week service
- roadmap sync
- crash reporting

It also owns global mutable state:
- onboarding completion
- current locale
- local `userProfile`

However, not everything uses it:
- `SessionManager` is created separately
- singletons still exist for feature onboarding, event bus, deep links, AI, and subscriptions

## View model usage
There is very little classical MVVM view-model structure.

Pattern in practice:
- Feature views often hold substantial logic directly
- Services provide business logic/data loading
- Views own local derived state, filters, and persistence in several places

This is a view-heavy architecture rather than view-model-heavy architecture.

## Service layer
There is a real service layer, but it is uneven in maturity.

Mature-ish:
- `ContentService`
- `TelemetryService`
- `NotificationService`
- `GamificationService`
- `RemoteConfigService`

Less cohesive / legacy:
- `AIService` (unused direct OpenAI client)
- `DeepLinkService`
- `AccountManager`
- subscription-related services

## API layer
Networking is centralized in static `APIClient`.

Characteristics:
- reads `API_BASE_URL` from `Info.plist`
- defaults to Render backend
- prepends `/api/v1`
- uses `URLSession`, manual request construction, `JSONSerialization`/`JSONDecoder`
- attaches bearer token from Keychain when available

It is simple but highly manual, with no formal typed repository layer above it.

## Persistence/storage
Persistence is spread across:
- `UserDefaults`
- `@AppStorage`
- Keychain
- JSON caches in `Caches/SweezyContent`
- ad hoc file exports/imports

There is no unified storage schema or migration layer.

## Local state vs remote state
The product is strongly local-first.

Patterns:
- local seed JSON is primary baseline
- remote content overlays or replaces some categories
- authenticated users may get more remote-backed content
- many screens still work entirely locally

## Async patterns used
The app uses:
- `async/await`
- `Task`
- `Task.sleep`
- `DispatchQueue.main.asyncAfter`
- `Combine` for `@Published` / simple bindings
- notification center publishers

Risk:
- timing-based orchestration is common, which suggests some data flows are not modeled cleanly

## Global environment objects / state objects
Mounted globally:
- `AppContainer`
- `ThemeManager`
- `AppLockManager`
- `SessionManager`

Not globally mounted, despite direct `EnvironmentObject` dependency in some views:
- `AccountManager`

That missing global injection is one of the strongest concrete architecture bugs found.

---

# 7. Code Structure

## Summary
This is a monorepo, not just an iOS app.

Top-level important areas:
- `sweezy/` native iOS app
- `backend/` FastAPI backend
- `admin/` web/admin client
- `fastlane/` release metadata and lanes
- `.github/workflows/` CI
- `docs/` and repo markdown artifacts

## Important tree

```text
SWEEEZY/
├── sweezy/
│   ├── sweezy.xcodeproj/
│   ├── sweezy/
│   │   ├── ContentView.swift
│   │   ├── AppRootView.swift
│   │   ├── Core/
│   │   │   ├── AppContainer.swift
│   │   │   ├── Models/
│   │   │   ├── Networking/APIClient.swift
│   │   │   ├── Security/KeychainStore.swift
│   │   │   └── Services/
│   │   ├── DesignSystem/
│   │   ├── Features/
│   │   │   ├── Home/
│   │   │   ├── Dovidnyk/
│   │   │   ├── Guides/
│   │   │   ├── Checklists/
│   │   │   ├── Map/
│   │   │   ├── Jobs/
│   │   │   ├── CV/
│   │   │   ├── Templates/
│   │   │   ├── Roadmap/
│   │   │   ├── Settings/
│   │   │   ├── Auth/
│   │   │   ├── Onboarding/
│   │   │   ├── Subscription/
│   │   │   ├── Calculator/
│   │   │   └── Appointments/
│   │   ├── Resources/
│   │   │   ├── AppContent/seeds/
│   │   │   ├── Localization/
│   │   │   └── PrivacyInfo.xcprivacy
│   ├── sweezyTests/
│   └── sweezyUITests/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── core/
│   │   ├── models/
│   │   ├── routers/
│   │   ├── schemas/
│   │   └── services/
│   └── alembic/
├── admin/
├── fastlane/
├── docs/
├── RELEASE.md
└── shared/openapi.json
```

## Main folders and purpose

### `sweezy/sweezy/Core`
- App-wide infrastructure
- models
- services
- networking
- security

### `sweezy/sweezy/Features`
- User-facing feature screens grouped by domain

### `sweezy/sweezy/DesignSystem`
- Theme and UI components

### `sweezy/sweezy/Resources`
- Seed content
- localization
- privacy manifest

### `backend/app`
- FastAPI backend with auth/content/jobs/subscription/legal/etc.

### `admin/`
- Separate admin/web UI for content management and backend interaction

## Legacy / duplicate / deprecated files

High-value stale or misleading artifacts:
- `sweezy/sweezy/AppRootView.swift`
- `sweezy/sweezy/Core/Services/AccountManager.swift`
- `sweezy/sweezy/Core/Services/AIService.swift`
- `sweezy/sweezy/Features/Guides/GuidesViewRedesigned.swift`
- `backend/app/routers/public.py`
- `backend/app/services/news.py`
- `sweezy/Production_Ready_Audit_Report.md`
- `docs/user-journey.md`
- portions of `README.md`
- parts of `fastlane/metadata/*`

Many of these describe an older product state.

---

# 8. Authentication & Session Analysis

## How auth currently works
Backend auth exists and is used by login/register/reset/delete flows.

Core path:
- register via backend if possible
- login via backend
- store tokens in Keychain
- mark local state as registered/authenticated

## Which auth provider/backend is used
Custom backend auth via FastAPI under `/api/v1/auth`.

There is no evidence of:
- Sign in with Apple
- Firebase Auth
- Auth0
- Supabase Auth

## How user sessions are stored
Tokens:
- stored in Keychain under service `sweezy.auth`

Local identity/session markers:
- `userName`, `userEmail`, `isRegistered`, biometrics flags in `AppStorage` / `UserDefaults`

## What happens on app start
Current app start behavior:
- no token refresh flow
- no `/me` restore
- no backend validation of auth freshness
- session is derived from local registration state

This means the app trusts local flags more than remote session truth.

## How guest mode was implemented
Guest mode is implemented at the root-shell level:
- `MainAppContent` ignores auth and only gates on onboarding completion
- `SessionManager` has explicit `.guest` state
- login screen includes “continue as guest”

This was clearly added for App Store 5.1.1 compliance.

## How protected routes/features are enforced
Protection is selective and inconsistent.

Properly enforced example:
- `ProfileEditView` checks `sessionManager.isAuthenticated`

Less robust pattern elsewhere:
- many screens branch on `lockManager.isRegistered`
- older auth assumptions still exist in some parts of the codebase

## Weak points in auth/session logic
- Registration can silently fall back to local-only mode
- “Authenticated” can mean “locally flagged” rather than “valid backend session”
- No startup token validation/refresh
- Multiple overlapping abstractions (`SessionManager`, `AppLockManager`, `AccountManager`)
- Protected behavior is not centralized

Net assessment:
- Good enough for a guest-first app with optional account features
- Not strong enough for a security-sensitive or purchase-sensitive app without refactor

---

# 9. Subscription / Monetization Analysis

## Current monetization-related code
Confirmed iOS artifacts:
- `Core/Services/SubscriptionManager.swift`
- `Core/Services/SubscriptionLiveService.swift`
- `Features/Subscription/SubscriptionView.swift`
- `APIClient` subscription DTOs and endpoints
- `RemoteConfigService` paywall fields
- `NotificationService` trial reminder methods
- `Guide.isPremium`
- roadmap premium fields

Confirmed backend artifacts:
- `backend/app/routers/subscriptions.py`
- `backend/app/services/stripe_service.py`
- premium enforcement in `backend/app/dependencies.py`
- legal page mentions auto-renewing subscriptions

## What used to exist
The product previously appears to have had:
- paid subscription plans
- trial flow
- premium entitlements
- paywall analytics
- favorites limits / AI access gating / guide gating / PDF gating

This is confirmed by:
- code comments
- backend endpoints
- remote config fields
- docs and App Store metadata

## What was removed / stubbed / bypassed for App Store review
Confirmed:
- Subscription manager now always returns premium
- live entitlement streaming is disabled
- subscription screen is a static “all features unlocked” placeholder
- many views hardcode unlocked access or suppress paywall UI

Examples:
- `JobsView`: `hasPremiumAccess = true`
- `CVBuilderView`: `hasPremiumAccess = true`, `hasAIAccess = true`
- `SettingsView`: shows “Unlocked”
- guides/roadmap/home comments note IAP removal

## Whether StoreKit is still referenced anywhere
Search result:
- No active StoreKit references found in Swift code

This is good for App Review, but it also means any future reintroduction will require re-adding client-side purchase code, not just flipping config.

## Whether paywall, premium flags, subscription manager, or entitlements still exist in any form
Yes.

Still exist:
- premium flags in models
- subscription endpoints in backend and API client
- entitlement DTOs
- live subscription update concept
- paywall fields in remote config
- paywall analytics endpoint
- trial reminder code
- legal/docs/metadata references

## What would be required to reintroduce monetization safely later
Safe reintroduction plan would require:
1. Choose architecture:
   - Native Apple IAP via StoreKit 2
   - External web checkout for permitted categories only
   - Or hybrid with Apple rules carefully respected
2. Rebuild entitlement truth:
   - one source of truth for entitlements
   - iOS app should not hardcode premium
   - backend and app must agree on access checks
3. Reintroduce client purchase handling:
   - purchase
   - restore
   - receipt/transaction sync
4. Clean up old stubs:
   - remove current “always unlocked” assumptions
   - remove misleading UI copy
5. Update legal/privacy/App Store metadata to match actual product
6. Re-test AI/jobs/CV locked behaviors end-to-end

Do not simply “turn back on” old endpoints. The codebase is too drifted for that to be safe.

---

# 10. Networking / Backend / API Audit

## Which backend is used
Custom FastAPI backend under `backend/app`, versioned under `/api/v1`.

Default production URL from iOS:
- `https://sweezy-9xyk.onrender.com`

## Which API services exist
Backend routers include:
- auth
- guides
- checklists
- templates
- appointments
- remote config
- admin
- media
- news
- ai
- jobs
- live
- translations
- subscriptions
- analytics
- telemetry
- legal/support public pages

## Important endpoints and responsibilities

### Auth
- `/api/v1/auth/register`
- `/api/v1/auth/login`
- `/api/v1/auth/password/forgot`
- `/api/v1/auth/password/reset`
- `/api/v1/auth/me`

### Content
- `/api/v1/guides`
- `/api/v1/checklists`
- `/api/v1/templates`
- `/api/v1/news`

### AI
- `/api/v1/ai/cv-suggest`
- `/api/v1/ai/job-apply`

### Jobs
- `/api/v1/jobs/search`
- `/api/v1/jobs/favorites` exists but is not the primary current iOS path

### Live / Utility
- `/api/v1/live/place-status`
- `/api/v1/remote-config`
- `/api/v1/telemetry/batch`

### Monetization / Analytics
- `/api/v1/subscriptions/*`
- `/api/v1/analytics/paywall`

## Whether data is mocked, live, hybrid, or partially stubbed
The app is hybrid.

By domain:
- Guides: live-first, then local/cache fallback
- Checklists/templates/news: remote only when token exists, otherwise local/cache
- Places: local seed + optional live status overlay
- Benefit rules: local
- Appointments: iOS currently local/mock despite backend support
- AI: backend with deterministic fallback if backend lacks OpenAI key
- Jobs: live search + local cache

## Error handling quality
Mixed.

Strengths:
- local fallbacks for many content flows
- some timeouts/retry-like behavior
- telemetry around request performance

Weaknesses:
- highly manual request building
- many endpoints just return empty arrays / nil on failure
- user-facing error states are inconsistent
- auth/entitlement failures can be masked by local assumptions

## Any telemetry/logging present
iOS:
- `TelemetryService` buffers and sends event batches
- `AnalyticsService` can send to Amplitude if enabled/configured
- `CrashReporterService` wraps Sentry if present/configured

Backend:
- structured request logging
- request IDs
- Prometheus instrumentation
- Sentry initialization
- JSONL telemetry log persistence

## Any obvious backend dependencies
- PostgreSQL / SQLAlchemy / Alembic
- Stripe for subscriptions
- optional OpenAI key for AI improvements
- optional SMTP for password reset/email
- optional Overpass/other sources for live place enrichment
- optional Telegram bot notifications for billing events

---

# 11. Data Model Audit

## Core iOS models

### `Guide`
Represents a long-form informational article.
Used in:
- guide lists
- guide detail
- search
- roadmap sync links

Notable fields:
- category
- tags
- canton applicability
- `isPremium`
- language
- source/verifiedAt

Risk:
- Backend IDs are not preserved when mapped to iOS model instances

### `Checklist`
Represents a structured process with ordered steps.
Used in:
- checklist list/detail/progress tracking

Risk:
- same identity drift problem as guides

### `DocumentTemplate`
Represents a fillable letter/form template with placeholders.
Used in:
- template list/detail/form/export

Risk:
- current feature may have environment injection bug

### `Appointment`
Rich local appointment model with reminder/location/contact metadata.
Used in:
- `AppointmentsView`
- notification scheduling

Risk:
- backend appointment model is much smaller; iOS and backend are not aligned

### `UserProfile`
Local personalization profile for canton, permit, goals, dates, contact, family state.
Used in:
- profile edit
- onboarding
- calculator
- first-week tasks

### `CVResume`
Local CV editing structure for builder and AI payload generation.
Used in:
- CV Builder
- AI request shaping

## Relationships between models
- `ChecklistStep` embeds `GuideLink`
- `AppointmentLocation` uses `Address` and optional `Coordinate`
- `BenefitRule` depends on user-domain concepts like canton/permit
- roadmap/progress systems depend on content IDs remaining stable

## Duplicated or conflicting logic
- content identity drift between backend IDs and local UUID-generated models
- translations exist on backend, but iOS uses bundled localized JSON instead
- appointment domain is richer on iOS than backend
- premium access logic exists in model fields, backend, and UI, but current runtime bypasses it

## Fragile data assumptions
- Stable IDs are assumed by progress/favorites/sync, but remote IDs are discarded
- Some content is assumed Ukrainian by default when loaded remotely
- many fallbacks assume bundle/cache data is sufficient
- backup import/export writes full content blobs into local cache without migration/version logic

---

# 12. UI/UX Audit

## Current design system
The app has a serious design system investment:
- centralized `Theme`
- custom components
- winter/new year seasonal overlays and icons
- gradients, glassmorphism, custom cards

Strength:
- visually distinctive

Risk:
- complexity and seasonal theming increase maintenance burden

## Navigation usability
Active shell is simple:
- 4 tabs

Good:
- clear high-level information architecture

Less good:
- several major features are modal from Home rather than first-class tabs
- old/dead navigation assumptions remain
- some hidden features are hard to discover

## iPhone vs iPad support
Confirmed:
- target device family includes iPhone and iPad

Assessment:
- iPad support exists at target level, but many screens are clearly designed mobile-first
- Expect large-screen whitespace and layout inconsistency rather than true iPad-native UX

## Known layout / UX issues
- Home contains many competing surfaces and modals
- seasonal design can reduce clarity
- some screens appear unfinished or detached from active flows
- calculator/app appointments feel prototype-like compared with polished Home

## Modal / sheet behavior
There are many sheets and full-screen covers.

Strength:
- feature entry is flexible

Risk:
- state complexity
- inconsistent modal hierarchy
- legacy screens still presented from modern shell

## Accessibility concerns
Positive:
- the project makes some explicit accessibility effort
- some identifiers and scalable patterns exist

Risks:
- visual density and decorative elements may impact VoiceOver clarity
- winter/seasonal overlays may complicate contrast or focus
- large modal-driven flows need more exhaustive VoiceOver/Dynamic Type testing

## App Store review-related UX issues that were fixed or may still exist
Fixed or intentionally changed:
- guest-first root shell
- removed visible paywall
- “all features unlocked” messaging
- privacy manifest corrected

Still risky:
- metadata and legal pages still mention subscriptions/trials
- app description says data stays on device, but AI/analytics/backend flows complicate that claim
- some premium language survives in code and maybe copy paths

## Obviously unfinished screens
- `BenefitsCalculatorView`
- `AppointmentsView`
- some dedicated gamification screens
- old onboarding/profile seeding flow relative to active onboarding
- `GuidesViewRedesigned` legacy lock behavior

---

# 13. Privacy / Permissions / Compliance

## Camera usage
Declared in app target build settings.
Use case likely scanning documents/QR codes per usage string.

## Face ID usage
Declared and implemented via `AppLockManager`.
However, active root shell does not enforce biometric lock UI like old root did.

## Location usage
Declared and implemented.
Used for nearby services on the map.

## Required plist descriptions
Confirmed for:
- camera
- Face ID
- location when in use
- photo library
- non-exempt encryption flag

## Privacy manifest status
Current manifest:
- exists at `sweezy/sweezy/Resources/PrivacyInfo.xcprivacy`
- declares no tracking
- declares no collected data types
- declares required-reason APIs for `UserDefaults` and `FileTimestamp`

This was recently corrected and should be valid structurally.

## Guest mode compliance
Strongly improved:
- general content is accessible without account
- aligns with App Store 5.1.1 intent

## Any App Review risks still present
- metadata/legal still reference subscriptions/trial
- privacy/disclosure mismatch risk:
  - app description claims local-only privacy
  - backend AI, analytics, crash reporting, and account storage exist
- backend premium enforcement may conflict with “all unlocked” behavior

## Sensitive data handling concerns
- tokens are correctly in Keychain
- many other user/session flags are in `UserDefaults`
- direct unused `AIService` suggests potential direct OpenAI calls if ever reactivated
- app privacy copy and actual network behavior need tighter alignment

---

# 14. App Store / Release Context

## App Store review issues that were encountered
Confirmed from recent operator context and code changes:
- Privacy manifest rejection (`ITMS-91056`) was addressed
- Apple also requested clarification of business model / paid content status

## What was changed to pass review
Confirmed recent state:
- invalid privacy manifest replaced with valid single manifest
- duplicate manifest removed
- guest-first access maintained
- paywall/IAP behavior removed or stubbed
- app made effectively “all features unlocked”

## Current App Store status
Best known status:
- version `1.0` under App Review / pre-release state
- not confirmed publicly released

## Current bundle ID
- `com.sweezy.mobile`

## Any release-specific workarounds
- subscription system disabled for review
- premium checks bypassed in app
- App Store messaging pivoted toward “no subscriptions in this build”

## Any things temporarily disabled for approval
- In-app purchase flows
- entitlement streaming
- paywall UI
- premium gating in several features
- some subscription/favorites sync logic

This is one of the most important handoff facts.

---

# 15. Build / Deployment / Release Process

## How to build the app
From Xcode:
- open `sweezy/sweezy.xcodeproj`
- scheme: `sweezy`

From CLI:
```bash
xcodebuild -project "sweezy/sweezy.xcodeproj" -scheme "sweezy" -configuration Release -destination "generic/platform=iOS" build
```

## How to archive the app
```bash
xcodebuild -project "sweezy/sweezy.xcodeproj" -scheme "sweezy" -configuration Release -destination "generic/platform=iOS" -archivePath "/tmp/sweezy.xcarchive" archive
```

## How to upload to App Store Connect
Fastlane lanes exist:
- `metadata`
- `upload`

Current Fastlane workflow:
- `build_app`
- `upload_to_testflight`

## How to increment build/version numbers
In project config:
- `MARKETING_VERSION = 1.0`
- `CURRENT_PROJECT_VERSION = 8`

These live in `sweezy/sweezy.xcodeproj/project.pbxproj`.

## Signing / capabilities gotchas
- App target uses automatic signing
- App target team ID differs from project/test team IDs
- This should be checked carefully before team-wide release automation

## Any special release steps
- Ensure `AMPLITUDE_API_KEY`, `API_BASE_URL`, `SENTRY_DSN`, and related build settings are correctly set
- Reconcile metadata/legal/privacy answers with actual current build behavior
- Verify privacy manifest and App Privacy questionnaire alignment

## Reasons a build may get rejected
- Subscription metadata does not match no-IAP build
- Privacy policy or App Privacy disclosures do not match analytics/AI/account behavior
- Legal terms mention auto-renew subscriptions while app says none exist
- Dormant but reachable premium paths could confuse review
- Guest-mode or account-gate regressions

---

# 16. Known Bugs / Risks / Technical Debt

## Known bugs / likely bugs
- `TemplatesView` depends on `AccountManager` environment object that is not globally injected
- calculator quick action likely does nothing in active shell because deep-link handling is not mounted there
- biometric lock state may not be enforced because lock UI lives in unused root
- first-week task system is under-seeded because active onboarding no longer generates tasks
- backend premium AI enforcement may conflict with fully unlocked iOS UI

## Fragile code areas
- `ContentService` remote-to-local model mapping
- session state across `SessionManager` / `AppLockManager` / `AccountManager`
- Home modal routing
- settings/data management import/export
- old onboarding + first week + profile interdependencies

## Temporary hacks
- “all features unlocked” hardcoding
- no-op subscription/live services
- static unlocked chip in settings
- trial reminder logic left in place despite no live subscription UX
- remote config mock still contains paywall fields/endpoints

## Removed-but-not-cleaned logic
- dead root architecture in `AppRootView`
- direct OpenAI `AIService`
- stale paywall/subscription docs and metadata
- stale legal subscription wording
- stale user journey docs

## Architectural debt
- no single source of truth for auth/session/entitlements
- mixed DI/service locator/singleton architecture
- little separation between view logic and business logic in some feature screens
- local persistence scattered across views and services

## UX debt
- hidden but substantial features not first-class in navigation
- old onboarding and new onboarding conflict conceptually
- some screens feel prototype-level compared with core polished surfaces

## Backend dependency risks
- premium enforcement mismatch
- schema drift between backend and iOS
- remote config model mismatch
- shared OpenAPI artifact is stale/not consumed
- file-based telemetry/media assumptions may be fragile in hosted environments

## Code paths that should not be trusted without testing
- template screen opening from Home
- jobs AI drafting under current no-premium build
- CV AI under current no-premium build
- biometrics lock behavior in active shell
- appointments persistence/notifications
- import/export restore edge cases

---

# 17. Recommendations

## Immediate cleanup tasks
- Remove or fix `TemplatesView` dependency on missing `AccountManager`
- Decide whether `AppRootView` is dead; delete it or remount the missing critical behaviors elsewhere
- Clean release metadata and legal pages to match current no-subscription build
- Align App Privacy disclosures with actual analytics/AI/backend behavior
- Remove or disable broken calculator deep-link entry if not fixed immediately

## Short-term improvements
- Centralize auth/session truth
- Preserve backend IDs in iOS content models
- Make active onboarding seed the systems Home expects
- Add end-to-end tests for guest flow, profile gate, templates, CV AI, jobs AI
- Rationalize Settings and Home modal surface area

## Medium-term product improvements
- Decide which features are core navigation vs hidden modal tools
- Either fully ship appointments/calculator or clearly de-scope them
- Reconcile backend translations vs local localization strategy
- Make iPad experience intentional rather than incidental

## Safe monetization reintroduction plan
- Do not reuse current stubs blindly
- First establish entitlement source of truth
- Rebuild purchase architecture cleanly
- Reconcile backend gating and iOS gating
- Update legal/privacy/metadata together
- Add automated purchase-state and entitlement regression tests

## Technical refactors
- Consolidate auth state into one subsystem
- Move more business logic out of views
- Replace scattered persistence with repositories or scoped stores
- Remove stale duplicate services/files
- Either use generated shared API contracts or delete the stale shared OpenAPI artifact

## UX improvements
- Promote important features to clearer navigation
- Simplify Home
- Make protected-account states clearer
- Reduce seasonal visual complexity where it hurts clarity
- Make empty/partial features visibly labeled or remove entry points

## App Store safety improvements
- Keep guest-first behavior intact
- Keep privacy manifest and App Privacy answers in sync
- Remove stale references to subscription/trial from metadata and legal pages if shipping no-IAP build
- Ensure all reviewer-visible messaging matches real product state

---

# 18. Claude Handoff Summary

## If you are Claude and you need to work on this project, here is what you must understand first

- The active app root is `ContentView.swift` via `SweezyApp`, not `AppRootView.swift`.
- The live product is currently guest-first. Do not reintroduce forced registration unless explicitly intended.
- Monetization is not really gone; it is bypassed/stubbed on iOS for App Review.
- Backend subscriptions, Stripe logic, premium enforcement, paywall analytics, and legal subscription copy still exist.
- The iOS app currently behaves as “all features unlocked,” but backend AI routes still require premium.
- `TemplatesView` has a likely runtime bug because it requires `AccountManager` but current Home flow does not inject it.
- `AppRootView` still contains logic for biometric lock and deep-link handling, but that logic is dormant because the file is not mounted.
- Active onboarding (`OnboardingViewRedesigned`) does not seed first-week tasks/profile the way old onboarding did, yet Home still depends on those systems.
- `ContentService` discards backend IDs when mapping content into local models. This can break progress, sync, dedupe, and identity continuity.
- The app is heavily local-first. Seed JSON and cache files matter a lot, even though a backend exists.
- Docs and metadata are stale in several places. Do not trust README, old audit docs, Fastlane metadata, or `docs/user-journey.md` without checking current code.
- The privacy manifest is currently valid, but privacy disclosures may still be mismatched with analytics/AI/backend behavior.
- Settings is the main place where account, data management, and destructive actions live; profile editing is the clearest real protected screen.
- Several features exist but are partial or unreachable: calculator, appointments, some gamification surfaces, and some deep-link-driven flows.
- If you change anything release-critical, preserve:
  - guest mode
  - current privacy manifest validity
  - no visible broken paywall behavior
  - the active main tab shell
  - the current App Review-safe business model messaging

## Production-critical things not to break
- App launch and onboarding completion flow
- Guest access to general content
- Settings login/logout/account deletion flow
- Guides/checklists/map core experience
- Privacy manifest and Info.plist permission declarations
- Archive/build viability for App Store submission

## Temporary things you should treat as temporary, not canonical
- always-unlocked premium behavior
- `SubscriptionManager` stub
- `SubscriptionView` placeholder
- old onboarding and old root architecture
- stale metadata/docs/legal references to subscriptions

## What must not be broken during refactors
- `AppContainer`-driven content/localization startup
- Keychain token storage
- Guest-first shell
- current build/release compliance posture

