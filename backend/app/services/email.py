"""
Transactional email helper backed by Resend.

If Resend is not configured, emails degrade gracefully to stdout logging so
local development and tests keep working without a real email provider.
"""

from __future__ import annotations

import html

import httpx

from ..core.config import get_settings


RESEND_API_URL = "https://api.resend.com/emails"


def _from_address() -> str:
    settings = get_settings()
    from_email = settings.RESEND_FROM_EMAIL or settings.SMTP_FROM or settings.SMTP_USERNAME or "no-reply@sweezy.app"
    from_name = (settings.RESEND_FROM_NAME or "").strip()
    if from_name:
        return f"{from_name} <{from_email}>"
    return from_email


def _send_email(to_email: str, *, subject: str, text_body: str, html_body: str | None = None) -> None:
    settings = get_settings()
    api_key = settings.RESEND_API_KEY
    if not api_key or not settings.RESEND_FROM_EMAIL:
        print(f"📧 [DEV] Email to {to_email}")
        print(f"📧 [DEV] Subject: {subject}")
        print(f"📧 [DEV] Body:\n{text_body}")
        return

    payload: dict[str, object] = {
        "from": _from_address(),
        "to": [to_email],
        "subject": subject,
        "text": text_body,
    }
    if html_body:
        payload["html"] = html_body

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    try:
        with httpx.Client(timeout=10) as client:
            response = client.post(RESEND_API_URL, headers=headers, json=payload)
            response.raise_for_status()
    except Exception as exc:
        print(f"⚠️ Failed to send email to {to_email}: {exc}")


def _code_email_html(*, heading: str, intro: str, code: str, expires_minutes: int, footer: str) -> str:
    escaped_heading = html.escape(heading)
    escaped_intro = html.escape(intro)
    escaped_code = html.escape(code)
    escaped_footer = html.escape(footer)
    return (
        "<div style=\"font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;"
        "background:#f6f7f9;padding:32px;color:#111827;\">"
        "<div style=\"max-width:520px;margin:0 auto;background:#ffffff;border-radius:18px;"
        "padding:32px;border:1px solid #e5e7eb;\">"
        f"<h1 style=\"margin:0 0 12px;font-size:24px;\">{escaped_heading}</h1>"
        f"<p style=\"margin:0 0 20px;font-size:15px;line-height:1.6;\">{escaped_intro}</p>"
        "<div style=\"margin:24px 0;padding:18px;border-radius:16px;background:#f0fdf4;"
        "border:1px solid #bbf7d0;text-align:center;\">"
        f"<div style=\"font-size:32px;font-weight:700;letter-spacing:8px;\">{escaped_code}</div>"
        "</div>"
        f"<p style=\"margin:0 0 16px;font-size:14px;color:#4b5563;\">Код дійсний {expires_minutes} хвилин.</p>"
        f"<p style=\"margin:0;font-size:13px;color:#6b7280;line-height:1.6;\">{escaped_footer}</p>"
        "</div></div>"
    )


def send_verification_code_email(to_email: str, code: str, expires_minutes: int) -> None:
    subject = "Sweezy - Підтвердження електронної пошти"
    text_body = (
        "Вітаємо в Sweezy.\n\n"
        "Введіть цей код у додатку, щоб підтвердити електронну пошту:\n"
        f"{code}\n\n"
        f"Код дійсний {expires_minutes} хвилин.\n\n"
        "Якщо ви не створювали акаунт у Sweezy, просто проігноруйте цей лист.\n"
    )
    html_body = _code_email_html(
        heading="Підтвердьте вашу пошту",
        intro="Введіть цей код у додатку Sweezy, щоб завершити реєстрацію.",
        code=code,
        expires_minutes=expires_minutes,
        footer="Якщо ви не створювали акаунт у Sweezy, просто проігноруйте цей лист.",
    )
    _send_email(to_email, subject=subject, text_body=text_body, html_body=html_body)


def send_password_reset_code_email(to_email: str, code: str, expires_minutes: int) -> None:
    subject = "Sweezy - Відновлення пароля"
    text_body = (
        "Ви запросили відновлення пароля для акаунта Sweezy.\n\n"
        "Введіть цей код у додатку, щоб встановити новий пароль:\n"
        f"{code}\n\n"
        f"Код дійсний {expires_minutes} хвилин.\n\n"
        "Якщо ви не запитували зміну пароля, просто проігноруйте цей лист.\n"
    )
    html_body = _code_email_html(
        heading="Код для відновлення пароля",
        intro="Введіть цей код у додатку Sweezy, щоб встановити новий пароль.",
        code=code,
        expires_minutes=expires_minutes,
        footer="Якщо ви не запитували зміну пароля, просто проігноруйте цей лист.",
    )
    _send_email(to_email, subject=subject, text_body=text_body, html_body=html_body)

