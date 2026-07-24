from __future__ import annotations

import json

from backend.app.core.config import get_settings
from backend.app.core.readiness import run_readiness_checks


def main() -> None:
    settings = get_settings()
    settings.assert_valid()
    checks = run_readiness_checks()
    print(json.dumps({"status": "ready", "checks": checks}, sort_keys=True))


if __name__ == "__main__":
    main()
