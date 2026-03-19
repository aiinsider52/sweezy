from __future__ import annotations

import json
import os
from typing import TYPE_CHECKING

from ..core.logging import get_logger

if TYPE_CHECKING:
    from ..models.marketplace import ServiceListing

log = get_logger(module="marketplace_moderation")


def moderate_listing(listing_id: str) -> None:
    """Run AI moderation on a listing and update its status in the DB."""
    from ..core.database import SessionLocal
    from ..models.marketplace import ServiceListing

    with SessionLocal() as db:
        listing = db.query(ServiceListing).filter(ServiceListing.id == listing_id).first()
        if not listing:
            log.warning("moderate_listing_not_found", listing_id=listing_id)
            return

        decision, reason, score, score_reason = _call_openai(listing)
        listing.ai_score = score
        listing.ai_score_reason = score_reason
        if decision in ("approved", "rejected"):
            listing.status = decision
            listing.rejection_reason = reason
            db.add(listing)
            db.commit()
            log.info("moderate_listing_done", listing_id=listing_id, decision=decision)
        else:
            log.info("moderate_listing_pending", listing_id=listing_id)


def _call_openai(listing: ServiceListing) -> tuple[str, str | None, int | None, str | None]:
    """
    Returns (decision, reason, ai_score, ai_score_reason).
    Falls back to ("pending", None, None, None) if OpenAI is unavailable.
    """
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return ("pending", None, None, None)

    try:
        from openai import OpenAI

        client = OpenAI(api_key=api_key)

        prompt = (
            "Перевір оголошення про послугу для дошки оголошень іммігрантів у Швейцарії.\n\n"
            f"Заголовок: {listing.title}\n"
            f"Опис: {listing.description}\n"
            f"Категорія: {listing.category}\n\n"
            f"Ім'я автора: {listing.author_name}\n"
            f"Тип контакту: {listing.contact_type}\n"
            f"Контакт: {listing.contact_value}\n\n"
            "Відхили якщо:\n"
            "- Спам або реклама нерелевантних товарів\n"
            "- Шахрайство або підозрілий контент\n"
            "- Ненависницький або образливий контент\n"
            "- Незаконні послуги\n"
            "- Нерелевантно для іммігрантів у Швейцарії\n\n"
            "Також оціни, наскільки оголошення виглядає реальним і добросовісним, за шкалою від 0 до 10.\n"
            "0 = майже напевно фейк/спам, 10 = дуже правдоподібне оголошення.\n\n"
            'Відповідь тільки JSON: {"decision": "approved" | "rejected", "reason": "..." | null, "ai_score": 0-10, "ai_score_reason": "..."}'
        )

        chat = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
            max_tokens=200,
        )

        raw = (chat.choices[0].message.content or "").strip()
        # Strip markdown fences if model wraps response
        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1].rsplit("```", 1)[0].strip()

        data = json.loads(raw)
        decision = data.get("decision", "pending")
        reason = data.get("reason")
        score_raw = data.get("ai_score")
        score_reason = data.get("ai_score_reason")

        if decision not in ("approved", "rejected"):
            return ("pending", None, None, None)

        try:
            score = max(0, min(10, int(score_raw)))
        except Exception:
            score = None

        return (decision, reason, score, score_reason)

    except Exception as exc:
        log.warning("openai_moderation_error", error=str(exc))
        return ("pending", None, None, None)
