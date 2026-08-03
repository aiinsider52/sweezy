# Jobs Copilot production runbook

## Data sources

Jobs are read from PostgreSQL. Client requests never call external providers directly.

Supported adapters:

- Jooble: `JOOBLE_API_KEY`, `JOOBLE_SYNC_QUERIES`, `JOOBLE_SYNC_PAGES`.
- Greenhouse: comma-separated authorized board tokens in `GREENHOUSE_BOARD_TOKENS`.
- Lever: comma-separated authorized site names in `LEVER_SITES`.
- Personio: comma-separated authorized company subdomains in `PERSONIO_COMPANIES`.
- Sweezy employers: business profile, moderated vacancy, direct candidate chat.

Only enable feeds covered by provider terms or employer permission. Do not scrape Jobs.ch, Jobup, LinkedIn, Indeed, or Job-Room.

## Release

1. Add provider credentials in Render dashboard. Never commit keys.
2. Deploy backend. Start command runs `alembic upgrade head` before Uvicorn.
3. Open `/admin/jobs`, run manual sync, and confirm at least one provider reports `healthy` with non-zero items.
4. Search public `/api/v1/jobs/search` with canton and pagination filters.
5. Verify favorite, alert, application tracker, employer moderation, direct chat, report, and push outbox flows with test accounts.
6. Enable APNs only after device-token registration and production certificate checks pass.

## Catalog behavior

- Sync runs every `JOBS_SYNC_INTERVAL_SEC` seconds; minimum 300.
- Provider records are upserted by provider ID and deduplicated by canonical URL plus company/title/location fingerprint.
- Jobs missing longer than `JOBS_STALE_AFTER_HOURS` are expired; minimum 24 hours.
- Empty or failed provider responses never replace healthy catalog data.
- Search runs against PostgreSQL and reports `ready`, `stale`, `empty`, or `source_unavailable`.
- Provider errors are visible only in admin source health.

## Monitoring

Alert when:

- enabled provider has two consecutive failures;
- last successful sync is older than twice configured interval;
- active catalog drops by more than 30% in one sync;
- pending employer vacancies or unresolved reports exceed moderation SLA;
- push outbox failures increase;
- search returns `source_unavailable`.

Metrics to track: active jobs by source/canton, sync duration, inserted/updated/expired counts, searches with zero results, alert delivery, match method, saves, applications, interviews, offers, employer response time.

## Recovery

- Provider outage: keep current catalog, mark provider degraded, investigate credentials/rate limits, retry manual sync.
- Bad import: disable affected provider env value, close rows from that source through admin/SQL review, then resync.
- Migration failure: Render start stops before app boot. Restore latest PostgreSQL backup, fix migration, redeploy. Never downgrade production schema before backup.
- Duplicate or suspicious vacancy: resolve report, close job, block employer if needed, preserve audit data.

## Launch gate

Do not advertise “thousands of jobs” or specific providers until live source-health evidence confirms them. Production launch requires provider permission, non-empty live catalog, Render migration proof, APNs delivery on a physical device, and end-to-end candidate/employer smoke test.
