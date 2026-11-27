from __future__ import annotations

import math

from fastapi.testclient import TestClient

from app.main import app
from app.services import ssp_mmc
from app.services.memory import MemoryState, next_state, recall_probability


def test_recall_probability_curve():
    assert recall_probability(10, 0) == 1.0
    assert math.isclose(recall_probability(10, 10), 0.5, rel_tol=1e-9)
    assert recall_probability(10, 20) < recall_probability(10, 10)


def test_success_increases_stability():
    state = MemoryState(h=5.0, d=4.0)
    nxt = next_state(state, 5.0, True)
    assert nxt.h > state.h
    assert nxt.d == state.d


def test_failure_increases_difficulty():
    state = MemoryState(h=30.0, d=4.0)
    nxt = next_state(state, 30.0, False)
    assert nxt.d > state.d
    assert nxt.h < state.h


def test_policy_lookup_in_range():
    table = ssp_mmc.load(ssp_mmc.Path("app/data/policy.json"))
    for d in (1.0, 3.0, 5.0, 7.0, 10.0):
        for h in (1.0, 10.0, 100.0):
            interval = ssp_mmc.lookup_interval(table, h, d)
            assert 1 <= interval <= 730


def test_review_plan_endpoint():
    with TestClient(app) as client:
        resp = client.post(
            "/api/review/plan",
            json={"h": 1.0, "d": 3.0, "days_since_review": 1, "recalled": True},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert 0 <= data["recall_probability"] <= 1
        assert 1 <= data["interval_days"] <= 730
        assert data["next_h"] > 1.0


def test_mastered_word_gets_maintenance_interval():
    with TestClient(app) as client:
        resp = client.post(
            "/api/review/plan",
            json={
                "h": 400,
                "d": 5,
                "days_since_review": 180,
                "recalled": True,
                "last_interval": 30,
            },
        )
        assert resp.status_code == 200
        assert resp.json()["interval_days"] == 365
