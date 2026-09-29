from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


CountryCode = Literal["CH", "DE", "AT"]
SUPPORTED_COUNTRY_CODES: tuple[CountryCode, ...] = ("CH", "DE", "AT")


@dataclass(frozen=True)
class CountryDefinition:
    code: CountryCode
    name: str
    currency_code: str
    timezone: str
    default_language: str
    subdivision_label: str
    subdivisions: dict[str, str]
    residence_statuses: dict[str, str]


COUNTRIES: dict[CountryCode, CountryDefinition] = {
    "CH": CountryDefinition(
        code="CH",
        name="Switzerland",
        currency_code="CHF",
        timezone="Europe/Zurich",
        default_language="de-CH",
        subdivision_label="canton",
        subdivisions={
            "AG": "Aargau", "AI": "Appenzell Innerrhoden", "AR": "Appenzell Ausserrhoden",
            "BE": "Bern", "BL": "Basel-Landschaft", "BS": "Basel-Stadt", "FR": "Fribourg",
            "GE": "Geneva", "GL": "Glarus", "GR": "Graubünden", "JU": "Jura", "LU": "Lucerne",
            "NE": "Neuchâtel", "NW": "Nidwalden", "OW": "Obwalden", "SG": "St. Gallen",
            "SH": "Schaffhausen", "SO": "Solothurn", "SZ": "Schwyz", "TG": "Thurgau",
            "TI": "Ticino", "UR": "Uri", "VD": "Vaud", "VS": "Valais", "ZG": "Zug", "ZH": "Zürich",
        },
        residence_statuses={
            "S": "Protection status S", "B": "Residence permit B", "C": "Settlement permit C",
            "F": "Provisional admission F", "N": "Asylum seeker N", "L": "Short stay permit L",
            "other": "Other",
        },
    ),
    "DE": CountryDefinition(
        code="DE",
        name="Germany",
        currency_code="EUR",
        timezone="Europe/Berlin",
        default_language="de-DE",
        subdivision_label="federal_state",
        subdivisions={
            "DE-BW": "Baden-Württemberg", "DE-BY": "Bavaria", "DE-BE": "Berlin",
            "DE-BB": "Brandenburg", "DE-HB": "Bremen", "DE-HH": "Hamburg",
            "DE-HE": "Hesse", "DE-MV": "Mecklenburg-Vorpommern", "DE-NI": "Lower Saxony",
            "DE-NW": "North Rhine-Westphalia", "DE-RP": "Rhineland-Palatinate",
            "DE-SL": "Saarland", "DE-SN": "Saxony", "DE-ST": "Saxony-Anhalt",
            "DE-SH": "Schleswig-Holstein", "DE-TH": "Thuringia",
        },
        residence_statuses={
            "temporary_protection_24": "Temporary protection under section 24",
            "residence_permit": "Residence permit", "permanent_residence": "Permanent residence",
            "eu_eea": "EU/EEA free movement", "asylum": "Asylum procedure", "other": "Other",
        },
    ),
    "AT": CountryDefinition(
        code="AT",
        name="Austria",
        currency_code="EUR",
        timezone="Europe/Vienna",
        default_language="de-AT",
        subdivision_label="federal_state",
        subdivisions={
            "AT-1": "Burgenland", "AT-2": "Carinthia", "AT-3": "Lower Austria",
            "AT-4": "Upper Austria", "AT-5": "Salzburg", "AT-6": "Styria",
            "AT-7": "Tyrol", "AT-8": "Vorarlberg", "AT-9": "Vienna",
        },
        residence_statuses={
            "displaced_person": "ID card for displaced persons", "red_white_red": "Red-White-Red Card",
            "residence_permit": "Residence permit", "eu_eea": "EU/EEA free movement",
            "asylum": "Asylum procedure", "other": "Other",
        },
    ),
}


def normalize_country_code(value: str | None, *, default: CountryCode = "CH") -> CountryCode:
    code = (value or default).strip().upper()
    if code not in COUNTRIES:
        raise ValueError(f"Unsupported country code: {code}")
    return code  # type: ignore[return-value]


def normalize_subdivision_code(country_code: str, value: str | None) -> str | None:
    if value is None or not value.strip():
        return None
    country = COUNTRIES[normalize_country_code(country_code)]
    raw = value.strip().upper()
    if country.code == "CH" and raw.startswith("CH-"):
        raw = raw[3:]
    elif country.code in {"DE", "AT"} and not raw.startswith(f"{country.code}-"):
        raw = f"{country.code}-{raw}"
    if raw not in country.subdivisions:
        raise ValueError(f"Unsupported subdivision '{value}' for {country.code}")
    return raw


def default_currency(country_code: str) -> str:
    return COUNTRIES[normalize_country_code(country_code)].currency_code


def default_timezone(country_code: str) -> str:
    return COUNTRIES[normalize_country_code(country_code)].timezone


def validate_currency(country_code: str, currency_code: str | None) -> str:
    expected = default_currency(country_code)
    value = (currency_code or expected).strip().upper()
    if value != expected:
        raise ValueError(f"Currency for {country_code} must be {expected}")
    return value
