from __future__ import annotations

from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, Request, UploadFile, status

from ..core.config import get_settings
from ..core.rate_limit import limiter
from ..dependencies import CurrentUser


UPLOAD_DIR = Path("backend/uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

router = APIRouter()

_ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


def _matches_image_signature(content: bytes, content_type: str) -> bool:
    if content_type == "image/jpeg":
        return content.startswith(b"\xff\xd8\xff")
    if content_type == "image/png":
        return content.startswith(b"\x89PNG\r\n\x1a\n")
    if content_type == "image/webp":
        return len(content) >= 12 and content[:4] == b"RIFF" and content[8:12] == b"WEBP"
    return False


@router.post("/upload", status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def upload_media(
    request: Request,
    _: CurrentUser,
    file: UploadFile = File(...),
) -> dict[str, str]:
    settings = get_settings()
    content_type = (file.content_type or "").lower()
    extension = _ALLOWED_IMAGE_TYPES.get(content_type)
    if extension is None:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="Unsupported image type")

    content = bytearray()
    try:
        while chunk := await file.read(1024 * 1024):
            content.extend(chunk)
            if len(content) > settings.MEDIA_MAX_UPLOAD_BYTES:
                raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Image is too large")
    finally:
        await file.close()

    raw = bytes(content)
    if not raw or not _matches_image_signature(raw, content_type):
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="Invalid image content")

    filename = f"{uuid4().hex}{extension}"
    target = (UPLOAD_DIR / filename).resolve()
    upload_root = UPLOAD_DIR.resolve()
    if target.parent != upload_root:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid filename")

    target.write_bytes(raw)
    return {"url": f"/media/{filename}", "filename": filename}
