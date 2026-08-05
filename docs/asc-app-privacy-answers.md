# App Store Connect — App Privacy answers

Fill ASC **App Privacy** to match `sweezy/sweezy/Resources/PrivacyInfo.xcprivacy` and the live privacy page.

**Privacy Policy URL:** https://sweezy-9xyk.onrender.com/legal/privacy  
**Tracking:** No (`NSPrivacyTracking = false`)

## Data collected

| Data type | Linked to user? | Used for tracking? | Purposes | Notes |
|-----------|-----------------|--------------------|----------|-------|
| Email Address | Yes | No | App Functionality | Account login / recovery |
| Crash Data | No | No | App Functionality | Sentry diagnostics |
| Product Interaction | No | No | Analytics | Optional first-party product analytics using pseudonymous install/session IDs |
| Coarse Location | No | No | App Functionality | Optional, when user grants permission for nearby map |

## Not collected (declare “No” unless product changes)

- Precise Location
- Contacts / Photos / Files (beyond user-chosen calendar add)
- Payment Info / Purchase History (this build has **no IAP**)
- Advertising Data / Device ID for ads
- Health / Financial / Sensitive Info beyond account email

## Third-party partners (disclose in ASC if asked)

- Sentry — crash/diagnostics
- SWEEEZY backend — optional first-party analytics (opt-in; no advertising identifiers)
- Resend — transactional email
- Apple — Sign in with Apple (if enabled)
- Google — Sign in with Google (if enabled)

## Checklist before submit

- [ ] ASC App Privacy matches this table
- [ ] Privacy / Terms / Support URLs open in Safari
- [ ] `PrivacyInfo.xcprivacy` shipped in the binary
- [ ] Review notes state **free / no IAP**
