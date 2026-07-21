from __future__ import annotations

from backend.app.main import app


def test_openapi_contract_has_unique_operation_ids() -> None:
    spec = app.openapi()
    operation_ids = [
        operation["operationId"]
        for path_item in spec["paths"].values()
        for method, operation in path_item.items()
        if method in {"get", "post", "put", "patch", "delete"}
    ]
    assert len(operation_ids) == len(set(operation_ids))


def test_auth_contract_exposes_backend_identity() -> None:
    spec = app.openapi()
    token_pair = spec["components"]["schemas"]["TokenPair"]
    assert {"access_token", "refresh_token", "user_id", "email"}.issubset(token_pair["required"])
