from __future__ import annotations

from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Appointment
from ..schemas import AppointmentCreate, AppointmentUpdate


class AppointmentService:
    @staticmethod
    def list(db: Session, *, offset: int = 0, limit: int = 100) -> List[Appointment]:
        stmt = select(Appointment).offset(offset).limit(limit)
        return list(db.execute(stmt).scalars().all())

    @staticmethod
    def get(db: Session, appointment_id: str) -> Optional[Appointment]:
        return db.get(Appointment, appointment_id)

    @staticmethod
    def create(db: Session, data: AppointmentCreate) -> Appointment:
        obj = Appointment(**data.model_dump())
        db.add(obj)
        db.commit()
        db.refresh(obj)
        return obj

    @staticmethod
    def update(db: Session, appointment: Appointment, data: AppointmentUpdate) -> Appointment:
        for key, value in data.model_dump(exclude_unset=True).items():
            setattr(appointment, key, value)
        db.add(appointment)
        db.commit()
        db.refresh(appointment)
        return appointment

    @staticmethod
    def delete(db: Session, appointment: Appointment) -> None:
        db.delete(appointment)
        db.commit()


