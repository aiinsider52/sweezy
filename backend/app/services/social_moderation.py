from __future__ import annotations

import json
from typing import Any

from ..core.config import get_settings
from ..core.database import SessionLocal
from ..models.social import SocialProfile
from .media_storage import get_media_storage


async def moderate_social_profile(user_id: str) -> tuple[str, str | None]:
    settings = get_settings()
    if not settings.OPENAI_API_KEY:
        return ("approved", None)
    with SessionLocal() as db:
        profile = db.get(SocialProfile, user_id)
        if not profile:
            return ("rejected", "Profile not found")
        try:
            from openai import AsyncOpenAI

            client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
            prompt = f"""
Moderate social profile for adult community app in Switzerland.
Name: {profile.display_name}
Bio: {profile.bio}
Avatar URL: {profile.avatar_url or "none"}

Reject scams, sexual services, hate, harassment, contact details, document photos,
impersonation claims, illegal activity, or attempts to move money.
Return JSON only: {{"decision":"approved"|"rejected","reason":"..."|null}}
""".strip()
            content: list[dict[str, Any]] = [{"type": "input_text", "text": prompt}]
            image_url = profile.avatar_url
            if image_url and image_url.startswith("/media/"):
                image_url = get_media_storage(settings).signed_read_url(image_url.rsplit("/", 1)[-1])
            if image_url and image_url.startswith("https://"):
                content.append({"type": "input_image", "image_url": image_url})
            response = await client.responses.create(
                model="gpt-4.1-mini", input=[{"role": "user", "content": content}]
            )
            data = json.loads(getattr(response, "output_text", "") or "{}")
            decision = data.get("decision")
            if decision not in {"approved", "rejected"}:
                return ("pending", None)
            profile.moderation_status = decision
            profile.moderation_reason = data.get("reason") if decision == "rejected" else None
            db.add(profile); db.commit()
            return (decision, profile.moderation_reason)
        except Exception:
            return ("pending", None)
