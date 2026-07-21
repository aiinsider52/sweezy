from __future__ import annotations

from datetime import datetime
from urllib.parse import urlparse


TRUSTED_OFFICIAL_HOSTS = {
    "ch.ch",
    "www.ch.ch",
    "admin.ch",
    "www.admin.ch",
    "sem.admin.ch",
    "bag.admin.ch",
    "bsv.admin.ch",
    "estv.admin.ch",
    "fedlex.admin.ch",
    "finma.ch",
    "www.finma.ch",
    "edk.ch",
    "www.edk.ch",
    "sbb.ch",
    "www.sbb.ch",
    "zh.ch",
    "www.zh.ch",
    "ge.ch",
    "www.ge.ch",
    "vd.ch",
    "www.vd.ch",
}


def is_trusted_official_url(raw: str | None) -> bool:
    if not raw:
        return False
    try:
        parsed = urlparse(raw.strip())
    except ValueError:
        return False
    if parsed.scheme != "https" or not parsed.hostname:
        return False
    host = parsed.hostname.lower().rstrip(".")
    return host in TRUSTED_OFFICIAL_HOSTS or host.endswith(".admin.ch")


def validate_publishable_source(
    *,
    is_published: bool,
    status: str | None,
    source_url: str | None,
    source_title: str | None,
    verified_at: datetime | None,
) -> None:
    published = is_published and (status in (None, "published"))
    if not published:
        return
    if not is_trusted_official_url(source_url):
        raise ValueError("Published content requires an HTTPS URL from a trusted Swiss official source")
    if not source_title or not source_title.strip():
        raise ValueError("Published content requires source_title")
    if verified_at is None:
        raise ValueError("Published content requires verified_at")
