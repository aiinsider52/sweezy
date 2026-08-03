from __future__ import annotations

import asyncio
import re
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, Request, UploadFile, status
from fastapi.responses import FileResponse, RedirectResponse

from ..core.config import get_settings
from ..core.rate_limit import limiter
from ..dependencies import CurrentUser
from ..services.media_storage import MediaStorageError, get_media_storage

# Kept for legacy importers; it is no longer exposed by a static mount.
UPLOAD_DIR = Path("backend/uploads")
router = APIRouter()
public_router = APIRouter()

_ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}
_SAFE_UPLOAD_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._ -]{0,127}\Z")
_SAFE_STORAGE_KEY = re.compile(r"[a-f0-9]{32}\.(?:jpg|png|webp)\Z")


def _matches_image_signature(content: bytes, content_type: str) -> bool:
    if content_type == "image/jpeg":
        return content.startswith(b"\xff\xd8\xff")
    if content_type == "image/png":
        return content.startswith(b"\x89PNG\r\n\x1a\n")
    if content_type == "image/webp":
        return len(content) >= 12 and content[:4] == b"RIFF" and content[8:12] == b"WEBP"
    return False


def _validate_upload_name(name: str | None, expected_extension: str) -> None:
    if not name or not _SAFE_UPLOAD_NAME.fullmatch(name):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid filename")
    if not name.lower().endswith(expected_extension):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Filename extension does not match image type")


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
    _validate_upload_name(file.filename, extension)

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
    try:
        storage = get_media_storage(settings)
        await asyncio.to_thread(storage.put, filename, raw, content_type)
    except MediaStorageError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Media storage is unavailable",
        ) from exc
    return {"url": f"/media/{filename}", "filename": filename}


@public_router.get("/media/{filename}", include_in_schema=False)
def read_media(filename: str):
    if not _SAFE_STORAGE_KEY.fullmatch(filename):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media not found")
    try:
        storage = get_media_storage(get_settings())
        signed_url = storage.signed_read_url(filename)
        if signed_url:
            return RedirectResponse(signed_url, status_code=status.HTTP_307_TEMPORARY_REDIRECT)
        path = storage.local_path(filename)
    except MediaStorageError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Media storage is unavailable",
        ) from exc
    if path is None or not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media not found")
    return FileResponse(path)
