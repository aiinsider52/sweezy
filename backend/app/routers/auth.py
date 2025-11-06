from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from ..schemas import Token, TokenPair
from ..schemas.user import UserCreate, UserLogin, UserOut
from ..services import AuthService
from ..services.users import UserService, seed_admin_user
from ..core.security import create_access_token, create_refresh_token
from ..core.database import get_db
from ..core.config import get_settings
from datetime import timedelta


router = APIRouter()


@router.post("/token", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends()) -> Token:
    token = AuthService.authenticate_admin(form_data.username, form_data.password)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")
    return Token(access_token=token)


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(user_in: UserCreate, db: Session = Depends(get_db)) -> UserOut:
    if UserService.get_by_email(db, user_in.email):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")
    user = UserService.create(db, email=user_in.email, password=user_in.password)
    return UserOut.model_validate(user)


@router.post("/login", response_model=TokenPair)
def login_user(payload: UserLogin, db: Session = Depends(get_db)) -> TokenPair:
    user = UserService.authenticate(db, email=payload.email, password=payload.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    access = create_access_token(subject=user.email, is_admin=user.is_superuser, expires_delta=timedelta(minutes=15))
    refresh = create_refresh_token(subject=user.email, expires_delta=timedelta(days=7))

    return TokenPair(access_token=access, refresh_token=refresh, expires_in=15 * 60)


@router.post("/seed-admin")
def seed_admin(request: Request, db: Session = Depends(get_db)) -> dict:
    settings = get_settings()
    secret = request.headers.get("x-setup-secret")
    allowed = [s for s in [settings.SETUP_SECRET, settings.SECRET_KEY, settings.JWT_SECRET_KEY] if s]
    if not allowed or secret not in allowed:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    seed_admin_user(db)
    return {"status": "ok"}

