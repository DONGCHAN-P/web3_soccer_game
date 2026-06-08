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
