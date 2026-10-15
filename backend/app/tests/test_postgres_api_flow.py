import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.security import create_access_token
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.services.seed import seed_phase1

TEST_DATABASE_URL = os.getenv("TEST_DATABASE_URL")


@pytest.fixture()
def client():
    if not TEST_DATABASE_URL:
        pytest.skip("Define TEST_DATABASE_URL con una base PostgreSQL de pruebas para ejecutar integración.")

    engine = create_engine(TEST_DATABASE_URL, pool_pre_ping=True)
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    TestingSession = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False)
    db = TestingSession()
    try:
        seed_phase1(db)
        db.commit()
    finally:
        db.close()

    def override_db():
        session = TestingSession()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_db
    try:
        yield TestClient(app)
    finally:
        app.dependency_overrides.clear()
        Base.metadata.drop_all(engine)
        engine.dispose()


def admin_headers(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "admin", "password": "Cambiar123!"},
    )
    assert response.status_code == 200
    return {"Authorization": "Bearer " + response.json()["access_token"]}


def test_login_me_and_user_list(client: TestClient) -> None:
    headers = admin_headers(client)
    me = client.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["username"] == "admin"

    users = client.get("/api/v1/users", headers=headers)
    assert users.status_code == 200
    assert users.json()[0]["username"] == "admin"


def test_refresh_token_issues_new_session(client: TestClient) -> None:
    login = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "admin", "password": "Cambiar123!"},
    )
    assert login.status_code == 200
    original = login.json()

    refreshed = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": original["refresh_token"]},
    )
    assert refreshed.status_code == 200
    renewed = refreshed.json()
    assert renewed["access_token"]
    assert renewed["refresh_token"]
    assert renewed["user"]["username"] == "admin"

    me = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {renewed['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["username"] == "admin"


def test_refresh_rejects_invalid_or_wrong_type_token(client: TestClient) -> None:
    invalid = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "not-a-valid-token"},
    )
    assert invalid.status_code == 401

    access_token = create_access_token("00000000-0000-0000-0000-000000000001")
    wrong_type = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": access_token},
    )
    assert wrong_type.status_code == 401


def test_work_order_create_and_list(client: TestClient) -> None:
    headers = admin_headers(client)
    payload = {
        "client_name": "Cliente de prueba",
        "description": "OIT de integración automatizada",
        "priority": "normal",
        "components": [{"name": "Soporte mecanizado", "quantity_required": 2}],
    }

    created = client.post("/api/v1/mes/work-orders", json=payload, headers=headers)
    assert created.status_code == 201
    created_body = created.json()
    assert created_body["client_name"] == "Cliente de prueba"
    assert created_body["status"] == "draft"
    assert len(created_body["components"]) == 1
    assert created_body["components"][0]["quantity_required"] == 2

    listed = client.get("/api/v1/mes/work-orders", headers=headers)
    assert listed.status_code == 200
    assert any(order["id"] == created_body["id"] for order in listed.json())


def test_work_orders_require_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/mes/work-orders").status_code == 401
    response = client.post(
        "/api/v1/mes/work-orders",
        json={
            "client_name": "Cliente de prueba",
            "description": "OIT sin sesión",
            "components": [{"name": "Pieza", "quantity_required": 1}],
        },
    )
    assert response.status_code == 401



def test_user_without_work_order_permissions_is_forbidden(client: TestClient) -> None:
    admin = admin_headers(client)
    created_user = client.post(
        "/api/v1/users",
        headers=admin,
        json={
            "full_name": "Usuario sin permisos",
            "username": "sin.permisos",
            "email": "sin.permisos@example.test",
            "password": "PruebaSegura123",
            "is_active": True,
            "role_ids": [],
            "permission_overrides": [],
        },
    )
    assert created_user.status_code == 201

    login = client.post(
        "/api/v1/auth/login",
        json={"username_or_email": "sin.permisos", "password": "PruebaSegura123"},
    )
    assert login.status_code == 200
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    listed = client.get("/api/v1/mes/work-orders", headers=headers)
    assert listed.status_code == 403

    created = client.post(
        "/api/v1/mes/work-orders",
        headers=headers,
        json={
            "client_name": "Cliente de prueba",
            "description": "OIT por usuario sin permisos",
            "components": [{"name": "Pieza", "quantity_required": 1}],
        },
    )
    assert created.status_code == 403
