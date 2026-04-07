import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.database import Base
from app.repositories.account_repo import (
    create_account, get_account, get_accounts, update_account, delete_account
)
from app.schemas.account import AccountCreate, AccountUpdate


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)


def test_create_account(db):
    account = create_account(db, AccountCreate(name="Acme Corp", tier="trial"))
    assert account.id is not None
    assert account.name == "Acme Corp"
    assert account.tier == "trial"


def test_get_account(db):
    created = create_account(db, AccountCreate(name="Acme Corp"))
    fetched = get_account(db, created.id)
    assert fetched is not None
    assert fetched.id == created.id


def test_get_account_not_found(db):
    result = get_account(db, 9999)
    assert result is None


def test_get_accounts_returns_active_only(db):
    a1 = create_account(db, AccountCreate(name="Active Co"))
    a2 = create_account(db, AccountCreate(name="Deleted Co"))
    delete_account(db, a2.id)
    accounts = get_accounts(db)
    ids = [a.id for a in accounts]
    assert a1.id in ids
    assert a2.id not in ids


def test_update_account(db):
    account = create_account(db, AccountCreate(name="Old Name"))
    updated = update_account(db, account.id, AccountUpdate(name="New Name"))
    assert updated.name == "New Name"


def test_delete_account_soft_deletes(db):
    account = create_account(db, AccountCreate(name="To Delete"))
    result = delete_account(db, account.id)
    assert result is True
    fetched = get_account(db, account.id)
    assert fetched.is_active is False
