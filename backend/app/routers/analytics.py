from __future__ import annotations

from typing import Dict, Any, Optional

from fastapi import APIRouter, HTTPException, status

from ..dependencies import CurrentUser, DBSession
from ..models.analytics import PaywallEvent

router = APIRouter()


@router.post("/paywall", status_code=status.HTTP_204_NO_CONTENT)
def log_paywall_event(payload: Dict[str, Any], db: DBSession, user: Optional[CurrentUser] = None):
    event_type = (payload.get("event_type") or "").strip().lower()
    context = (payload.get("context") or "").strip()
    if event_type not in {"view", "cta_click", "purchase_start", "dismiss"}:
        raise HTTPException(status_code=400, detail="Invalid event_type")
    try:
        row = PaywallEvent(
            user_id=getattr(user, "id", None) if user else None,
            event_type=event_type,
            context=context[:255] if context else None,
        )
        db.add(row)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to log")
    return


