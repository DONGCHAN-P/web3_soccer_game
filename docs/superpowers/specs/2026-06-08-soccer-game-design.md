# Football Manager 모바일 게임 — 설계 문서

**날짜:** 2026-06-08  
**상태:** 승인됨

---

## 1. 프로젝트 개요

현재 Python FastAPI 기반 웹 축구 시뮬레이션 게임을 **Flutter 모바일 앱 + Supabase 백엔드** 구조로 전환한다. 목표는 싱글플레이어 Football Manager 스타일의 모바일 게임이며, P2P 멀티플레이어는 이후 단계에서 추가한다.

### 핵심 방향

- **플랫폼:** Flutter (iOS + Android 동시 지원)
- **백엔드:** Supabase (PostgreSQL + Edge Functions)
- **게임 스타일:** 싱글플레이어, AI 상대와 시즌 진행
- **멀티플레이어:** Phase 3에서 비동기 P2P 추가 (현재 범위 외)

---

## 2. 전환 전략 — 점진적 전환 (방식 A)

언제나 동작하는 버전을 유지하면서 단계적으로 이전한다.

```
Phase 0 → Phase 1 → Phase 2 → Phase 3
코드정리   Flutter MVP  엔진이전    기능확장
```

| 단계 | 내용 | 결과물 |
|------|------|--------|
| **Phase 0** | 코드 정리 | 깔끔한 Python API, 레거시 제거, 폴더 재편 |
| **Phase 1** | Flutter MVP + Supabase 연결 | 로그인, 팀 생성, AI 경기, 결과 저장 |
| **Phase 2** | 경기 엔진 → Edge Function 이전 | Python 의존성 제거, 시즌/리그 추가 |
| **Phase 3** | 게임 기능 확장 | 이적 시장, 선수 성장, (P2P 선택) |

---

## 3. 아키텍처

```
┌─────────────────────────────────────────┐
│           Flutter 앱 (모바일)             │
│  - 팀 관리 / 전술 / 선수 스카우트          │
│  - AI 상대팀과 경기                       │
│  - 리그 / 시즌 진행                       │
└────────────┬────────────────────────────┘
             │ HTTP / Supabase SDK
    ┌────────▼────────────┐
    │   Supabase           │
    │  - Auth (계정 관리)  │
    │  - PostgreSQL DB     │
    │  - Realtime (알림)   │
    │  - Edge Functions    │
    │    └ 경기 시뮬레이션  │
    └─────────────────────┘
             │ (임시, Phase 0~1)
    ┌────────▼────────────┐
    │  Python FastAPI      │
    │  (현재 경기 엔진)     │
    │  → Phase 2에서 제거  │
    └─────────────────────┘
```

---

## 4. Phase 0 — 코드 정리

### 삭제

| 파일 | 이유 |
|------|------|
| `player_maker.py` | 레거시 탐색 스크립트. 핵심 로직은 `engine/player.py`에 이미 반영됨 |
| `demo.html` | `manager.html`로 통합 가능 |

### 이동

| 파일 | 현재 위치 | 목표 위치 |
|------|-----------|-----------|
| `engine/` | 루트 | `backend/engine/` |
| `api/` | 루트 | `backend/api/` |
| `requirements.txt` | 루트 | `backend/requirements.txt` |
| `manager.html` | 루트 | `frontend/manager.html` |
| `manager3d.html` | 루트 | `frontend/manager3d.html` (보관) |

### 수정

- `manager.html` 내장 JS 로직 → API 호출 방식으로 교체
- `api/main.py` 엔드포인트 정리 및 주석 보완

