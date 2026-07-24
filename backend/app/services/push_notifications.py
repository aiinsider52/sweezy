from __future__ import annotations

import asyncio
import json
import time
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx
from jose import jwt
from sqlalchemy import delete, func, or_, select

from ..core.chat_metrics import CHAT_PUSH_DELIVERIES
from ..core.config import get_settings
from ..core.database import SessionLocal
from ..core.logging import get_logger
from ..models.chat import ChatMessage, ChatParticipant, NotificationOutbox, PushDevice


log = get_logger(module="push_notifications")


class APNsClient:
    def __init__(self) -> None:
        self.settings = get_settings()
        self._provider_token: str | None = None
        self._provider_token_at: datetime | None = None
        self._client: httpx.AsyncClient | None = None

    @property
    def configured(self) -> bool:
        return all(
            [
                self.settings.APNS_KEY_ID,
                self.settings.APNS_TEAM_ID,
                self.settings.APNS_PRIVATE_KEY,
                self.settings.APNS_BUNDLE_ID,
            ]
        )

    def _token(self) -> str:
        now = datetime.now(timezone.utc)
        if self._provider_token and self._provider_token_at and now - self._provider_token_at < timedelta(minutes=50):
            return self._provider_token
        private_key = (self.settings.APNS_PRIVATE_KEY or "").replace("\\n", "\n")
        self._provider_token = jwt.encode(
            {"iss": self.settings.APNS_TEAM_ID, "iat": int(now.timestamp())},
            private_key,
            algorithm="ES256",
            headers={"kid": self.settings.APNS_KEY_ID},
        )
        self._provider_token_at = now
        return self._provider_token

    async def send(self, device: PushDevice, payload: dict[str, Any], event_key: str) -> tuple[bool, bool, str | None]:
        host = "https://api.sandbox.push.apple.com" if device.environment == "sandbox" else "https://api.push.apple.com"
        headers = {
            "authorization": f"bearer {self._token()}",
            "apns-topic": str(self.settings.APNS_BUNDLE_ID),
            "apns-push-type": "alert",
            "apns-priority": "10",
            "apns-collapse-id": event_key[:64],
        }
        try:
            if self._client is None:
                self._client = httpx.AsyncClient(http2=True, timeout=10)
            response = await self._client.post(f"{host}/3/device/{device.token}", headers=headers, json=payload)
            if response.status_code == 200:
                CHAT_PUSH_DELIVERIES.labels(outcome="success").inc()
                return True, False, None
            reason = response.text[:400]
            CHAT_PUSH_DELIVERIES.labels(outcome="permanent_failure" if response.status_code in {400, 403, 404, 410} else "retryable_failure").inc()
            return False, response.status_code in {400, 403, 404, 410}, reason
        except Exception as exc:
            CHAT_PUSH_DELIVERIES.labels(outcome="retryable_failure").inc()
            return False, False, str(exc)[:400]

    async def close(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None


apns_client = APNsClient()


def enqueue_chat_push(
    db,
    *,
    message_id: str,
    recipient_id: str,
    conversation_id: str,
    sender_name: str,
    message_preview: str,
) -> None:
    settings = get_settings()
    if not settings.PUSH_NOTIFICATIONS_ENABLED:
        return
    body = message_preview[:120] if settings.PUSH_SHOW_MESSAGE_PREVIEW else "У вас нове повідомлення"
    unread_count = db.scalar(
        select(func.count(ChatMessage.id))
        .select_from(ChatMessage)
        .join(ChatParticipant, ChatParticipant.conversation_id == ChatMessage.conversation_id)
        .where(
            ChatParticipant.user_id == recipient_id,
            ChatParticipant.archived.is_(False),
            ChatParticipant.deleted_at.is_(None),
            ChatMessage.sender_id != recipient_id,
            ChatMessage.deleted_at.is_(None),
            or_(ChatParticipant.last_read_at.is_(None), ChatMessage.created_at > ChatParticipant.last_read_at),
        )
    ) or 0
    payload = {
        "aps": {
            "alert": {"title": sender_name[:80], "body": body},
            "sound": "default",
            "badge": min(unread_count, 999),
            "mutable-content": 1,
        },
        "type": "chat_message",
        "conversation_id": conversation_id,
        "message_id": message_id,
    }
    db.add(
        NotificationOutbox(
            event_key=f"chat:{message_id}",
            recipient_id=recipient_id,
            event_type="chat_message",
            payload_json=json.dumps(payload, ensure_ascii=False),
        )
    )


def _claim_batch() -> list[tuple[str, str, str, list[tuple[str, str]]]]:
    if not apns_client.configured:
        return []
    now = datetime.now(timezone.utc)
    with SessionLocal() as db:
        rows = db.execute(
            select(NotificationOutbox)
            .where(
                NotificationOutbox.next_attempt_at <= now,
                or_(NotificationOutbox.status == "pending", NotificationOutbox.status == "processing"),
                NotificationOutbox.attempts < 6,
            )
            .order_by(NotificationOutbox.created_at)
            .with_for_update(skip_locked=True)
            .limit(25)
        ).scalars().all()
        claimed: list[tuple[str, str, str, list[tuple[str, str]]]] = []
        for row in rows:
            row.status = "processing"
            row.attempts += 1
            row.next_attempt_at = now + timedelta(minutes=5)
            devices = db.execute(
                select(PushDevice).where(
                    PushDevice.user_id == row.recipient_id,
                    PushDevice.enabled.is_(True),
                    PushDevice.revoked_at.is_(None),
                )
            ).scalars().all()
            claimed.append((row.id, row.event_key, row.payload_json, [(d.id, d.token) for d in devices]))
        db.commit()
        return claimed


async def process_notification_outbox() -> int:
    claimed = await asyncio.to_thread(_claim_batch)
    processed = 0
    for row_id, event_key, raw_payload, device_refs in claimed:
        payload = json.loads(raw_payload)
        results: list[tuple[str, bool, bool, str | None]] = []
        with SessionLocal() as db:
            devices = [db.get(PushDevice, device_id) for device_id, _ in device_refs]
            devices = [device for device in devices if device is not None]
        for device in devices:
            ok, permanent, error = await apns_client.send(device, payload, event_key)
            results.append((device.id, ok, permanent, error))

        now = datetime.now(timezone.utc)
        with SessionLocal() as db:
            row = db.get(NotificationOutbox, row_id)
            if not row:
                continue
            for device_id, _, permanent, _ in results:
                if permanent:
                    device = db.get(PushDevice, device_id)
                    if device:
                        device.enabled = False
                        device.revoked_at = now
            successful = any(ok for _, ok, _, _ in results)
            transient_errors = [error for _, ok, permanent, error in results if not ok and not permanent and error]
            if successful or not devices:
                row.status = "processed"
                row.processed_at = now
                row.last_error = None
                processed += 1
            elif row.attempts >= 6 or not transient_errors:
                row.status = "failed"
                row.last_error = "; ".join(error or "APNs rejected device" for _, _, _, error in results)[:500]
            else:
                row.status = "pending"
                row.next_attempt_at = now + timedelta(seconds=min(900, 2 ** row.attempts * 15))
                row.last_error = "; ".join(transient_errors)[:500]
            db.commit()
    return processed


def cleanup_notification_data() -> tuple[int, int]:
    """Remove delivery-only data after its configured retention window."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    outbox_cutoff = now - timedelta(days=settings.CHAT_OUTBOX_RETENTION_DAYS)
    device_cutoff = now - timedelta(days=settings.PUSH_REVOKED_RETENTION_DAYS)
    with SessionLocal() as db:
        outbox_result = db.execute(
            delete(NotificationOutbox).where(
                NotificationOutbox.status.in_(("processed", "failed")),
                NotificationOutbox.created_at < outbox_cutoff,
            )
        )
        device_result = db.execute(
            delete(PushDevice).where(
                PushDevice.enabled.is_(False),
                PushDevice.revoked_at.is_not(None),
                PushDevice.revoked_at < device_cutoff,
            )
        )
        db.commit()
        return int(outbox_result.rowcount or 0), int(device_result.rowcount or 0)


async def notification_worker() -> None:
    last_cleanup = 0.0
    try:
        while True:
            try:
                await process_notification_outbox()
                if time.monotonic() - last_cleanup >= 60 * 60:
                    removed_outbox, removed_devices = await asyncio.to_thread(cleanup_notification_data)
                    last_cleanup = time.monotonic()
                    if removed_outbox or removed_devices:
                        log.info(
                            "chat_notification_cleanup",
                            removed_outbox=removed_outbox,
                            removed_devices=removed_devices,
                        )
            except asyncio.CancelledError:
                raise
            except Exception as exc:
                log.error("push_outbox_failed", error=str(exc))
            await asyncio.sleep(2)
    finally:
        await apns_client.close()
