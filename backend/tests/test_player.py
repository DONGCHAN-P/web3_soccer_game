import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from engine.player import generate_player, generate_squad, POSITION_MAIN_ATTRS, _get_tier


def test_generate_player_returns_valid_player():
    p = generate_player(1, "ST")
    assert p.id == 1
    assert p.position == "ST"
    assert isinstance(p.rating, float)
    assert 0 < p.rating < 100
    assert p.tier in ("N", "S", "R", "W", "G")
    assert len(p.stats) > 0


def test_generate_player_random_position():
    p = generate_player(1)
    assert p.position in POSITION_MAIN_ATTRS


def test_generate_player_stats_in_range():
    p = generate_player(1, "CM")
    for val in p.stats.values():
        assert 1 <= val <= 99, f"스탯 범위 초과: {val}"


def test_generate_player_unknown_position_still_generates_stats():
    # 엔진은 알 수 없는 포지션에서 예외를 던지지 않음
    # main/sec attrs가 없어 모든 스탯이 기타 분포(μ=35)로 생성됨
    p = generate_player(1, "INVALID")
    assert len(p.stats) > 0
    assert p.rating >= 0


def test_generate_squad_returns_11_players():
    squad = generate_squad(0)
    assert len(squad) == 11


def test_generate_squad_has_gk():
    squad = generate_squad(0)
    positions = [p.position for p in squad]
    assert "GK" in positions


def test_player_to_dict_has_required_keys():
    p = generate_player(1, "GK")
    d = p.to_dict()
    for key in ("id", "name", "position", "nationality", "rating", "tier", "stats"):
        assert key in d, f"to_dict()에 '{key}' 키 없음"


def test_tier_thresholds_coverage():
    assert _get_tier(59.9) == "N"
    assert _get_tier(60.0) == "S"
    assert _get_tier(69.9) == "S"
    assert _get_tier(70.0) == "R"
    assert _get_tier(90.0) == "G"
