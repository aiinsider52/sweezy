from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

# Ensure repo root is on sys.path so we can import `backend`
REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.app.main import app  # noqa: E402


def run() -> None:
    spec = app.openapi()
    shared_dir = REPO_ROOT / "shared"
    shared_dir.mkdir(parents=True, exist_ok=True)
    out_path = shared_dir / "openapi.json"
    out_path.write_text(json.dumps(spec, indent=2, sort_keys=True) + "\n")
    print(f"Wrote {out_path}")
    subprocess.run(
        [sys.executable, str(REPO_ROOT / "backend" / "scripts" / "generate_clients.py")],
        cwd=REPO_ROOT,
        check=True,
    )


if __name__ == "__main__":
    run()
