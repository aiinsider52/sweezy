# Germany and Austria rollout runbook

Last reviewed: 2026-08-25

## Scope

Supported residence markets: Switzerland (`CH`), Germany (`DE`), Austria (`AT`). Country context owns subdivision, residence status, currency, locale, and timezone. Guides, checklists, templates, jobs, marketplace, events, professional network, friends, and business listings are country-scoped. Switching country keeps history and activates one context.

Germany and Austria content is informational, not legal advice. Every legal or administrative guide must keep official `source_url`, `verified_at`, and, when known, `valid_until`.

## Safe production order

1. Create PostgreSQL backup and record current backend release SHA.
2. Deploy backend build containing additive schema support. Keep mobile clients on current production version.
3. Run `alembic upgrade 0041` from `backend/`.
4. Restart backend. Startup seed adds deterministic DE/AT content rows once.
5. Verify health, catalog, content isolation, and authenticated country switching.
6. Upload iOS build. Release only to Germany closed TestFlight group first.
7. Open Austria group after Germany acceptance gates pass.

Do not run a schema downgrade during normal rollback. Migration is additive; old backend can ignore new columns. Restore backup only after confirmed data corruption.

## Production smoke checks

Use production base URL and test account token. Never place credentials in shell history or this file.

```bash
curl -fsS "$API_BASE/api/v1/health"
curl -fsS "$API_BASE/api/v1/country-context/catalog"
curl -fsS "$API_BASE/api/v1/guides?country_code=DE&language=uk"
curl -fsS "$API_BASE/api/v1/guides?country_code=AT&language=uk"
curl -fsS "$API_BASE/api/v1/marketplace/?country_code=DE"
curl -fsS "$API_BASE/api/v1/jobs/?country_code=AT"
```

Authenticated switch:

```bash
curl -fsS -X PUT \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -H "Content-Type: application/json" \
  "$API_BASE/api/v1/country-context/me/DE" \
  -d '{"country_code":"DE","subdivision_code":"DE-BE","city":"Berlin","residence_status":"temporary_protection_24","preferred_language":"uk","is_active":true}'
```

Required results:

- catalog contains exactly `CH`, `DE`, `AT` with correct currency/timezone;
- DE query never returns CH/AT content or community rows;
- AT query never returns CH/DE content or community rows;
- switch persists after relaunch and one context remains active;
- Germany map opens Berlin regional seeds; Austria map opens Vienna regional seeds;
- empty, offline, loading, and API-error states remain usable;
- country switch invalidates country-scoped caches.

## Germany closed beta

Create external TestFlight group `Germany Closed Beta`. Add only invited testers residing in multiple German federal states. Keep Austria testers out until Germany gates pass. Minimum useful cohort: 30 activated testers, including new and existing CH users switching country.

Test scenarios:

1. Fresh install → DE → federal state → §24 or another status → dashboard.
2. Existing CH account → switch to DE → relaunch → data remains DE.
3. DE guides/checklists/templates show official source and verification date.
4. Jobs, marketplace, events, network, and map contain no CH/AT leakage.
5. Create listing/event/profile in DE; verify invisible under CH and AT filters.
6. Offline launch after DE content loaded.
7. VoiceOver, Dynamic Type, small iPhone, and German text expansion.
8. Delete account and export/privacy flows remain reachable.

## Acceptance gates

- crash-free sessions at least 99.5%;
- onboarding completion at least 80%;
- country-switch success at least 99%;
- zero confirmed cross-country data leakage;
- content/API error rate below 1%;
- no P0/P1 accessibility, privacy, auth, or data-integrity issue;
- every published DE legal/admin guide has reachable official HTTPS source;
- support owner approves top reported wording and content issues.

Metrics must be segmented by `country_code`, app version, fresh install vs switch, and subdivision where sample size protects privacy. Never collect residence status, exact location, or free text as analytics properties.

## Austria expansion

After Germany gates pass: enable `Austria Closed Beta`, repeat same scenarios with `AT-1...AT-9`, Vienna registration, displaced-person status, AMS jobs, EUR formatting, and Vienna timezone. Austria launch requires separate content-owner sign-off; German approval does not cover Austrian legal wording.

## Rollback

1. Stop new TestFlight invitations and distribution for affected country.
2. Publish in-app/support status message if users are affected.
3. Roll back mobile build through TestFlight group control or ship fixed build.
4. Roll back backend code to recorded SHA. Leave additive `0041` schema in place.
5. Disable or unpublish faulty country content rows; do not delete user contexts.
6. Re-run CH smoke tests before declaring recovery.
7. Restore database backup only for verified corruption, with incident owner approval.

## Content operations

- Review DE/AT official-source links every 30 days and before each release.
- Re-verify immediately after residence-policy, benefits, registration, or employment-law changes.
- Expired `valid_until` content must not be presented as current.
- Keep editorial change log: country, content ID, source, reviewer, review date, summary.
- Product/legal owner decides final wording. Engineering tests provenance and isolation, not legal correctness.

