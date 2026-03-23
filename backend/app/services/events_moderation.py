from __future__ import annotations

import json

from ..core.config import get_settings
from ..core.database import SessionLocal
from ..models.event_listing import EventListing


async def moderate_event_listing(event_id: str) -> tuple[str, str | None]:
    settings = get_settings()
    if not settings.OPENAI_API_KEY:
        return ("pending", None)

    with SessionLocal() as db:
        event = db.get(EventListing, event_id)
        if not event:
            return ("pending", None)

        try:
            from openai import AsyncOpenAI

            client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
            prompt = f"""
Перевір подію для дошки спільноти іммігрантів у Швейцарії.

Назва: {event.title}
Опис: {event.description}
Категорія: {event.category}
Місто: {event.city}
Адреса: {event.address}
Організатор: {event.organizer_name}

Відхили якщо:
- спам або нерелевантна реклама
- шахрайство або підозрілий контент
- ненависницький або образливий контент
- незаконна подія або небезпечний контент
- подія нерелевантна для життя, інтеграції або спільноти у Швейцарії

Відповідь тільки JSON:
{{"decision":"approved"|"rejected","reason":"..."|null}}
""".strip()

            response = await client.responses.create(
                model="gpt-4.1-mini",
                input=prompt,
            )
            raw_text = getattr(response, "output_text", "") or ""
            data = json.loads(raw_text)
            decision = data.get("decision")
            reason = data.get("reason")

            if decision not in {"approved", "rejected"}:
                return ("pending", None)

            event.status = decision
            event.rejection_reason = reason if decision == "rejected" else None
            db.add(event)
            db.commit()
            return (decision, event.rejection_reason)
        except Exception:
            return ("pending", None)
