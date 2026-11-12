import datetime
import os
import sys

import jwt

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from app import create_app  # noqa: E402
from forecast import forecast_next  # noqa: E402


def make_client():
    c = create_app("sqlite:///:memory:").test_client()
    token = jwt.encode({"sub": "1", "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=1)},
                       "dev-secret-change-me", algorithm="HS256")
    return c, {"Authorization": f"Bearer {token}"}


def test_requires_auth():
    c, _ = make_client()
    assert c.get("/api/expenses").status_code == 401


def test_crud_and_summary():
    c, h = make_client()
    r = c.post("/api/expenses", json={"title": "Lunch", "amount": 250, "category": "food", "spent_on": "2026-01-10"}, headers=h)
    assert r.status_code == 201
    c.post("/api/expenses", json={"title": "Cab", "amount": 100, "category": "travel", "spent_on": "2026-02-10"}, headers=h)
    assert len(c.get("/api/expenses", headers=h).get_json()) == 2
    s = c.get("/api/expenses/summary", headers=h).get_json()
    assert s["by_category"]["food"] == 250
    assert c.delete(f"/api/expenses/{r.get_json()['id']}", headers=h).status_code == 204


def test_validation():
    c, h = make_client()
    assert c.post("/api/expenses", json={"title": "x", "amount": -5}, headers=h).status_code == 400


def test_forecast_function():
    assert forecast_next([]) == 0.0
    assert forecast_next([100, 200, 300]) == 400.0


def test_predict_endpoint():
    c, h = make_client()
    assert c.get("/api/expenses/predict", headers=h).status_code == 200
