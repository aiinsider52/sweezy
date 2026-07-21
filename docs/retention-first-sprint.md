# Sweezy Retention First Sprint

## Product Loop

The current sprint turns Sweezy into a guided assistant instead of a static content library:

1. Onboarding captures canton, permit, arrival date, language, and family context.
2. `FirstWeekChecklistService` generates first-week tasks from that profile.
3. `RoadmapService` seeds the starting roadmap level from arrival timing and family/work context.
4. Home shows one next-best action: checklist first, roadmap second.
5. Notifications schedule first-week deadlines and a soft re-engagement reminder.
6. Telemetry records whether users see, tap, and complete the loop.

## Content Source Audit

| Surface | Current source | Notes |
| --- | --- | --- |
| Guides | Remote API first via `APIClient.fetchGuides()`, then bundled JSON/cache fallback | Bundled seed files remain important for offline and cold-start reliability. |
| Checklists | Remote API first via `APIClient.fetchChecklists()`, then localized/bundled JSON/cache fallback | First-week checklist is locally generated from onboarding profile. |
| News | Remote API first via `APIClient.fetchNews()`, then bundled/cache fallback | Good candidate for weekly editorial retention. |
| Templates | Remote API first via `APIClient.fetchTemplates()`, then bundled/cache fallback | Useful for CV/documents activation. |
| Places / Map | Bundled JSON + extra seed files | No backend sync yet; keep offline-first. |
| Benefits rules | Bundled localized JSON + cache fallback | Needs legal/compliance review before prominent Home placement. |
| Marketplace / Events | Backend API | Main practical value and partner monetization surface. |
| Jobs | Backend API + local cache | Strong retention candidate through saved searches and alerts. |

## Marketplace Trust Model

Trust is now explicit in listing data:

- `community`: approved community listing.
- `verified`: moderator has checked identity/content quality.
- `partner`: featured partner listing with optional partner label.

Admin moderation can approve listings with verification, featured placement, partner label, and moderation notes. iOS displays verified/partner badges and backend sorts approved public listings by featured, then verified, then newest.

## Retention Telemetry Events

Events are defined in `TelemetryService.RetentionEvent`:

- `retention_onboarding_profile_saved`
- `retention_roadmap_seeded`
- `retention_next_action_viewed`
- `retention_next_action_tapped`
- `retention_roadmap_task_completed`
- `retention_content_opened`
- `retention_first_week_reminder_scheduled`
- `retention_marketplace_listing_viewed`
- `retention_marketplace_contact_tapped`
- `retention_job_search_performed`
- `retention_notification_permission_updated`

Primary dashboards should start with next-action views/taps, roadmap task completion, notification opt-in, marketplace views/contact taps, and job searches.

## First Sprint Breakdown

### iOS

- Seed roadmap progress from onboarding profile.
- Schedule first-week and re-engagement reminders after onboarding.
- Log Home next-action views/taps and roadmap task completion.
- Show verified/partner trust badges in marketplace listing cards and detail hero.

### Backend

- Add marketplace trust fields and migration.
- Return trust metadata to public and admin listing responses.
- Sort public approved listings by featured, verified, newest.
- Accept trust metadata during admin listing approval.

### Admin

- Let moderators mark approved listings as verified or featured.
- Capture optional partner label and moderation notes.
- Show trust counts, badges, and notes in moderation.

### Next Sprint Candidates

- Saved job search alerts.
- Marketplace contact telemetry from iOS taps.
- Home “Aktualno this week” editorial module from admin/news.
- Remote-config schema validation in admin before publishing flags.
