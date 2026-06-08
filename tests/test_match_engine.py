import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from engine.player import generate_squad
from engine.team import Team
from engine.match_engine import MatchEngine


def _make_teams():
    home = Team(name="Home FC", players=generate_squad(0))
    away = Team(name="Away FC", players=generate_squad(100))
    return home, away


def test_simulate_returns_result():
    eng = MatchEngine()
    home, away = _make_teams()
    result = eng.simulate(home, away)
    assert result is not None


def test_simulate_result_has_scores():
    eng = MatchEngine()
    home, away = _make_teams()
    result = eng.simulate(home, away)
    d = result.to_dict()
    assert "home_score" in d
    assert "away_score" in d
    assert d["home_score"] >= 0
    assert d["away_score"] >= 0


def test_simulate_result_has_events():
    eng = MatchEngine()
    home, away = _make_teams()
    result = eng.simulate(home, away)
    d = result.to_dict()
    assert "events" in d
    assert isinstance(d["events"], list)


def test_simulate_result_has_possession():
    eng = MatchEngine()
    home, away = _make_teams()
    result = eng.simulate(home, away)
    d = result.to_dict()
    assert "home_possession" in d
    assert 0 <= d["home_possession"] <= 100


def test_simulate_multiple_runs_are_different():
    eng = MatchEngine()
    results = set()
    for _ in range(5):
        home, away = _make_teams()
        r = eng.simulate(home, away)
        d = r.to_dict()
        results.add((d["home_score"], d["away_score"]))
    assert len(results) >= 2
