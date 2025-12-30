from __future__ import annotations

"""
Lightweight email helper for transactional messages (e.g. password reset).

If SMTP settings are not configured, the functions degrade gracefully by
printing the email contents to stdout. This keeps local development simple
while allowing real email delivery in staging/production once SMTP_* env vars
are set.
"""

from email.message import EmailMessage
import smtplib
from typing import Optional

from ..core.config import get_settings


def _build_smtp_client() -> Optional[smtplib.SMTP]:
    """
    Create an SMTP client using settings, or return None when SMTP is disabled.
    """
    settings = get_settings()
    if not settings.SMTP_HOST:
        # SMTP is not configured – caller should fall back to logging only.
        return None

    host = settings.SMTP_HOST
    port = settings.SMTP_PORT or 587
    client = smtplib.SMTP(host, port, timeout=10)
    try:
        # Use STARTTLS by default; most providers require it.
        client.starttls()
    except Exception:
        # If STARTTLS fails, continue without TLS to avoid hard failure in
        # misconfigured dev environments. In production, SMTP should be set up
        # correctly.
        pass

    if settings.SMTP_USERNAME and settings.SMTP_PASSWORD:
        try:
            client.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
        except Exception:
            # Authentication failure – let caller decide how to handle.
            client.quit()
            raise

    return client


def send_password_reset_email(to_email: str, token: str) -> None:
    """
    Send a password reset email with a short-lived token.

    The email contains:
      - The raw reset token (so user can paste it into the app)
      - A mobile deep-link that the app can handle: sweezy://auth/password/reset
    """
    settings = get_settings()

    # Deep link that the iOS app can handle via DeepLinkService.
    reset_deep_link = f"sweezy://auth/password/reset?token={token}"

    subject = "Sweezy – Відновлення паролю"
    body = (
        "Ви запросили відновлення паролю для свого акаунта Sweezy.\n\n"
        "Ваш код для відновлення:\n"
        f"{token}\n\n"
        "Скопіюйте цей код у додатку Sweezy в екрані \"Забули пароль?\" "
        "та введіть новий пароль.\n\n"
        "Якщо додаток встановлено, можна також спробувати відкрити це посилання:\n"
        f"{reset_deep_link}\n\n"
        "Якщо ви не запитували зміну паролю — просто проігноруйте цей лист.\n"
    )

    from_addr = settings.SMTP_FROM or settings.SMTP_USERNAME or "no-reply@sweezy.app"

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = from_addr
    msg["To"] = to_email
    msg.set_content(body)

    try:
        client = _build_smtp_client()
        if client is None:
            # Development fallback: log token to stdout.
            print(f"📧 [DEV] Password reset email to {to_email}")
            print(f"📧 [DEV] Token: {token}")
            print(f"📧 [DEV] Deep link: {reset_deep_link}")
            return

        with client:
            client.send_message(msg)
    except Exception as exc:
        # Never crash the API because of email issues; just log for debugging.
        print(f"⚠️ Failed to send password reset email to {to_email}: {exc}")


