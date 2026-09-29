from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator

from ..core.countries import normalize_country_code, normalize_subdivision_code


class GuideBase(BaseModel):
    title: str
    slug: str
    description: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    country_code: str = "CH"
    subdivision_codes: list[str] = Field(default_factory=list)
    language: str = "uk"
    image_url: Optional[str] = None
    source_url: Optional[str] = None
    source_title: Optional[str] = None
    verified_at: Optional[datetime] = None
    is_published: bool = True
    status: Optional[str] = None
    version: int = 1
    valid_from: Optional[datetime] = None
    valid_until: Optional[datetime] = None

    @model_validator(mode="after")
    def validate_scope(self):
        self.country_code = normalize_country_code(self.country_code)
        self.subdivision_codes = [
            code for raw in self.subdivision_codes
            if (code := normalize_subdivision_code(self.country_code, raw)) is not None
        ]
        if self.valid_from and self.valid_until and self.valid_until <= self.valid_from:
            raise ValueError("valid_until must be after valid_from")
        return self


class GuideCreate(GuideBase):
    pass


class GuideUpdate(BaseModel):
    title: Optional[str] = None
    slug: Optional[str] = None
    description: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    country_code: Optional[str] = None
    subdivision_codes: Optional[list[str]] = None
    language: Optional[str] = None
    image_url: Optional[str] = None
    source_url: Optional[str] = None
    source_title: Optional[str] = None
    verified_at: Optional[datetime] = None
    is_published: Optional[bool] = None
    status: Optional[str] = None
    version: Optional[int] = None
    valid_from: Optional[datetime] = None
    valid_until: Optional[datetime] = None


class GuideOut(GuideBase):
    model_config = ConfigDict(from_attributes=True)
    id: str
