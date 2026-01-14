from __future__ import annotations

from datetime import datetime
from typing import Dict, Any
from urllib.parse import urlparse, urljoin
import time

import feedparser
import httpx
from sqlalchemy.orm import Session

from ..models.news import News
from ..models.rss_feed import RSSFeed
from .news_service import NewsService
from ..routers.media import UPLOAD_DIR


class RSSImporter:
  @staticmethod
  def _fetch_text(client: httpx.Client, url: str) -> str:
    try:
      r = client.get(url)
      if r.status_code < 400:
        return r.text
    except Exception:
      pass
    return ""

  @staticmethod
  def import_from_url(db: Session, feed_url: str, *, language: str = "uk", status: str = "draft", max_items: int = 50, download_images: bool = True) -> Dict[str, int]:
    client = httpx.Client(timeout=10, follow_redirects=True, headers={
      "User-Agent": "SweezyRSS/1.0 (+https://sweezy-9xyk.onrender.com)"
    })
    text = RSSImporter._fetch_text(client, feed_url)
    parsed = feedparser.parse(text or feed_url)
    created = updated = skipped = 0
    src = parsed.feed.get("title") if getattr(parsed, "feed", None) else (urlparse(feed_url).hostname or "RSS")

    # Fallback to discover <link rel="alternate" type="application/rss+xml">
    if not getattr(parsed, "entries", None):
      import re as _re
      m = _re.search(r'<link[^>]+type="application/(?:rss|atom)\+xml"[^>]+href="([^"]+)"', text, flags=_re.I) if text else None
      if m:
        feed_abs = urljoin(feed_url, m.group(1))
        text2 = RSSImporter._fetch_text(client, feed_abs)
        parsed = feedparser.parse(text2)

    if not getattr(parsed, "entries", None):
      # Single article import via OpenGraph
      try:
        html = text or RSSImporter._fetch_text(client, feed_url)
        import re as _re
        def meta(prop=None, name=None):
          if prop:
            m = _re.search(rf'<meta[^>]+property=["\']{_re.escape(prop)}["\'][^>]*content=["\']([^"\']+)["\']', html, flags=_re.I)
            if m: return m.group(1)
          if name:
            m = _re.search(rf'<meta[^>]+name=["\']{_re.escape(name)}["\'][^>]*content=["\']([^"\']+)["\']', html, flags=_re.I)
            if m: return m.group(1)
          return None
        title = meta(prop="og:title") or meta(name="title")
        if not title:
          mtitle = _re.search(r'<title[^>]*>(.*?)</title>', html, flags=_re.I|_re.S)
          title = (mtitle.group(1).strip() if mtitle else "Untitled")
        desc = meta(prop="og:description") or meta(name="description") or ""
        img = meta(prop="og:image") or meta(name="image")
        pub = meta(prop="article:published_time") or meta(name="article:published_time")
        pub_dt = datetime.utcnow()
        try:
          p = pub.replace("Z","").split("+")[0] if pub else ""
          if p:
            pub_dt = datetime.fromisoformat(p)
        except Exception:
          pass
        image_url = None
        if img:
          try:
            r = client.get(urljoin(feed_url, img))
            if r.status_code == 200 and download_images:
              name = f"{__import__('uuid').uuid4()}.jpg"
              (UPLOAD_DIR / name).write_bytes(r.content)
              image_url = f"/media/{name}"
            else:
              image_url = img
          except Exception:
            image_url = img
        data = {
          "title": title.strip(),
          "summary": desc.strip(),
          "content": None,
          "url": feed_url,
          "source": src,
          "language": language,
          "status": status,
          "published_at": pub_dt,
          "image_url": image_url,
        }
        existing = db.query(News).filter(News.url == feed_url).first()
        if existing:
          NewsService.update(db, existing, **data); updated += 1
        else:
          NewsService.create(db, **data); created += 1
        client.close()
        return {"created": created, "updated": updated, "skipped": skipped}
      except Exception:
        client.close()
        return {"created": created, "updated": updated, "skipped": skipped}

    # Feed entries
    for entry in getattr(parsed, "entries", [])[:max_items]:
      try:
        url = entry.get("link")
        if not url:
          skipped += 1
          continue
        existing = db.query(News).filter(News.url == url).first()
        title = (entry.get("title") or "Untitled").strip()
        summary = entry.get("summary") or entry.get("description") or ""
        pub_dt = datetime.utcnow()
        if entry.get("published_parsed"):
          pub_dt = datetime.fromtimestamp(time.mktime(entry.published_parsed))
        image_url = None
        media = entry.get("media_content") or entry.get("enclosures") or []
        if isinstance(media, list) and media:
          m0 = media[0]
          if isinstance(m0, dict):
            image_url = m0.get("url")
        if not image_url and isinstance(summary, str):
          import re as _re
          m = _re.search(r'<img[^>]+src="([^"]+)"', summary)
          if m:
            image_url = m.group(1)
        if image_url and download_images:
          try:
            r = client.get(image_url)
            if r.status_code == 200:
              name = f"{__import__('uuid').uuid4()}.jpg"
              (UPLOAD_DIR / name).write_bytes(r.content)
              image_url = f"/media/{name}"
          except Exception:
            pass
        data = {
          "title": title,
          "summary": summary,
          "content": None,
          "url": url,
          "source": src,
          "language": language,
          "status": status,
          "published_at": pub_dt,
          "image_url": image_url,
        }
        if existing:
          NewsService.update(db, existing, **data); updated += 1
        else:
          NewsService.create(db, **data); created += 1
      except Exception:
        skipped += 1
        continue
    client.close()
    return {"created": created, "updated": updated, "skipped": skipped}

  @staticmethod
  def import_feed_record(db: Session, feed: RSSFeed) -> Dict[str, int]:
    res = RSSImporter.import_from_url(
      db,
      feed.url,
      language=feed.language,
      status=feed.status,
      max_items=feed.max_items,
      download_images=feed.download_images,
    )
    feed.last_imported_at = datetime.utcnow()
    db.add(feed)
    db.commit()
    return res


