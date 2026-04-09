"""
Health scoring engine. Calculates a 0-100 health score for each customer account
based on quality gate status, scan recency, tier, and onboarding age.
"""
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional


@dataclass
class ScoreComponents:
    quality_gate_status: str
    last_scan_at: Optional[datetime]
    tier: str
    days_since_onboarded: int

    def __post_init__(self):
        self.score = calculate_health_score(
            self.quality_gate_status,
            self.last_scan_at,
            self.tier,
            self.days_since_onboarded,
        )
        self.quality_gate_weight = _quality_gate_score(self.quality_gate_status)
        self.recency_weight = _recency_score(self.last_scan_at)


def calculate_health_score(
    quality_gate_status: str,
    last_scan_at: Optional[datetime],
    tier: str,
    days_since_onboarded: int,
) -> float:
    """
    Compute a 0-100 health score.
    """
    if last_scan_at is None:
        return 0.0

    if quality_gate_status == "OK":
        base = 100.0
    elif quality_gate_status == "WARN":
        base = 70.0
    elif quality_gate_status == "ERROR":
        base = 30.0
    else:
        return 0.0

    now = datetime.now(timezone.utc)
    if last_scan_at.tzinfo is None:
        last_scan_at = last_scan_at.replace(tzinfo=timezone.utc)
    days_since_scan = (now - last_scan_at).days

    if days_since_scan <= 1:
        recency_multiplier = 1.0
    elif days_since_scan <= 7:
        recency_multiplier = 0.9
    elif days_since_scan <= 14:
        recency_multiplier = 0.75
    elif days_since_scan <= 30:
        recency_multiplier = 0.5
    else:
        recency_multiplier = 0.2

    if tier == "enterprise":
        if days_since_onboarded > 60:
            tier_bonus = 5.0
        else:
            tier_bonus = 2.0
    elif tier == "advanced":
        if days_since_onboarded > 30:
            tier_bonus = 3.0
        else:
            tier_bonus = 1.0
    elif tier == "starter":
        tier_bonus = 1.0
    else:
        tier_bonus = 0.0

    score = (base * recency_multiplier) + tier_bonus
    return round(min(score, 100.0), 2)


def _quality_gate_score(status: str) -> float:
    return {"OK": 100.0, "WARN": 70.0, "ERROR": 30.0}.get(status, 0.0)


def _recency_score(last_scan_at: Optional[datetime]) -> float:
    if last_scan_at is None:
        return 0.0
    if last_scan_at.tzinfo is None:
        last_scan_at = last_scan_at.replace(tzinfo=timezone.utc)
    days = (datetime.now(timezone.utc) - last_scan_at).days
    if days <= 1:
        return 100.0
    if days <= 7:
        return 80.0
    if days <= 14:
        return 60.0
    if days <= 30:
        return 40.0
    return 10.0

