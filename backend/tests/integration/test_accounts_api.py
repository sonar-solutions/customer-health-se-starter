import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.main import app
from app.database import Base, get_db


@pytest.fixture
def client():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)

    def override_get_db():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=engine)


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_and_list_accounts(client):
    response = client.post("/api/accounts/", json={"name": "Acme Corp", "tier": "trial"})
    assert response.status_code == 201
    account_id = response.json()["id"]

    response = client.get("/api/accounts/")
    assert response.status_code == 200
    ids = [a["id"] for a in response.json()]
    assert account_id in ids


def test_get_account_not_found(client):
    response = client.get("/api/accounts/9999")
    assert response.status_code == 404


def test_update_account(client):
    response = client.post("/api/accounts/", json={"name": "Old Name"})
    account_id = response.json()["id"]
    response = client.patch(f"/api/accounts/{account_id}", json={"name": "New Name"})
    assert response.status_code == 200
    assert response.json()["name"] == "New Name"


def test_delete_account(client):
    response = client.post("/api/accounts/", json={"name": "To Delete"})
    account_id = response.json()["id"]
    response = client.delete(f"/api/accounts/{account_id}")
    assert response.status_code == 204
    response = client.get("/api/accounts/")
    ids = [a["id"] for a in response.json()]
    assert account_id not in ids
