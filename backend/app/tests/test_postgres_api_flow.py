import os

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

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


def test_login_me_and_user_list(client: TestClient) -> None:
    response = client.post("/api/v1/auth/login", json={"username_or_email": "admin", "password": "Cambiar123!"})

    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert "users_permissions.manage_users" in body["user"]["effective_permissions"]

    headers = {"Authorization": "Bearer " + body["access_token"]}
    me = client.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["username"] == "admin"

    users = client.get("/api/v1/users", headers=headers)
    assert users.status_code == 200
    assert users.json()[0]["username"] == "admin"