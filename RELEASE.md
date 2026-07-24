# Release Guide

Current App Store build posture: **free, fully unlocked, no In‑App Purchases**.
Do not declare IAP products in App Store Connect until StoreKit is re‑enabled in the app.

## Backend / chat reliability

- `render.yaml`: API + admin + Redis Key Value on **starter** (always-on), same `oregon` region
- Chat Redis listener auto-resubscribes with backoff (`backend/app/services/chat_realtime.py`)
- Keep `PUSH_NOTIFICATIONS_ENABLED=false` until APNs `.p8` secrets are set, then:
  - `./scripts/enable-apns-push.sh` (checks secrets) → flip flag → redeploy
  - Device QA: `docs/chat-production-runbook.md`

## App Store Connect

1. Create app "Sweezy", bundle id `com.sweezy.mobile`
2. Do **not** add IAP SKUs for this build
3. Fill App Privacy from `docs/asc-app-privacy-answers.md` + `PrivacyInfo.xcprivacy`
4. URLs (also in `fastlane/metadata/`):
   - Privacy: https://sweezy-9xyk.onrender.com/legal/privacy
   - Terms: https://sweezy-9xyk.onrender.com/legal/terms
   - Support: https://sweezy-9xyk.onrender.com/support
5. Screenshots: `./scripts/capture-journey-screenshots.sh` → `fastlane/metadata/<locale>/screenshots/`
6. Review notes: `fastlane/metadata/review_information/notes.txt` (states free / no IAP)

## Secrets (iOS)

- Add `SENTRY_DSN` and `AMPLITUDE_API_KEY` to Info.plist / xcconfig
- Configure `fastlane/Appfile` (or `FASTLANE_USER` / team env vars)

## Build & upload

```bash
bundle install
bundle exec fastlane tests
bundle exec fastlane upload          # binary → TestFlight
bundle exec fastlane deliver_metadata
```

Full device matrix: `docs/testflight-smoke-checklist.md`

## QA before submit

- [ ] Journey language switch uk/en/de
- [ ] Guides/checklists load from API
- [ ] Experts/events never leak `contact_value` publicly
- [ ] Account deletion path works
- [ ] Chat WS on two devices (push optional until APNs live)
