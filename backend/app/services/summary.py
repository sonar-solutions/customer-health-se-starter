"""
Aggregate health statistics across all active accounts.
"""
from sqlalchemy.orm import Session
from app.repositories import account_repo


def compute(db: Session) -> dict:
    accounts = account_repo.get_accounts(db, limit=1000)

    if not accounts:
        return {
            "total": 0,
            "scored": 0,
            "avg_health_score": None,
            "by_quality_gate": {},
            "by_tier": {},
        }

    scored = [a for a in accounts if a.health_score is not None]
    avg = round(sum(a.health_score for a in scored) / len(scored), 1) if scored else None

    by_gate: dict[str, int] = {}
    for a in accounts:
        status = a.quality_gate_status or "NONE"
        by_gate[status] = by_gate.get(status, 0) + 1

    by_tier: dict[str, int] = {}
    for a in accounts:
        by_tier[a.tier] = by_tier.get(a.tier, 0) + 1

    return {
        "total": len(accounts),
        "scored": len(scored),
        "avg_health_score": avg,
        "by_quality_gate": by_gate,
        "by_tier": by_tier,
    }
