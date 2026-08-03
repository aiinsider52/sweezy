from __future__ import annotations

import socket

import httpx
import pytest

from backend.app.core.url_security import fetch_public_url, validate_public_http_url


@pytest.mark.parametrize(
    "url",
    [
        "http://127.0.0.1/admin",
        "http://169.254.169.254/latest/meta-data/",
        "http://[::1]/",
        "file:///etc/passwd",
        "https://user:password@example.com/",
    ],
)
def test_import_url_rejects_non_public_targets(url: str) -> None:
    with pytest.raises(ValueError):
        validate_public_http_url(url)


def test_import_url_rejects_dns_resolving_private(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        socket,
        "getaddrinfo",
        lambda *_args, **_kwargs: [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("10.0.0.8", 80))],
    )
    with pytest.raises(ValueError):
        validate_public_http_url("https://attacker.example/feed")


def test_import_redirect_target_is_revalidated(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        socket,
        "getaddrinfo",
        lambda *_args, **_kwargs: [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))],
    )
    transport = httpx.MockTransport(
        lambda _request: httpx.Response(302, headers={"location": "http://127.0.0.1/secret"})
    )
    with httpx.Client(transport=transport) as client, pytest.raises(ValueError):
        fetch_public_url(client, "https://example.com/feed")


def test_import_response_size_is_limited(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        socket,
        "getaddrinfo",
        lambda *_args, **_kwargs: [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))],
    )
    transport = httpx.MockTransport(
        lambda _request: httpx.Response(200, headers={"content-length": "100"}, content=b"x" * 100)
    )
    with httpx.Client(transport=transport) as client, pytest.raises(ValueError):
        fetch_public_url(client, "https://example.com/feed", max_bytes=10)
