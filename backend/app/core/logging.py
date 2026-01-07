from __future__ import annotations

"""
Structured logging configuration for the backend.

We use `structlog` on top of the stdlib `logging` module and attach
request‑scoped context (request_id, path, method, etc.) via
`structlog.contextvars`.

All logs are emitted as single‑line JSON to stdout so that Render (or any
other host) can aggregate and search them easily.
"""

from typing import Any
import logging
import os
import sys

import structlog


def configure_logging(level: str | None = None) -> None:
    """
    Configure global logging.

    Call this once during app startup (early in `main.py`).
    """
    log_level = (level or os.getenv("LOG_LEVEL") or "INFO").upper()

    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, log_level, logging.INFO),
    )

    processors: list[structlog.types.Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.filter_by_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),
    ]

    structlog.configure(
        processors=processors,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )


def get_logger(**kwargs: Any) -> structlog.BoundLogger:
    """
    Convenience accessor for the shared structlog logger.
    """
    return structlog.get_logger(**kwargs)