### 목표 폴더 구조

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
│   └── requirements.txt
├── frontend/
│   ├── manager.html
│   └── manager3d.html
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-06-08-soccer-game-design.md
└── README.md
```

### 선수 생성 엔진 개념 (보존)

`engine/player.py`에 이미 구현된 핵심 개념:

- 포지션별 주요/보조 능력치 (주요 70% + 보조 30% 가중 평균)
- 포지션 분포 비율 (GK 10%, CB 20% 등 실제 축구 기준)
- FIFA 100개국 국적 배정 (선수 레이팅에 비례한 지수 가중치)
- N / S / R / W / G 등급 시스템 (60 미만 ~ 90 이상)
- 정규분포 기반 스탯 생성 (주요: μ=70, 보조: μ=60, 기타: μ=35)

---

## 5. Supabase 스키마

### 테이블 관계

```
users (Supabase Auth)
  └── teams
        ├── players
        │     └── player_stats
        ├── squad_slots
        ├── seasons
        │     └── matches
        │           └── match_events
        └── transfer_listings (Phase 3)
```

### 테이블 정의

**`teams`**
```sql
id          uuid PK
user_id     uuid FK → auth.users
name        text
balance     integer  -- 이적 시장용 (Phase 3)
created_at  timestamptz
```

**`players`**
```sql
id          uuid PK
team_id     uuid FK → teams
name        text
position    text  -- GK/CB/RB/LB/CDM/CM/CAM/RW/LW/ST
nationality text
rating      float
tier        text  -- N/S/R/W/G
age         integer
is_for_sale boolean
```

**`player_stats`**
```sql
player_id       uuid FK → players
attribute_name  text
value           integer
PRIMARY KEY (player_id, attribute_name)
```

**`seasons`**
```sql
id             uuid PK
team_id        uuid FK → teams
season_number  integer
wins           integer
draws          integer
losses         integer
goals_for      integer
goals_against  integer
status         text  -- active / completed
```

**`matches`**
```sql
id              uuid PK
season_id       uuid FK → seasons
home_team_id    uuid FK → teams
away_team_name  text   -- AI 상대는 이름만 저장
home_score      integer
away_score      integer
played_at       timestamptz
```

**`match_events`**
```sql
id          uuid PK
match_id    uuid FK → matches
minute      integer
event_type  text  -- goal / save / tackle / miss
player_id   uuid FK → players (nullable)
description text
```

**`squad_slots`**
```sql
id             uuid PK
team_id        uuid FK → teams
formation      text  -- 4-3-3 등
slot_position  text  -- GK / CB1 / CB2 등
player_id      uuid FK → players
```

### 설계 원칙

- `player_stats` 별도 테이블 → 능력치 추가 시 스키마 변경 불필요
- AI 상대팀은 매치 시 즉석 생성 → DB에 영구 저장하지 않음
- Edge Function이 경기 시뮬레이션 실행 → 결과만 저장

---

## 6. Flutter 앱 화면 구조

### 네비게이션

```
앱 진입
  ├── 로그인 / 회원가입
  └── 홈 (메인 허브)
        ├── 내 팀
        │     ├── 스쿼드 관리 (선발 11명 + 교체)
        │     ├── 선수 목록
        │     └── 포메이션 설정
        ├── 경기
        │     ├── 경기 시작 (AI 상대)
        │     ├── 경기 진행 (이벤트 피드)
        │     └── 경기 결과
        ├── 시즌
        │     ├── 순위표 / 일정
        │     └── 시즌 통계
        └── 설정
```

### 화면 흐름

```
로그인 → 구단 이름 설정 → 초기 스쿼드 생성
  → 홈 → 스쿼드 확인 → 경기 시작
  → 경기 이벤트 피드 → 결과 화면
  → 홈 (시즌 업데이트)
```

### 핵심 화면 구성요소

| 화면 | 주요 구성요소 |
|------|--------------|
| **홈** | 다음 경기 카드, 시즌 순위 미리보기, 최근 결과 |
| **스쿼드 관리** | 포메이션 피치 뷰, 선수 카드, 드래그앤드롭 |
| **경기 진행** | 실시간 이벤트 피드, 스코어, 점유율/슈팅 통계, 교체 버튼 |
| **선수 상세** | 능력치 레이더 차트, 등급 배지, 국적/나이 |

---

## 7. 미결 사항

- 선수 이름 생성 방식 (랜덤 생성 vs 실제 이름 DB)
- 포메이션 종류 (4-3-3 외 추가 여부)
- 시즌 구조 (경기 수, AI 팀 수)
- 앱 이름 / 브랜딩
