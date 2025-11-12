from __future__ import annotations

import os
from typing import List, Dict, Tuple, Any
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


def _parse_jsearch(item: dict, canton: str | None) -> JobItem | None:
    try:
        job_id = str(item.get("job_id") or item.get("id") or "")
        if not job_id:
            return None
        # Posted at (timestamp or ISO)
        posted_at = None
        ts = item.get("job_posted_at_timestamp")
        if isinstance(ts, (int, float)):
            try:
                posted_at = datetime.utcfromtimestamp(int(ts))
            except Exception:
                posted_at = None
        if not posted_at:
            posted_at = _parse_date(item.get("job_posted_at_datetime_utc"))
        # Build display location
        city = item.get("job_city")
        state = item.get("job_state")
        country = item.get("job_country")
        location = ", ".join([x for x in [city, state, country] if x])
        return JobItem(
            id=f"jsearch:{job_id}",
            source="jsearch",
            title=item.get("job_title") or "",
            company=item.get("employer_name"),
            location=location or country or "Switzerland",
            canton=canton,
            url=item.get("job_apply_link") or item.get("job_apply_url") or item.get("job_apply_link"),
            posted_at=posted_at,
            employment_type=item.get("job_employment_type"),
            salary=item.get("job_salary") or item.get("job_min_salary"),
            snippet=(item.get("job_description") or "")[:280] if isinstance(item.get("job_description"), str) else None,
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


async def search_jobs(q: str | None, canton: str | None, page: int, per_page: int, debug: bool = False) -> Tuple[List[JobItem], Dict[str, int], Dict[str, Any]]:
    """
    Fetch jobs from Indeed RapidAPI and optionally RAV Job-Room API, merge and sort by date desc.
    """
    items: List[JobItem] = []
    source_counts: Dict[str, int] = {}
    debug_info: Dict[str, Any] = {"indeed": [], "rav": []} if debug else {}

    async with httpx.AsyncClient(timeout=15.0) as client:
        # Indeed (RapidAPI)
        rapid_key = os.getenv("RAPIDAPI_KEY") or os.getenv("RAPID_API_KEY") or os.getenv("INDEED_RAPIDAPI_KEY")
        if rapid_key:
            primary_host = os.getenv("RAPIDAPI_HOST") or "indeed-api.p.rapidapi.com"
            alt_hosts = [primary_host]
            # Fallback to the stable package if a custom host is set
            if primary_host != "indeed-api.p.rapidapi.com":
                alt_hosts.append("indeed-api.p.rapidapi.com")
            # JSearch (jsearch.p.rapidapi.com) - special handling
            if "jsearch" in primary_host:
                try:
                    # JSearch wants location inside query string + country code separately
                    canton_map = {
                        "ZH": "Zurich", "BE": "Bern", "LU": "Lucerne", "UR": "Uri", "SZ": "Schwyz",
                        "OW": "Obwalden", "NW": "Nidwalden", "GL": "Glarus", "ZG": "Zug", "FR": "Fribourg",
                        "SO": "Solothurn", "BS": "Basel", "BL": "Basel-Landschaft", "SH": "Schaffhausen",
                        "AR": "Appenzell Ausserrhoden", "AI": "Appenzell Innerrhoden", "SG": "St. Gallen",
                        "GR": "Grisons", "AG": "Aargau", "TG": "Thurgau", "TI": "Ticino", "VD": "Vaud",
                        "VS": "Valais", "NE": "Neuchâtel", "GE": "Geneva", "JU": "Jura",
                    }
                    city = canton_map.get((canton or "").upper())
                    base_query = (q or "jobs").strip()
                    if city:
                        query = f"{base_query} in {city}"
                    else:
                        query = f"{base_query} in Switzerland"
                    params = {
                        "query": query,
                        "page": str(max(page, 1)),
                        "num_pages": "1",
                        "country": "ch",
                        "date_posted": "all",
                    }
                    headers = {
                        "x-rapidapi-key": rapid_key,
                        "x-rapidapi-host": primary_host,
                        "Accept": "application/json",
                    }
                    url = f"https://{primary_host}/search"
                    resp = await client.get(url, params=params, headers=headers)
                    if debug:
                        try:
                            snippet = "" if resp.status_code == 200 else resp.text[:220]
                            debug_info["indeed"].append({"host": primary_host, "url": url, "params": params, "status": resp.status_code, "body": snippet})
                        except Exception:
                            pass
                    if resp.status_code == 200:
                        data = resp.json()
                        raw = data.get("data") or []
                        parsed = [_parse_jsearch(it, canton) for it in raw]
                        j_items = [p for p in parsed if p]
                        if j_items:
                            items.extend(j_items)
                            source_counts["jsearch"] = len(j_items)
                            # we consider success and skip other hosts
                            alt_hosts = []
                        else:
                            source_counts["jsearch"] = 0
                except Exception:
                    # swallow and continue to generic hosts
                    pass

            # Try a few common endpoint/param variants used by different Indeed RapidAPI packs
            canton_map = {
                "ZH": "Zurich",
                "BE": "Bern",
                "LU": "Lucerne",
                "UR": "Uri",
                "SZ": "Schwyz",
                "OW": "Obwalden",
                "NW": "Nidwalden",
                "GL": "Glarus",
                "ZG": "Zug",
                "FR": "Fribourg",
                "SO": "Solothurn",
                "BS": "Basel",
                "BL": "Basel-Landschaft",
                "SH": "Schaffhausen",
                "AR": "Appenzell Ausserrhoden",
                "AI": "Appenzell Innerrhoden",
                "SG": "St. Gallen",
                "GR": "Grisons",
                "AG": "Aargau",
                "TG": "Thurgau",
                "TI": "Ticino",
                "VD": "Vaud",
                "VS": "Valais",
                "NE": "Neuchâtel",
                "GE": "Geneva",
                "JU": "Jura",
            }
            location_text = f"{canton_map.get((canton or '').upper(), (canton or '').upper() or 'Switzerland')}, Switzerland".strip(", ")
            query = (q or "").strip() or "a"  # fallback to broad match to fetch any listings
            success = False
            for host in alt_hosts:
                headers = {
                    "x-rapidapi-key": rapid_key,
                    "x-rapidapi-host": host,
                    "X-RapidAPI-Key": rapid_key,
                    "X-RapidAPI-Host": host,
                    "Accept": "application/json",
                }
                variants = []
                if query:
                    variants.extend([
                        (f"https://{host}/jobs/search", {"query": query, "location": location_text, "country": "CH", "page_id": str(max(page, 1))}),
                        (f"https://{host}/jobs/search", {"q": query, "location": location_text, "country": "CH", "page": str(max(page, 1))}),
                        (f"https://{host}/search", {"query": query, "location": location_text, "country": "CH", "page": str(max(page, 1))}),
                        (f"https://{host}/search", {"q": query, "l": location_text, "page": str(max(page, 1))}),
                        (f"https://{host}/jobs/search", {"query": query, "location": location_text, "page": str(max(page, 1))}),
                        (f"https://{host}/search", {"q": query, "l": location_text, "page": str(max(page, 1))}),
                        (f"https://{host}/search", {"q": query, "l": location_text, "co": "ch", "start": str((max(page, 1)-1)*per_page), "limit": str(per_page)}),
                    ])
                else:
                    variants.extend([
                        (f"https://{host}/jobs/search", {"location": location_text, "country": "CH", "page_id": str(max(page, 1))}),
                        (f"https://{host}/jobs/search", {"location": location_text, "country": "CH", "page": str(max(page, 1))}),
                        (f"https://{host}/search", {"location": location_text, "country": "CH", "page": str(max(page, 1))}),
                        (f"https://{host}/search", {"l": location_text, "page": str(max(page, 1))}),
                        (f"https://{host}/search", {"l": location_text, "co": "ch", "start": str((max(page, 1)-1)*per_page), "limit": str(per_page)}),
                    ])
                for url, params in variants:
                    try:
                        resp = await client.get(url, params=params, headers=headers)
                        if debug:
                            try:
                                snippet = ""
                                if resp.status_code != 200:
                                    try:
                                        snippet = resp.text[:220]
                                    except Exception:
                                        snippet = ""
                                debug_info["indeed"].append({"host": host, "url": url, "params": params, "status": resp.status_code, "body": snippet})
                            except Exception:
                                pass
                        if resp.status_code != 200:
                            continue
                        data = resp.json()
                        raw_list = data.get("data") or data.get("jobs") or data.get("results") or data.get("items") or []
                        parsed = [_parse_indeed(it, canton) for it in raw_list]
                        indeed_items = [p for p in parsed if p]
                        if indeed_items:
                            items.extend(indeed_items)
                            source_counts["indeed"] = len(indeed_items)
                            success = True
                            break
                    except Exception:
                        continue
                if success:
                    break
            if not success:
                # mark as attempted so clients don't assume "not configured"
                source_counts["indeed"] = -1

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
                if debug:
                    try:
                        debug_info["rav"].append({"url": rav_url, "params": params, "status": resp.status_code})
                    except Exception:
                        pass
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
    return items[start:end], source_counts, debug_info


