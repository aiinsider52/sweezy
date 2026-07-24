# Marketplace chat production runbook

## Runtime contract

- PostgreSQL is the source of truth for conversations, messages, read state, reports, reviews, devices, and the push outbox.
- Redis is mandatory in production. It distributes WebSocket events across backend instances; startup fails if it is unavailable.
- APNs is independently feature-flagged. Chat and realtime can run while push notifications are disabled. Notification text is private by default and does not include message content.
- External seller contact values are not returned by the public marketplace API. Communication stays inside the reportable and blockable chat flow.

## Required Render variables

Set these on the backend service without committing secrets:

```text
CHAT_ENABLED=true
REDIS_URL=<Render Key Value internal URL>
CHAT_REDIS_CHANNEL=sweezy:chat:events
PUSH_NOTIFICATIONS_ENABLED=false
APNS_KEY_ID=<Apple key id>
APNS_TEAM_ID=<Apple team id>
APNS_PRIVATE_KEY=<contents of AuthKey_*.p8, newlines may be encoded as \\n>
APNS_BUNDLE_ID=com.sweezy.mobile
PUSH_SHOW_MESSAGE_PREVIEW=false
CHAT_OUTBOX_RETENTION_DAYS=30
PUSH_REVOKED_RETENTION_DAYS=30
```

Deploy the backend only after the Render PostgreSQL backup policy is enabled and migration `0025_production_chat` is visible at `alembic current`.

`render.yaml` keeps the API, admin, and Redis Key Value on **starter** (always-on) plans in the same region so chat WebSockets and the push outbox worker do not die from free-tier spin-down.

Production deploy order:

1. Back up PostgreSQL and verify point-in-time recovery is enabled.
2. Keep `PUSH_NOTIFICATIONS_ENABLED=false` until valid APNs credentials are configured. Never store APNs or JWT secrets in Git.
3. Sync `render.yaml` and confirm the Key Value internal URL populates `REDIS_URL`.
4. Deploy backend. Render runs migration `0025_production_chat` and
   `backend/scripts/production_preflight.py` before traffic switches.
5. Deploy admin after backend `/ready` returns 200.
6. When APNs `.p8` secrets are set, enable push via dashboard or `./scripts/enable-apns-push.sh`, then redeploy.

## Release checks

1. Use two verified non-admin accounts and one approved service or item.
2. Start the conversation as buyer; verify seller receives WebSocket delivery while online.
3. Background the seller app; verify one APNs notification and deep-link into the exact conversation.
4. Send with the same `client_message_id` twice; verify only one message exists.
5. Mark the conversation read and verify unread count reaches zero on inbox and app badge.
6. Block the seller; verify neither participant can send and the conversation disappears from the active inbox.
7. Report a received message; verify only the bounded context appears in **Admin > Chat Safety**.
8. Close the deal as seller; verify the listing is no longer public and each participant can leave one review.
9. Log out; verify the stored push device is revoked and no notification for the old account reaches the device.

## Monitoring and alerts

Scrape `/metrics` and alert on:

- `sweezy_chat_push_deliveries_total{outcome="retryable_failure"}` increasing for 10 minutes;
- any `permanent_failure` spike above normal token churn;
- zero successful pushes while messages continue increasing;
- WebSocket reconnect or HTTP 5xx spikes on `/api/v1/chat/*`;
- oldest pending `notification_outbox.next_attempt_at` lagging by more than five minutes.

Useful product counters are `sweezy_chat_conversations_created_total`, `sweezy_chat_messages_sent_total`, `sweezy_chat_deals_closed_total`, `sweezy_chat_reviews_created_total`, and `sweezy_chat_safety_actions_total`.

## Incident controls

- Set `CHAT_ENABLED=false` and redeploy to disable chat workers and realtime during an incident.
- Keep the API and iOS feature release coordinated. Do not ship the iOS CTA before migration, Redis, APNs, and admin moderation are live.
- Rotate an exposed APNs key in Apple Developer, update Render, then redeploy. Never log the private key or device tokens.
