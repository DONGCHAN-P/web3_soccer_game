# Phase 0: 코드 정리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 현재 루트에 혼재된 파일들을 `backend/` / `frontend/` 구조로 재편하고, 레거시 파일 삭제 및 중복 JS 로직을 API 호출로 교체한다.

**Architecture:** Python 엔진과 API는 `backend/`로, HTML 프론트엔드는 `frontend/`로 분리한다. `manager.html` 내장 시뮬레이션 JS는 FastAPI `/match/simulate` 호출로 교체한다. 구조 변경 전에 pytest 테스트를 먼저 작성해 리팩토링 안전망으로 사용한다.

**Tech Stack:** Python 3.x, FastAPI, pytest, pytest-asyncio, httpx (TestClient용)

---

## 목표 폴더 구조

```
web3_soccer_game/
├── backend/
│   ├── api/
│   │   ├── __init__.py
│   │   └── main.py
│   ├── engine/
│   │   ├── __init__.py
│   │   ├── match_engine.py
│   │   ├── player.py
│   │   └── team.py
│   ├── tests/
│   │   ├── __init__.py
│   │   ├── test_player.py
│   │   ├── test_match_engine.py
│   │   └── test_api.py
│   └── requirements.txt
├── frontend/
│   ├── manager.html     ← 내장 simulate() 제거, API 호출로 교체
│   └── manager3d.html   ← 그대로 이동
├── docs/
│   └── superpowers/
│       ├── specs/
│       │   └── 2026-06-08-soccer-game-design.md
│       └── plans/
│           └── 2026-06-08-phase0-code-cleanup.md
└── README.md
```

---

## Task 1: 테스트 의존성 추가

**Files:**
- Modify: `requirements.txt`

- [ ] **Step 1: requirements.txt에 테스트 의존성 추가**

`requirements.txt` 내용을 다음으로 교체:

```
fastapi>=0.110.0
uvicorn>=0.27.0
pydantic>=2.0.0
numpy>=1.26.0
pytest>=8.0.0
httpx>=0.27.0
```

- [ ] **Step 2: 의존성 설치 확인**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
pip install -r requirements.txt
```

Expected: 설치 완료, 오류 없음

- [ ] **Step 3: Commit**

```bash
git add requirements.txt
git commit -m "chore: add pytest and httpx to requirements"
```

---

## Task 2: 엔진 단위 테스트 작성 (현재 위치에서)

**Files:**
- Create: `tests/__init__.py`
- Create: `tests/test_player.py`
- Create: `tests/test_match_engine.py`

> 폴더 이동 전에 테스트를 먼저 작성한다. 이후 Task 4에서 경로만 조정한다.

- [ ] **Step 1: tests/ 디렉토리 생성**

```bash
mkdir tests
touch tests/__init__.py
```

- [ ] **Step 2: test_player.py 작성**

`tests/test_player.py`:

```python
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from engine.player import generate_player, generate_squad, POSITION_MAIN_ATTRS, TIER_THRESHOLDS

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

def test_generate_player_invalid_position_raises():
    import pytest
    with pytest.raises(Exception):
        # position 유효성은 API 레이어에서 처리하므로 엔진 자체는 예외 없이 실행됨
        # 이 테스트는 알 수 없는 포지션이 들어올 때 stats가 비어있지 않음을 검증
        p = generate_player(1, "INVALID")
        # INVALID 포지션은 main/sec attrs가 없으므로 모든 스탯이 기타 분포로 생성됨
        assert len(p.stats) > 0

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
    # 60 미만 → N
    from engine.player import _get_tier
    assert _get_tier(59.9) == "N"
    assert _get_tier(60.0) == "S"
    assert _get_tier(69.9) == "S"
    assert _get_tier(70.0) == "R"
    assert _get_tier(90.0) == "G"
```

- [ ] **Step 3: test_match_engine.py 작성**

`tests/test_match_engine.py`:

```python
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

