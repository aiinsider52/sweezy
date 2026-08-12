# TestFlight & device smoke checklist

## 0) Prerequisites

- [ ] Apple Developer account access for team owning `com.sweezy.mobile`
- [ ] App Store Connect app created; bundle id matches Xcode
- [ ] Signing: Release APS environment = production
- [ ] API live: https://sweezy-9xyk.onrender.com/ready → `ready`
- [ ] Privacy/Terms/Support URLs open
- [ ] Optional: APNs secrets on Render → then set `PUSH_NOTIFICATIONS_ENABLED=true`

## 1) Local verification (before upload)

```bash
# Unit + UI tests (adjust simulator name/OS to installed runtimes)
xcodebuild \
  -scheme sweezy \
  -project sweezy/sweezy.xcodeproj \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test

# Or via fastlane (after `bundle install`)
bundle exec fastlane tests
```

- [ ] `xcodebuild test` / `fastlane tests` green
- [ ] App language switch uk → en → de updates Journey tab labels
- [ ] Directory / Market empty states are honest (no fake “124 experts”)
- [ ] Experts list does not expose emails/phones
- [ ] Account deletion path visible in Settings

## 2) Capture App Store screenshots

Required folders:

- `fastlane/metadata/en-US/screenshots/`
- `fastlane/metadata/uk/screenshots/`
- `fastlane/metadata/de-DE/screenshots/`

Capture at least 3–6 frames per locale on a 6.7" device (or simulator):

1. Home (Journey)
2. Directory with guides
3. Map
4. Marketplace
5. Settings / language

Helper:

```bash
./scripts/capture-journey-screenshots.sh
```

## 3) Upload to TestFlight

```bash
bundle install
# Configure fastlane/Appfile with apple_id / team_id / itc_team_id
bundle exec fastlane upload
# Metadata only:
bundle exec fastlane metadata
```

- [ ] Build appears in TestFlight
- [ ] Internal testers can install

## 4) Device smoke (two phones recommended for chat)

| # | Flow | Pass? |
|---|------|-------|
| 1 | Cold launch → Journey tabs load | |
| 2 | Sign up / Sign in | |
| 3 | Open guide + checklist | |
| 4 | Map search + pin focus from City Hub | |
| 5 | Market listings + create listing (pending moderation) | |
| 6 | Experts → Ask question | |
| 7 | Chat: two users, message, unread badge | |
| 8 | Language uk/en/de | |
| 9 | Delete account | |
| 10 | Background app → receive chat push → deep link opens exact conversation | |
| 11 | Universal links open guide, checklist, template, map filter, place, CV, profile, privacy, language and What's New | |
| 12 | Light mode: Directory and Marketplace search, filters, empty/loading states remain readable | |
| 13 | Job search: change query quickly; older response never replaces latest results | |
| 14 | Large external image (>12 MB or >8192 px) is rejected without memory spike/crash | |

## Subscription release gate

Local StoreKit tests cover product contract, purchase, restore, forced renewal,
billing grace period and refund. Before every App Store release, repeat these
flows through Sandbox/TestFlight on a real device because local StoreKit tests
do not validate App Store Connect configuration, Apple server delivery or the
production receipt chain.

- [ ] Monthly product shows localized `4.95 CHF` and one-month free trial
- [ ] New purchase updates backend entitlement for signed-in Sweezy account
- [ ] Restore after reinstall and sign-in restores same account entitlement
- [ ] Renewal keeps Plus; expiration removes Plus
- [ ] Billing retry + enabled grace period keeps Plus until grace ends
- [ ] Refund/revocation removes Plus after Server Notification V2 delivery
- [ ] Notification replay is idempotent
- [ ] Second Sweezy account cannot claim same original Apple transaction
- [ ] Ask Sweezy, job application and CV API enforce backend entitlement

## 5) ASC submit readiness

- [ ] Screenshots uploaded for en-US (+ uk/de if shipping those storefronts)
- [ ] App Privacy filled from `docs/asc-app-privacy-answers.md`
- [ ] Review notes describe Sweezy Plus, free trial, restore path and account binding
- [ ] Export compliance / encryption answers completed
- [ ] Age rating completed
