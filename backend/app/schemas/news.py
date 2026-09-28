from __future__ import annotations

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, model_validator

from ..core.countries import normalize_country_code, normalize_subdivision_code


class NewsBase(BaseModel):
    title: str = Field(..., max_length=300)
    summary: str = ""
    content: Optional[str] = None
    # Allow non-ASCII paths and relative URLs to pass through (validated client-side)
    url: str
    source: str = "Sweezy"
    language: str = "uk"
    country_code: str = "CH"
    subdivision_codes: list[str] = Field(default_factory=list)
    status: str = Field(default="published", description="draft|published|archived")
    published_at: datetime
    # Can be absolute (http...) or relative (/media/...)
    image_url: Optional[str] = None
    import_source: str = "manual"
    import_reference_id: Optional[str] = None

    @model_validator(mode="after")
    def validate_scope(self):
        self.country_code = normalize_country_code(self.country_code)
        self.subdivision_codes = [
            code for raw in self.subdivision_codes
            if (code := normalize_subdivision_code(self.country_code, raw)) is not None
        ]
        return self


class NewsCreate(NewsBase):
    pass


class NewsUpdate(BaseModel):
    title: Optional[str] = None
    summary: Optional[str] = None
    content: Optional[str] = None
    url: Optional[str] = None
    source: Optional[str] = None
    language: Optional[str] = None
    country_code: Optional[str] = None
    subdivision_codes: Optional[list[str]] = None
    status: Optional[str] = None
    published_at: Optional[datetime] = None
    image_url: Optional[str] = None
    import_source: Optional[str] = None
    import_reference_id: Optional[str] = None


class NewsOut(NewsBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime
    updated_at: datetime
