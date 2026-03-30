from __future__ import annotations

from datetime import datetime
from typing import Any, Dict
from urllib.parse import urlparse

import httpx
from sqlalchemy.orm import Session

from ..core.config import get_settings
from ..models.brave_news_query import BraveNewsQuery
from ..models.news import News
from .news_service import NewsService


class BraveSearchImporter:
    @staticmethod
    def _freshness_param(days: int) -> str:
        if days <= 1:
            return "pd"
        if days <= 7:
            return "pw"
        if days <= 31:
            return "pm"
        return "py"

    @staticmethod
    def _parse_published_at(raw: str | None) -> datetime:
        if not raw:
            return datetime.utcnow()
        normalized = raw.strip()
        if not normalized:
            return datetime.utcnow()
        try:
            if normalized.endswith("Z"):
                normalized = normalized[:-1] + "+00:00"
            value = datetime.fromisoformat(normalized)
            return value.replace(tzinfo=None) if value.tzinfo else value
        except Exception:
            return datetime.utcnow()

    @staticmethod
    def _summary_for(result: Dict[str, Any]) -> str:
        description = str(result.get("description") or "").strip()
        if description:
            return description
        extra = result.get("extra_snippets") or []
        if isinstance(extra, list):
            for item in extra:
                text = str(item or "").strip()
                if text:
                    return text
        return ""

    @staticmethod
    def _image_for(result: Dict[str, Any]) -> str | None:
        thumbnail = result.get("thumbnail") or {}
        if isinstance(thumbnail, dict):
            for key in ("src", "original", "url"):
                value = thumbnail.get(key)
                if value:
                    return str(value)
        profile = result.get("profile") or {}
        if isinstance(profile, dict):
            image = profile.get("img")
            if image:
                return str(image)
        return None

    @staticmethod
    def _source_for(result: Dict[str, Any], url: str) -> str:
        meta_url = result.get("meta_url") or {}
        if isinstance(meta_url, dict):
            hostname = meta_url.get("hostname")
            if hostname:
                return str(hostname).removeprefix("www.")
        hostname = urlparse(url).hostname or "Brave Search"
        return hostname.removeprefix("www.")

    @staticmethod
    def _fetch_results(query: BraveNewsQuery) -> list[Dict[str, Any]]:
        settings = get_settings()
        if not settings.BRAVE_API_KEY:
            raise RuntimeError("BRAVE_API_KEY is not configured")

        params: Dict[str, Any] = {
            "q": query.query,
            "count": max(1, min(query.max_results, settings.BRAVE_MAX_RESULTS_PER_QUERY)),
            "extra_snippets": "true",
        }
        if query.language:
            params["search_lang"] = query.language
        if query.country:
            params["country"] = query.country
        if query.freshness_days > 0:
            params["freshness"] = BraveSearchImporter._freshness_param(query.freshness_days)

        with httpx.Client(
            timeout=20,
            follow_redirects=True,
            headers={
                "Accept": "application/json",
                "X-Subscription-Token": settings.BRAVE_API_KEY,
                "User-Agent": "SweezyBrave/1.0",
            },
        ) as client:
            response = client.get(settings.BRAVE_SEARCH_BASE_URL, params=params)
            response.raise_for_status()
            payload = response.json()
        results = payload.get("web", {}).get("results", [])
        return results if isinstance(results, list) else []

    @staticmethod
    def import_query(db: Session, query: BraveNewsQuery) -> Dict[str, int]:
        created = updated = skipped = archived = 0
        results = BraveSearchImporter._fetch_results(query)
        if not results:
            query.last_imported_at = datetime.utcnow()
            query.updated_at = datetime.utcnow()
            db.add(query)
            db.commit()
            return {"created": 0, "updated": 0, "skipped": 0, "archived": 0}

        urls_in_latest_batch: set[str] = set()
        for raw in results[: query.max_results]:
            url = str(raw.get("url") or "").strip()
            title = str(raw.get("title") or "").strip()
            if not url or not title:
                skipped += 1
                continue
            urls_in_latest_batch.add(url)

        active_rows = (
            db.query(News)
            .filter(
                News.import_source == "brave",
                News.import_reference_id == query.id,
                News.status != "archived",
            )
            .all()
        )
        for row in active_rows:
            if row.url not in urls_in_latest_batch:
                row.status = "archived"
                row.updated_at = datetime.utcnow()
                db.add(row)
                archived += 1

        for raw in results[: query.max_results]:
            url = str(raw.get("url") or "").strip()
            title = str(raw.get("title") or "").strip()
            if not url or not title:
                skipped += 1
                continue

            existing = db.query(News).filter(News.url == url).first()
            payload = {
                "title": title,
                "summary": BraveSearchImporter._summary_for(raw),
                "content": None,
                "url": url,
                "source": BraveSearchImporter._source_for(raw, url),
                "language": query.language or "uk",
                "status": query.status,
                "published_at": BraveSearchImporter._parse_published_at(raw.get("age")),
                "image_url": BraveSearchImporter._image_for(raw),
                "import_source": "brave",
                "import_reference_id": query.id,
            }

            if existing:
                if existing.import_source not in {"brave", "manual", "rss"}:
                    skipped += 1
                    continue
                if existing.import_source in {"manual", "rss"}:
                    skipped += 1
                    continue
                NewsService.update(db, existing, **payload)
                updated += 1
            else:
                NewsService.create(db, **payload)
                created += 1

        query.last_imported_at = datetime.utcnow()
        query.updated_at = datetime.utcnow()
        db.add(query)
        db.commit()
        return {"created": created, "updated": updated, "skipped": skipped, "archived": archived}

    @staticmethod
    def import_enabled_queries(db: Session) -> Dict[str, Any]:
        queries = db.query(BraveNewsQuery).filter(BraveNewsQuery.enabled == True).all()  # noqa: E712
        summary = {"queries": 0, "created": 0, "updated": 0, "skipped": 0, "archived": 0}
        for query in queries:
            result = BraveSearchImporter.import_query(db, query)
            summary["queries"] += 1
            summary["created"] += result.get("created", 0)
            summary["updated"] += result.get("updated", 0)
            summary["skipped"] += result.get("skipped", 0)
            summary["archived"] += result.get("archived", 0)
        return summary
