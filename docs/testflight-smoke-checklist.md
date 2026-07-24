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
| 10 | (If push on) background app → receive chat push → deep link | |

## 5) ASC submit readiness

- [ ] Screenshots uploaded for en-US (+ uk/de if shipping those storefronts)
- [ ] App Privacy filled from `docs/asc-app-privacy-answers.md`
- [ ] Review notes say free / no IAP
- [ ] Export compliance / encryption answers completed
- [ ] Age rating completed
