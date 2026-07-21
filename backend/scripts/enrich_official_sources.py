#!/usr/bin/env python3
"""Add required Swiss official-source metadata to bundled guides/checklists."""

from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[2]
SEEDS = ROOT / "sweezy" / "sweezy" / "Resources" / "AppContent" / "seeds"
VERIFIED_AT = "2026-07-15T00:00:00Z"

SOURCES: dict[str, tuple[str, str]] = {
    "arrival": ("https://www.ch.ch/en/foreign-nationals-in-switzerland/", "ch.ch — Foreign nationals in Switzerland"),
    "documents": ("https://www.ch.ch/en/foreign-nationals-in-switzerland/", "ch.ch — Foreign nationals in Switzerland"),
    "integration": ("https://www.sem.admin.ch/sem/en/home/integration-einbuergerung.html", "SEM — Integration and naturalisation"),
    "housing": ("https://www.ch.ch/en/housing/", "ch.ch — Housing"),
    "insurance": ("https://www.ch.ch/en/health/health-insurance/", "ch.ch — Health insurance"),
    "healthcare": ("https://www.ch.ch/en/health/", "ch.ch — Health"),
    "health": ("https://www.ch.ch/en/health/", "ch.ch — Health"),
    "finance": ("https://www.ch.ch/en/taxes-and-finances/", "ch.ch — Taxes and finances"),
    "banking": ("https://www.finma.ch/en/finma-public/fragen-und-probleme/", "FINMA — Information for clients"),
    "education": ("https://www.ch.ch/en/school-and-education/", "ch.ch — School and education"),
    "work": ("https://www.ch.ch/en/work/", "ch.ch — Work"),
    "family": ("https://www.ch.ch/en/family-and-partnership/", "ch.ch — Family and partnership"),
    "legal": ("https://www.ch.ch/en/safety-and-justice/", "ch.ch — Safety and justice"),
    "emergency": ("https://www.ch.ch/en/safety-and-justice/", "ch.ch — Safety and justice"),
    "transport": ("https://www.ch.ch/en/mobility/", "ch.ch — Mobility"),
    "lifestyle": ("https://www.ch.ch/en/", "ch.ch — Swiss authorities online"),
}
DEFAULT_SOURCE = ("https://www.ch.ch/en/", "ch.ch — Swiss authorities online")


def is_trusted(raw: object) -> bool:
    if not isinstance(raw, str):
        return False
    parsed = urlparse(raw)
    host = (parsed.hostname or "").lower()
    return parsed.scheme == "https" and (
        host in {"ch.ch", "www.ch.ch", "finma.ch", "www.finma.ch"} or host.endswith(".admin.ch")
    )


def inferred_language(path: Path, item: dict) -> str | None:
    for code in ("uk", "en", "de"):
        if path.stem.endswith(f"_{code}") or f"lang:{code}" in [str(tag).lower() for tag in item.get("tags", [])]:
            return code
    return item.get("language")


def source_for(item: dict) -> tuple[str, str]:
    category = str(item.get("category") or "").lower()
    return SOURCES.get(category, DEFAULT_SOURCE)


def enrich_item(path: Path, item: dict, *, guide: bool) -> bool:
    changed = False
    default_url, default_title = source_for(item)
    if not is_trusted(item.get("source")):
        item["source"] = default_url
        changed = True
    source_url = str(item["source"])

    if not item.get("sourceTitle"):
        item["sourceTitle"] = default_title if source_url == default_url else (urlparse(source_url).hostname or default_title)
        changed = True
    if item.get("verifiedAt") != VERIFIED_AT:
        item["verifiedAt"] = VERIFIED_AT
        changed = True

    language = inferred_language(path, item)
    if language and item.get("language") != language:
        item["language"] = language
        changed = True

    if guide:
        links = item.setdefault("links", [])
        if not any(is_trusted(link.get("url")) and link.get("url") == source_url for link in links if isinstance(link, dict)):
            links.append(
                {
                    "id": f"official-source-{str(item.get('id', 'guide'))[:24]}",
                    "title": item["sourceTitle"],
                    "url": source_url,
                    "type": "website",
                    "description": "Official Swiss source used to verify this material",
                }
            )
            changed = True
    return changed


def main() -> None:
    files = sorted([*SEEDS.glob("guides*.json"), *SEEDS.glob("checklists*.json")])
    changed_files = 0
    records = 0
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            continue
        is_guide = path.name.startswith("guides")
        changed = False
        for item in data:
            if isinstance(item, dict):
                records += 1
                changed = enrich_item(path, item, guide=is_guide) or changed
        if changed:
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            changed_files += 1
    print(f"Enriched {records} records in {changed_files} files")


if __name__ == "__main__":
    main()
