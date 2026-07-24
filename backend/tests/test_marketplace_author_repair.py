from __future__ import annotations

import uuid

from backend.app.core.database import SessionLocal
from backend.app.models.marketplace import ServiceListing
from backend.app.services.marketplace_author_repair import repair_orphan_listing_authors


def test_repair_orphan_listing_authors_assigns_seller() -> None:
    with SessionLocal() as db:
        listing = ServiceListing(
            id=str(uuid.uuid4()),
            listing_type="service",
            title="Test barber",
            description="A long enough description for validation rules.",
            category="beauty",
            canton="LU",
            contact_type="email",
            contact_value="hidden@example.com",
            author_name="Dana",
            author_id=None,
            status="approved",
            image_urls=[],
        )
        db.add(listing)
        db.commit()
        listing_id = listing.id

        result = repair_orphan_listing_authors(db)
        assert result["repaired"] >= 1

        refreshed = db.get(ServiceListing, listing_id)
        assert refreshed is not None
        assert refreshed.author_id is not None
