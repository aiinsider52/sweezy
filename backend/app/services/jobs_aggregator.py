from __future__ import annotations

import os
from typing import List, Dict, Tuple
from datetime import datetime
import httpx

from ..schemas.job import JobItem


def _parse_indeed(item: dict, canton: str | None) -> JobItem | None:
    try:
        job_id = str(item.get("jobkey") or item.get("id") or item.get("job_id") or item.get("jobKey") or "")
        if not job_id:
            return None
        return JobItem(
            id=f"indeed:{job_id}",
            source="indeed",
            title=item.get("title") or "",
            company=item.get("company") or item.get("employer_name"),
            location=item.get("location") or item.get("city") or "Switzerland",
            canton=canton,
            url=item.get("url") or item.get("job_url") or "",
            posted_at=_parse_date(item.get("date") or item.get("published_at")),
            employment_type=item.get("employment_type"),
            salary=(item.get("salary") or item.get("salary_info")),
            snippet=item.get("snippet") or item.get("description_snippet"),
        )
    except Exception:
        return None


def _parse_rav(item: dict) -> JobItem | None:
    try:
        job_id = str(item.get("id") or item.get("externalId") or "")
        if not job_id:
            return None
        company = None
        if isinstance(item.get("company"), dict):
            company = item["company"].get("name") or item["company"].get("displayName")
        return JobItem(
            id=f"rav:{job_id}",
            source="rav",
            title=item.get("title") or "",
            company=company,
            location=(item.get("workplace") or {}).get("city") if isinstance(item.get("workplace"), dict) else None,
            canton=(item.get("workplace") or {}).get("canton") if isinstance(item.get("workplace"), dict) else None,
            url=item.get("jobAdvertisementUrl") or item.get("url") or "",
            posted_at=_parse_date(item.get("publicationDate") or item.get("createdDate")),
            employment_type=(item.get("employment") or {}).get("workloadPeriod"),
            salary=None,
            snippet=(item.get("description") or "")[:280] if isinstance(item.get("description"), str) else None,
        )
    except Exception:
        return None


def _parse_date(value) -> datetime | None:
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    for fmt in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%d"):
        try:
            return datetime.strptime(str(value), fmt)
        except Exception:
            continue
    return None


async def search_jobs(q: str, canton: str | None, page: int, per_page: int) -> Tuple[List[JobItem], Dict[str, int]]:
    """
    Fetch jobs from Indeed RapidAPI and optionally RAV Job-Room API, merge and sort by date desc.
    """
    items: List[JobItem] = []
    source_counts: Dict[str, int] = {}

    async with httpx.AsyncClient(timeout=15.0) as client:
        # Indeed (RapidAPI)
        rapid_key = os.getenv("RAPIDAPI_KEY") or os.getenv("RAPID_API_KEY") or os.getenv("INDEED_RAPIDAPI_KEY")
        if rapid_key:
            try:
                host = os.getenv("RAPIDAPI_HOST") or "indeed-api.p.rapidapi.com"
                params = {
                    "query": q,
                    "location": f"{canton or ''}, Switzerland".strip(", "),
                    "country": "CH",
                    "page_id": str(max(page, 1)),
                }
                headers = {
                    "x-rapidapi-key": rapid_key,
                    "x-rapidapi-host": host,
                }
                indeed_url = f"https://{host}/jobs/search"
                resp = await client.get(indeed_url, params=params, headers=headers)
                if resp.status_code == 200:
                    data = resp.json()
                    raw_list = data.get("data") or data.get("jobs") or data.get("results") or []
                    parsed = [_parse_indeed(it, canton) for it in raw_list]
                    indeed_items = [p for p in parsed if p]
                    items.extend(indeed_items)
                    source_counts["indeed"] = len(indeed_items)
            except Exception:
                pass

        # RAV Job-Room (optional)
        rav_base = os.getenv("RAV_API_URL")
        rav_token = os.getenv("RAV_API_KEY")
        if rav_base:
            try:
                params = {
                    "query": q,
                    "workplaceCantons": canton or "",
                    "page": str(max(page - 1, 0)),
                    "size": str(per_page),
                }
                headers = {"Authorization": f"Bearer {rav_token}"} if rav_token else {}
                base = rav_base.rstrip("/")
                if base.lower().endswith("jobadvertisements"):
                    rav_url = base
                else:
                    rav_url = f"{base}/jobAdvertisements"
                resp = await client.get(rav_url, params=params, headers=headers)
                if resp.status_code == 200:
                    data = resp.json()
                    raw_list = data.get("content") if isinstance(data, dict) else data
                    if isinstance(raw_list, list):
                        parsed = [_parse_rav(it) for it in raw_list]
                        rav_items = [p for p in parsed if p]
                        items.extend(rav_items)
                        source_counts["rav"] = len(rav_items)
            except Exception:
                pass

    # Normalize, sort, paginate
    items.sort(key=lambda x: x.posted_at or datetime.min, reverse=True)
    start = (page - 1) * per_page
    end = start + per_page
    return items[start:end], source_counts


