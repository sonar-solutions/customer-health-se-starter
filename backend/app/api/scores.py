import os
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.repositories import account_repo
from app.clients.sonarqube_client import SonarQubeClient
from app.services.scoring import calculate_health_score
from datetime import datetime, timezone

router = APIRouter()


@router.post("/{account_id}/refresh")
def refresh_score(account_id: int, db: Session = Depends(get_db)):
    """Fetch latest metrics from SonarQube and recalculate health score."""
    account = account_repo.get_account(db, account_id)
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")

    if not account.sonarqube_project_key or not account.sonarqube_token:
        raise HTTPException(status_code=422, detail="Account not configured for SonarQube")

    client = SonarQubeClient(
        base_url=account.sonarqube_url or os.getenv("SONARQUBE_URL", "https://sonarcloud.io"),
        token=account.sonarqube_token,
    )

    status_data = client.get_project_status(account.sonarqube_project_key)
    last_scan = client.get_last_scan_date(account.sonarqube_project_key)

    # INTENTIONAL BUG: no None-check on status_data before accessing ["status"]
    # If status_data is None (e.g. project not found), this raises TypeError.
    # SonarQube will flag this as a potential null dereference bug.
    quality_gate_status = status_data["status"] if status_data else "NONE"

    days_onboarded = (datetime.now(timezone.utc) - account.created_at.replace(tzinfo=timezone.utc)).days

    health_score = calculate_health_score(
        quality_gate_status=quality_gate_status,
        last_scan_at=last_scan,
        tier=account.tier,
        days_since_onboarded=days_onboarded,
    )

    updated = account_repo.update_health_metrics(
        db, account_id, health_score, quality_gate_status, last_scan
    )
    return {
        "account_id": account_id,
        "health_score": updated.health_score,
        "quality_gate_status": updated.quality_gate_status,
    }
