from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from ..core.countries import (
    COUNTRIES,
    default_currency,
    default_timezone,
    normalize_country_code,
    normalize_subdivision_code,
    validate_currency,
)


class CountryMetadata(BaseModel):
    code: Literal["CH", "DE", "AT"]
    name: str
    currency_code: str
    timezone: str
    default_language: str
    subdivision_label: str
    subdivisions: dict[str, str]
    residence_statuses: dict[str, str]


class CountryCatalog(BaseModel):
    countries: list[CountryMetadata]


class CountryContextUpsert(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    country_code: Literal["CH", "DE", "AT"] = "CH"
    subdivision_code: str | None = Field(default=None, max_length=10)
    city: str | None = Field(default=None, max_length=120)
    residence_status: str | None = Field(default=None, max_length=40)
    preferred_language: Literal["uk", "de", "en"] = "uk"
    currency_code: str | None = Field(default=None, min_length=3, max_length=3)
    timezone: str | None = Field(default=None, max_length=50)
    is_active: bool = True

    @model_validator(mode="after")
    def normalize_scope(self) -> "CountryContextUpsert":
        self.country_code = normalize_country_code(self.country_code)
        self.subdivision_code = normalize_subdivision_code(self.country_code, self.subdivision_code)
        self.currency_code = validate_currency(self.country_code, self.currency_code)
        expected_timezone = default_timezone(self.country_code)
        if self.timezone and self.timezone != expected_timezone:
            raise ValueError(f"Timezone for {self.country_code} must be {expected_timezone}")
        self.timezone = expected_timezone
        if self.residence_status and self.residence_status not in COUNTRIES[self.country_code].residence_statuses:
            raise ValueError(f"Unsupported residence status for {self.country_code}")
        return self


class CountryContextResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    country_code: str
    subdivision_code: str | None
    city: str | None
    residence_status: str | None
    preferred_language: str
    currency_code: str
    timezone: str
    is_active: bool
    created_at: datetime
    updated_at: datetime


def country_catalog() -> CountryCatalog:
    return CountryCatalog(
        countries=[
            CountryMetadata(
                code=item.code,
                name=item.name,
                currency_code=item.currency_code,
                timezone=item.timezone,
                default_language=item.default_language,
                subdivision_label=item.subdivision_label,
                subdivisions=item.subdivisions,
                residence_statuses=item.residence_statuses,
            )
            for item in COUNTRIES.values()
        ]
    )

