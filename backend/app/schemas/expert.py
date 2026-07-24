from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class ExpertSpecialty(str, Enum):
    tax = "tax"
    legal = "legal"
    insurance = "insurance"
    relocation = "relocation"
    career = "career"
    family = "family"


class ExpertQuestionCreate(BaseModel):
    listing_id: str
    question_text: str = Field(..., min_length=10, max_length=2000)
    asker_name: Optional[str] = Field(None, max_length=120)
    asker_language: Optional[str] = Field(None, max_length=10)


class ExpertQuestionAnswer(BaseModel):
    answer_text: str = Field(..., min_length=2, max_length=4000)


class ExpertQuestionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    listing_id: str
    asker_name: Optional[str] = None
    asker_language: Optional[str] = None
    question_text: str
    answer_text: Optional[str] = None
    status: str
    answered_at: Optional[datetime] = None
    created_at: datetime
