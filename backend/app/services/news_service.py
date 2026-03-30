from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from sqlalchemy.orm import Session
from uuid import uuid4

from ..models.news import News


class NewsService:
  @staticmethod
  def list_news(
    db: Session,
    language: Optional[str] = None,
    limit: int = 50,
    *,
    status: Optional[str] = None,
    include_drafts: bool = False,
    import_source: Optional[str] = None,
  ) -> List[News]:
    query = db.query(News).order_by(News.published_at.desc())
    if language:
      query = query.filter(News.language == language)
    if import_source:
      query = query.filter(News.import_source == import_source)
    if status:
      query = query.filter(News.status == status)
    elif not include_drafts:
      query = query.filter(News.status == "published")
    return query.limit(limit).all()

  @staticmethod
  def get(db: Session, news_id: str) -> Optional[News]:
    return db.query(News).filter(News.id == news_id).first()

  @staticmethod
  def create(db: Session, **data) -> News:
    news = News(
      id=str(uuid4()),
      title=data["title"],
      summary=data.get("summary", ""),
      content=data.get("content"),
      url=str(data["url"]),
      source=data.get("source", "Sweezy"),
      language=data.get("language", "uk"),
      status=data.get("status", "published"),
      import_source=data.get("import_source", "manual"),
      import_reference_id=data.get("import_reference_id"),
      published_at=data.get("published_at") or datetime.utcnow(),
      image_url=str(data["image_url"]) if data.get("image_url") else None,
      created_at=datetime.utcnow(),
      updated_at=datetime.utcnow(),
    )
    db.add(news)
    db.commit()
    db.refresh(news)
    return news

  @staticmethod
  def update(db: Session, news: News, **data) -> News:
    for field, value in data.items():
      if value is not None:
        setattr(news, field, value)
    news.updated_at = datetime.utcnow()
    db.add(news)
    db.commit()
    db.refresh(news)
    return news

  @staticmethod
  def delete(db: Session, news: News) -> None:
    db.delete(news)
    db.commit()


