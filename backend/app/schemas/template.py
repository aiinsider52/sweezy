from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator

from ..core.countries import normalize_country_code, normalize_subdivision_code


class TemplateBase(BaseModel):
    name: str
    category: Optional[str] = None
    content: str
    status: Optional[str] = None
    country_code: str = "CH"
    subdivision_codes: list[str] = Field(default_factory=list)
    language: str = "uk"

    @model_validator(mode="after")
    def validate_scope(self):
        self.country_code = normalize_country_code(self.country_code)
        self.subdivision_codes = [
            code for raw in self.subdivision_codes
            if (code := normalize_subdivision_code(self.country_code, raw)) is not None
        ]
        return self


class TemplateCreate(TemplateBase):
    pass


class TemplateUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    content: Optional[str] = None
    status: Optional[str] = None
    country_code: Optional[str] = None
    subdivision_codes: Optional[list[str]] = None
    language: Optional[str] = None


class TemplateOut(TemplateBase):
    model_config = ConfigDict(from_attributes=True)
    id: str

