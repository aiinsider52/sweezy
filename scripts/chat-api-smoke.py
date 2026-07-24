#!/usr/bin/env python3
"""API smoke for marketplace chat (one or two verified accounts).

One-user (buyer against an existing listing):
  BASE_URL=https://sweezy-9xyk.onrender.com \\
  BUYER_EMAIL=... BUYER_PASSWORD=... \\
  ./scripts/chat-api-smoke.py

Two-user (seller listing → admin approve → buyer message → seller reply):
  also set SELLER_EMAIL/SELLER_PASSWORD and ADMIN_EMAIL/ADMIN_PASSWORD
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from typing import Any, Dict, Optional, Tuple

BASE_URL = os.environ.get("BASE_URL", "https://sweezy-9xyk.onrender.com").rstrip("/")
API = f"{BASE_URL}/api/v1"


def die(msg: str, code: int = 1) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def call(
    method: str,
    path: str,
    *,
    token: Optional[str] = None,
    body: Optional[Dict[str, Any]] = None,
) -> Tuple[int, Any]:
    data = None if body is None else json.dumps(body).encode()
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            raw = resp.read().decode() or "null"
            return resp.status, json.loads(raw)
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode()
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = raw
        return exc.code, parsed


def login(email: str, password: str) -> str:
    code, payload = call("POST", "/auth/login", body={"email": email, "password": password})
    if code != 200:
        die(f"login failed for {email}: {code} {payload}")
    return payload["access_token"]


def main() -> None:
    buyer_email = os.environ.get("BUYER_EMAIL")
    buyer_password = os.environ.get("BUYER_PASSWORD")
    if not buyer_email or not buyer_password:
        die("Set BUYER_EMAIL and BUYER_PASSWORD")

    print("== login buyer ==")
    buyer = login(buyer_email, buyer_password)

    listing_id = os.environ.get("LISTING_ID")
    seller_token = None
    seller_email = os.environ.get("SELLER_EMAIL")
    seller_password = os.environ.get("SELLER_PASSWORD")
    admin_email = os.environ.get("ADMIN_EMAIL")
    admin_password = os.environ.get("ADMIN_PASSWORD")

    if seller_email and seller_password and admin_email and admin_password:
        print("== two-user path: seller creates listing ==")
        seller_token = login(seller_email, seller_password)
        admin = login(admin_email, admin_password)
        code, created = call(
            "POST",
            "/marketplace/",
            token=seller_token,
            body={
                "listing_type": "service",
                "title": "Chat smoke listing",
                "description": "Temporary listing for chat API smoke.",
                "category": "moving",
                "canton": "ZH",
                "price_info": "CHF 1",
                "contact_type": "email",
                "contact_value": "smoke@example.com",
                "author_name": "Smoke Seller",
                "image_urls": [],
            },
        )
        if code != 201:
            die(f"create listing failed: {code} {created}")
        listing_id = created["id"]
        code, approved = call("PATCH", f"/admin/marketplace/{listing_id}/approve", token=admin, body={})
        if code != 200:
            die(f"approve failed: {code} {approved}")
        print(f"approved listing {listing_id}")
    elif not listing_id:
        print("== pick existing listing ==")
        code, listings = call("GET", "/marketplace?limit=20", token=buyer)
        if code != 200:
            die(f"list marketplace failed: {code} {listings}")
        items = listings.get("items", listings if isinstance(listings, list) else [])
        if not items:
            die("no marketplace listings")
        listing_id = items[0]["id"]

    print(f"== create conversation for {listing_id} ==")
    code, conv = call("POST", "/chat/conversations", token=buyer, body={"listing_id": listing_id})
    if code not in (200, 201):
        die(f"create conversation failed: {code} {conv}")
    conv_id = conv["id"]
    print(f"conversation {conv_id}")

    print("== get conversation ==")
    code, got = call("GET", f"/chat/conversations/{conv_id}", token=buyer)
    if code != 200 or got.get("id") != conv_id:
        die(f"get conversation failed: {code} {got}")
    print("get_ok")

    print("== send message ==")
    client_id = str(uuid.uuid4())
    code, msg = call(
        "POST",
        f"/chat/conversations/{conv_id}/messages",
        token=buyer,
        body={"client_message_id": client_id, "body": "chat api smoke"},
    )
    if code != 201:
        die(f"send failed: {code} {msg}")
    msg_id = msg["id"]

    if seller_token:
        print("== seller unread + reply ==")
        code, unread = call("GET", "/chat/conversations/unread-count", token=seller_token)
        if code != 200 or unread.get("count", 0) < 1:
            die(f"seller unread unexpected: {code} {unread}")
        print("seller_unread", unread["count"])
        code, reply = call(
            "POST",
            f"/chat/conversations/{conv_id}/messages",
            token=seller_token,
            body={"client_message_id": str(uuid.uuid4()), "body": "smoke reply"},
        )
        if code != 201:
            die(f"seller reply failed: {code} {reply}")

    print("== buyer mark read ==")
    code, _ = call(
        "POST",
        f"/chat/conversations/{conv_id}/read",
        token=buyer,
        body={"message_id": msg_id},
    )
    if code != 200:
        die(f"mark read failed: {code}")

    print(f"OK chat smoke conversation={conv_id} message={msg_id}")


if __name__ == "__main__":
    main()
