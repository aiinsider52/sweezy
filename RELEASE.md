# Release Guide

Current App Store build posture: **free, fully unlocked, no In‑App Purchases**.
Do not declare IAP products in App Store Connect until StoreKit is re‑enabled in the app.

1) App Store Connect
- Create app "Sweezy", bundle id matches Xcode target
- Do **not** add IAP SKUs for this build (`sweezy.pro.monthly` / `sweezy.pro.yearly` are deferred)
- Fill App Privacy from `PrivacyInfo.xcprivacy` (no tracking; email, crash diagnostics, optional analytics, optional coarse location)
- Privacy Policy URL: `https://<api-host>/legal/privacy`
- Support URL: `https://<api-host>/support`
- Terms URL: `https://<api-host>/legal/terms`

2) Secrets
- Add `SENTRY_DSN` and `AMPLITUDE_API_KEY` to Info.plist or .xcconfig

3) Icons
- Place icon set in `Assets.xcassets/AppIcon.appiconset/` (1024 and iOS sizes)

4) Screenshots & Metadata
- Edit fastlane/metadata (en-US, uk). Add screenshots to `fastlane/metadata/<lang>/screenshots/`
- Generate screenshots locally (Xcode, Simulator) or use fastlane snapshot

5) Build & Upload
```bash
bundle exec fastlane metadata   # upload metadata only
bundle exec fastlane upload     # build & upload to TestFlight
```

6) QA
- Run GitHub Actions CI; ensure tests pass
- Test TestFlight build on devices
- Confirm experts/events never expose raw `contact_value` on public endpoints

7) Release
- Promote build to App Store after review
