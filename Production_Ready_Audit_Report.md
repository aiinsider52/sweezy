# Production Readiness Audit Report

Date: 2025-11-05

## Executive Summary

Sweezy is a SwiftUI mobile app backed by a FastAPI service that replaces local JSON with server-managed content (Guides, Checklists, Templates, Appointments) and a Remote Config. The codebase is modern and thoughtfully structured (design tokens, layered backend, Dockerized deploy, Alembic migrations, CI lint/test), but several areas remain MVP-level: authentication is a demo admin token, backend sync/async split is inconsistent, tests are minimal, and infra automation is basic. With focused work on auth, data-model integrity, async consistency, testing, observability, and a few design-system refinements, the system can reach enterprise-grade quality.

---

## 1) System Overview

- **Purpose**: Provide curated, localized guidance for newcomers to Switzerland, with interactive checklists, templates generation, appointments, a service map, and feature flags via remote config.
- **Architecture**: Monorepo containing:
  - `sweezy/` SwiftUI iOS app (design system, features, localization, theming, onboarding).
  - `backend/` FastAPI app with routers → services → schemas → models, PostgreSQL via SQLAlchemy 2.x, Alembic, Dockerfile, GitHub CI, Render deployment.
- **Data flow**:
  - App retrieves `remote-config` for flags and version. Content endpoints exist for guides/checklists/templates/appointments; current app still uses local content heavily with ongoing migration to API.
  - State via SwiftUI `EnvironmentObject`s (`AppContainer`, `LocalizationService`, `ThemeManager`, `AppLockManager`).
  - Backend uses Pydantic v2 schemas; CRUD services commit to DB via SQLAlchemy, JWT for admin-only mutating operations.
- **Maturity**:
  - Frontend UI kit and navigation are mature; localization and theming are in place. Some duplication (legacy/new screens) and uneven use of new design components.
  - Backend layering, Sentry, Alembic, Docker exist; auth is prototype; migrations/testing/observability need deepening; async consistency needs work.

---

## 2) Frontend Architecture Audit (SwiftUI)

### Framework & Structure
- SwiftUI app with modular folders: Features (Home, Guides, Checklists, Templates, Map, Appointments, Onboarding), DesignSystem (Theme, tokens, reusable components), Core services (Localization, Theme, DeepLink, RemoteConfig), and Resources (localization).
- Navigation via `NavigationStack`. Theming via `ThemeManager` (System/Light/Dark) with tokens in `Theme.swift`.

### State Management
- Lightweight state through `EnvironmentObject` containers and local `@State`/`@AppStorage`. No heavy global store; suitable for app size. Consider isolating feature-specific view models to reduce container coupling as app scales.

### Component System & Tokens
- `Theme.swift` defines colors, spacing, typography, shadows, animations; good readability and reuse.
- Reusable components (`GlassCard`, `SectionHeader`, `PastelCard`, `TagChip`, `InteractiveCard`, etc.). Dark-mode adjustments recently added to avoid high contrast.
- Recommendation: extract tokens to a single `Theme.Tokens` namespace and generate from a Figma source of truth to avoid drift.

### Routing, Performance
- Screens are independent and use lazy stacks where appropriate. Large lists use `LazyVStack`. Consider image caching for news/cards and prefetch for guide details.

### Code Quality & Consistency
- Naming clear; cohesive files. Some duplication and legacy variants exist: `HomeView` and `HomeViewRedesigned`, two onboarding variants; unify and remove deprecated paths.
- Localization: multiple `.strings` files with a few duplicate keys; add linting script for keys consistency.

### UI/UX
- Visual language is consistent: Apple × OpenAI × GoIT aesthetic; micro-interactions on cards and hero sections; onboarding upgraded with theme picker.
- Accessibility: fonts and contrast mostly good; continue to add `accessibilityLabel`/`Hint` to tappables and support Dynamic Type scaling.
- Internationalization: `LocalizationService` and `Bundle` switching implemented; ensure pluralization rules and right-to-left readiness.

### Build & Optimization
- iOS target builds locally; no Fastlane automations detected. Add:
  - Fastlane lanes for test/build/archive/TestFlight.
  - SwiftLint/SwiftFormat and Danger for PR linting.
  - Snapshot/UI tests (XCUITest) for critical flows.

### Frontend Recommendations
- Merge legacy/new screens; enforce a single home/onboarding path.
- Add SwiftLint/SwiftFormat; add unit and UI tests (Guides list render, RemoteConfig fetch, Quick Actions navigation).
- Introduce image caching (e.g., `AsyncImage` with custom cache) and prefetch policies.
- Add localization key checker; centralize tokens from a design source (Figma → JSON → `Theme.swift`).

