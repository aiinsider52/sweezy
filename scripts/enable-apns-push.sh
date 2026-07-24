#!/usr/bin/env bash
# Flip chat push on only after APNs secrets exist on the Render service.
# Usage:
#   RENDER_API_KEY=... RENDER_SERVICE_ID=srv-... ./scripts/enable-apns-push.sh
# Or rely on the Render dashboard: set APNS_* then set PUSH_NOTIFICATIONS_ENABLED=true.
set -euo pipefail

: "${RENDER_API_KEY:?Set RENDER_API_KEY}"
: "${RENDER_SERVICE_ID:?Set RENDER_SERVICE_ID (sweezy API service)}"

missing=0
for key in APNS_KEY_ID APNS_TEAM_ID APNS_PRIVATE_KEY; do
  code="$(curl -sS -o /tmp/render-env.json -w '%{http_code}' \
    -H "Authorization: Bearer $RENDER_API_KEY" \
    "https://api.render.com/v1/services/$RENDER_SERVICE_ID/env-vars/$key" || true)"
  if [[ "$code" != "200" ]]; then
    echo "Missing or inaccessible env var: $key (HTTP $code)" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Create an APNs Auth Key (.p8) in Apple Developer, set APNS_* on Render, then re-run." >&2
  exit 1
fi

echo "APNs secrets look present. Set PUSH_NOTIFICATIONS_ENABLED=true in the Render dashboard (or Blueprint) and redeploy."
echo "Then verify with docs/chat-production-runbook.md release checks (background app → one push)."
