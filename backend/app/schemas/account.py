from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class AccountBase(BaseModel):
    name: str
    sonarqube_project_key: Optional[str] = None
    sonarqube_url: Optional[str] = None
    tier: str = "trial"
    owner: Optional[str] = None
    is_active: bool = True


class AccountCreate(AccountBase):
    sonarqube_token: Optional[str] = None


class AccountUpdate(BaseModel):
    name: Optional[str] = None
    sonarqube_project_key: Optional[str] = None
    sonarqube_url: Optional[str] = None
    sonarqube_token: Optional[str] = None
    tier: Optional[str] = None
    owner: Optional[str] = None
    is_active: Optional[bool] = None


class AccountResponse(AccountBase):
    id: int
    health_score: Optional[float] = None
    last_scan_at: Optional[datetime] = None
    quality_gate_status: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
