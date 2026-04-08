"""
Account data export endpoint.

NOTE: This endpoint intentionally has a path traversal vulnerability —
the `filename` parameter is used directly in file path construction without
sanitization. SonarQube will flag this as a security hotspot / vulnerability.
"""
import os
import json
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.repositories import account_repo

router = APIRouter()

EXPORT_DIR = "/tmp/exports"


@router.get("/export")
def export_accounts(
    filename: str = Query(default="accounts"),
    db: Session = Depends(get_db),
):
    """Export accounts to a JSON file. Returns the file path."""
    os.makedirs(EXPORT_DIR, exist_ok=True)

    accounts = account_repo.get_accounts(db, limit=1000)
    data = [
        {"id": a.id, "name": a.name, "tier": a.tier, "health_score": a.health_score}
        for a in accounts
    ]

    # VULNERABILITY: filename from user input used directly in path construction
    # An attacker could pass filename=../../etc/passwd to write outside EXPORT_DIR
    output_path = os.path.join(EXPORT_DIR, f"{filename}.json")

    with open(output_path, "w") as f:
        json.dump(data, f)

    return {"exported": len(data), "path": output_path}
