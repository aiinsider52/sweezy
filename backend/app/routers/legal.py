from __future__ import annotations

from fastapi import APIRouter
from fastapi.responses import HTMLResponse


router = APIRouter()


@router.get("/legal/privacy", include_in_schema=False)
def privacy_policy() -> HTMLResponse:
    # Minimal public privacy policy page (used for App Store Connect "Privacy Policy URL").
    html = """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Sweezy – Privacy Policy</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; margin: 32px; line-height: 1.5; max-width: 860px; }
      h1,h2 { line-height: 1.2; }
      code { background: #f6f8fa; padding: 2px 6px; border-radius: 6px; }
      .muted { color: #666; }
      a { color: #0b5fff; }
    </style>
  </head>
  <body>
    <h1>Sweezy – Privacy Policy</h1>
    <p class="muted">Last updated: 2026‑01‑14</p>

    <h2>What we collect</h2>
    <ul>
      <li><strong>Account data</strong>: email (for login), subscription status (if applicable).</li>
      <li><strong>Diagnostics</strong>: crash reports and basic performance data to improve stability (e.g. Sentry).</li>
      <li><strong>Usage analytics</strong>: optional, privacy‑friendly product analytics to improve features (e.g. Amplitude).</li>
      <li><strong>Location</strong>: optional coarse location for nearby services (only when you grant permission).</li>
    </ul>

    <h2>What we do not do</h2>
    <ul>
      <li>We do not sell personal data.</li>
      <li>We do not use advertising tracking.</li>
      <li>We do not track you across other companies' apps and websites.</li>
    </ul>

    <h2>Account deletion</h2>
    <p>
      You can delete your account in the app: <code>Settings → Data Management → Delete Account</code>.
    </p>

    <h2>Contact</h2>
    <p>If you have questions about privacy, contact us at <a href="mailto:support@sweezy.app">support@sweezy.app</a>.</p>
  </body>
</html>
"""
    return HTMLResponse(content=html, status_code=200)


@router.get("/legal/terms", include_in_schema=False)
def terms_of_use() -> HTMLResponse:
    html = """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Sweezy – Terms of Use</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; margin: 32px; line-height: 1.5; max-width: 860px; }
      h1,h2 { line-height: 1.2; }
      .muted { color: #666; }
      a { color: #0b5fff; }
    </style>
  </head>
  <body>
    <h1>Sweezy – Terms of Use</h1>
    <p class="muted">Last updated: 2026‑01‑14</p>
    <p>
      By using Sweezy, you agree to use the app responsibly and comply with applicable laws.
      Content is provided for informational purposes and does not constitute legal advice.
    </p>
    <h2>Subscriptions</h2>
    <p>
      If you purchase a subscription, it may auto‑renew unless cancelled in your Apple ID settings.
    </p>
    <h2>Contact</h2>
    <p>Support: <a href="mailto:support@sweezy.app">support@sweezy.app</a>.</p>
  </body>
</html>
"""
    return HTMLResponse(content=html, status_code=200)


@router.get("/support", include_in_schema=False)
def support() -> HTMLResponse:
    html = """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Sweezy – Support</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; margin: 32px; line-height: 1.5; max-width: 860px; }
      a { color: #0b5fff; }
    </style>
  </head>
  <body>
    <h1>Sweezy – Support</h1>
    <p>Email: <a href="mailto:support@sweezy.app">support@sweezy.app</a></p>
  </body>
</html>
"""
    return HTMLResponse(content=html, status_code=200)

