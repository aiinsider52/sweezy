from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from ..core.config import Settings
from ..core.logging import get_logger

log = get_logger(component="media_storage")


class MediaStorageError(RuntimeError):
    """Raised when media cannot be stored or accessed safely."""


class MediaStorage(Protocol):
    def put(self, key: str, content: bytes, content_type: str) -> None: ...

    def signed_read_url(self, key: str) -> str | None: ...

    def local_path(self, key: str) -> Path | None: ...


def _safe_local_path(root: Path, key: str) -> Path:
    root = root.resolve()
    target = (root / key).resolve()
    if target.parent != root:
        raise MediaStorageError("Invalid media key")
    return target


@dataclass(frozen=True)
class LocalMediaStorage:
    root: Path

    def put(self, key: str, content: bytes, content_type: str) -> None:
        target = _safe_local_path(self.root, key)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)

    def signed_read_url(self, key: str) -> None:
        return None

    def local_path(self, key: str) -> Path:
        return _safe_local_path(self.root, key)


@dataclass(frozen=True)
class S3MediaStorage:
    settings: Settings

    def _client(self):
        try:
            import boto3
            from botocore.config import Config
        except ImportError as exc:  # pragma: no cover - deployment dependency guard
            raise MediaStorageError("S3 client dependency is unavailable") from exc

        return boto3.client(
            "s3",
            endpoint_url=self.settings.MEDIA_S3_ENDPOINT_URL,
            region_name=self.settings.MEDIA_S3_REGION,
            aws_access_key_id=self.settings.MEDIA_S3_ACCESS_KEY_ID,
            aws_secret_access_key=self.settings.MEDIA_S3_SECRET_ACCESS_KEY,
            config=Config(signature_version="s3v4"),
        )

    def _object_key(self, key: str) -> str:
        prefix = self.settings.MEDIA_S3_PREFIX.strip("/")
        return f"{prefix}/{key}" if prefix else key

    def put(self, key: str, content: bytes, content_type: str) -> None:
        try:
            self._client().put_object(
                Bucket=self.settings.MEDIA_S3_BUCKET,
                Key=self._object_key(key),
                Body=content,
                ContentType=content_type,
                CacheControl="private, max-age=0, no-store",
            )
        except Exception as exc:
            raise MediaStorageError("Object storage upload failed") from exc

    def signed_read_url(self, key: str) -> str:
        try:
            return self._client().generate_presigned_url(
                "get_object",
                Params={"Bucket": self.settings.MEDIA_S3_BUCKET, "Key": self._object_key(key)},
                ExpiresIn=self.settings.MEDIA_SIGNED_URL_TTL_SECONDS,
            )
        except Exception as exc:
            raise MediaStorageError("Object storage signing failed") from exc

    def local_path(self, key: str) -> None:
        return None


def get_media_storage(settings: Settings) -> MediaStorage:
    configured = all(
        (
            settings.MEDIA_S3_BUCKET,
            settings.MEDIA_S3_ACCESS_KEY_ID,
            settings.MEDIA_S3_SECRET_ACCESS_KEY,
        )
    )
    if configured:
        return S3MediaStorage(settings)
    if settings.APP_ENV.lower() in {"development", "test"} or settings.MEDIA_ALLOW_EPHEMERAL_FALLBACK:
        if settings.APP_ENV.lower() == "production":
            log.warning("media_ephemeral_fallback_enabled")
        return LocalMediaStorage(Path(settings.MEDIA_LOCAL_DIR))
    raise MediaStorageError("Object storage is required for media in this environment")