---

## 3) Backend Architecture Audit (FastAPI)

### Stack & Structure
- FastAPI, SQLAlchemy 2.x, Alembic, Pydantic v2, psycopg2, python-jose, passlib, Sentry.
- Clean layering: routers → services → schemas → models → core (`config`, `database`, `security`), `dependencies.py`.
- Endpoints: `/guides`, `/checklists`, `/templates`, `/appointments`, `/remote-config`, `/auth/token`.

### Strengths
- Clear separation of concerns; Pydantic v2 models; Sentry integration; Dockerization; Alembic configured; OpenAPI generator script.

### Key Gaps & Risks
1) **Async consistency**
   - An async engine exists in `backend/app/database.py`, but current routers/services/dependencies use the sync engine in `core/database.py`. This mismatch can cause blocking under load.
   - Action: migrate to async end-to-end: `create_async_engine`, `async_sessionmaker`, `async def` routers/services with `await` queries; update dependencies and Alembic env to use sync driver only for migrations.

2) **Auth & Security**
   - Demo admin via env vars, no users table, no refresh tokens, no password rotation, no RBAC.
   - CORS currently wide-open (`*`).
   - Action: implement proper user model + OAuth2 password or Magic Link; add refresh tokens/rotation, token TTL, rate limiting (e.g., SlowAPI), scope-based authorization, configurable CORS.

3) **Database Design**
   - Models use string UUID PKs (OK) with timestamps; guide `slug` unique — good.
   - Missing explicit indexes (e.g., `created_at`, `updated_at`, `status`, `category`), and foreign keys if relationships added later.
   - Action: add indexes, constraints, and data validations; version content (`version` is present in guides but unused in flow).

4) **API Design & Versioning**
   - No version prefix (e.g., `/api/v1`), mixed endpoints without pagination on list routes.
   - Action: add `/api/v1` router prefix, standard pagination (limit/offset with max caps), filtering & ordering, consistent error envelopes.

5) **Observability & Logging**
   - Sentry is in place; structured logging is minimal; no metrics.
   - Action: add `structlog`/`loguru`, request/response logging with correlation IDs, Prometheus metrics (via `prometheus-fastapi-instrumentator`), health/ready endpoints, and slow-query logging.

6) **Background Jobs**
   - Background loop placeholder exists; no job runner (Celery/RQ/APScheduler) for periodic syncs (e.g., cache warm, content refresh).
   - Action: introduce APScheduler or a worker (Celery + Redis) if future processing required.

7) **Testing & CI**
   - Minimal pytest (health only). CI runs ruff + pytest; no coverage gate, no integration tests.
   - Action: add service tests (CRUD for each entity), schema/validator tests, auth tests, OpenAPI regression test; set coverage threshold (e.g., 80%).

8) **Docker & Deploy**
   - Single-stage image; alembic conditional run; `uvicorn` single process.
   - Action: multi-stage build, non-root user, `--workers` via gunicorn/uvicorn workers in production, healthcheck, proper alembic invocation in entrypoint, pinned dependency versions.

### Concrete Recommendations per Layer
- Core/Config: enforce strong defaults; disallow `*` CORS in prod; read secrets from environment and support secret stores.
- Security: rotate secrets, use Argon2 for hashing or strong bcrypt; add refresh token + blacklist; enable 2FA for admin if any panel.
- Services/DB: switch to async ORM calls; wrap tx with retries; add `SELECT FOR UPDATE` where appropriate; add indices.
- Routers: add `/api/v1`; validate payload sizes; add rate limits on mutating endpoints; emit audit logs.
- Migrations: generate initial schema migration; configure offline/online Alembic; document migration workflow.

---

## 4) Design & UX System Audit

- **Consistency**: Tokens are coherent (colors/spacing/typography); components share visual DNA (glass, gradients, pixel pattern). Nice onboarding with theme picker.
- **Scalability**: Tokens live in `Theme.swift`—centralized; recommend extracting to a structured token map and generating code for multi-platform parity.
- **A11y**: Mostly good contrast; continue testing under reduced motion / larger text; add VoiceOver labels for all tappables (cards, chips, tiles).
- **Brand & Tone**: Friendly and modern; ensure consistent use of gradients and blur in dark mode to avoid excessive contrast.
- **Missing Patterns**: Comprehensive empty/error states across all lists, skeleton placeholders for all top-level screens, consistent badge system.
- **Documentation**: Create a Figma library synchronized with tokens; document component usage and motion principles; add a design changelog.

