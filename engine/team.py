# -*- coding: utf-8 -*-
"""
팀 클래스
11명 선수 구성 + 포지션별 팀 강점 계산
"""

from dataclasses import dataclass, field
from typing import List, Dict
from .player import Player

# ── 포지션 그룹 ──────────────────────────────────────────────────
GK_POSITIONS  = {"GK"}
DEF_POSITIONS = {"CB", "RB", "LB"}
MID_POSITIONS = {"CDM", "CM", "CAM"}
ATK_POSITIONS = {"RW", "LW", "ST"}

# ── 역할별 핵심 스탯 ──────────────────────────────────────────────
GK_STATS    = ["반사 신경", "다이빙", "핸들링", "1대1 방어"]
DEF_STATS   = ["태클", "인터셉트", "헤딩", "힘", "위치 선정"]
MID_STATS   = ["패스", "경기 지능", "위치 선정", "퍼스트 터치", "스태미너"]
ATK_STATS   = ["드리블", "속도", "공간 침투", "민첩성", "가속력"]
SHOOT_STATS = ["슛 정확도", "공격 성향"]


def _avg_stats(players: List[Player], attrs: List[str]) -> float:
    if not players:
        return 50.0
    vals = [p.get_stat(a) for p in players for a in attrs]
    return round(sum(vals) / len(vals), 1) if vals else 50.0


# ── 팀 클래스 ────────────────────────────────────────────────────
@dataclass
class Team:
    name: str
    players: List[Player]

    def __post_init__(self):
        if len(self.players) != 11:
            raise ValueError(f"팀은 정확히 11명이어야 합니다. 현재: {len(self.players)}명")
        gk_count = sum(1 for p in self.players if p.position == "GK")
        if gk_count != 1:
            raise ValueError(f"골키퍼는 정확히 1명이어야 합니다. 현재: {gk_count}명")

    # ── 포지션별 선수 필터 ────────────────────────────────────────
    @property
    def gk(self) -> List[Player]:
        return [p for p in self.players if p.position in GK_POSITIONS]

    @property
    def defenders(self) -> List[Player]:
        return [p for p in self.players if p.position in DEF_POSITIONS]

    @property
    def midfielders(self) -> List[Player]:
        return [p for p in self.players if p.position in MID_POSITIONS]

    @property
    def attackers(self) -> List[Player]:
        return [p for p in self.players if p.position in ATK_POSITIONS]

    # ── 팀 강점 계산 ──────────────────────────────────────────────
    def get_strengths(self) -> Dict[str, float]:
        """
        경기 엔진이 사용하는 5가지 팀 강점 지표 (0~99 스케일).
        - goalkeeping : GK 능력
        - defense     : 수비진 능력
        - midfield    : 미드필드 지배력 (점유율 결정)
        - attack      : 공격 기회 창출력
        - shooting    : 슈팅 정확도 (득점 확률)
        """
        return {
            "goalkeeping": _avg_stats(self.gk, GK_STATS),
            "defense":     _avg_stats(self.defenders, DEF_STATS),
            "midfield":    _avg_stats(self.midfielders, MID_STATS),
            "attack":      _avg_stats(self.attackers, ATK_STATS),
            "shooting":    _avg_stats(self.attackers + self.midfielders, SHOOT_STATS),
        }

    @property
    def overall_rating(self) -> float:
        return round(sum(p.rating for p in self.players) / 11, 1)

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "overall_rating": self.overall_rating,
            "strengths": self.get_strengths(),
            "players": [p.to_dict() for p in self.players],
        }
