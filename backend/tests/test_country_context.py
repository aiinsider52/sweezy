from __future__ import annotations

import uuid

from fastapi.testclient import TestClient

from backend.app.core.database import SessionLocal
from backend.app.core.security import create_access_token
from backend.app.main import app
from backend.app.services.users import UserService


client = TestClient(app)


def _user_headers() -> dict[str, str]:
    with SessionLocal() as db:
        user = UserService.create(
            db,
            email=f"country_{uuid.uuid4().hex}@example.com",
            password="StrongPass1!",
            role="user",
            email_verified=True,
        )
        token = create_access_token(subject=user.id, is_admin=False, role=user.role)
    return {"Authorization": f"Bearer {token}"}


def test_country_catalog_exposes_supported_markets() -> None:
    response = client.get("/api/v1/country-context/catalog")
    assert response.status_code == 200

    countries = {item["code"]: item for item in response.json()["countries"]}
    assert set(countries) == {"CH", "DE", "AT"}
    assert countries["CH"]["currency_code"] == "CHF"
    assert countries["DE"]["currency_code"] == "EUR"
    assert countries["AT"]["timezone"] == "Europe/Vienna"
    assert "DE-BE" in countries["DE"]["subdivisions"]
    assert "AT-9" in countries["AT"]["subdivisions"]


def test_country_pack_official_hosts_are_trusted() -> None:
    from backend.app.services.official_sources import is_trusted_official_url

    assert is_trusted_official_url("https://www.germany4ukraine.de/EN/startseite_node.html")
    assert is_trusted_official_url("https://www.make-it-in-germany.com/en/")
    assert is_trusted_official_url("https://www.oesterreich.gv.at/en/themen.html")
    assert is_trusted_official_url("https://www.ams.at/arbeitsuchende")
    assert is_trusted_official_url("https://www.bbu.gv.at/ukraine")
    assert not is_trusted_official_url("https://example.com/fake-official-guide")


def test_country_context_switch_keeps_history_and_one_active_context() -> None:
    headers = _user_headers()

    germany = client.put(
        "/api/v1/country-context/me/DE",
        headers=headers,
        json={
            "country_code": "DE",
            "subdivision_code": "BE",
            "city": "Berlin",
            "residence_status": "temporary_protection_24",
            "preferred_language": "uk",
            "is_active": True,
        },
    )
    assert germany.status_code == 200, germany.text
    assert germany.json()["subdivision_code"] == "DE-BE"
    assert germany.json()["currency_code"] == "EUR"
    assert germany.json()["timezone"] == "Europe/Berlin"

    austria = client.put(
        "/api/v1/country-context/me/AT",
        headers=headers,
        json={
            "country_code": "AT",
            "subdivision_code": "9",
            "city": "Wien",
            "residence_status": "displaced_person",
            "preferred_language": "de",
            "is_active": True,
        },
    )
    assert austria.status_code == 200, austria.text
    assert austria.json()["subdivision_code"] == "AT-9"

    active = client.get("/api/v1/country-context/me/active", headers=headers)
    assert active.status_code == 200
    assert active.json()["country_code"] == "AT"

    contexts = client.get("/api/v1/country-context/me", headers=headers)
    assert contexts.status_code == 200
    by_country = {item["country_code"]: item for item in contexts.json()}
    assert set(by_country) == {"DE", "AT"}
    assert by_country["AT"]["is_active"] is True
    assert by_country["DE"]["is_active"] is False


def test_country_context_rejects_cross_country_values() -> None:
    headers = _user_headers()

    wrong_subdivision = client.put(
        "/api/v1/country-context/me/DE",
        headers=headers,
        json={"country_code": "DE", "subdivision_code": "AT-9"},
    )
    assert wrong_subdivision.status_code == 422

    wrong_currency = client.put(
        "/api/v1/country-context/me/AT",
        headers=headers,
        json={"country_code": "AT", "subdivision_code": "AT-9", "currency_code": "CHF"},
    )
    assert wrong_currency.status_code == 422

    mismatch = client.put(
        "/api/v1/country-context/me/CH",
        headers=headers,
        json={"country_code": "DE", "subdivision_code": "DE-BE"},
    )
    assert mismatch.status_code == 409


def test_marketplace_country_filter_prevents_cross_market_leakage() -> None:
    headers = _user_headers()

    created = client.post(
        "/api/v1/marketplace/",
        headers=headers,
        json={
            "listing_type": "service",
            "title": "Berlin relocation support",
            "description": "Verified local help for registration and residence paperwork.",
            "category": "documents",
            "country_code": "DE",
            "subdivision_code": "DE-BE",
            "price_minor": 8000,
            "currency_code": "EUR",
            "contact_type": "email",
            "contact_value": "helper@example.com",
            "author_name": "Berlin Helper",
            "image_urls": [],
        },
    )
    assert created.status_code == 201, created.text
    listing_id = created.json()["id"]

    with SessionLocal() as db:
        from backend.app.models.marketplace import ServiceListing

        listing = db.get(ServiceListing, listing_id)
        listing.status = "approved"
        db.add(listing)
        db.commit()

    germany = client.get("/api/v1/marketplace/?country_code=DE")
    switzerland = client.get("/api/v1/marketplace/?country_code=CH")
    assert listing_id in {item["id"] for item in germany.json()["items"]}
    assert listing_id not in {item["id"] for item in switzerland.json()["items"]}


def test_country_content_packs_seed_once_and_keep_markets_separate() -> None:
    from backend.app.models.checklist import Checklist
    from backend.app.models.guide import Guide
    from backend.app.models.template import Template
    from backend.app.services.content_seed import _seed_country_packs

    with SessionLocal() as db:
        first = _seed_country_packs(db)
        second = _seed_country_packs(db)

        assert first == {
            "country_guides": 20,
            "country_checklists": 8,
            "country_templates": 8,
        }
        assert second == {
            "country_guides": 0,
            "country_checklists": 0,
            "country_templates": 0,
        }

        assert db.query(Guide).filter(Guide.country_code == "DE").count() == 10
        assert db.query(Guide).filter(Guide.country_code == "AT").count() == 10
        assert db.query(Checklist).filter(Checklist.country_code == "DE").count() == 4
        assert db.query(Checklist).filter(Checklist.country_code == "AT").count() == 4
        assert db.query(Template).filter(Template.country_code == "DE").count() == 4
        assert db.query(Template).filter(Template.country_code == "AT").count() == 4

        germany_sources = {
            row.source_url
            for row in db.query(Guide).filter(Guide.country_code == "DE").all()
        }
        austria_sources = {
            row.source_url
            for row in db.query(Guide).filter(Guide.country_code == "AT").all()
        }
        assert all(url and url.startswith("https://") for url in germany_sources)
        assert all(url and url.startswith("https://") for url in austria_sources)
