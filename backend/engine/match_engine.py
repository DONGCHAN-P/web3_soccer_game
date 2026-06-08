# -*- coding: utf-8 -*-
"""
경기 시뮬레이션 엔진

설계 원칙:
  - 스탯이 결과를 실제로 결정함 (랜덤 ≠ 순수 확률)
  - 90분을 30개 페이즈(3분 단위)로 나눠 진행
  - 각 페이즈: 미드필드 점유 싸움 → 공격 기회 생성 → 슈팅 → 골/선방

페이즈별 흐름:
  1. 미드필드 배틀   : 양 팀 midfield 스탯 차이 → 점유 확률
  2. 기회 창출      : 공격팀 attack+midfield  vs 수비팀 defense+midfield
  3. 슈팅           : 공격팀 shooting 스탯 → 유효슈팅 여부
  4. 골 결정        : 슈팅 품질 vs GK goalkeeping 스탯

목표 분포 (랜덤 팀 기준):
  - 경기당 슈팅: 12~16
  - 유효슈팅 비율: ~50%
  - 골 전환율: ~30%
  - 평균 골: 2.0~3.0 / 게임
"""

import math
import random
from dataclasses import dataclass, field
from typing import List

from .team import Team


# ── 이벤트 타입 ──────────────────────────────────────────────────
EVENT_GOAL   = "goal"
EVENT_SAVE   = "save"
EVENT_MISS   = "miss"
EVENT_TACKLE = "tackle"


@dataclass
class MatchEvent:
    minute: int
    event_type: str   # goal | save | miss | tackle
    team: str         # "home" | "away" | "defense"
    description: str


@dataclass
class MatchResult:
    home_team: str
    away_team: str
    home_score: int
    away_score: int
    events: List[MatchEvent]
    home_possession: float        # % (0~100)
    home_shots: int
    away_shots: int
    home_shots_on_target: int
    away_shots_on_target: int
    home_strengths: dict
    away_strengths: dict

    def score_str(self) -> str:
        return f"{self.home_team} {self.home_score} - {self.away_score} {self.away_team}"

    def to_dict(self) -> dict:
        return {
            "home_team": self.home_team,
            "away_team": self.away_team,
            "home_score": self.home_score,
            "away_score": self.away_score,
            "score": self.score_str(),
            "home_possession": self.home_possession,
            "away_possession": round(100 - self.home_possession, 1),
            "home_shots": self.home_shots,
            "away_shots": self.away_shots,
            "home_shots_on_target": self.home_shots_on_target,
            "away_shots_on_target": self.away_shots_on_target,
            "home_strengths": self.home_strengths,
            "away_strengths": self.away_strengths,
            "events": [
                {
                    "minute": e.minute,
                    "type": e.event_type,
                    "team": e.team,
                    "description": e.description,
                }
                for e in self.events
            ],
        }


