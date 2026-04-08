from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.repositories import account_repo
from app.schemas.account import AccountCreate, AccountResponse, AccountUpdate
from app.services import summary as summary_service

router = APIRouter()


@router.get("/", response_model=list[AccountResponse])
def list_accounts(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return account_repo.get_accounts(db, skip=skip, limit=limit)


@router.post("/", response_model=AccountResponse, status_code=201)
def create_account(account: AccountCreate, db: Session = Depends(get_db)):
    return account_repo.create_account(db, account)


@router.get("/{account_id}", response_model=AccountResponse)
def get_account(account_id: int, db: Session = Depends(get_db)):
    account = account_repo.get_account(db, account_id)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    return account


@router.patch("/{account_id}", response_model=AccountResponse)
def update_account(account_id: int, updates: AccountUpdate, db: Session = Depends(get_db)):
    account = account_repo.update_account(db, account_id, updates)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    return account


@router.delete("/{account_id}", status_code=204)
def delete_account(account_id: int, db: Session = Depends(get_db)):
    if not account_repo.delete_account(db, account_id):
        raise HTTPException(status_code=404, detail="Account not found")


@router.get("/summary/stats")
def get_summary(db: Session = Depends(get_db)):
    """Aggregate health stats across all active accounts."""
    return summary_service.compute(db)
