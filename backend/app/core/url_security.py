from __future__ import annotations

import ipaddress
import socket
from urllib.parse import urljoin, urlparse

import httpx

MAX_RESPONSE_BYTES = 2 * 1024 * 1024
MAX_REDIRECTS = 5


def validate_public_http_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("Only public HTTP(S) URLs are allowed")
    try:
        addresses = {item[4][0] for item in socket.getaddrinfo(parsed.hostname, parsed.port or (443 if parsed.scheme == "https" else 80))}
    except socket.gaierror as exc:
        raise ValueError("URL host could not be resolved") from exc
    if not addresses:
        raise ValueError("URL host could not be resolved")
    for raw in addresses:
        ip = ipaddress.ip_address(raw.split("%", 1)[0])
        if not ip.is_global:
            raise ValueError("Private, loopback, link-local, and metadata addresses are forbidden")
    return url


def fetch_public_bytes(client: httpx.Client, url: str, *, max_bytes: int = MAX_RESPONSE_BYTES) -> tuple[bytes, str, str]:
    current = validate_public_http_url(url)
    for _ in range(MAX_REDIRECTS + 1):
        with client.stream("GET", current, follow_redirects=False) as response:
            if response.status_code in {301, 302, 303, 307, 308}:
                location = response.headers.get("location")
                if not location:
                    raise ValueError("Redirect missing location")
                current = validate_public_http_url(urljoin(current, location))
                continue
            response.raise_for_status()
            declared = response.headers.get("content-length")
            if declared and int(declared) > max_bytes:
                raise ValueError("Remote response is too large")
            chunks: list[bytes] = []
            total = 0
            for chunk in response.iter_bytes():
                total += len(chunk)
                if total > max_bytes:
                    raise ValueError("Remote response is too large")
                chunks.append(chunk)
            return b"".join(chunks), current, response.encoding or "utf-8"
    raise ValueError("Too many redirects")


def fetch_public_url(client: httpx.Client, url: str, *, max_bytes: int = MAX_RESPONSE_BYTES) -> tuple[str, str]:
    body, final_url, encoding = fetch_public_bytes(client, url, max_bytes=max_bytes)
    return body.decode(encoding, errors="replace"), final_url
