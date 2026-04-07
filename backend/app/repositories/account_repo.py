from typing import Optional
from sqlalchemy.orm import Session
from app.models.account import Account
from app.schemas.account import AccountCreate, AccountUpdate


def get_account(db: Session, account_id: int) -> Optional[Account]:
    return db.query(Account).filter(Account.id == account_id).first()


def get_accounts(db: Session, skip: int = 0, limit: int = 100) -> list[Account]:
    return db.query(Account).filter(Account.is_active == True).offset(skip).limit(limit).all()


def create_account(db: Session, account: AccountCreate) -> Account:
    db_account = Account(**account.model_dump())
    db.add(db_account)
    db.commit()
    db.refresh(db_account)
    return db_account


def update_account(db: Session, account_id: int, updates: AccountUpdate) -> Optional[Account]:
    db_account = get_account(db, account_id)
    if not db_account:
        return None
    for field, value in updates.model_dump(exclude_unset=True).items():
        setattr(db_account, field, value)
    db.commit()
    db.refresh(db_account)
    return db_account


def update_health_metrics(
    db: Session,
    account_id: int,
    health_score: float,
    quality_gate_status: str,
    last_scan_at,
) -> Optional[Account]:
    db_account = get_account(db, account_id)
    if not db_account:
        return None
    db_account.health_score = health_score
    db_account.quality_gate_status = quality_gate_status
    db_account.last_scan_at = last_scan_at
    db.commit()
    db.refresh(db_account)
    return db_account


def delete_account(db: Session, account_id: int) -> bool:
    db_account = get_account(db, account_id)
    if not db_account:
        return False
    db_account.is_active = False
    db.commit()
    return True
