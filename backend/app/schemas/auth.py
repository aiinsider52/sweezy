from __future__ import annotations

from pydantic import BaseModel, EmailStr, Field, field_validator

from ..core.password_policy import validate_password_strength


class AuthStatus(BaseModel):
    status: str
    email: EmailStr | None = None
    message: str | None = None


class AppleOAuthRequest(BaseModel):
    id_token: str = Field(..., min_length=20)
    authorization_code: str | None = None
    nonce: str | None = None
    full_name: str | None = Field(default=None, max_length=120)


class GoogleOAuthRequest(BaseModel):
    id_token: str = Field(..., min_length=20)
    full_name: str | None = Field(default=None, max_length=120)


class SocialLinkConfirmRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    link_token: str = Field(..., min_length=20)


class SocialAuthResponse(BaseModel):
    status: str
    email: EmailStr | None = None
    message: str | None = None
    provider: str | None = None
    name: str | None = None
    access_token: str | None = None
    refresh_token: str | None = None
    token_type: str = "bearer"
    expires_in: int | None = None
    link_token: str | None = None


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