---

## 5) Infrastructure & DevOps

### Dockerization
- Present and functional, but not optimized. Use multi-stage builds with builder cache, non-root user, and pinned Python base image digest. Provide a `HEALTHCHECK` and a deterministic entrypoint that runs migrations then app.

### Environment & Secrets
- `.env.example` exists. On Render, ensure secrets via dashboard, not baked into image. Add schema validation for env vars at boot.

### Deployment
- Manual deploy to Render is workable for staging; for production, configure GitHub Actions to build image, push to registry, and trigger deploy; add blue/green or canary strategy if feasible.

### CI/CD
- Current CI: ruff + pytest minimal. Expand to matrix for Python versions, run MyPy, bandit, trivy scan for image, and Swift lint/tests for iOS.

### Monitoring & DR
- Sentry integrated; add metrics (Prometheus), uptime checks, log aggregation (e.g., Loki/ELK), daily DB backups with retention; document restore runbook.

---

## 6) Production Readiness Checklist

| Area | Current Status | Risk Level | What’s Missing for Production |
|------|----------------|-----------|-------------------------------|
| Frontend | Modern SwiftUI app, tokens, localization, redesigned onboarding | Medium | Remove legacy dupes, add SwiftLint/Format, UI tests, image caching, localization key linting |
| Backend | Layered FastAPI, Sentry, Alembic, Docker | High | Async consistency, real auth (users + refresh), API versioning, pagination, logging/metrics, tests, indices |
| Database | Basic tables with UUID PKs, timestamps | Medium | Indexes, constraints, seed strategy via migrations, migration workflow docs |
| Auth / Security | Demo admin JWT via env | High | Users, password/2FA, refresh tokens, RBAC/scopes, rate limiting, strict CORS, secret rotation |
| Observability | Sentry only | Medium | Structured logs, request IDs, Prometheus metrics, dashboards, slow query logging |
| Design System | Strong tokens/components | Low | Token generation pipeline, a11y audit, design docs, empty/error state patterns |
| CI/CD | Basic lint/test workflow | Medium | Coverage gates, type/security scans, Docker build & vulnerability scan, deploy pipeline, Fastlane for iOS |

---

## 7) Strategic Recommendations

### Roadmap to Production (8–10 weeks)
1. **Security & Auth (Week 1–2)**: Implement users, OAuth2 password with refresh tokens, scopes; lock down CORS; add rate limiting; secret rotation.
2. **Async & DB (Week 2–3)**: Migrate backend to fully async; add indexes; initial Alembic migration; backfill seeds via migrations; add `/api/v1` and pagination.
3. **Observability (Week 3)**: structlog + request ID middleware; Prometheus metrics; Grafana dashboards; slow query and error budgets.
4. **Testing (Week 3–5)**: Backend unit/integration tests to ≥80% coverage; contract tests vs OpenAPI; iOS unit + XCUITests for critical journeys.
5. **Design System & UX (Week 4–5)**: Finalize tokens; Figma → code pipeline; empty/error/skeleton states; a11y pass; performance polish.
6. **CI/CD & Infra (Week 5–6)**: Multi-stage Docker; trivy/bandit scans; GitHub Actions build/test/deploy; Fastlane/TestFlight for iOS.
7. **Content & Feature Parity (Week 6–8)**: Replace remaining local JSON usage with API; add caching layer if needed; finalize RemoteConfig rollout strategy.

### Quick Wins (this week)
- Prefix API with `/api/v1` and add pagination to list routes.
- Lock CORS in production env; rotate JWT secret.
- Add health (`/health`) and ready (`/ready`) endpoints returning DB connectivity.
- Introduce SwiftLint/SwiftFormat and a localization key consistency script.
- Multi-stage Docker and non-root user; add `HEALTHCHECK`.

### Deep Refactors
- Full async migration, auth overhaul, and observability stack.
- Consolidate legacy/new screens and rationalize component library.

### Technical Debt
- Sync/async split; demo auth; sparse tests; duplicate localization keys; duplicated Home/Onboarding views.

---

## ✅ What’s Done / 🧩 What’s Missing / 🚀 What To Do Next

- ✅ Modern SwiftUI design system; localization; onboarding with theme picker; FastAPI with layered architecture; Alembic; Docker; Sentry; CI skeleton.
- 🧩 Missing: robust auth, async consistency, pagination/versioning, structured logs & metrics, comprehensive tests, hardened Docker/CI, content parity in app.
- 🚀 Next: ship auth + async + observability, lock down security, finish API integration in app, add tests and CI/CD; then iterate on performance and a11y.


