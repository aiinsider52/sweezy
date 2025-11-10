from __future__ import annotations
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..schemas.news import NewsOut, NewsCreate, NewsUpdate
from ..services.news_service import NewsService
from ..dependencies import get_db, CurrentAdmin

router = APIRouter()

@router.get("/", response_model=List[NewsOut])
def list_news(language: Optional[str] = None, limit: int = 50, db: Session = Depends(get_db)):
  return NewsService.list_news(db, language=language, limit=limit)

@router.get("/{news_id}", response_model=NewsOut)
def get_news(news_id: str, db: Session = Depends(get_db)):
  news = NewsService.get(db, news_id)
  if not news:
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="News not found")
  return news

@router.post("/", response_model=NewsOut)
def create_news(payload: NewsCreate, db: Session = Depends(get_db), _: CurrentAdmin = Depends()):
  return NewsService.create(db, **payload.model_dump())

@router.put("/{news_id}", response_model=NewsOut)
def update_news(news_id: str, payload: NewsUpdate, db: Session = Depends(get_db), _: CurrentAdmin = Depends()):
  news = NewsService.get(db, news_id)
  if not news:
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="News not found")
  return NewsService.update(db, news, **payload.model_dump(exclude_unset=True))

@router.delete("/{news_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_news(news_id: str, db: Session = Depends(get_db), _: CurrentAdmin = Depends()):
  news = NewsService.get(db, news_id)
  if not news:
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="News not found")
  NewsService.delete(db, news)
  return None
