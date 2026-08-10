# Sweezy Plus — App Store Connect setup

## Subscription group

- Reference name: `Sweezy Plus`
- Type: Auto-Renewable Subscription

## Products expected by app

| Plan | Product ID | Duration | Suggested Switzerland price |
|---|---|---|---|
| Monthly | `sweezy_plus_monthly` | 1 month | 4.95 CHF |
| Yearly | `sweezy_plus_yearly` | 1 year | 49.50 CHF |

Product IDs must match exactly. App loads localized price and currency from StoreKit.

## App Store Connect checklist

1. Accept Paid Apps Agreement, then complete banking and tax forms.
2. Create one subscription group named `Sweezy Plus`.
3. Add both products above with exact IDs and durations.
4. Add Ukrainian, English, and German display names/descriptions.
5. Configure price tiers and availability.
6. Add a 1-month introductory free trial to monthly plan. App only shows trial copy when StoreKit returns an active introductory offer.
7. Add review screenshot showing paywall and review notes explaining where Plus is opened.
8. Submit first subscription products together with app version.
9. Test purchase, cancel, renewal, expiration, and Restore Purchases with Sandbox/TestFlight accounts.

## Before production launch

- Run database migration `alembic upgrade head` during backend deploy.
- Set backend environment:
  - `APPLE_IAP_ENABLED=true`
  - `APPLE_IAP_BUNDLE_ID=com.sweezy.mobile`
  - `APPLE_IAP_APP_APPLE_ID=<numeric App Store app ID>`
  - `APPLE_IAP_PRODUCT_IDS=sweezy_plus_monthly,sweezy_plus_yearly`
  - `APPLE_IAP_ALLOW_SANDBOX=true` while testing; switch to `false` after Sandbox/TestFlight verification if desired.
  - `APPLE_IAP_ENABLE_ONLINE_CHECKS=true`
  - `APPLE_IAP_ROOT_CERTIFICATES_BASE64=<comma-separated base64 DER Apple root certificates>`
  - `STRIPE_SUBSCRIPTIONS_ENABLED=false` for iOS digital subscriptions.
- Download required Apple root certificates from Apple PKI. Convert each DER file with `base64 < certificate.cer | tr -d '\n'`; join values with commas. Never commit certificates or secrets.
- Configure App Store Server Notifications V2 production and sandbox URL:
  `https://sweezy-9xyk.onrender.com/api/v1/subscriptions/apple/notifications`
- Deploy backend, confirm migration `0031_apple_subscriptions` applied, then test authenticated transaction sync:
  `POST /api/v1/subscriptions/apple/transactions`.
- Confirm purchased user changes to `trial` or `premium` in `GET /api/v1/subscriptions/entitlements`.
- Confirm direct fourth free call to CV Improve/Translate returns HTTP 402; active Apple subscriber receives HTTP 200.
- Update Terms and Privacy URLs in App Store Connect.
- Never unlock Plus from client flags or payment callback without verified Apple transaction.

## Production acceptance tests

1. New monthly purchase with 1-month introductory offer.
2. Existing subscriber purchase without second trial.
3. Restore Purchases after reinstall and after login on another device.
4. Renewal, expiration, billing retry/grace period, refund/revocation, upgrade/downgrade.
5. Notification replay returns success without duplicate entitlement changes.
6. Purchase cannot be linked to a second Sweezy account.
7. Ask Sweezy and job application return 402 for free users and work for verified subscribers.
8. CV Improve/Translate enforce shared three-use quota on backend, not only device.

Backend verifies StoreKit transaction JWS and Notifications V2 with Apple's official server library. App sends `appAccountToken` equal to authenticated Sweezy user UUID, binding original Apple transaction to one account.
