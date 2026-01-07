from __future__ import annotations

from datetime import datetime
from pydantic import BaseModel, EmailStr, Field, field_validator

from ..core.password_policy import validate_password_strength


class UserBase(BaseModel):
    email: EmailStr


class UserCreate(UserBase):
    password: str = Field(min_length=8)

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        ok, message = validate_password_strength(v)
        if not ok:
            # Pydantic will surface this as a 422 with detail
            raise ValueError(message or "Weak password")
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(UserBase):
    id: str
    is_active: bool
    is_superuser: bool
    role: str = "viewer"
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