def test_simulate_multiple_runs_are_different():
    eng = MatchEngine()
    results = set()
    for _ in range(5):
        home, away = _make_teams()
        r = eng.simulate(home, away)
        d = r.to_dict()
        results.add((d["home_score"], d["away_score"]))
    # 5번 중 최소 2개는 다른 결과여야 함 (랜덤 시뮬레이션)
    assert len(results) >= 2
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
python -m pytest tests/ -v
```

Expected: 모든 테스트 PASS

- [ ] **Step 5: Commit**

```bash
git add tests/
git commit -m "test: add engine unit tests before restructuring"
```

---

## Task 3: API 통합 테스트 작성

**Files:**
- Create: `tests/test_api.py`

- [ ] **Step 1: test_api.py 작성**

`tests/test_api.py`:

```python
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
```

- [ ] **Step 2: API 테스트 실행**

```bash
python -m pytest tests/test_api.py -v
```

Expected: 모든 테스트 PASS

- [ ] **Step 3: Commit**

```bash
git add tests/test_api.py
git commit -m "test: add API integration tests"
```

---

## Task 4: 폴더 구조 재편

**Files:**
- Create: `backend/` (디렉토리)
- Move: `engine/` → `backend/engine/`
- Move: `api/` → `backend/api/`
- Move: `requirements.txt` → `backend/requirements.txt`
- Modify: `backend/api/main.py` (import 경로 수정)
- Move: `tests/` → `backend/tests/`

- [ ] **Step 1: backend/ 구조 생성 및 파일 이동**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
mkdir backend
cp -r engine backend/engine
cp -r api backend/api
cp -r tests backend/tests
cp requirements.txt backend/requirements.txt
```

- [ ] **Step 2: backend/api/main.py의 sys.path 수정**

현재 `backend/api/main.py`의 19번째 줄:
```python
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
```

이 코드는 `api/` 부모 디렉토리(= `backend/`)를 path에 추가하므로 이동 후에도 동일하게 동작한다. 변경 불필요.

- [ ] **Step 3: backend/tests/ 내 sys.path 수정**

`backend/tests/test_player.py`, `test_match_engine.py`, `test_api.py` 각각의 첫 두 줄을:

```python
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
```

위 코드는 `tests/` 부모 디렉토리(= `backend/`)를 path에 추가하므로 이동 후에도 동일하게 동작한다. 변경 불필요.

- [ ] **Step 4: 이동 후 테스트 통과 확인**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game/backend"
python -m pytest tests/ -v
```

Expected: 모든 테스트 PASS (경로 문제 없음 확인)

- [ ] **Step 5: frontend/ 디렉토리 생성 및 HTML 이동**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
mkdir frontend
cp manager.html frontend/manager.html
cp manager3d.html frontend/manager3d.html
```

- [ ] **Step 6: 원본 파일/폴더 삭제**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
rm -rf engine api tests
rm requirements.txt
rm manager.html manager3d.html
```

- [ ] **Step 7: 최종 구조 확인**

```bash
find . -not -path "./.git/*" -not -path "./backend/__pycache__/*" -not -path "./backend/engine/__pycache__/*"
```

Expected 출력:
```
./README.md (아직 없어도 무방)
./backend/api/__init__.py
./backend/api/main.py
./backend/engine/__init__.py
./backend/engine/match_engine.py
./backend/engine/player.py
./backend/engine/team.py
./backend/requirements.txt
./backend/tests/__init__.py
./backend/tests/test_player.py
./backend/tests/test_match_engine.py
./backend/tests/test_api.py
./frontend/manager.html
./frontend/manager3d.html
./docs/superpowers/specs/2026-06-08-soccer-game-design.md
./docs/superpowers/plans/2026-06-08-phase0-code-cleanup.md
```

- [ ] **Step 8: 이동 완료 후 테스트 재확인**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game/backend"
python -m pytest tests/ -v
```

Expected: 모든 테스트 PASS

- [ ] **Step 9: Commit**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
git add backend/ frontend/ docs/
git commit -m "refactor: restructure project into backend/ and frontend/ directories"
```

---

## Task 5: 레거시 파일 삭제

**Files:**
- Delete: `player_maker.py`
- Delete: `demo.html`

- [ ] **Step 1: 파일 삭제**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
rm player_maker.py demo.html
```

- [ ] **Step 2: 테스트 재실행 (삭제 영향 없음 확인)**

```bash
cd backend
python -m pytest tests/ -v
```

Expected: 모든 테스트 PASS

- [ ] **Step 3: Commit**

```bash
cd ..
git add -u
git commit -m "chore: remove legacy player_maker.py and demo.html"
```

---

