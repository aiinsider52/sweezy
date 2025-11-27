# Release Guide

1) App Store Connect
- Create app "Sweezy", bundle id matches Xcode target
- Add In‑App Purchases: `sweezy.pro.monthly`, `sweezy.pro.yearly`
- Fill App Privacy based on PrivacyInfo.xcprivacy (no tracking)

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

7) Release
- Promote build to App Store after review


