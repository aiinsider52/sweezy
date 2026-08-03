from __future__ import annotations

from pathlib import Path

import pytest

from backend.app.core.config import Settings
from backend.app.services.media_storage import (
    LocalMediaStorage,
    MediaStorageError,
    S3MediaStorage,
    get_media_storage,
)


def _settings(**overrides) -> Settings:
    values = {"APP_ENV": "test", "DATABASE_URL": "sqlite://"}
    values.update(overrides)
    return Settings(_env_file=None, **values)


def test_local_storage_is_limited_to_development_and_tests(tmp_path: Path) -> None:
    storage = get_media_storage(_settings(MEDIA_LOCAL_DIR=str(tmp_path)))
    assert isinstance(storage, LocalMediaStorage)
    storage.put("a" * 32 + ".jpg", b"image", "image/jpeg")
    assert (tmp_path / ("a" * 32 + ".jpg")).read_bytes() == b"image"

    with pytest.raises(MediaStorageError, match="required"):
        get_media_storage(_settings(APP_ENV="production"))


def test_production_ephemeral_fallback_requires_explicit_opt_in(tmp_path: Path) -> None:
    storage = get_media_storage(
        _settings(
            APP_ENV="production",
            MEDIA_LOCAL_DIR=str(tmp_path),
            MEDIA_ALLOW_EPHEMERAL_FALLBACK=True,
        )
    )
    assert isinstance(storage, LocalMediaStorage)


def test_local_storage_rejects_path_traversal(tmp_path: Path) -> None:
    storage = LocalMediaStorage(tmp_path)
    with pytest.raises(MediaStorageError, match="Invalid media key"):
        storage.put("../escape.jpg", b"image", "image/jpeg")


def test_complete_object_storage_configuration_selects_s3() -> None:
    storage = get_media_storage(
        _settings(
            APP_ENV="production",
            MEDIA_S3_BUCKET="private-media",
            MEDIA_S3_ACCESS_KEY_ID="access",
            MEDIA_S3_SECRET_ACCESS_KEY="secret",
        )
    )
    assert isinstance(storage, S3MediaStorage)


def test_partial_object_storage_configuration_is_invalid() -> None:
    settings = _settings(MEDIA_S3_BUCKET="private-media")
    with pytest.raises(RuntimeError, match="configured together"):
        settings.assert_valid()
