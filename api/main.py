# -*- coding: utf-8 -*-
"""
FastAPI 백엔드
엔드포인트:
  POST /players/generate        - 선수 1명 생성
  POST /players/squad           - 11명 스쿼드 생성
  POST /match/simulate          - 두 팀 경기 시뮬레이션
  GET  /match/simulate/quick    - 랜덤 두 팀 즉시 경기 (테스트용)
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import sys
import os

# 프로젝트 루트를 sys.path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from engine.player import generate_player, generate_squad, POSITION_MAIN_ATTRS
from engine.team import Team
from engine.match_engine import MatchEngine

app = FastAPI(title="Web3 Soccer Game API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

engine = MatchEngine()


# ── 요청 스키마 ──────────────────────────────────────────────────
class GeneratePlayerRequest(BaseModel):
    position: Optional[str] = None   # None이면 랜덤
    player_id: int = 1

class SimulateMatchRequest(BaseModel):
    home_team_name: str = "Home FC"
    away_team_name: str = "Away FC"
    # 선수 데이터를 직접 넘기거나, 없으면 랜덤 생성
    home_players: Optional[List[dict]] = None
    away_players: Optional[List[dict]] = None


# ── 엔드포인트 ───────────────────────────────────────────────────
@app.get("/")
def root():
    return {"status": "ok", "message": "Web3 Soccer Game API"}


@app.post("/players/generate")
def generate_one_player(req: GeneratePlayerRequest):
    """선수 1명 생성"""
    if req.position and req.position not in POSITION_MAIN_ATTRS:
        raise HTTPException(
            status_code=400,
            detail=f"유효하지 않은 포지션: {req.position}. 가능: {list(POSITION_MAIN_ATTRS.keys())}",
        )
    player = generate_player(req.player_id, req.position)
    return player.to_dict()


@app.post("/players/squad")
def generate_full_squad(team_name: str = "My Team", start_id: int = 0):
    """4-3-3 기준 11명 스쿼드 생성"""
    players = generate_squad(start_id)
    team = Team(name=team_name, players=players)
    return team.to_dict()


@app.post("/match/simulate")
def simulate_match(req: SimulateMatchRequest):
    """두 팀 경기 시뮬레이션. 선수 데이터 없으면 랜덤 생성."""
    # 홈 팀
    if req.home_players and len(req.home_players) == 11:
        home_players = _dict_to_players(req.home_players, offset=0)
    else:
        home_players = generate_squad(start_id=0)

    # 어웨이 팀
    if req.away_players and len(req.away_players) == 11:
        away_players = _dict_to_players(req.away_players, offset=100)
    else:
        away_players = generate_squad(start_id=100)

    try:
        home = Team(name=req.home_team_name, players=home_players)
        away = Team(name=req.away_team_name, players=away_players)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    result = engine.simulate(home, away)
    return result.to_dict()


@app.get("/match/simulate/quick")
def quick_match():
    """랜덤 두 팀을 즉시 생성해 경기 (개발/테스트용)"""
    home = Team(name="Alpha FC", players=generate_squad(0))
    away = Team(name="Beta FC",  players=generate_squad(100))
    result = engine.simulate(home, away)
    return result.to_dict()


# ── 유틸 ────────────────────────────────────────────────────────
def _dict_to_players(data: List[dict], offset: int):
    """API로 받은 dict 리스트를 Player 객체로 복원"""
    from engine.player import Player
    players = []
    for i, d in enumerate(data):
        players.append(Player(
            id=d.get("id", offset + i),
            name=d.get("name", f"Player_{offset+i}"),
            position=d.get("position", "CM"),
            nationality=d.get("nationality", "Unknown"),
            stats=d.get("stats", {}),
            rating=d.get("rating", 60.0),
            tier=d.get("tier", "N"),
        ))
    return players
