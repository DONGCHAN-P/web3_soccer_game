# -*- coding: utf-8 -*-
"""
선수 생성 엔진
player_maker.py의 로직을 Player 데이터클래스 기반으로 리팩토링
"""

import numpy as np
from dataclasses import dataclass, field
from typing import Dict, Optional

# ── 포지션별 능력치 ──────────────────────────────────────────────
POSITION_MAIN_ATTRS: Dict[str, list] = {
    "GK":  ["반사 신경", "다이빙", "핸들링", "1대1 방어"],
    "CB":  ["태클", "헤딩", "인터셉트", "힘"],
    "RB":  ["속도", "태클", "크로스", "스태미너"],
    "LB":  ["속도", "태클", "크로스", "스태미너"],
    "CDM": ["태클", "인터셉트", "경기 지능", "위치 선정"],
    "CM":  ["패스", "경기 지능", "퍼스트 터치", "위치 선정"],
    "CAM": ["패스", "드리블", "공간 침투", "공격 성향"],
    "RW":  ["속도", "드리블", "크로스", "민첩성"],
    "LW":  ["속도", "드리블", "크로스", "민첩성"],
    "ST":  ["슛 정확도", "헤딩", "공간 침투", "균형 감각"],
}

POSITION_SEC_ATTRS: Dict[str, list] = {
    "GK":  ["킥 능력", "반응 속도", "펀칭"],
    "CB":  ["침착함", "균형감각", "패스"],
    "RB":  ["인터셉트", "드리블", "민첩성"],
    "LB":  ["인터셉트", "드리블", "민첩성"],
    "CDM": ["팀워크", "수비 성향", "스태미너"],
    "CM":  ["킥 능력", "공간 침투", "체력 회복력"],
    "CAM": ["슛 정확도", "크로스", "위치 선정"],
    "RW":  ["슛 정확도", "퍼스트 터치", "가속력"],
    "LW":  ["슛 정확도", "퍼스트 터치", "가속력"],
    "ST":  ["가속도", "공격 성향", "위치 선정"],
}

POSITION_DIST: Dict[str, float] = {
    "GK": 0.10, "CB": 0.20, "RB": 0.10, "LB": 0.10,
    "CDM": 0.10, "CM": 0.15, "CAM": 0.08,
    "RW": 0.07, "LW": 0.07, "ST": 0.08,
}

FIFA_NATIONS = [
    "Argentina", "France", "Brazil", "England", "Belgium", "Croatia",
    "Netherlands", "Italy", "Portugal", "Spain", "USA", "Mexico",
    "Germany", "Switzerland", "Morocco", "Uruguay", "Denmark", "Colombia",
    "Senegal", "Japan", "Sweden", "Poland", "Iran", "Serbia", "South Korea",
    "Ukraine", "Australia", "Chile", "Austria", "Tunisia", "Hungary",
    "Wales", "Algeria", "Russia", "Egypt", "Scotland", "Ecuador", "Nigeria",
    "Turkey", "Norway", "Paraguay", "Slovakia", "Canada", "Czech Republic",
    "Romania", "Peru", "Greece", "Costa Rica", "Venezuela", "Iceland",
    "Qatar", "Bosnia and Herzegovina", "Ghana", "Saudi Arabia", "Panama",
    "United Arab Emirates", "Slovenia", "South Africa", "Iraq", "China",
    "Honduras", "Montenegro", "Bulgaria", "Finland", "Jamaica", "Mali",
    "Israel", "Bolivia", "Gabon", "Uzbekistan", "Guinea", "Armenia",
    "Oman", "El Salvador", "Georgia", "Congo DR", "Benin", "Bahrain",
    "Uganda", "North Macedonia", "Syria", "Haiti", "Curacao", "Zambia",
    "Belarus", "Lebanon", "Luxembourg", "Equatorial Guinea", "Vietnam",
    "Madagascar", "Kyrgyzstan", "Kenya", "Jordan", "Palestine",
    "Trinidad and Tobago", "Mauritania", "India", "Central African Republic",
    "New Zealand", "Cape Verde",
]

