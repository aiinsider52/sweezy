from __future__ import annotations

"""
Shared password strength validation used across the API.

Rules are intentionally aligned with the iOS client:
  - At least 8 characters
  - At least one uppercase letter
  - At least one lowercase letter
  - At least one digit
  - At least one punctuation / symbol
  - No whitespace characters
"""

import re
from typing import Tuple


_UPPER_RE = re.compile(r"[A-Z]")
_LOWER_RE = re.compile(r"[a-z]")
_DIGIT_RE = re.compile(r"[0-9]")
_SPACE_RE = re.compile(r"\s")


def validate_password_strength(password: str) -> Tuple[bool, str | None]:
    """
    Return (ok, error_message).

    When `ok` is False, `error_message` contains a human‑readable reason that
    can be safely returned to the client.
    """
    if len(password) < 8:
        return False, "Password must be at least 8 characters long."
    if _SPACE_RE.search(password):
        return False, "Password must not contain spaces."
    if not _UPPER_RE.search(password):
        return False, "Password must contain at least one uppercase letter."
    if not _LOWER_RE.search(password):
        return False, "Password must contain at least one lowercase letter."
    if not _DIGIT_RE.search(password):
        return False, "Password must contain at least one digit."
    if not any(ch for ch in password if not ch.isalnum()):
        return False, "Password must contain at least one special character."
    return True, None



