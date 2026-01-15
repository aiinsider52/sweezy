from fastapi import APIRouter, Response
from fastapi.responses import HTMLResponse, PlainTextResponse, RedirectResponse

router = APIRouter(tags=["public"])

PRIVACY_HTML = """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <title>Sweezy — Privacy Policy</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 24px; line-height: 1.6; color: #0c0c15; background: #ffffff; }
      .wrap { max-width: 860px; margin: 0 auto; }
      h1 { font-size: 28px; margin: 0 0 8px; }
      h2 { font-size: 20px; margin-top: 28px; }
      .muted { color: #6b7280; }
      a { color: #0ea5a4; text-decoration: none; }
      a:hover { text-decoration: underline; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <h1>Sweezy — Privacy Policy</h1>
      <p class="muted">Last updated: 3 Dec 2025</p>
      <p>Sweezy respects your privacy. This policy explains what data we collect and how we use it.</p>
      <h2>Data We Collect</h2>
      <ul>
        <li>Account data you provide (name, email) to enable core features.</li>
        <li>Content you choose to store (checklists, preferences) to personalize your experience.</li>
        <li>Diagnostic and performance data (crash reports, anonymized telemetry) to improve app stability.</li>
        <li>Approximate location for map features when you grant permission. You can disable it at any time in iOS Settings.</li>
      </ul>
      <h2>How We Use Data</h2>
      <ul>
        <li>To provide and improve Sweezy’s functionality.</li>
        <li>To communicate important updates and respond to support requests.</li>
        <li>To maintain security and prevent abuse.</li>
      </ul>
      <h2>Data Sharing</h2>
      <p>We do not sell your data. Limited third-party processors may be used to provide infrastructure (e.g., hosting, analytics, crash reporting) under GDPR-compliant agreements.</p>
      <h2>Your Rights</h2>
      <p>You can request data export or deletion by contacting <a href="mailto:support@sweezy.app">support@sweezy.app</a>.</p>
      <h2>Contact</h2>
      <p>Email: <a href="mailto:support@sweezy.app">support@sweezy.app</a></p>
    </div>
  </body>
  </html>
"""

TERMS_HTML = """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <title>Sweezy — Terms of Use</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 24px; line-height: 1.6; color: #0c0c15; background: #ffffff; }
      .wrap { max-width: 860px; margin: 0 auto; }
      h1 { font-size: 28px; margin: 0 0 8px; }
      h2 { font-size: 20px; margin-top: 28px; }
      .muted { color: #6b7280; }
      a { color: #0ea5a4; text-decoration: none; }
      a:hover { text-decoration: underline; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <h1>Sweezy — Terms of Use</h1>
      <p class="muted">Last updated: 3 Dec 2025</p>
      <p>By using Sweezy, you agree to these Terms of Use.</p>
      <h2>License</h2>
      <p>We grant you a personal, non-transferable, non-exclusive license to use the app in accordance with these terms and Apple’s App Store policies.</p>
      <h2>Content</h2>
      <p>Guides, checklists and templates are educational. We do not provide legal advice. You are responsible for how you use the information in the app.</p>
      <h2>Subscriptions</h2>
      <p>Some features may require a subscription. Apple manages billing. You can cancel anytime in App Store settings.</p>
      <h2>Liability</h2>
      <p>The app is provided “as is”. To the maximum extent permitted by law, we are not liable for indirect or consequential damages.</p>
      <h2>Contact</h2>
      <p>Email: <a href="mailto:support@sweezy.app">support@sweezy.app</a></p>
    </div>
  </body>
  </html>
"""

SUPPORT_HTML = """
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <title>Sweezy — Support</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 24px; line-height: 1.6; color: #0c0c15; background: #ffffff; }
      .wrap { max-width: 860px; margin: 0 auto; }
      h1 { font-size: 28px; margin: 0 0 8px; }
      .muted { color: #6b7280; }
      a { color: #0ea5a4; text-decoration: none; }
      a:hover { text-decoration: underline; }
      .card { background: #f8fafc; border: 1px solid #e5e7eb; border-radius: 12px; padding: 16px; margin-top: 16px; }
      code { background: #f3f4f6; padding: 2px 6px; border-radius: 6px; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <h1>Sweezy — Support</h1>
      <p class="muted">We usually reply within 24 hours.</p>
      <div class="card">
        <strong>Email</strong><br/>
        <a href="mailto:support@sweezy.app">support@sweezy.app</a>
      </div>
      <div class="card">
        <strong>Version</strong><br/>
        If contacting us about a bug, please include the app version and steps to reproduce. You can find the version in Settings → About.
      </div>
    </div>
  </body>
  </html>
"""


@router.get("/legal/privacy", response_class=HTMLResponse)
async def privacy_policy() -> HTMLResponse:
    return HTMLResponse(content=PRIVACY_HTML)


@router.get("/legal/terms", response_class=HTMLResponse)
async def terms_of_use() -> HTMLResponse:
    return HTMLResponse(content=TERMS_HTML)


@router.get("/support", response_class=HTMLResponse)
async def support_page() -> HTMLResponse:
    return HTMLResponse(content=SUPPORT_HTML)


