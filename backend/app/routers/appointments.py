from __future__ import annotations

from typing import List

from fastapi import APIRouter, HTTPException, Query

from ..dependencies import CurrentAdmin, DBSession
from ..schemas import AppointmentCreate, AppointmentOut, AppointmentUpdate
from ..services import AppointmentService


router = APIRouter()


@router.get("/", response_model=List[AppointmentOut])
def list_appointments(db: DBSession, offset: int = Query(0, ge=0), limit: int = Query(100, ge=1, le=1000)) -> list[AppointmentOut]:
    return AppointmentService.list(db, offset=offset, limit=limit)


@router.get("/{appointment_id}", response_model=AppointmentOut)
def get_appointment(appointment_id: str, db: DBSession) -> AppointmentOut:
    obj = AppointmentService.get(db, appointment_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Appointment not found")
    return obj


@router.post("/", response_model=AppointmentOut)
def create_appointment(payload: AppointmentCreate, db: DBSession, _: CurrentAdmin) -> AppointmentOut:
    return AppointmentService.create(db, payload)


@router.put("/{appointment_id}", response_model=AppointmentOut)
def update_appointment(appointment_id: str, payload: AppointmentUpdate, db: DBSession, _: CurrentAdmin) -> AppointmentOut:
    obj = AppointmentService.get(db, appointment_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Appointment not found")
    return AppointmentService.update(db, obj, payload)


@router.delete("/{appointment_id}", status_code=204)
def delete_appointment(appointment_id: str, db: DBSession, _: CurrentAdmin) -> None:
    obj = AppointmentService.get(db, appointment_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Appointment not found")
    AppointmentService.delete(db, obj)
    return None


