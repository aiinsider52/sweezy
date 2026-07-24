# Screenshot capture notes

Folders are ready:

- `fastlane/metadata/en-US/screenshots/`
- `fastlane/metadata/uk/screenshots/`
- `fastlane/metadata/de-DE/screenshots/`

ASC expects device-sized PNGs (e.g. 6.7" iPhone). Capture from Simulator:

```bash
# Boot iPhone 17 Pro (or 16 Pro Max), run the app, navigate to each tab:
open -a Simulator
./scripts/capture-journey-screenshots.sh en-US
./scripts/capture-journey-screenshots.sh uk
./scripts/capture-journey-screenshots.sh de-DE
```

Required frames (min 3): Home, Directory, Map, Market, Settings — once per locale after switching language in Settings.

Until real PNGs are added, metadata upload should use `skip_screenshots: true` or deliver will fail on empty folders.
