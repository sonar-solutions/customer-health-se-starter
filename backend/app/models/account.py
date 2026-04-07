from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean
from app.database import Base


class Account(Base):
    __tablename__ = "accounts"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, index=True)
    sonarqube_project_key = Column(String, nullable=True)
    sonarqube_url = Column(String, nullable=True)
    sonarqube_token = Column(String, nullable=True)
    tier = Column(String, default="trial")  # trial, starter, advanced, enterprise
    owner = Column(String, nullable=True)
    health_score = Column(Float, nullable=True)
    last_scan_at = Column(DateTime, nullable=True)
    quality_gate_status = Column(String, nullable=True)  # OK, WARN, ERROR, NONE
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
