from __future__ import annotations

from pydantic import BaseModel, EmailStr, Field, field_validator

from ..core.password_policy import validate_password_strength


class AuthStatus(BaseModel):
    status: str
    email: EmailStr | None = None
    message: str | None = None


class EmailCodeRequest(BaseModel):
    email: EmailStr


class EmailCodeConfirm(BaseModel):
    email: EmailStr
    code: str = Field(..., min_length=6, max_length=6)

    @field_validator("code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("Code must contain only digits")
        return v


class PasswordResetConfirm(BaseModel):
    email: EmailStr
    code: str = Field(..., min_length=6, max_length=6)
    password: str = Field(..., min_length=8)

    @field_validator("code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("Code must contain only digits")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        ok, message = validate_password_strength(v)
        if not ok:
            raise ValueError(message or "Weak password")
        return v
