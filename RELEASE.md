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
   - Privacy: https://sweezy-api.onrender.com/legal/privacy
   - Terms: https://sweezy-api.onrender.com/legal/terms
   - Support: https://sweezy-api.onrender.com/support
5. Screenshots: `./scripts/capture-journey-screenshots.sh` → `fastlane/metadata/<locale>/screenshots/`
6. Review notes: `fastlane/metadata/review_information/notes.txt` (states free / no IAP)

## Business accounts (In‑App Purchases)

Business pages, the directory, bookings and reviews are free. Paid placement uses three products
in a separate subscription group **Sweezy Business**:

| Product ID | Type | Effect |
|---|---|---|
| `sweezy_business_pro_monthly` | Auto‑renewable, 1 month | Plan **Pro**: higher ranking, 20 services, 5 offers, 90‑day insights, documents |
| `sweezy_business_max_monthly` | Auto‑renewable, 1 month | Plan **Business**: top ranking, AI receptionist, team of 10, 50 services, 20 offers |
| `sweezy_business_boost_7d` | Consumable | 7 days at the top of directory, map and guide tips, labelled «Реклама/Anzeige» |

Backend must verify purchases server-side, otherwise `/business/plan/apple` answers 503:
`APPLE_IAP_ENABLED=true`, `APPLE_IAP_APP_APPLE_ID`, `APPLE_IAP_ROOT_CERTIFICATES_BASE64`
(product IDs default to the table above via `APPLE_IAP_BUSINESS_PRODUCT_IDS`).
Set the App Store Server Notifications V2 URL to `https://sweezy-api.onrender.com/api/v1/subscriptions/apple/notifications`
so renewals, refunds and expirations reach the business plan.

Launch partners can get a free plan without a purchase: admin → Businesses → *Launch plan grant*.

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
