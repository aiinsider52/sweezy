from __future__ import annotations

import json
import urllib.request

from ..core.config import get_settings
from ..core.logging import get_logger

logger = get_logger(component="telegram_notifier")


def send_telegram_message(text: str) -> bool:
    """Send a bounded, best-effort Telegram message."""
    settings = get_settings()
    if not settings.TELEGRAM_BOT_TOKEN or not settings.TELEGRAM_CHAT_ID:
        return False
    body = json.dumps(
        {"chat_id": settings.TELEGRAM_CHAT_ID, "text": text[: settings.INCIDENT_ALERT_MAX_CHARS]}
    ).encode("utf-8")
    request = urllib.request.Request(
        f"https://api.telegram.org/bot{settings.TELEGRAM_BOT_TOKEN}/sendMessage",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=settings.INCIDENT_TELEGRAM_TIMEOUT_SECONDS):  # nosec B310
            return True
    except Exception as exc:
        logger.warning("telegram_notification_failed", error_type=type(exc).__name__)
        return False