ALL_ATTRS = sorted(set(
    sum(POSITION_MAIN_ATTRS.values(), []) +
    sum(POSITION_SEC_ATTRS.values(), []) + [
        "태클", "속도", "위치 선정", "1대1 방어", "민첩성", "반사 신경", "펀칭",
        "수비 성향", "다이빙", "인터셉트", "크로스", "슛 정확도", "가속력", "팀워크",
        "스태미너", "드리블", "균형감각", "공간 침투", "리더십", "패스", "킥 능력",
        "침착함", "헤딩", "경기 지능", "핸들링", "점프력", "공격 성향", "퍼스트 터치",
        "반응 속도", "힘",
    ]
))

TIER_THRESHOLDS = [(60, "N"), (70, "S"), (80, "R"), (90, "W"), (999, "G")]
TIER_LABELS = {"N": "Normal", "S": "Special", "R": "Rare", "W": "World Class", "G": "GOAT"}


# ── 데이터 클래스 ────────────────────────────────────────────────
@dataclass
class Player:
    id: int
    name: str
    position: str
    nationality: str
    stats: Dict[str, int]
    rating: float
    tier: str

    def get_stat(self, attr: str, default: int = 40) -> int:
        return self.stats.get(attr, default)

    def tier_label(self) -> str:
        return TIER_LABELS.get(self.tier, self.tier)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "position": self.position,
            "nationality": self.nationality,
            "rating": self.rating,
            "tier": self.tier,
            "tier_label": self.tier_label(),
            "stats": self.stats,
        }


# ── 헬퍼 ────────────────────────────────────────────────────────
def _get_tier(rating: float) -> str:
    for threshold, tier in TIER_THRESHOLDS:
        if rating < threshold:
            return tier
    return "G"


def _assign_nationality(rating: float) -> str:
    rank_index = min(int(rating), len(FIFA_NATIONS) - 1)
    weights = np.exp(np.linspace(10, 1, len(FIFA_NATIONS)))
    probs = weights[:rank_index + 1] / weights[:rank_index + 1].sum()
    return np.random.choice(FIFA_NATIONS[:rank_index + 1], p=probs)


# ── 핵심 생성 함수 ───────────────────────────────────────────────
def generate_player(player_id: int, position: Optional[str] = None) -> Player:
    """
    player_maker.py의 generate_random_player 로직과 동일.
    position 미지정 시 POSITION_DIST 비율로 랜덤 배정.
    """
    if position is None:
        positions = list(POSITION_DIST.keys())
        position = np.random.choice(positions, p=list(POSITION_DIST.values()))

    stats: Dict[str, int] = {}
    main_vals, sec_vals = [], []

    for attr in ALL_ATTRS:
        if attr in POSITION_MAIN_ATTRS.get(position, []):
            v = int(np.clip(np.random.normal(70, 30), 38, 99))
            main_vals.append(v)
        elif attr in POSITION_SEC_ATTRS.get(position, []):
            v = int(np.clip(np.random.normal(60, 20), 35, 90))
            sec_vals.append(v)
        else:
            v = int(np.clip(np.random.normal(35, 20), 1, 80))
        stats[attr] = v

    avg_main = np.mean(main_vals) * 0.7 if main_vals else 0
    avg_sec  = np.mean(sec_vals)  * 0.3 if sec_vals  else 0
    rating   = round(avg_main + avg_sec, 1)

    return Player(
        id=player_id,
        name=f"Player_{player_id:04d}",
        position=position,
        nationality=_assign_nationality(rating),
        stats=stats,
        rating=rating,
        tier=_get_tier(rating),
    )


def generate_squad(start_id: int = 0) -> list["Player"]:
    """
    11명짜리 기본 스쿼드 생성.
    포메이션 4-3-3 기준: GK×1, CB×2, RB×1, LB×1, CDM×1, CM×2, RW×1, LW×1, ST×1
    """
    formation_slots = [
        "GK", "CB", "CB", "RB", "LB",
        "CDM", "CM", "CM",
        "RW", "LW", "ST",
    ]
    return [generate_player(start_id + i, pos) for i, pos in enumerate(formation_slots)]
