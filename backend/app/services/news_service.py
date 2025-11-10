from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from sqlalchemy.orm import Session

from ..models.news import News
from ..utils.ids import generate_uuid


class NewsService:
  @staticmethod
  def list_news(db: Session, language: Optional[str] = None, limit: int = 50) -> List[News]:
    query = db.query(News).order_by(News.published_at.desc())
    if language:
      query = query.filter(News.language == language)
    return query.limit(limit).all()

  @staticmethod
  def get(db: Session, news_id: str) -> Optional[News]:
    return db.query(News).filter(News.id == news_id).first()

  @staticmethod
  def create(db: Session, **data) -> News:
    news = News(
      id=generate_uuid(),
      title=data["title"],
      summary=data.get("summary", ""),
      url=str(data["url"]),
      source=data.get("source", "Sweezy"),
      language=data.get("language", "uk"),
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


