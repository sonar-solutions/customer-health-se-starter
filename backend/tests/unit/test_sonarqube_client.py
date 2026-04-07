import pytest
import respx
import httpx
from datetime import datetime
from app.clients.sonarqube_client import SonarQubeClient


@pytest.fixture
def client():
    return SonarQubeClient(base_url="https://sonarcloud.io", token="fake-token")


@respx.mock
def test_get_project_status_success(client):
    respx.get("https://sonarcloud.io/api/qualitygates/project_status").mock(
        return_value=httpx.Response(
            200,
            json={"projectStatus": {"status": "OK", "conditions": []}},
        )
    )
    result = client.get_project_status("my-project")
    assert result["status"] == "OK"


@respx.mock
def test_get_project_status_returns_none_on_error(client):
    respx.get("https://sonarcloud.io/api/qualitygates/project_status").mock(
        return_value=httpx.Response(404)
    )
    result = client.get_project_status("missing-project")
    assert result is None


@respx.mock
def test_get_last_scan_date_parses_iso_date(client):
    respx.get("https://sonarcloud.io/api/project_analyses/search").mock(
        return_value=httpx.Response(
            200,
            json={"analyses": [{"date": "2024-03-15T10:30:00Z", "key": "AX1"}]},
        )
    )
    result = client.get_last_scan_date("my-project")
    assert isinstance(result, datetime)
    assert result.year == 2024


@respx.mock
def test_get_last_scan_date_returns_none_when_no_analyses(client):
    respx.get("https://sonarcloud.io/api/project_analyses/search").mock(
        return_value=httpx.Response(200, json={"analyses": []})
    )
    result = client.get_last_scan_date("my-project")
    assert result is None