# ── 경기 엔진 ────────────────────────────────────────────────────
class MatchEngine:
    """
    스탯 기반 경기 시뮬레이터.

    핵심 수식:
      sigmoid(diff) = 0.2 + 1/(1+exp(-diff*scale)) * 0.6
      → 스탯 차이를 [0.2, 0.8] 범위의 확률로 변환 (극단적 편차 방지)

    stat_to_prob(stat, weight):
      → stat 값을 0~1 확률로 변환, [MIN_PROB, MAX_PROB]로 클램프
    """

    PHASES = 30            # 3분 × 30 = 90분
    POSS_SCALE = 0.06      # 미드필드 스탯 차이 감도
    CHANCE_SCALE = 0.05    # 기회 창출 감도
    MAX_CHANCE_PROB = 0.72 # 페이즈당 최대 기회 생성 확률 (공격 극강팀 상한)

    # 슈팅: stat=43(평균팀) → 0.43*0.005+0.25=0.465 (46.5% 유효슈팅)
    SHOOT_WEIGHT = 0.005
    SHOOT_BASE   = 0.25

    # GK: stat=69(평균팀) → 69*0.004+0.10=0.376 (37.6% 선방) → 62.4% 골
    GK_WEIGHT = 0.007
    GK_BASE   = 0.20

    # ── 진입점 ────────────────────────────────────────────────────
    def simulate(self, home: Team, away: Team) -> MatchResult:
        home_str = home.get_strengths()
        away_str = away.get_strengths()

        events: List[MatchEvent] = []
        home_score = away_score = 0
        home_shots = away_shots = 0
        home_on_target = away_on_target = 0
        home_poss_count = 0

        for phase in range(self.PHASES):
            minute = phase * 3 + random.randint(1, 3)

            # ── 1. 미드필드 점유 배틀 ─────────────────────────────
            home_poss_prob = self._sigmoid(
                home_str["midfield"] - away_str["midfield"],
                self.POSS_SCALE,
            )
            if random.random() < home_poss_prob:
                atk_name, def_name = home.name, away.name
                atk_str, def_str   = home_str, away_str
                team_side          = "home"
                home_poss_count   += 1
            else:
                atk_name, def_name = away.name, home.name
                atk_str, def_str   = away_str, home_str
                team_side          = "away"

            # ── 2. 기회 창출 ──────────────────────────────────────
            atk_power   = atk_str["attack"]  * 0.65 + atk_str["midfield"] * 0.35
            def_power   = def_str["defense"] * 0.75 + def_str["midfield"] * 0.25
            chance_prob = self._sigmoid(atk_power - def_power, self.CHANCE_SCALE)
            chance_prob = min(chance_prob, self.MAX_CHANCE_PROB)

            if random.random() > chance_prob:
                if random.random() < 0.3:
                    events.append(MatchEvent(
                        minute=minute, event_type=EVENT_TACKLE,
                        team="defense",
                        description=f"🛡️ {minute}' {def_name} 수비 차단",
                    ))
                continue

            # 슛 시도
            if team_side == "home":
                home_shots += 1
            else:
                away_shots += 1

            # ── 3. 유효슈팅 여부 ──────────────────────────────────
            shoot_prob = self._stat_to_prob(
                atk_str["shooting"], self.SHOOT_WEIGHT, self.SHOOT_BASE,
                lo=0.30, hi=0.70,
            )
            if random.random() > shoot_prob:
                events.append(MatchEvent(
                    minute=minute, event_type=EVENT_MISS,
                    team=team_side,
                    description=f"💨 {minute}' {atk_name} 슈팅 빗나감",
                ))
                continue

            if team_side == "home":
                home_on_target += 1
            else:
                away_on_target += 1

            # ── 4. 골 결정 ────────────────────────────────────────
            gk_prob = self._stat_to_prob(
                def_str["goalkeeping"], self.GK_WEIGHT, self.GK_BASE,
                lo=0.50, hi=0.80,
            )
            if random.random() > gk_prob:
                if team_side == "home":
                    home_score += 1
                else:
                    away_score += 1
                events.append(MatchEvent(
                    minute=minute, event_type=EVENT_GOAL,
                    team=team_side,
                    description=(
                        f"⚽ {minute}' {atk_name} 골! "
                        f"({home_score}-{away_score})"
                    ),
                ))
            else:
                events.append(MatchEvent(
                    minute=minute, event_type=EVENT_SAVE,
                    team="defense",
                    description=f"🧤 {minute}' {def_name} 골키퍼 선방!",
                ))

        home_possession = round(home_poss_count / self.PHASES * 100, 1)

        return MatchResult(
            home_team=home.name,
            away_team=away.name,
            home_score=home_score,
            away_score=away_score,
            events=events,
            home_possession=home_possession,
            home_shots=home_shots,
            away_shots=away_shots,
            home_shots_on_target=home_on_target,
            away_shots_on_target=away_on_target,
            home_strengths=home_str,
            away_strengths=away_str,
        )

    # ── 수식 헬퍼 ────────────────────────────────────────────────
    @staticmethod
    def _sigmoid(diff: float, scale: float) -> float:
        """스탯 차이 → [0.2, 0.8] 확률"""
        raw = 1.0 / (1.0 + math.exp(-diff * scale))
        return 0.2 + raw * 0.6

    @staticmethod
    def _stat_to_prob(stat: float, weight: float, base: float,
                      lo: float = 0.20, hi: float = 0.85) -> float:
        """스탯 값 → 확률 [lo, hi]"""
        return max(lo, min(hi, stat * weight + base))