## Task 6: manager.html 내장 시뮬레이션 JS → API 호출로 교체

**Files:**
- Modify: `frontend/manager.html`

> 목표: `startMatch()` 함수가 내장 `simulate()` 대신 `POST /match/simulate`를 호출하도록 변경. 이벤트 피드 렌더링 로직은 유지.

- [ ] **Step 1: manager.html에서 내장 simulate 함수 위치 확인**

`frontend/manager.html`에서 `function simulate(` 를 검색해 해당 함수 전체 범위를 파악한다.

- [ ] **Step 2: startMatch() 함수를 API 호출 방식으로 교체**

`frontend/manager.html`에서 `function startMatch(){` 부분을 찾아 아래 코드로 교체:

```javascript
async function startMatch(){
  if(matchRunning) return;
  if(!mySquad) regenSquad();

  const hn = document.getElementById('teamNameInput').value || 'My Team';

  document.getElementById('kickoffBtn').disabled = true;
  document.getElementById('eventsFeed').innerHTML = '<div style="color:#6b8cae;padding:8px">경기 시뮬레이션 중...</div>';
  document.getElementById('sbScore').textContent = '0 : 0';
  document.getElementById('progressBar').style.width = '0';
  document.getElementById('minuteLabel').textContent = "0'";
  document.getElementById('matchStatus').className = 'match-status live';
  document.getElementById('matchStatus').textContent = 'LIVE';

  let result;
  try {
    const res = await fetch('http://localhost:8000/match/simulate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        home_team_name: hn,
        away_team_name: 'Rival FC',
        home_players: mySquad.map(p => ({
          id: p.id, name: p.name || `Player_${p.id}`,
          position: p.pos, nationality: p.nation || 'Unknown',
          rating: p.rating, tier: p.tier, stats: p.stats
        }))
      })
    });
    if (!res.ok) throw new Error(`API 오류: ${res.status}`);
    result = await res.json();
  } catch (e) {
    document.getElementById('eventsFeed').innerHTML =
      `<div style="color:#ef5350;padding:8px">서버 연결 실패: ${e.message}<br>백엔드를 먼저 실행하세요: uvicorn api.main:app --reload</div>`;
    document.getElementById('kickoffBtn').disabled = false;
    return;
  }

  matchRunning = true;
  let idx = 0, hScore = 0, aScore = 0, hSh = 0, aSh = 0, hOn = 0, aOn = 0;
  const allEvents = result.events;

  ['H','A'].forEach(s => ['Shots','On'].forEach(k => {
    document.getElementById(`sc${k}${s}`).textContent = '0';
    document.getElementById(`bar${k}${s}`).style.width = '0';
  }));
  document.getElementById('possH').textContent = Math.round(result.possession_home) + '%';
  document.getElementById('possA').textContent = Math.round(100 - result.possession_home) + '%';
  document.getElementById('possBarH').style.width = result.possession_home + '%';
  document.getElementById('possBarA').style.width = (100 - result.possession_home) + '%';

  function tick(){
    if(idx >= allEvents.length){
      finishMatch(result, hn); return;
    }
    const ev = allEvents[idx++];
    const min = ev.min || ev.minute || 0;
    document.getElementById('progressBar').style.width = Math.min(min/90*100, 100) + '%';
    document.getElementById('minuteLabel').textContent = min + "'";

    if(ev.type === 'goal'){
      if(ev.side === 'home'){ hScore++; hSh++; hOn++; }
      else { aScore++; aSh++; aOn++; }
      document.getElementById('sbScore').textContent = hScore + ' : ' + aScore;
    }

    const feed = document.getElementById('eventsFeed');
    const div = document.createElement('div');
    div.className = 'event-row' + (ev.type === 'goal' ? ' ev-goal' : '');
    div.innerHTML = `<span class="ev-min">${min}'</span><span class="ev-text">${ev.description || ev.text || ev.type}</span>`;
    feed.insertBefore(div, feed.firstChild);

    matchTimer = setTimeout(tick, matchSpeed);
  }
  tick();
}
```

- [ ] **Step 3: 내장 simulate() 함수 제거**

`frontend/manager.html`에서 `function simulate(` 로 시작하는 함수 블록 전체를 찾아 삭제한다. 이 함수는 내장 경기 엔진 로직을 담고 있으며 API 호출로 대체되었으므로 더 이상 필요하지 않다.

- [ ] **Step 4: 브라우저에서 동작 확인**

백엔드 실행:
```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game/backend"
uvicorn api.main:app --reload
```

브라우저에서 `frontend/manager.html` 열고:
1. "스쿼드 생성" 버튼 클릭 → 선수 목록 표시됨
2. Match 탭 → "킥오프" 버튼 클릭 → 이벤트 피드에 경기 진행 표시됨
3. 경기 종료 후 최종 스코어 표시됨

- [ ] **Step 5: Commit**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
git add frontend/manager.html
git commit -m "refactor: replace inline simulate() with API call in manager.html"
```

---

## Task 7: README.md 작성

**Files:**
- Create: `README.md`

- [ ] **Step 1: README.md 작성**

프로젝트 루트에 `README.md` 생성:

```markdown
# Football Manager Mobile Game

Football Manager 스타일 모바일 게임. 현재 Phase 0 (코드 정리) 완료.

## 프로젝트 구조

```
backend/   - Python FastAPI + 경기 시뮬레이션 엔진
frontend/  - 웹 프로토타입 UI (Flutter 앱 개발 전 참조용)
docs/      - 설계 문서 및 구현 계획
```

## 백엔드 실행

```bash
cd backend
pip install -r requirements.txt
uvicorn api.main:app --reload
```

API: http://localhost:8000
문서: http://localhost:8000/docs

## 테스트 실행

```bash
cd backend
python -m pytest tests/ -v
```

## 기술 스택

- **백엔드 (임시):** Python, FastAPI, NumPy
- **목표 백엔드:** Supabase (PostgreSQL + Edge Functions)
- **목표 프론트엔드:** Flutter (iOS/Android)

## 로드맵

- [x] Phase 0: 코드 정리 및 구조 재편
- [ ] Phase 1: Flutter MVP + Supabase 연결
- [ ] Phase 2: 경기 엔진 → Supabase Edge Function 이전
- [ ] Phase 3: 게임 기능 확장 (리그, 이적 시장, 선수 성장)
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with project structure and roadmap"
```

---

## Task 8: 최종 검증

- [ ] **Step 1: 전체 테스트 통과 확인**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game/backend"
python -m pytest tests/ -v
```

Expected 출력 (예시):
```
tests/test_player.py::test_generate_player_returns_valid_player PASSED
tests/test_player.py::test_generate_player_random_position PASSED
tests/test_player.py::test_generate_player_stats_in_range PASSED
tests/test_player.py::test_generate_squad_returns_11_players PASSED
tests/test_player.py::test_generate_squad_has_gk PASSED
tests/test_player.py::test_player_to_dict_has_required_keys PASSED
tests/test_player.py::test_tier_thresholds_coverage PASSED
tests/test_match_engine.py::test_simulate_returns_result PASSED
tests/test_match_engine.py::test_simulate_result_has_scores PASSED
tests/test_match_engine.py::test_simulate_result_has_events PASSED
tests/test_match_engine.py::test_simulate_multiple_runs_are_different PASSED
tests/test_api.py::test_root_returns_ok PASSED
tests/test_api.py::test_generate_player_endpoint PASSED
tests/test_api.py::test_generate_player_invalid_position PASSED
tests/test_api.py::test_generate_squad_endpoint PASSED
tests/test_api.py::test_quick_match_endpoint PASSED
```

- [ ] **Step 2: 루트 디렉토리에 불필요한 파일 없음 확인**

```bash
cd "c:/Users/e2ken/OneDrive/바탕 화면/동찬_/02. 게임/web3_soccer_game"
ls
```

Expected: `backend/  docs/  frontend/  README.md` 만 존재

- [ ] **Step 3: 최종 Commit**

```bash
git add -A
git commit -m "chore: phase 0 complete - project restructured and legacy files removed"
```

---

## 다음 단계

Phase 0 완료 후 → **Phase 1 계획 작성**

Phase 1 범위:
- Flutter 프로젝트 셋업 (iOS + Android)
- Supabase 프로젝트 생성 + 스키마 마이그레이션
- Auth (로그인 / 회원가입)
- 팀 생성 + 초기 스쿼드 생성
- AI와 경기 + 결과 저장
- 홈 화면 + 스쿼드 관리 화면
