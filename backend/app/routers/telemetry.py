from __future__ import annotations

from typing import Any, Dict, List, Optional
from datetime import datetime, timezone
from pathlib import Path
import json

from fastapi import APIRouter, HTTPException

from ..dependencies import CurrentAdmin

router = APIRouter()

LOG_DIR = Path("backend/logs")
LOG_DIR.mkdir(parents=True, exist_ok=True)


def _log_file_path(dt: Optional[datetime] = None) -> Path:
    d = (dt or datetime.now(timezone.utc)).strftime("%Y-%m-%d")
    return LOG_DIR / f"telemetry-{d}.jsonl"


@router.post("/batch")
def ingest_batch(payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    Ingest a batch of telemetry events.
    Body: { events: [{ id, ts, level, source, type, message?, meta? }] }
    """
    events = payload.get("events") or []
    if not isinstance(events, list):
        raise HTTPException(status_code=400, detail="events must be a list")
    # Append to JSONL file (one line per event). This is intentionally sync
    # and FastAPI will run it in a threadpool because the handler is not async.
    p = _log_file_path()
    accepted = 0
    with p.open("a", encoding="utf-8") as f:
        for raw in events:
            if not isinstance(raw, dict):
                continue
            evt = {
                "id": str(raw.get("id") or ""),
                "ts": str(raw.get("ts") or datetime.now(timezone.utc).isoformat()),
                "level": str(raw.get("level") or "info"),
                "source": str(raw.get("source") or "client"),
                "type": str(raw.get("type") or "event"),
                "message": raw.get("message"),
                "meta": raw.get("meta") or {},
            }
            f.write(json.dumps(evt, ensure_ascii=False) + "\n")
            accepted += 1
    return {"accepted": accepted}


@router.get("/admin")
def list_telemetry(_: CurrentAdmin, limit: int = 200, level: Optional[str] = None, source: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Return the latest telemetry events from today's and yesterday's files.
    """
    out: List[Dict[str, Any]] = []
    today = _log_file_path()
    yesterday = _log_file_path(datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0))
    files = [p for p in [today, yesterday] if p.exists()]
    for p in files:
        try:
            with p.open("r", encoding="utf-8") as f:
                for line in f:
                    try:
                        obj = json.loads(line.strip() or "{}")
                        if level and str(obj.get("level")) != level:
                            continue
                        if source and str(obj.get("source")) != source:
                            continue
                        out.append(obj)
                    except Exception:
                        continue
        except Exception:
            continue
    # sort by timestamp desc and cut
    def _key(o: Dict[str, Any]) -> str:
        return o.get("ts") or ""
    out.sort(key=_key, reverse=True)
    return out[: max(1, min(1000, limit))]



