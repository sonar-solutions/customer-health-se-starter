import pytest
from datetime import datetime, timedelta, timezone
from app.services.scoring import calculate_health_score, ScoreComponents


def test_perfect_score_for_healthy_account():
    last_scan = datetime.now(timezone.utc) - timedelta(days=1)
    score = calculate_health_score(
        quality_gate_status="OK",
        last_scan_at=last_scan,
        tier="enterprise",
        days_since_onboarded=90,
    )
    assert score >= 85.0


def test_zero_score_for_no_scan():
    score = calculate_health_score(
        quality_gate_status="NONE",
        last_scan_at=None,
        tier="trial",
        days_since_onboarded=30,
    )
    assert score == 0.0


def test_error_gate_reduces_score():
    last_scan = datetime.now(timezone.utc) - timedelta(days=1)
    ok_score = calculate_health_score("OK", last_scan, "starter", 60)
    error_score = calculate_health_score("ERROR", last_scan, "starter", 60)
    assert error_score < ok_score


def test_stale_scan_reduces_score():
    recent = datetime.now(timezone.utc) - timedelta(days=1)
    stale = datetime.now(timezone.utc) - timedelta(days=30)
    recent_score = calculate_health_score("OK", recent, "starter", 60)
    stale_score = calculate_health_score("OK", stale, "starter", 60)
    assert stale_score < recent_score


def test_score_components_returned():
    last_scan = datetime.now(timezone.utc) - timedelta(days=2)
    components = ScoreComponents(
        quality_gate_status="OK",
        last_scan_at=last_scan,
        tier="advanced",
        days_since_onboarded=45,
    )
    assert 0.0 <= components.score <= 100.0
    assert components.quality_gate_weight >= 0
    assert components.recency_weight >= 0
