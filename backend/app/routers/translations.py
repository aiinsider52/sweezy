from typing import Dict, List, Optional
from fastapi import APIRouter, HTTPException

from ..dependencies import DBSession, CurrentUser, OptionalAdmin, require_roles
from ..models.translation import Translation
from ..models.glossary import GlossaryTerm

router = APIRouter()


@router.get("/", response_model=List[Dict])
def list_translations(
    db: DBSession,
    is_admin: OptionalAdmin,
    entity: Optional[str] = None,
    language: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100,
) -> List[Dict]:
    q = db.query(Translation)
    if entity:
        q = q.filter(Translation.entity == entity)
    if language:
        q = q.filter(Translation.language == language)
    if status and status != "approved" and not is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    if status:
        q = q.filter(Translation.status == status)
    elif not is_admin:
        q = q.filter(Translation.status == "approved")
    rows = q.order_by(Translation.updated_at.desc()).limit(limit).all()
    return [
        {
            "id": r.id,
            "entity": r.entity,
            "entity_id": r.entity_id,
            "language": r.language,
            "status": r.status,
            "title": r.title,
            "description": r.description,
            "updated_at": r.updated_at.isoformat(),
        }
        for r in rows
    ]


@router.get("/glossary", response_model=List[Dict])
def list_glossary(db: DBSession, q: Optional[str] = None, limit: int = 200) -> List[Dict]:
    query = db.query(GlossaryTerm)
    if q:
        like = f"%{q}%"
        query = query.filter(GlossaryTerm.term.ilike(like))
    rows = query.order_by(GlossaryTerm.term.asc()).limit(limit).all()
    return [
        {"id": r.id, "term": r.term, "uk": r.uk, "ru": r.ru, "en": r.en, "description": r.description}
        for r in rows
    ]


@router.post("/", response_model=Dict, dependencies=[require_roles("translator", "editor")])
def create_or_update_translation(payload: Dict, db: DBSession, user: CurrentUser) -> Dict:
    entity = payload.get("entity")
    entity_id = payload.get("entity_id")
    language = payload.get("language")
    if not entity or not entity_id or not language:
        raise HTTPException(status_code=400, detail="entity, entity_id, language are required")
    row = (
        db.query(Translation)
        .filter(Translation.entity == entity, Translation.entity_id == entity_id, Translation.language == language)
        .first()
    )
    fields = {
        "title": payload.get("title"),
        "description": payload.get("description"),
        "content": payload.get("content"),
    }
    if row:
        for k, v in fields.items():
            if v is not None:
                setattr(row, k, v)
        row.status = payload.get("status", row.status)
        db.add(row)
    else:
        row = Translation(entity=entity, entity_id=entity_id, language=language, author_email=user.email, **fields)
        db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id}


@router.post("/{translation_id}/approve", dependencies=[require_roles("editor")])
def approve_translation(translation_id: str, db: DBSession) -> Dict:
    row = db.query(Translation).filter(Translation.id == translation_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Not found")
    row.status = "approved"
    db.add(row)
    db.commit()
    return {"ok": True}


@router.post("/glossary", response_model=Dict, dependencies=[require_roles("editor", "admin")])
def create_glossary_term(payload: Dict, db: DBSession) -> Dict:
    term = GlossaryTerm(
        term=payload["term"],
        uk=payload.get("uk"),
        ru=payload.get("ru"),
        en=payload.get("en"),
        description=payload.get("description"),
    )
    db.add(term)
    db.commit()
    db.refresh(term)
    return {"id": term.id}


@router.delete("/glossary/{term_id}", dependencies=[require_roles("editor", "admin")])
def delete_glossary_term(term_id: str, db: DBSession) -> Dict:
    t = db.query(GlossaryTerm).filter(GlossaryTerm.id == term_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Not found")
    db.delete(t)
    db.commit()
    return {"ok": True}

