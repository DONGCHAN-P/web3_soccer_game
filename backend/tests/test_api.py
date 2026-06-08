import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from fastapi.testclient import TestClient
from api.main import app

client = TestClient(app)


def test_root_returns_ok():
    r = client.get("/")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_generate_player_endpoint():
    r = client.post("/players/generate", json={"position": "ST", "player_id": 1})
    assert r.status_code == 200
    data = r.json()
    assert data["position"] == "ST"
    assert "rating" in data
    assert "tier" in data


def test_generate_player_invalid_position():
    r = client.post("/players/generate", json={"position": "INVALID"})
    assert r.status_code == 400


def test_generate_squad_endpoint():
    r = client.post("/players/squad", params={"team_name": "Test FC"})
    assert r.status_code == 200
    data = r.json()
    assert "players" in data
    assert len(data["players"]) == 11


def test_quick_match_endpoint():
    r = client.get("/match/simulate/quick")
    assert r.status_code == 200
    data = r.json()
    assert "home_score" in data
    assert "away_score" in data
    assert "events" in data
    assert "home_possession" in data
