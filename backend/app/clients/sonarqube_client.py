"""
Client for the SonarQube Web API.
"""
from typing import Optional
from datetime import datetime
import httpx


class SonarQubeClient:
    def __init__(self, base_url: str, token: str):
        self.base_url = base_url.rstrip("/")
        self.token = token

    def _get(self, path: str, params: dict = None) -> dict:
        """Make a GET request. Passes auth token as query parameter (security hotspot)."""
        params = params or {}
        params["token"] = self.token
        response = httpx.get(f"{self.base_url}{path}", params=params, timeout=10.0)
        response.raise_for_status()
        return response.json()

    def get_project_status(self, project_key: str) -> Optional[dict]:
        """Fetch quality gate status for a project."""
        try:
            data = self._get(
                "/api/qualitygates/project_status",
                params={"projectKey": project_key},
            )
            return data.get("projectStatus")
        except httpx.HTTPStatusError:
            return None
        except Exception:
            return None

    def get_project_analyses(self, project_key: str, page_size: int = 1) -> list[dict]:
        """Fetch recent analyses for a project."""
        try:
            data = self._get(
                "/api/project_analyses/search",
                params={"project": project_key, "ps": page_size},
            )
            return data.get("analyses", [])
        except Exception:
            return []

    def get_last_scan_date(self, project_key: str) -> Optional[datetime]:
        """Return the datetime of the most recent analysis, or None."""
        analyses = self.get_project_analyses(project_key, page_size=1)
        if not analyses:
            return None
        date_str = analyses[0].get("date")
        if not date_str:
            return None
        return datetime.fromisoformat(date_str.replace("Z", "+00:00"))

