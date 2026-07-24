"""Idempotent seed for the canonical Swiss "moments" calendar.

Called from app startup so that production gets the default set of windows
(KK switching, tax season, school registration, end-of-year deductions, …)
without manual intervention. Existing rows (matched by `key`) are not
overwritten — admins can safely tune them through the admin UI.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Iterable

from sqlalchemy.orm import Session

from ..models.swiss_moment import SwissMoment


def _utc(year: int, month: int, day: int) -> datetime:
    return datetime(year, month, day, tzinfo=timezone.utc)


def _default_moments(year: int) -> Iterable[dict]:
    """Yield seed dicts for the upcoming/current cycle."""
    return [
        {
            "key": "kk_switching",
            "title": "Krankenkasse switching window",
            "description_md": (
                "Each year you can switch your basic health insurance (Grundversicherung) "
                "until **30 November**. New premiums are announced end of September. "
                "Compare on Priminfo or Comparis and send a registered letter (Einschreiben)."
            ),
            "starts_at": _utc(year, 9, 25),
            "ends_at": _utc(year, 11, 30),
            "recurrence": "yearly",
            "audience_filters": {},
            "cta_kind": "calculator",
            "cta_payload": {"tool": "kk_switcher"},
            "priority": 90,
        },
        {
            "key": "tax_season_b",
            "title": "Tax declaration window (Mar–Apr)",
            "description_md": (
                "Standard cantonal tax declaration runs **1 March – 30 April**. "
                "Many cantons grant extensions on request. Collect Lohnausweis, "
                "3a contributions, healthcare deductions in advance."
            ),
            "starts_at": _utc(year, 3, 1),
            "ends_at": _utc(year, 4, 30),
            "recurrence": "yearly",
            "audience_filters": {"min_tenure_months": 3},
            "cta_kind": "checklist",
            "cta_payload": {"tool": "tax_hub"},
            "priority": 80,
        },
        {
            "key": "quellensteuer_recalc",
            "title": "Quellensteuer recalculation request",
            "description_md": (
                "If you are taxed at source (B/L permit, income < CHF 120k), you can request "
                "a **Neuveranlagung** until 31 March to claim deductions (3a, transport, etc)."
            ),
            "starts_at": _utc(year, 1, 15),
            "ends_at": _utc(year, 3, 31),
            "recurrence": "yearly",
            "audience_filters": {"permits": ["B", "L"]},
            "cta_kind": "link",
            "cta_payload": {"url": "https://www.estv.admin.ch/estv/en/home.html"},
            "priority": 60,
        },
        {
            "key": "school_registration",
            "title": "School registration window",
            "description_md": (
                "Most cantons collect school registrations in **March–April** for the August start. "
                "Contact your Schulamt / Service des écoles."
            ),
            "starts_at": _utc(year, 3, 1),
            "ends_at": _utc(year, 4, 30),
            "recurrence": "yearly",
            "audience_filters": {"has_children": True},
            "cta_kind": "checklist",
            "cta_payload": {"tool": "school_registration"},
            "priority": 70,
        },
        {
            "key": "end_of_year_deductions",
            "title": "End-of-year deductions checklist",
            "description_md": (
                "**Pillar 3a**, additional pension purchases (Einkauf), donations and "
                "training expenses must be paid before 31 December to count for this tax year."
            ),
            "starts_at": _utc(year, 11, 1),
            "ends_at": _utc(year, 12, 31),
            "recurrence": "yearly",
            "audience_filters": {"min_tenure_months": 6},
            "cta_kind": "checklist",
            "cta_payload": {"tool": "end_of_year"},
            "priority": 65,
        },
        {
            "key": "c_permit_eligibility",
            "title": "C permit eligibility window",
            "description_md": (
                "After **5–10 years** of B permit (depending on nationality and integration) "
                "you may be eligible to apply for a C permit (Niederlassungsbewilligung)."
            ),
            "starts_at": _utc(year, 1, 1),
            "ends_at": _utc(year, 12, 31),
            "recurrence": "yearly",
            "audience_filters": {"permits": ["B"], "min_tenure_months": 60},
            "cta_kind": "link",
            "cta_payload": {"url": "https://www.sem.admin.ch/sem/en/home.html"},
            "priority": 40,
        },
    ]


def seed_swiss_moments(db: Session) -> int:
    """Insert default moments for the current calendar year (idempotent).

    Returns the number of newly created rows. Updating existing rows is left
    to the admin to avoid clobbering manual tuning.
    """
    year = datetime.utcnow().year
    inserted = 0
    for spec in _default_moments(year):
        existing = db.query(SwissMoment).filter(SwissMoment.key == spec["key"]).first()
        if existing:
            continue
        moment = SwissMoment(
            key=spec["key"],
            title=spec["title"],
            description_md=spec.get("description_md", ""),
            starts_at=spec["starts_at"],
            ends_at=spec["ends_at"],
            recurrence=spec.get("recurrence", "yearly"),
            audience_filters=spec.get("audience_filters", {}),
            cta_kind=spec.get("cta_kind", "link"),
            cta_payload=spec.get("cta_payload", {}),
            priority=spec.get("priority", 0),
            is_active=True,
        )
        db.add(moment)
        inserted += 1
    if inserted:
        db.commit()
    return inserted
