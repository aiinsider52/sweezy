from __future__ import annotations

import hashlib
import secrets
import re
from typing import Any

from sqlalchemy.orm import Session

from ..models.marketplace import ServiceListing
from .users import UserService
from ..core.logging import get_logger


log = get_logger(module="marketplace_author_repair")


def _seller_email(author_name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", (author_name or "seller").lower()).strip("-")[:40] or "seller"
    digest = hashlib.sha256(author_name.encode("utf-8")).hexdigest()[:10]
    return f"seller+{slug}-{digest}@marketplace.sweezy.internal"


def repair_orphan_listing_authors(db: Session) -> dict[str, Any]:
    """Attach approved marketplace listings without author_id to synthetic seller accounts.

    Seeded/demo listings often have a display name but no owning user, which breaks chat
    (`POST /chat/conversations` requires listing.author_id). This repair is idempotent.
    """
    orphans = (
        db.query(ServiceListing)
        .filter(ServiceListing.author_id.is_(None))
        .filter(ServiceListing.status == "approved")
        .all()
    )
    if not orphans:
        return {"repaired": 0, "sellers_created": 0}

    sellers_created = 0
    repaired = 0
    cache: dict[str, str] = {}

    for listing in orphans:
        name = (listing.author_name or "Sweezy Seller").strip() or "Sweezy Seller"
        if name in cache:
            user_id = cache[name]
        else:
            email = _seller_email(name)
            existing = UserService.get_by_email(db, email)
            if existing is None:
                user = UserService.create(
                    db,
                    email=email,
                    password=secrets.token_urlsafe(24),
                    role="user",
                    email_verified=True,
                )
                sellers_created += 1
                user_id = user.id
            else:
                user_id = existing.id
            cache[name] = user_id

        listing.author_id = user_id
        db.add(listing)
        repaired += 1

    db.commit()
    log.info("orphan_listing_authors_repaired", repaired=repaired, sellers_created=sellers_created)
    return {"repaired": repaired, "sellers_created": sellers_created}
