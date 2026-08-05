# Incident alerting

Operational failures are deduplicated in the `incidents` table and shown at
`/admin/incidents`. Telegram delivery is best-effort: a Telegram outage never
changes an API response.

## Configuration

- `INCIDENTS_ENABLED`: persist and process incidents (default `true`).
- `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`: Telegram Bot API destination.
- `INCIDENT_ALERT_DEDUPE_SECONDS`: minimum notification interval per fingerprint.
- `INCIDENT_ALERT_MAX_CHARS`: maximum outbound Telegram message length.
- `INCIDENT_TELEGRAM_TIMEOUT_SECONDS`: bounded network timeout.
- `INCIDENT_CRITICAL_TELEMETRY_TYPES`: comma-separated client event allowlist.

Messages and context are redacted for credentials, authorization headers, tokens,
email addresses, cookies, and passwords. Do not intentionally submit customer
data in incident context.

## Operations

Administrators can resolve or reopen incidents and send a protected test alert
from the incidents page. The test endpoint is limited to two requests per hour.
Hooks cover unhandled/returned HTTP 5xx responses, readiness failures,
transactional email failures, unexpected admin-auth processing failures, and
allowlisted critical telemetry.
