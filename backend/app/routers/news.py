from __future__ import annotations
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session
from ..schemas.news import NewsOut, NewsCreate, NewsUpdate
from ..services.news_service import NewsService
from ..dependencies import get_db, CurrentAdmin
from ..core.security import decode_token
from ..services.users import UserService

router = APIRouter()
_optional_bearer = HTTPBearer(auto_error=False)


def _is_admin_request(
  db: Session = Depends(get_db),
  credentials: Optional[HTTPAuthorizationCredentials] = Depends(_optional_bearer),
) -> bool:
  if credentials is None:
    return False
  try:
    payload = decode_token(credentials.credentials)
    user_id = payload.get("sub")
    user = UserService.get_by_id(db, user_id) if user_id else None
    return bool(user and user.is_active and user.is_superuser and payload.get("is_admin"))
  except Exception:
    return False

@router.get("/", response_model=List[NewsOut])
def list_news(
  language: Optional[str] = None,
  status: Optional[str] = None,
  include_drafts: bool = False,
  import_source: Optional[str] = None,
  limit: int = 50,
  db: Session = Depends(get_db),
  is_admin_request: bool = Depends(_is_admin_request),
):
  if not is_admin_request:
    return NewsService.list_news(
      db,
      language=language,
      limit=limit,
      status="published",
      include_drafts=False,
      import_source=import_source,
    )
  return NewsService.list_news(
    db,
    language=language,
    limit=limit,
    status=status,
    include_drafts=include_drafts,
    import_source=import_source,
  )

@router.get("/{news_id}", response_model=NewsOut)
def get_news(
  news_id: str,
  db: Session = Depends(get_db),
  is_admin_request: bool = Depends(_is_admin_request),
):
  news = NewsService.get(db, news_id)
  if not news:
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="News not found")
  if not is_admin_request and news.status != "published":
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="News not found")
  return news

@router.post("/", response_model=NewsOut)
def create_news(payload: NewsCreate, _: CurrentAdmin, db: Session = Depends(get_db)):
  return NewsService.create(db, **payload.model_dump())

@router.put("/{news_id}", response_model=NewsOut)
def update_news(news_id: str, payload: NewsUpdate, _: CurrentAdmin, db: Session = Depends(get_db)):
  news = NewsService.get(db, news_id)
  if not news:
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="News not found")
  return NewsService.update(db, news, **payload.model_dump(exclude_unset=True))

@router.delete("/{news_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_news(news_id: str, _: CurrentAdmin, db: Session = Depends(get_db)):
  news = NewsService.get(db, news_id)
  if not news:
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="News not found")
  NewsService.delete(db, news)
  return None
